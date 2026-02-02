# libprolog

A modern, ISO-compliant Prolog engine for Dart. Designed for embedding in Dart applications with a clean, idiomatic API.

[![Tests](https://img.shields.io/badge/tests-passing-brightgreen)]()
[![ISO Compliance](https://img.shields.io/badge/ISO%2013211-core%20features-blue)]()
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue)]()

## Features

- **ISO Prolog Core**: Implements ISO/IEC 13211-1:1995 standard predicates
- **DCG Support**: Full Definite Clause Grammar support (ISO/IEC TS 13211-3:2025)
- **Pure Dart**: No native dependencies, runs anywhere Dart runs
- **Type Safe**: Leverages Dart's null safety and strong typing
- **Stream-based Queries**: Lazy evaluation with async/await support
- **Extensible**: Easy foreign predicate registration
- **Well Tested**: Comprehensive test suite covering all core features

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  libprolog: ^0.1.0
```

### Basic Usage

```dart
import 'package:libprolog/libprolog.dart';

void main() async {
  // Create a Prolog engine
  final prolog = PrologEngine();

  // Assert facts
  prolog.assertz(Compound(Atom('parent'), [Atom('tom'), Atom('bob')]));
  prolog.assertz(Compound(Atom('parent'), [Atom('bob'), Atom('ann')]));

  // Query with variables
  final x = Variable('X');
  final query = Compound(Atom('parent'), [Atom('tom'), x]);

  // Get solutions
  await for (final solution in prolog.query(query)) {
    print('Tom is parent of: ${solution['X']}');
  }
  // Output: Tom is parent of: bob
}
```

## Core Concepts

### Terms

Prolog terms are the building blocks:

```dart
// Atoms
final atom = Atom('hello');
final nil = Atom.nil;  // Empty list

// Numbers
final integer = PrologInteger(42);
final float = PrologFloat(3.14);

// Variables
final x = Variable('X');

// Compounds (structures)
final compound = Compound(Atom('person'), [
  Atom('alice'),
  PrologInteger(30)
]);

// Lists
final list = Compound.fromList([Atom('a'), Atom('b'), Atom('c')]);
```

### Queries

Three ways to query:

```dart
// 1. Stream of all solutions
await for (final solution in prolog.query(query)) {
  print('${solution['X']} is parent of ${solution['Y']}');
}

// 2. First solution only
final x = Variable('X');
final query = Compound(Atom('parent'), [Atom('tom'), x]);
final result = await prolog.queryOnce(query);
if (result.success) {
  print('Found: ${result['X']}');
}

// 3. All solutions at once
final solutions = await prolog.queryAll(query);
print('Found ${solutions.length} solutions');
```

### Rules

Define rules using compound terms:

```dart
// grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
final x = Variable('X');
final y = Variable('Y');
final z = Variable('Z');

final head = Compound(Atom('grandparent'), [x, z]);
final body = Compound(Atom(','), [
  Compound(Atom('parent'), [x, y]),
  Compound(Atom('parent'), [y, z]),
]);

prolog.assertz(Compound(Atom(':-'), [head, body]));
```

## Built-in Predicates

### Type Testing
- `var/1`, `nonvar/1`, `atom/1`, `number/1`, `integer/1`, `float/1`
- `compound/1`, `callable/1`, `ground/1`

### Arithmetic
- `is/2` - Arithmetic evaluation
- `</2`, `=</2`, `>/2`, `>=/2` - Comparison
- `=:=/2`, `=\=/2` - Arithmetic equality/inequality
- `+`, `-`, `*`, `/`, `mod`, `abs`, `min`, `max` - Operators

### Term Manipulation
- `functor/3` - Extract or construct functor
- `arg/3` - Access arguments
- `=../2` - Univ (term ↔ list conversion)
- `copy_term/2` - Copy with fresh variables

### Control
- `true/0`, `fail/0`, `!/0` (cut)
- `,/2` (and), `;/2` (or), `->/2` (if-then)
- `\+/1` - Negation as failure

### All-Solutions
- `findall/3` - Collect all solutions
- `bagof/3` - Grouped solutions
- `setof/3` - Sorted unique solutions

### Database
- `assert/1`, `asserta/1`, `assertz/1` - Add clauses
- `retract/1` - Remove clauses
- `abolish/1` - Remove all clauses for a predicate
- `consult/1`, `load/1` - Load Prolog files

### I/O
- `see/1`, `seen/0`, `tell/1`, `told/0` - File I/O
- `get_char/1`, `put_char/1` - Character I/O
- `read/1`, `write/1` - Term I/O
- `nl/0` - Newline

## DCG (Definite Clause Grammars)

DCGs provide elegant parsing capabilities:

```dart
// Define grammar rules
prolog.assertTerm(Compound(Atom('-->'), [
  Atom('sentence'),
  Compound(Atom(','), [Atom('noun_phrase'), Atom('verb_phrase')])
]));

prolog.assertTerm(Compound(Atom('-->'), [
  Atom('noun'),
  Compound.fromList([Atom('cat')])
]));

prolog.assertTerm(Compound(Atom('-->'), [
  Atom('noun'),
  Compound.fromList([Atom('dog')])
]));

// Parse sentences
final sentence = Compound.fromList([Atom('cat')]);
final query = Compound(Atom('noun'), [sentence, Atom.nil]);
final result = await prolog.queryOnce(query);
print('Valid: ${result.success}');  // true
```

DCG rules automatically translate to difference lists:

```prolog
% DCG rule
sentence --> noun, verb.

% Translates to
sentence(S0, S2) :- noun(S0, S1), verb(S1, S2).
```

## Foreign Predicates

Extend Prolog with Dart functions:

```dart
// Register a custom predicate
prolog.registerForeign('always_true', 0, (context) {
  return const BuiltinSuccess();
});

// Use it
final result = await prolog.queryOnce(Atom('always_true'));
print(result.success);  // true
```

## Term Conversion

Convert between Dart and Prolog:

```dart
// Dart → Prolog
final term = TermConversion.fromDart([1, 2, 3]);
// Creates: [1, 2, 3] as Prolog list

// Prolog → Dart
final dart = TermConversion.toDart(term);
// Returns: [1, 2, 3] as Dart List

// Supported types:
// int, double, String, bool, null, List, Map
```

## Examples

### Prolog Programs

The `example/` directory contains ready-to-use Prolog programs:

- **`family_examples.pl`** - Family relationships demonstrating facts, rules, and recursion
- **`README.md`** - Complete guide to using the REPL and `consult/1`

Load and explore them:

```bash
dart run bin/prolog.dart
?- consult('example/family_examples.pl').
?- predicates.
```

### Dart Integration Examples

See the `example/` directory for Dart integration examples:

- `api_example.dart` - High-level API usage
- `builtins.dart` - Built-in predicates demonstration
- `dcg.dart` - DCG grammar examples
- `io.dart` - I/O operations
- `parser_example.dart` - Parser usage
- `resolver_example.dart` - SLD resolution examples
- `unification_example.dart` - Unification demonstrations

## Architecture

```
libprolog/
├── terms/          # Term representation (Atom, Variable, Compound, Number)
├── unification/    # Robinson's unification algorithm
├── engine/         # SLD resolution, backtracking, choice points
├── database/       # Clause storage with first-argument indexing
├── parser/         # Prolog syntax parser and lexer
├── builtins/       # ISO standard built-in predicates
├── io/             # Stream-based I/O
├── dcg/            # DCG translation
└── api/            # High-level Dart API
```

## ISO Compliance

libprolog implements core predicates from ISO/IEC 13211-1:1995:

- **Section 8.2**: Unification (`=/2`, `\=/2`, `unify_with_occurs_check/2`)
- **Section 8.3**: Type testing (`var/1`, `nonvar/1`, `atom/1`, `number/1`, etc.)
- **Section 8.4**: Term comparison (`@</2`, `@=</2`, `@>/2`, `@>=/2`, etc.)
- **Section 8.5**: Term manipulation (`functor/3`, `arg/3`, `=../2`, `copy_term/2`)
- **Section 7.8**: Control constructs (`!/0`, `->/2`, `;/2`, `\+/1`, etc.)
- **Section 9**: Arithmetic (`is/2`, `</2`, `=</2`, `+`, `-`, `*`, `/`, `mod`, etc.)
- **Section 8.10**: All-solutions (`findall/3`, `bagof/3`, `setof/3`)

Compliance: Core features implemented with ongoing improvements for full standard conformance

## Performance

libprolog uses several optimizations:

- **First-argument indexing**: Fast clause retrieval
- **Trail-based backtracking**: Efficient undo
- **Lazy evaluation**: Stream-based solution generation
- **Immutable terms**: Safe concurrent access

## Testing

Run tests:

```bash
dart test                                    # All tests
dart test test/iso_compliance_test.dart      # ISO compliance only
dart test test/api_test.dart                 # API tests
```

Test coverage:
- **Comprehensive test suite** covering terms, unification, resolution, built-ins, parser, DCG, and API
- **ISO compliance tests**: Validates adherence to ISO Prolog standard
- **Unit tests**: Full coverage of all modules
- **Integration tests**: End-to-end scenarios

## REPL

libprolog includes a command-line REPL (Read-Eval-Print Loop) for interactive Prolog sessions:

```bash
# Run the REPL using Dart
dart run bin/prolog.dart

# Or compile to a native executable for better performance
dart compile exe bin/prolog.dart -o prolog
./prolog
```

### REPL Features

The REPL supports interactive Prolog development with:

- **File Loading**: Load Prolog programs with `consult('file.pl')`
- **Database Inspection**: View all predicates and clauses with `listing.`, `predicates.`
- **Interactive Queries**: Test predicates and explore solutions
- **Multi-line Input**: Properly handles rules spanning multiple lines

#### Example Session

```prolog
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
```

See `example/README.md` for detailed REPL documentation and usage examples.

## Contributing

Contributions welcome! Areas of interest:

1. **Additional ISO predicates**: Implement missing standard predicates
2. **Performance**: Indexing improvements, WAM backend
3. **Extensions**: Constraints (CLP), tabling, modules
4. **Documentation**: More examples and tutorials

## License

BSD 3-Clause License - see LICENSE file for details.

## References

- [ISO/IEC 13211-1:1995](https://www.iso.org/standard/21413.html) - Prolog Core Standard
- [The Art of Prolog](https://mitpress.mit.edu/books/art-prolog) - Sterling & Shapiro
- [Warren's Abstract Machine](https://wambook.sourceforge.net/) - WAM Tutorial

---

**Made with ❤️ for the Prolog and Dart communities**
