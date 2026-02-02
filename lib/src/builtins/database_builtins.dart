import 'dart:io';
import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../terms/number.dart';
import '../terms/variable.dart';
import '../database/database.dart';
import '../engine/clause.dart';
import '../parser/parser.dart';
import '../parser/lexer.dart';
import 'builtin.dart';

/// Creates an ISO instantiation_error.
/// Format: error(instantiation_error, Context)
BuiltinError _instantiationError(final String context) {
  return BuiltinError(
    Compound(Atom('error'), [Atom('instantiation_error'), Atom(context)]),
  );
}

/// Creates an ISO type_error.
/// Format: error(type_error(ExpectedType, Culprit), Context)
BuiltinError _typeError(
  final String expected,
  final Term culprit,
  final String context,
) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('type_error'), [Atom(expected), culprit]),
      Atom(context),
    ]),
  );
}

/// Creates an ISO permission_error.
/// Format: error(permission_error(Operation, ObjectType, Culprit), Context)
/// Reserved for future use (e.g., static predicate modification).
// ignore: unused_element
BuiltinError _permissionError(
  final String operation,
  final String type,
  final Term culprit,
  final String context,
) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('permission_error'), [
        Atom(operation),
        Atom(type),
        culprit,
      ]),
      Atom(context),
    ]),
  );
}

/// Registers database manipulation built-ins.
///
/// Note: These provide Prolog-level access to the database.
/// The Database and PrologEngine classes provide Dart-level APIs.
void registerDatabaseBuiltins(
  final BuiltinRegistry registry,
  final Database database,
) {
  // asserta/1 - assert clause at beginning
  registry.register('asserta', 1, (context) => _asserta(context, database));

  // assertz/1 - assert clause at end
  registry.register('assertz', 1, (context) => _assertz(context, database));

  // assert/1 - same as assertz/1 (ISO default)
  registry.register('assert', 1, (context) => _assertz(context, database));

  // retract/1 - retract first matching clause
  registry.register('retract', 1, (context) => _retract(context, database));

  // abolish/1 - remove all clauses for a predicate
  registry.register('abolish', 1, (context) => _abolish(context, database));

  // consult/1 - load Prolog file
  registry.register('consult', 1, (context) => _consult(context, database));

  // load/1 - alias for consult/1
  registry.register('load', 1, (context) => _consult(context, database));
}

/// Implements asserta/1: asserta(+Clause).
///
/// Adds Clause at the beginning of the database.
/// ISO errors:
/// - instantiation_error if Clause is a variable
/// - type_error(callable, Clause) if Clause is not callable
BuiltinResult _asserta(final BuiltinContext context, final Database database) {
  final term = context.arg(0);

  // ISO: Clause must not be a variable
  if (term is Variable) {
    return _instantiationError('asserta/1');
  }

  // ISO: Clause must be callable (atom or compound)
  if (!term.isCallable) {
    return _typeError('callable', term, 'asserta/1');
  }

  try {
    final clause = _termToClause(term);
    database.asserta(clause);
    return const BuiltinSuccess();
  } catch (e) {
    return _typeError('callable', term, 'asserta/1');
  }
}

/// Implements assertz/1: assertz(+Clause).
///
/// Adds Clause at the end of the database.
/// ISO errors:
/// - instantiation_error if Clause is a variable
/// - type_error(callable, Clause) if Clause is not callable
BuiltinResult _assertz(final BuiltinContext context, final Database database) {
  final term = context.arg(0);

  // ISO: Clause must not be a variable
  if (term is Variable) {
    return _instantiationError('assertz/1');
  }

  // ISO: Clause must be callable (atom or compound)
  if (!term.isCallable) {
    return _typeError('callable', term, 'assertz/1');
  }

  try {
    final clause = _termToClause(term);
    database.assertz(clause);
    return const BuiltinSuccess();
  } catch (e) {
    return _typeError('callable', term, 'assertz/1');
  }
}

/// Implements retract/1: retract(+Clause).
///
/// Retracts the first clause that unifies with Clause.
/// ISO errors:
/// - instantiation_error if Clause (or its head) is a variable
/// - type_error(callable, Clause) if Clause is not callable
BuiltinResult _retract(final BuiltinContext context, final Database database) {
  final term = context.arg(0);

  // ISO: Clause must not be a variable
  if (term is Variable) {
    return _instantiationError('retract/1');
  }

  // ISO: Clause must be callable (atom or compound)
  if (!term.isCallable) {
    return _typeError('callable', term, 'retract/1');
  }

  // Check if it's a rule - the head must also be instantiated
  if (term is Compound && term.functor == Atom(':-') && term.arity == 2) {
    final head = term.args[0];
    if (head is Variable) {
      return _instantiationError('retract/1');
    }
    if (!head.isCallable) {
      return _typeError('callable', head, 'retract/1');
    }
  }

  try {
    final clause = _termToClause(term);
    final removed = database.retract(clause);
    return removed ? const BuiltinSuccess() : const BuiltinFailure();
  } catch (e) {
    return _typeError('callable', term, 'retract/1');
  }
}

/// Implements abolish/1: abolish(+PredicateIndicator).
///
/// Removes all clauses for the specified predicate.
/// PredicateIndicator is Name/Arity (e.g., foo/2).
/// ISO errors:
/// - instantiation_error if PredicateIndicator or components are variables
/// - type_error(predicate_indicator, PI) if PI is not Name/Arity form
/// - type_error(atom, Name) if Name is not an atom
/// - type_error(integer, Arity) if Arity is not an integer
/// - domain_error(not_less_than_zero, Arity) if Arity is negative
BuiltinResult _abolish(final BuiltinContext context, final Database database) {
  final indicator = context.arg(0);

  // ISO: PredicateIndicator must not be a variable
  if (indicator is Variable) {
    return _instantiationError('abolish/1');
  }

  // ISO: PredicateIndicator must be Name/Arity
  if (indicator is! Compound ||
      indicator.functor.value != '/' ||
      indicator.arity != 2) {
    return _typeError('predicate_indicator', indicator, 'abolish/1');
  }

  final name = indicator.args[0];
  final arity = indicator.args[1];

  // ISO: Name must not be a variable
  if (name is Variable) {
    return _instantiationError('abolish/1');
  }

  // ISO: Arity must not be a variable
  if (arity is Variable) {
    return _instantiationError('abolish/1');
  }

  // ISO: Name must be an atom
  if (name is! Atom) {
    return _typeError('atom', name, 'abolish/1');
  }

  // ISO: Arity must be an integer
  if (arity is! PrologInteger) {
    return _typeError('integer', arity, 'abolish/1');
  }

  // ISO: Arity must be non-negative
  if (arity.value < 0) {
    return BuiltinError(
      Compound(Atom('error'), [
        Compound(Atom('domain_error'), [Atom('not_less_than_zero'), arity]),
        Atom('abolish/1'),
      ]),
    );
  }

  // Create a dummy term with the functor/arity to match
  final Term headPattern;
  if (arity.value == 0) {
    headPattern = name;
  } else {
    // Create compound with fresh placeholder variables
    // Use Variable instances (not Atom('_')) for proper unification
    final args = List.generate(arity.value, (i) => Variable('_$i'));
    headPattern = Compound(name, args);
  }

  // Retract all clauses matching this predicate
  database.retractAll(headPattern);

  // ISO says abolish/1 always succeeds (even if no clauses removed)
  return const BuiltinSuccess();
}

/// Converts a Prolog term to a Clause.
///
/// Handles both facts (simple terms) and rules (Head :- Body).
Clause _termToClause(final Term term) {
  // Check if it's a rule: Head :- Body
  if (term is Compound && term.functor == Atom(':-') && term.arity == 2) {
    final head = term.args[0];
    final bodyTerm = term.args[1];

    // Parse body into list of goals
    final body = _parseBody(bodyTerm);
    return Clause(head, body);
  }

  // Otherwise it's a fact
  return Clause(term, []);
}

/// Parses a body term into a list of goals.
///
/// Handles conjunction (,/2) by flattening into a list.
List<Term> _parseBody(final Term bodyTerm) {
  if (bodyTerm is Compound &&
      bodyTerm.functor == Atom(',') &&
      bodyTerm.arity == 2) {
    // Conjunction: flatten recursively
    final left = _parseBody(bodyTerm.args[0]);
    final right = _parseBody(bodyTerm.args[1]);
    return [...left, ...right];
  }

  // Single goal
  return [bodyTerm];
}

/// Implements consult/1: consult(+File).
///
/// Loads clauses from a Prolog file into the database.
/// File can be an atom or a string.
BuiltinResult _consult(final BuiltinContext context, final Database database) {
  final file = context.arg(0);

  // Extract filename
  String filename;
  if (file is Atom) {
    filename = file.value;
  } else {
    return const BuiltinFailure();
  }

  // Load the file
  try {
    final result = _loadPrologFile(filename, database);
    return result ? const BuiltinSuccess() : const BuiltinFailure();
  } catch (e) {
    // Silent failure for ISO compliance (or could throw error)
    return const BuiltinFailure();
  }
}

/// Loads a Prolog file into the database.
///
/// Returns true if successful, false otherwise.
/// Handles multi-line clauses and comments properly.
/// Supports both absolute and relative paths.
bool _loadPrologFile(final String path, final Database database) {
  // Resolve relative paths to absolute paths
  final absolutePath = _resolvePath(path);
  final file = File(absolutePath);

  if (!file.existsSync()) {
    return false;
  }

  try {
    final content = file.readAsStringSync();
    final cleaned = _removeFileComments(content);
    final clauses = _splitFileIntoClauses(cleaned);

    for (final text in clauses) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;

      try {
        final lexer = Lexer(trimmed);
        final tokens = lexer.scanTokens();
        final parser = Parser(tokens);
        final term = parser.term();

        database.assertTerm(term);
      } catch (e) {
        // Skip unparseable clauses (could log warning)
        continue;
      }
    }

    return true;
  } catch (e) {
    return false;
  }
}

/// Removes comments from Prolog source code.
///
/// Handles both line comments (%) and block comments (/* ... */).
String _removeFileComments(final String source) {
  final buffer = StringBuffer();
  var i = 0;
  var inQuote = false;
  var quote = '';
  var inBlock = false;

  while (i < source.length) {
    final c = source[i];

    // Handle block comment end
    if (inBlock) {
      if (c == '*' && i + 1 < source.length && source[i + 1] == '/') {
        inBlock = false;
        i += 2;
        continue;
      }
      i++;
      continue;
    }

    // Handle quote start/end (outside block comments)
    if ((c == '"' || c == "'") && (i == 0 || source[i - 1] != '\\')) {
      if (!inQuote) {
        inQuote = true;
        quote = c;
      } else if (c == quote) {
        inQuote = false;
      }
      buffer.write(c);
      i++;
      continue;
    }

    // Inside quotes - just copy
    if (inQuote) {
      buffer.write(c);
      i++;
      continue;
    }

    // Handle block comment start
    if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      inBlock = true;
      i += 2;
      continue;
    }

    // Handle line comment
    if (c == '%') {
      // Skip to end of line
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      // Keep the newline
      if (i < source.length) {
        buffer.write('\n');
        i++;
      }
      continue;
    }

    // Regular character
    buffer.write(c);
    i++;
  }

  return buffer.toString();
}

/// Splits source into individual clauses.
List<String> _splitFileIntoClauses(final String source) {
  final result = <String>[];
  final buffer = StringBuffer();

  var inQuote = false;
  var quote = '';
  var depth = 0;
  var brackets = 0;

  for (var i = 0; i < source.length; i++) {
    final c = source[i];

    if ((c == '"' || c == "'") && (i == 0 || source[i - 1] != '\\')) {
      if (!inQuote) {
        inQuote = true;
        quote = c;
      } else if (c == quote) {
        inQuote = false;
      }
      buffer.write(c);
      continue;
    }

    if (inQuote) {
      buffer.write(c);
      continue;
    }

    if (c == '(' || c == '{') {
      depth++;
      buffer.write(c);
    } else if (c == ')' || c == '}') {
      depth--;
      buffer.write(c);
    } else if (c == '[') {
      brackets++;
      buffer.write(c);
    } else if (c == ']') {
      brackets--;
      buffer.write(c);
    } else if (c == '.' && depth == 0 && brackets == 0) {
      if (i + 1 >= source.length ||
          source[i + 1] == ' ' ||
          source[i + 1] == '\t' ||
          source[i + 1] == '\n' ||
          source[i + 1] == '\r') {
        final clause = buffer.toString().trim();
        if (clause.isNotEmpty) {
          result.add('$clause.');
        }
        buffer.clear();
        continue;
      } else {
        buffer.write(c);
      }
    } else {
      buffer.write(c);
    }
  }

  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) {
    result.add(remaining);
  }

  return result;
}

/// Resolves a file path, converting relative paths to absolute paths.
///
/// If the path is already absolute, returns it unchanged.
/// If the path is relative, resolves it relative to the current working directory.
String _resolvePath(final String path) {
  // Check if path is already absolute
  if (path.startsWith('/') || (path.length >= 2 && path[1] == ':')) {
    // Windows: C:\
    return path;
  }

  // Resolve relative path
  final currentDir = Directory.current.path;
  return '$currentDir/$path';
}
