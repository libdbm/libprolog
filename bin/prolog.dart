#!/usr/bin/env dart

import 'dart:io';
import 'package:libprolog/libprolog.dart';
import 'package:dart_console/dart_console.dart';

/// Whether syntax highlighting is enabled.
var _colorEnabled = true;

/// Interactive Prolog REPL (Read-Eval-Print Loop).
///
/// Start with: `dart run bin/prolog.dart`
void main(final List<String> args) async {
  final console = Console();

  console.writeLine('libprolog REPL v1.0');
  console.writeLine('ISO Prolog interpreter for Dart');
  console.writeLine('Type "help." for commands, "exit." to quit.');
  console.writeLine('Use arrow keys for line editing and command history.');
  console.writeLine(
    'Syntax highlighting is ${Highlighter.success("on")}. Use /nocolor to disable.\n',
  );

  final engine = PrologEngine();
  final history = <String>[];
  var running = true;

  while (running) {
    console.write('?- ');
    final input = _readLineWithHistory(console, history)?.trim() ?? '';

    if (input.isEmpty) continue;

    // Add non-empty input to history
    if (input.isNotEmpty && (history.isEmpty || history.last != input)) {
      history.add(input);
    }

    // Handle REPL commands
    if (input == 'exit.' || input == 'quit.' || input == 'halt.') {
      console.writeLine('Goodbye!');
      running = false;
      continue;
    }

    if (input == 'help.') {
      _printHelp(console);
      continue;
    }

    // Color toggle commands
    if (input == '/color' || input == '/color.') {
      _colorEnabled = true;
      console.writeLine(
        'Syntax highlighting ${Highlighter.success("enabled")}.\n',
      );
      continue;
    }

    if (input == '/nocolor' || input == '/nocolor.') {
      _colorEnabled = false;
      console.writeLine('Syntax highlighting disabled.\n');
      continue;
    }

    if (input == 'listing.' || input.startsWith('listing(')) {
      _listClauses(input, engine, console);
      continue;
    }

    if (input == 'predicates.') {
      _listPredicates(engine, console);
      continue;
    }

    if (input.startsWith('consult(') || input.startsWith('load(')) {
      _consultFile(input, engine, console);
      continue;
    }

    // Parse and execute query
    try {
      final term = Parser.parseTerm(input);

      // Check if it's an assertion
      if (term is Compound && term.functor.value == ':-') {
        if (term.arity == 1) {
          // Directive: :- goal.
          await _executeDirective(term.args[0], engine, console);
        } else if (term.arity == 2) {
          // Rule: head :- body.
          engine.assertz(term);
          console.writeLine('Rule asserted.\n');
        }
        continue;
      }

      // Check if it's a fact to assert vs a query
      // A term is a query if:
      // - It contains variables (e.g., grandparent(X, michael))
      // - It's a builtin predicate
      // - Input contains '?' (explicit query marker)
      // Otherwise, treat it as a fact to assert
      if (input.endsWith('.') &&
          !input.contains('?') &&
          term.isGround &&
          !_isBuiltinQuery(term)) {
        engine.assertz(term);
        console.writeLine('Fact asserted.\n');
        continue;
      }

      // Execute as query
      await _executeQuery(term, engine, console);
    } catch (e) {
      console.writeLine('Error: $e\n');
    }
  }
}

/// Executes a Prolog query and displays results.
Future<void> _executeQuery(
  final Term query,
  final PrologEngine engine,
  final Console console,
) async {
  var count = 0;
  var more = true;

  // Collect original query variable names (not renamed variables like _R0)
  final variables = _collectVariableNames(query);

  try {
    await for (final solution in engine.query(query)) {
      count++;

      // Filter bindings to show only query variables
      final relevantBindings = solution.bindings.entries
          .where((e) => variables.contains(e.key))
          .toList();

      if (relevantBindings.isEmpty) {
        if (_colorEnabled) {
          console.write(Highlighter.success('true'));
        } else {
          console.write('true');
        }
      } else {
        final bindings = relevantBindings
            .map((e) {
              if (_colorEnabled) {
                return '${Highlighter.variable(e.key)} = ${Highlighter.highlight(e.value.toString())}';
              } else {
                return '${e.key} = ${e.value}';
              }
            })
            .join(', ');
        console.write(bindings);
      }

      // Ask user if they want more solutions
      console.write(' ;');
      final response = stdin.readLineSync()?.trim() ?? '';

      if (response.isEmpty || response == ';') {
        continue; // Get next solution
      } else {
        more = false;
        console.writeLine('');
        break;
      }
    }

    if (more) {
      console.writeLine('.');
    }

    if (count == 0) {
      if (_colorEnabled) {
        console.writeLine('${Highlighter.error("false")}.\n');
      } else {
        console.writeLine('false.\n');
      }
    } else {
      console.writeLine('');
    }
  } catch (e) {
    console.writeLine('Error during query: $e\n');
  }
}

/// Collects all variable names from a term (for query variable filtering).
Set<String> _collectVariableNames(final Term term) {
  final vars = <String>{};

  void collect(final Term t) {
    if (t is Variable) {
      vars.add(t.name);
    } else if (t is Compound) {
      for (final arg in t.args) {
        collect(arg);
      }
    }
  }

  collect(term);
  return vars;
}

/// Executes a directive (e.g., :- assert(fact)).
Future<void> _executeDirective(
  final Term goal,
  final PrologEngine engine,
  final Console console,
) async {
  final result = await engine.queryOnce(goal);
  if (result.success) {
    console.writeLine('Directive executed.\n');
  } else {
    console.writeLine('Directive failed.\n');
  }
}

/// Prints help information.
void _printHelp(final Console console) {
  console.writeLine('''
REPL Commands:
  help.              - Show this help
  exit.              - Exit REPL (also: quit., halt.)
  listing.           - List all clauses in database
  listing(pred/N).   - List clauses for specific predicate
  predicates.        - List all predicate indicators
  consult('file').   - Load Prolog file
  /color             - Enable syntax highlighting
  /nocolor           - Disable syntax highlighting

Query Syntax:
  goal.              - Execute query
  fact.              - Assert fact
  rule :- body.      - Assert rule

Examples:
  ?- parent(tom, bob).
  ?- parent(X, bob).
  ?- X = 1, Y = 2.

Special Keys:
  ;                  - Request next solution
  . or Enter         - Stop after current solution
''');
}

/// Lists clauses in the database.
///
/// Supports:
/// - `listing.` - Lists all clauses
/// - `listing(pred/N).` - Lists clauses for specific predicate
void _listClauses(
  final String input,
  final PrologEngine engine,
  final Console console,
) {
  if (engine.clauseCount == 0) {
    console.writeLine('Database is empty.\n');
    return;
  }

  // Check if listing a specific predicate
  if (input.startsWith('listing(')) {
    final match = RegExp(r"listing\(([^)]+)\)").firstMatch(input);
    if (match == null) {
      console.writeLine(
        'Error: Invalid listing syntax. Use: listing(pred/N).\n',
      );
      return;
    }

    final indicator = match.group(1)!;
    _listByIndicator(indicator, engine, console);
    return;
  }

  // List all clauses grouped by predicate
  final byPredicate = engine.clausesByPredicate();
  final indicators = byPredicate.keys.toList()..sort();

  console.writeLine(
    'Database (${engine.clauseCount} clauses, ${indicators.length} predicates):\n',
  );

  for (final indicator in indicators) {
    final clauses = byPredicate[indicator]!;
    console.writeLine(
      '% $indicator (${clauses.length} clause${clauses.length == 1 ? "" : "s"})',
    );
    for (final clause in clauses) {
      console.writeLine(_formatClause(clause));
    }
    console.writeLine('');
  }
}

/// Lists clauses for a specific predicate indicator.
void _listByIndicator(
  final String indicator,
  final PrologEngine engine,
  final Console console,
) {
  final clauses = engine.listByIndicator(indicator).toList();

  if (clauses.isEmpty) {
    console.writeLine('No clauses found for $indicator.\n');
    return;
  }

  console.writeLine(
    '% $indicator (${clauses.length} clause${clauses.length == 1 ? "" : "s"})\n',
  );
  for (final clause in clauses) {
    console.writeLine(_formatClause(clause));
  }
  console.writeLine('');
}

/// Formats a clause for display.
String _formatClause(final Clause clause) {
  if (clause.body.isEmpty) {
    // Fact
    final text = '${clause.head}.';
    return _colorEnabled ? Highlighter.highlight(text) : text;
  } else {
    // Rule
    final bodyStr = clause.body.map((t) => t.toString()).join(', ');
    final text = '${clause.head} :- $bodyStr.';
    return _colorEnabled ? Highlighter.highlight(text) : text;
  }
}

/// Lists all predicate indicators in the database.
void _listPredicates(final PrologEngine engine, final Console console) {
  if (engine.clauseCount == 0) {
    console.writeLine('Database is empty.\n');
    return;
  }

  final indicators = engine.predicateIndicators().toList()..sort();
  final byPredicate = engine.clausesByPredicate();

  console.writeLine('Predicates (${indicators.length} total):\n');

  for (final indicator in indicators) {
    final count = byPredicate[indicator]!.length;
    console.writeLine('  $indicator ($count clause${count == 1 ? "" : "s"})');
  }
  console.writeLine('');
}

/// Consults (loads) a Prolog file.
void _consultFile(
  final String input,
  final PrologEngine engine,
  final Console console,
) {
  // Extract filename from consult('filename') or load('filename')
  final match = RegExp(r"(?:consult|load)\('([^']+)'\)").firstMatch(input);
  if (match == null) {
    console.writeLine(
      'Error: Invalid consult syntax. Use: consult(\'file.pl\').\n',
    );
    return;
  }

  final filename = match.group(1)!;
  _loadFile(filename, engine, console);
}

/// Loads a Prolog file into the database.
///
/// Uses the Parser directly for robust multi-line clause handling.
/// Properly handles:
/// - Multi-line clauses
/// - Comments (% and /* */ style handled by lexer)
/// - Complex nested terms
/// - Operator precedence
void _loadFile(
  final String filename,
  final PrologEngine engine,
  final Console console,
) {
  final file = File(filename);

  if (!file.existsSync()) {
    console.writeLine('Error: File not found: $filename\n');
    return;
  }

  try {
    final content = file.readAsStringSync();

    // Use Parser.parse() which properly handles all Prolog syntax
    final clauses = Parser.parse(content);

    var loaded = 0;

    for (final clause in clauses) {
      try {
        engine.assertz(clause);
        loaded++;
      } catch (e) {
        console.writeLine('Warning: Failed to assert clause: $clause');
        console.writeLine('  Error: $e');
      }
    }

    console.writeLine(
      'Loaded $loaded clause${loaded == 1 ? "" : "s"} from $filename\n',
    );
  } catch (e) {
    console.writeLine('Error loading file: $e\n');
  }
}

/// Checks if a term looks like a builtin query vs a fact.
bool _isBuiltinQuery(final Term term) {
  if (term is! Compound) return false;

  final builtins = {
    '=',
    '\\=',
    '==',
    '\\==',
    '@<',
    '@=<',
    '@>',
    '@>=',
    'is',
    '<',
    '=<',
    '>',
    '>=',
    '=:=',
    '=\\=',
    'var',
    'nonvar',
    'atom',
    'number',
    'integer',
    'float',
    'compound',
    'functor',
    'arg',
    '=..',
    'write',
    'writeln',
    'nl',
  };

  return builtins.contains(term.functor.value);
}

/// Reads a line with command history support using dart_console.
///
/// Supports:
/// - Arrow keys for line editing (left/right)
/// - Up/Down arrows for command history navigation
/// - Home/End keys
/// - Backspace/Delete
String? _readLineWithHistory(
  final Console console,
  final List<String> history,
) {
  final buffer = StringBuffer();
  var cursor = 0;
  var historyIndex = history.length; // Start after last command

  while (true) {
    final key = console.readKey();

    if (key.isControl) {
      switch (key.controlChar) {
        case ControlCharacter.ctrlC:
          return null;
        case ControlCharacter.enter:
          console.writeLine();
          return buffer.toString();
        case ControlCharacter.backspace:
          if (cursor > 0) {
            final text = buffer.toString();
            buffer.clear();
            buffer.write(text.substring(0, cursor - 1));
            buffer.write(text.substring(cursor));
            cursor--;
            _redrawLine(console, buffer.toString(), cursor);
          }
          break;
        case ControlCharacter.delete:
          if (cursor < buffer.length) {
            final text = buffer.toString();
            buffer.clear();
            buffer.write(text.substring(0, cursor));
            buffer.write(text.substring(cursor + 1));
            _redrawLine(console, buffer.toString(), cursor);
          }
          break;
        case ControlCharacter.arrowLeft:
          if (cursor > 0) {
            cursor--;
            console.cursorLeft();
          }
          break;
        case ControlCharacter.arrowRight:
          if (cursor < buffer.length) {
            cursor++;
            console.cursorRight();
          }
          break;
        case ControlCharacter.arrowUp:
          if (historyIndex > 0) {
            historyIndex--;
            buffer.clear();
            buffer.write(history[historyIndex]);
            cursor = buffer.length;
            _redrawLine(console, buffer.toString(), cursor);
          }
          break;
        case ControlCharacter.arrowDown:
          if (historyIndex < history.length - 1) {
            historyIndex++;
            buffer.clear();
            buffer.write(history[historyIndex]);
            cursor = buffer.length;
            _redrawLine(console, buffer.toString(), cursor);
          } else if (historyIndex == history.length - 1) {
            historyIndex++;
            buffer.clear();
            cursor = 0;
            _redrawLine(console, buffer.toString(), cursor);
          }
          break;
        case ControlCharacter.home:
          if (cursor > 0) {
            for (var i = 0; i < cursor; i++) {
              console.cursorLeft();
            }
            cursor = 0;
          }
          break;
        case ControlCharacter.end:
          if (cursor < buffer.length) {
            for (var i = cursor; i < buffer.length; i++) {
              console.cursorRight();
            }
            cursor = buffer.length;
          }
          break;
        default:
          break;
      }
    } else {
      // Regular character input
      final text = buffer.toString();
      buffer.clear();
      buffer.write(text.substring(0, cursor));
      buffer.write(key.char);
      buffer.write(text.substring(cursor));
      cursor++;
      _redrawLine(console, buffer.toString(), cursor);
    }
  }
}

/// Redraws the current input line at the given cursor position.
void _redrawLine(final Console console, final String text, final int cursor) {
  // Move cursor to start of line (after prompt)
  for (var i = 0; i < 1000; i++) {
    console.cursorLeft(); // Move way left
  }
  for (var i = 0; i < 3; i++) {
    console.cursorRight(); // Move to after "?- "
  }

  // Clear line from cursor
  console.write('\x1b[K');

  // Write new text with optional syntax highlighting
  if (_colorEnabled) {
    console.write(Highlighter.highlight(text));
  } else {
    console.write(text);
  }

  // Position cursor (use plain text length for cursor positioning)
  final target = cursor;
  final current = text.length;
  if (current > target) {
    for (var i = 0; i < current - target; i++) {
      console.cursorLeft();
    }
  }
}
