import 'package:libprolog/libprolog.dart';

/// Example: ISO-Compliant Parser
///
/// Demonstrates the Prolog parser including:
/// - Lexical analysis (tokenization)
/// - Syntactic analysis (parsing)
/// - Operator precedence handling
/// - List notation
/// - Clause parsing (facts and rules)
void main() {
  print('=== ISO-Compliant Parser ===\n');

  // Example 1: Basic Terms
  print('--- Example 1: Parsing Basic Terms ---');
  basicTerms();

  // Example 2: Operator Precedence
  print('\n--- Example 2: Operator Precedence ---');
  operatorPrecedence();

  // Example 3: List Notation
  print('\n--- Example 3: List Notation ---');
  listNotation();

  // Example 4: Clauses (Facts and Rules)
  print('\n--- Example 4: Parsing Clauses ---');
  clauseParsing();

  // Example 5: Complex Expressions
  print('\n--- Example 5: Complex Expressions ---');
  complexExpressions();

  // Example 6: Complete Program
  print('\n--- Example 6: Complete Prolog Program ---');
  completeProgram();
}

/// Demonstrates parsing basic Prolog terms.
void basicTerms() {
  // Atoms
  final atom = Parser.parseTerm('hello');
  print('Atom: hello → $atom');

  // Variables
  final variable = Parser.parseTerm('X');
  print('Variable: X → $variable');

  // Numbers
  final integer = Parser.parseTerm('42');
  print('Integer: 42 → $integer');

  final float = Parser.parseTerm('3.14');
  print('Float: 3.14 → $float');

  // Compound terms
  final compound = Parser.parseTerm('parent(john, mary)');
  print('Compound: parent(john, mary) → $compound');
}

/// Demonstrates operator precedence parsing.
void operatorPrecedence() {
  // Arithmetic precedence
  final expr1 = Parser.parseTerm('X + Y * Z');
  print('Expression: X + Y * Z');
  print('Parsed as: $expr1');
  print('(* binds tighter than +)\n');

  // Parentheses override precedence
  final expr2 = Parser.parseTerm('(X + Y) * Z');
  print('Expression: (X + Y) * Z');
  print('Parsed as: $expr2\n');

  // Left associativity
  final expr3 = Parser.parseTerm('A + B + C');
  print('Expression: A + B + C');
  print('Parsed as: $expr3');
  print('(+ is left-associative)\n');

  // Comparison operators
  final expr4 = Parser.parseTerm('X < Y');
  print('Expression: X < Y');
  print('Parsed as: $expr4');
}

/// Demonstrates list notation parsing.
void listNotation() {
  // Empty list
  final empty = Parser.parseTerm('[]');
  print('Empty list: [] → $empty');

  // List with elements
  final list1 = Parser.parseTerm('[1, 2, 3]');
  print('List: [1, 2, 3] → $list1');

  // List with head and tail
  final list2 = Parser.parseTerm('[H|T]');
  print('List with tail: [H|T] → $list2');

  // List with elements and tail
  final list3 = Parser.parseTerm('[1, 2|Rest]');
  print('Mixed list: [1, 2|Rest] → $list3');

  // String as character code list
  final str = Parser.parseTerm('"hello"');
  print('String: "hello" → (character codes)');
  if (str is Compound) {
    print(
      '  First char code: ${(str.args[0] as PrologInteger).value}',
    ); // 'h' = 104
  }
}

/// Demonstrates clause parsing (facts and rules).
void clauseParsing() {
  // Simple fact
  final fact = Parser.parse('cat(tom).');
  print('Fact: cat(tom).');
  print('Parsed: ${fact[0]}\n');

  // Rule with single goal
  final rule1 = Parser.parse('mortal(X) :- human(X).');
  print('Rule: mortal(X) :- human(X).');
  print('Parsed: ${rule1[0]}');
  print('Body goals: ${rule1[0].body.length}\n');

  // Rule with multiple goals
  final rule2 = Parser.parse(
    'grandparent(X, Z) :- parent(X, Y), parent(Y, Z).',
  );
  print('Rule: grandparent(X, Z) :- parent(X, Y), parent(Y, Z).');
  print('Parsed: ${rule2[0]}');
  print('Body goals: ${rule2[0].body.length}');
  print('  Goal 1: ${rule2[0].body[0]}');
  print('  Goal 2: ${rule2[0].body[1]}');
}

/// Demonstrates parsing complex expressions.
void complexExpressions() {
  // Arithmetic with is/2
  final arith = Parser.parseTerm('Result is X + Y * 2');
  print('Arithmetic: Result is X + Y * 2');
  print('Parsed: $arith\n');

  // Negation as failure
  final negation = Parser.parseTerm(r'\+ member(X, L)');
  print(r'Negation: \+ member(X, L)');
  print('Parsed: $negation\n');

  // Conjunction in parentheses
  final conj = Parser.parseTerm('(a, b, c)');
  print('Conjunction: (a, b, c)');
  print('Parsed: $conj');
  print('(comma is right-associative)\n');

  // Unification
  final unif = Parser.parseTerm('X = f(Y, Z)');
  print('Unification: X = f(Y, Z)');
  print('Parsed: $unif');
}

/// Demonstrates parsing a complete Prolog program.
void completeProgram() {
  final source = '''
    % Facts about family relationships
    parent(john, mary).
    parent(john, tom).
    parent(mary, alice).
    parent(mary, bob).

    % Rules
    grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
    sibling(X, Y) :- parent(P, X), parent(P, Y).

    % Lists
    member(X, [X|_]).
    member(X, [_|T]) :- member(X, T).
  ''';

  print('Parsing complete program:');
  print(source);

  final clauses = Parser.parse(source);
  print('Successfully parsed ${clauses.length} clauses:');
  for (var i = 0; i < clauses.length; i++) {
    final clause = clauses[i];
    print(
      '  ${i + 1}. ${clause.indicator} - ${clause.isFact ? "fact" : "rule"}',
    );
  }

  // Show structure of a rule
  print('\nDetailed view of grandparent rule:');
  final grandparentRule = clauses[4]; // grandparent rule
  print('  Head: ${grandparentRule.head}');
  print('  Body:');
  for (var goal in grandparentRule.body) {
    print('    - $goal');
  }
}
