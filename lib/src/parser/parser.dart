import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/variable.dart';
import '../terms/variable_factory.dart';
import '../terms/compound.dart';
import '../terms/number.dart';
import '../engine/clause.dart';
import '../exceptions/prolog_exception.dart' as exceptions;
import 'token.dart';
import 'lexer.dart';
import 'operator.dart';

/// ISO-compliant Prolog parser.
///
/// Implements operator precedence parsing for Prolog terms and clauses.
/// Supports:
/// - Operator precedence (1-1200)
/// - Prefix, infix, and postfix operators
/// - List notation [H|T]
/// - Curly braces {Goals}
/// - Standard Prolog syntax
class Parser {
  final List<Token> tokens;
  final OperatorTable operators;
  final VariableFactory _variableFactory;

  int current = 0;

  /// Variable scope for current clause/term being parsed.
  /// Maps variable names to Variable instances to ensure same-named
  /// variables within a clause share the same object.
  Map<String, Variable> _variables = {};

  Parser(
    this.tokens, {
    OperatorTable? operators,
    VariableFactory? variableFactory,
  }) : operators = operators ?? OperatorTable(),
       _variableFactory = variableFactory ?? VariableFactory();

  /// Parses Prolog source code and returns list of clauses.
  static List<Clause> parse(final String source, {OperatorTable? operators}) {
    final lexer = Lexer(source);
    final tokens = lexer.scanTokens();
    final parser = Parser(tokens, operators: operators);
    return parser.parseClauses();
  }

  /// Parses a single term from source.
  static Term parseTerm(final String source, {OperatorTable? operators}) {
    final lexer = Lexer(source);
    final tokens = lexer.scanTokens();
    final parser = Parser(tokens, operators: operators);
    parser._variables = {}; // Reset variable scope
    return parser.term();
  }

  /// Parses multiple clauses (a Prolog program).
  List<Clause> parseClauses() {
    final clauses = <Clause>[];

    while (!isAtEnd) {
      // Skip any standalone dots
      if (check(TokenType.dot)) {
        advance();
        continue;
      }

      clauses.add(parseClause());
    }

    return clauses;
  }

  /// Parses a single clause (fact or rule).
  Clause parseClause() {
    // Reset variable scope for this clause
    _variables = {};
    _variableFactory.reset();

    // Parse the entire clause term (which might include :-)
    final clauseTerm = term();

    // Check if it's a rule (head :- body)
    if (clauseTerm is Compound &&
        clauseTerm.functor == Atom(':-') &&
        clauseTerm.arity == 2) {
      // It's a rule
      final head = clauseTerm.args[0];
      final bodyTerm = clauseTerm.args[1];

      // Expand body into list of goals
      final body = <Term>[];
      _expandConjunction(bodyTerm, body);

      expect(TokenType.dot, 'Expected . at end of clause');
      return Clause(head, body);
    }

    // It's a fact
    expect(TokenType.dot, 'Expected . at end of clause');
    return Clause(clauseTerm);
  }

  /// Expands a conjunction term into a flat list of goals.
  void _expandConjunction(final Term term, final List<Term> goals) {
    if (term is Compound && term.functor == Atom(',') && term.arity == 2) {
      _expandConjunction(term.args[0], goals);
      _expandConjunction(term.args[1], goals);
    } else {
      goals.add(term);
    }
  }

  /// Parses a term with maximum precedence (1200).
  Term term() {
    return expression(1200);
  }

  /// Parses a term with given maximum precedence (operator precedence climbing).
  ///
  /// Implements operator precedence climbing algorithm.
  Term expression(final int maxPrecedence) {
    // Try prefix operator
    final prefixOp = operators.lookupPrefix(peekAtomValue());
    if (prefixOp != null && prefixOp.precedence <= maxPrecedence) {
      advance(); // consume operator
      final argPrec = prefixOp.type == OperatorType.fx
          ? prefixOp.precedence - 1
          : prefixOp.precedence;
      final arg = expression(argPrec);
      return Compound(Atom(prefixOp.name), [arg]);
    }

    // Parse primary term
    var left = parsePrimary();

    // Try infix and postfix operators
    while (true) {
      // Try postfix operator
      final postfixOp = operators.lookupPostfix(peekAtomValue());
      if (postfixOp != null && postfixOp.precedence <= maxPrecedence) {
        advance(); // consume operator
        left = Compound(Atom(postfixOp.name), [left]);
        continue;
      }

      // Try infix operator
      final infixOp = operators.lookupInfix(peekAtomValue());
      if (infixOp == null || infixOp.precedence > maxPrecedence) {
        break; // No more operators at this precedence level
      }

      // Consume operator token (might be atom, comma, or pipe)
      if (check(TokenType.comma)) {
        advance(); // consume comma as operator
      } else if (check(TokenType.pipe)) {
        advance(); // consume pipe as operator
      } else {
        advance(); // consume atom operator
      }

      // Determine right operand precedence
      final rightPrec = switch (infixOp.type) {
        OperatorType.xfx => infixOp.precedence - 1, // Non-associative
        OperatorType.xfy => infixOp.precedence, // Right-associative
        OperatorType.yfx => infixOp.precedence - 1, // Left-associative
        _ => throw ParserError('Invalid infix operator type', peek()),
      };

      final right = expression(rightPrec);
      left = Compound(Atom(infixOp.name), [left, right]);
    }

    return left;
  }

  /// Parses a primary term (atom, variable, number, compound, list, etc.).
  Term parsePrimary() {
    // Variable
    if (match(TokenType.variable)) {
      final name = previous().value as String;
      // Reuse existing variable instance if we've seen this name in current scope
      return _variables.putIfAbsent(
        name,
        () => _variableFactory.createVariable(name),
      );
    }

    // Number
    if (match(TokenType.integer)) {
      return PrologInteger(previous().value as int);
    }
    if (match(TokenType.float)) {
      return PrologFloat(previous().value as double);
    }

    // String (converted to list of character codes)
    if (match(TokenType.string)) {
      final str = previous().value as String;
      return _stringToList(str);
    }

    // List notation [...]
    if (match(TokenType.leftBracket)) {
      return parseList();
    }

    // Curly braces {Term}
    if (match(TokenType.leftBrace)) {
      if (match(TokenType.rightBrace)) {
        // Empty braces: {}
        return Atom('{}');
      }
      final t = term();
      expect(TokenType.rightBrace, 'Expected }');
      return Compound(Atom('{}'), [t]);
    }

    // Parenthesized term or compound
    if (match(TokenType.leftParen)) {
      final t = term();
      expect(TokenType.rightParen, 'Expected )');
      return t;
    }

    // Atom or compound term
    if (match(TokenType.atom)) {
      final atomName = previous().value as String;
      final atom = Atom(atomName);

      // Check for compound term: functor(args)
      if (match(TokenType.leftParen)) {
        if (match(TokenType.rightParen)) {
          // functor() - still a compound with arity 0? No, syntax error in ISO
          throw ParserError('Empty argument list not allowed', previous());
        }

        final args = parseArguments();
        expect(TokenType.rightParen, 'Expected )');
        return Compound(atom, args);
      }

      // Just an atom
      return atom;
    }

    throw ParserError('Expected term', peek());
  }

  /// Parses list notation: [], [H|T], [1,2,3], [1,2|T].
  Term parseList() {
    // Empty list: []
    if (match(TokenType.rightBracket)) {
      return Atom.nil;
    }

    final elements = <Term>[];

    // Parse first element (up to precedence 999 to exclude comma operator at 1000)
    elements.add(expression(999));

    // Parse remaining elements
    while (match(TokenType.comma)) {
      elements.add(expression(999));
    }

    // Check for tail: [H|T]
    Term? tail;
    if (match(TokenType.pipe)) {
      tail = expression(999);
    }

    expect(TokenType.rightBracket, 'Expected ]');

    // Build list structure
    return Compound.fromList(elements, tail);
  }

  /// Parses function arguments (comma-separated terms).
  List<Term> parseArguments() {
    final args = <Term>[];

    // Parse arguments up to precedence 999 to exclude comma operator
    args.add(expression(999));

    while (match(TokenType.comma)) {
      args.add(expression(999));
    }

    return args;
  }

  /// Converts a string to a list of character codes.
  Term _stringToList(final String str) {
    final codes = str.codeUnits.map((c) => PrologInteger(c)).toList();
    return Compound.fromList(codes);
  }

  /// Returns the atom value of the current token, or empty string.
  String peekAtomValue() {
    if (check(TokenType.atom)) {
      return peek().value as String? ?? '';
    }
    // Handle comma as an operator (it has both roles: separator and operator)
    if (check(TokenType.comma)) {
      return ',';
    }
    // Handle pipe as an operator (it has both roles: list tail separator and disjunction)
    if (check(TokenType.pipe)) {
      return '|';
    }
    return '';
  }

  // Token navigation helpers

  bool match(final TokenType type) {
    if (check(type)) {
      advance();
      return true;
    }
    return false;
  }

  bool check(final TokenType type) {
    if (isAtEnd) return false;
    return peek().type == type;
  }

  Token advance() {
    if (!isAtEnd) current++;
    return previous();
  }

  bool get isAtEnd => peek().type == TokenType.eof;

  Token peek() => tokens[current];

  Token previous() => tokens[current - 1];

  void expect(final TokenType type, final String message) {
    if (check(type)) {
      advance();
      return;
    }
    throw ParserError(message, peek());
  }
}

/// Parser error exception (kept for backwards compatibility in this file).
class ParserError extends exceptions.ParserError {
  final Token token;

  ParserError(super.message, this.token)
    : super(line: token.line, column: token.column);

  @override
  String toString() =>
      'Parser error at line ${token.line}, column ${token.column}: $message (got ${token.type})';
}
