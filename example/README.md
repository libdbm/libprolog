# libprolog Examples

This directory contains example Prolog programs and usage demonstrations for libprolog.

## Using the REPL

The libprolog REPL (Read-Eval-Print Loop) provides an interactive environment for writing and testing Prolog programs.

### Starting the REPL

```bash
# Run with Dart
dart run bin/prolog.dart

# Or compile to native executable (faster)
dart compile exe bin/prolog.dart -o prolog
./prolog
```

### REPL Commands

```prolog
?- help.              % Show all available commands
?- exit.              % Exit REPL (also: quit., halt.)
?- listing.           % List all clauses in database
?- listing(pred/N).   % List clauses for specific predicate
?- predicates.        % List all predicate indicators
?- consult('file').   % Load Prolog file
```

## Loading Files with consult/1

### Method 1: REPL Command Syntax

```prolog
?- consult('example/family_examples.pl').
Loaded 9 clauses from example/family_examples.pl

?- predicates.
Predicates (4 total):
  ancestor/2 (2 clauses)
  grandparent/2 (1 clause)
  parent/2 (5 clauses)
  sibling/2 (1 clause)
```

### Method 2: Query Syntax

You can also use `consult/1` as a regular predicate in queries:

```prolog
?- consult('example/family_examples.pl'), parent(tom, X).
X = bob ;
X = liz.
```

### Method 3: Programmatic API

From Dart code:

```dart
import 'package:libprolog/libprolog.dart';

void main() async {
  final prolog = PrologEngine();

  // Load file using consult/1 predicate
  final result = await prolog.queryOnce("consult('example/family_examples.pl')");

  if (result.success) {
    print('File loaded successfully!');

    // Now query the loaded data
    await for (final solution in prolog.query('parent(tom, X)')) {
      print('Tom is parent of: ${solution['X']}');
    }
  }
}
```

## Example Session

Here's a complete REPL session demonstrating file loading and database inspection:

```prolog
$ dart run bin/prolog.dart
libprolog REPL v1.0
ISO Prolog interpreter for Dart
Type "help." for commands, "exit." to quit.

?- consult('example/family_examples.pl').
Loaded 9 clauses from example/family_examples.pl

?- predicates.
Predicates (4 total):
  ancestor/2 (2 clauses)
  grandparent/2 (1 clause)
  parent/2 (5 clauses)
  sibling/2 (1 clause)

?- listing(grandparent/2).
% grandparent/2 (1 clause)

grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

?- parent(tom, X).
X = bob ;
X = liz.

?- grandparent(tom, X).
X = ann ;
X = pat.

?- ancestor(tom, X).
X = bob ;
X = liz ;
X = ann ;
X = pat ;
X = jim.

?- listing.
Database (9 clauses, 4 predicates):

% ancestor/2 (2 clauses)
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Z) :- parent(X, Y), ancestor(Y, Z).

% grandparent/2 (1 clause)
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

% parent/2 (5 clauses)
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).

% sibling/2 (1 clause)
sibling(X, Y) :- parent(P, X), parent(P, Y), X \= Y.

?- exit.
Goodbye!
```

## File Format

Prolog source files (`.pl` extension) support:

### Comments

```prolog
% This is a single-line comment
% Comments start with % and continue to end of line

parent(tom, bob).  % Comments can also appear after code
```

### Facts

```prolog
% Simple facts
parent(tom, bob).
age(tom, 55).

% Facts with complex terms
person(alice, female, [reading, hiking]).
```

### Rules

Rules can span multiple lines:

```prolog
% Single-line rule
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

% Multi-line rule (recommended for readability)
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Z) :-
    parent(X, Y),
    ancestor(Y, Z).
```

### Nested Structures

```prolog
% Complex nested terms work correctly
tree(node(
    leaf(1),
    node(leaf(2), leaf(3))
)).

% Lists
likes(alice, [reading, hiking, coding]).
likes(bob, [gaming, music]).
```

## Database Inspection

### View All Predicates

```prolog
?- predicates.
Predicates (4 total):
  ancestor/2 (2 clauses)
  grandparent/2 (1 clause)
  parent/2 (5 clauses)
  sibling/2 (1 clause)
```

### List Specific Predicate

```prolog
?- listing(parent/2).
% parent/2 (5 clauses)

parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).
```

### List All Clauses

```prolog
?- listing.
Database (9 clauses, 4 predicates):

% ancestor/2 (2 clauses)
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Z) :- parent(X, Y), ancestor(Y, Z).

% grandparent/2 (1 clause)
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

% parent/2 (5 clauses)
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).

% sibling/2 (1 clause)
sibling(X, Y) :- parent(P, X), parent(P, Y), X \= Y.
```

## Interactive Development Workflow

1. **Create a Prolog file** with your rules and facts
2. **Load it in the REPL** using `consult('file.pl')`
3. **Test queries** interactively
4. **Inspect the database** with `listing.` or `predicates.`
5. **Modify the file** in your editor
6. **Reload** with `consult('file.pl')` again
7. **Repeat** until satisfied

### Tips

- Use `predicates.` to see what's available after loading
- Use `listing(pred/N).` to inspect specific predicate definitions
- Press `;` to get more solutions, or `.` to stop
- All clauses from `consult/1` are added to the database (not replaced)
- Use `clear.` or restart REPL to start fresh

## Advanced Usage

### Loading Multiple Files

```prolog
?- consult('base.pl'), consult('extensions.pl').
Loaded 10 clauses from base.pl
Loaded 5 clauses from extensions.pl
```

### Conditional Loading

```prolog
?- consult('config.pl'), (setting(debug, true) -> consult('debug.pl') ; true).
```

### Combining with Queries

```prolog
% Load file and immediately query
?- consult('data.pl'), findall(X, person(X, _, _), People).
People = [alice, bob, charlie].
```

## Available Examples

- **`family_examples.pl`** - Family relationships with rules for ancestors, grandparents, siblings
  - Demonstrates: Facts, rules, recursion, queries
  - Try: `consult('example/family_examples.pl')` and explore!

More examples coming soon!

## Creating Your Own Programs

1. Create a `.pl` file in the `example/` directory (or anywhere)
2. Add facts and rules following Prolog syntax
3. Load with `consult('path/to/file.pl')`
4. Test interactively in the REPL

Example template:

```prolog
% myprogram.pl - Description of what this does

% Facts section
fact1(data).
fact2(more, data).

% Rules section
rule1(X, Y) :-
    fact1(X),
    fact2(X, Y).

% Recursive rules
recursive_rule(X) :- base_case(X).
recursive_rule(X) :-
    step(X, Y),
    recursive_rule(Y).

% Example queries to try:
% ?- rule1(X, Y).
% ?- recursive_rule(start).
```

## Troubleshooting

### File Not Found

```prolog
?- consult('missing.pl').
Error: File not found: missing.pl
```

**Solution**: Check the file path. Paths are relative to where you started the REPL.

### Parse Errors

```prolog
?- consult('broken.pl').
Warning: Failed to parse clause: broken syntax here...
  Error: Parser error at line 1, column 5: Expected term
Loaded 0 clauses from broken.pl
```

**Solution**: Fix the syntax in your `.pl` file. Each clause must end with a period.

### Unexpected Behavior

Use `listing.` to see exactly what was loaded:

```prolog
?- listing.
Database (5 clauses, 2 predicates):

% Shows exactly what's in the database
```

## More Information

- See `../README.md` for full API documentation
- See `../CLAUDE.md` for implementation details
- Visit the test files in `../test/` for more examples
