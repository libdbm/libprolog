/// A modern, ISO-compliant Prolog engine for Dart.
///
/// libprolog provides a complete Prolog implementation designed for embedding
/// in Dart applications. It supports ISO Prolog core predicates and DCG.
///
/// Example usage:
/// ```dart
/// import 'package:libprolog/libprolog.dart';
///
/// void main() async {
///   // Create a Prolog engine
///   final prolog = PrologEngine();
///
///   // Assert facts
///   prolog.assertz('parent(tom, bob)');
///   prolog.assertz('parent(bob, ann)');
///
///   // Query
///   await for (final solution in prolog.query('parent(X, Y)')) {
///     print('${solution['X']} is parent of ${solution['Y']}');
///   }
/// }
/// ```
library;

// Terms
export 'src/terms/terms.dart';

// Unification
export 'src/unification/unification.dart';

// Database
export 'src/database/database_exports.dart';

// Engine
export 'src/engine/engine_exports.dart';

// Parser
export 'src/parser/parser_exports.dart';

// Built-ins
export 'src/builtins/builtins.dart';

// I/O
export 'src/io/io_exports.dart';

// DCG
export 'src/dcg/dcg_exports.dart';

// API
export 'src/api/api_exports.dart';

// Exceptions
export 'src/exceptions/prolog_exception.dart';

// REPL utilities
export 'src/repl/highlighter.dart';
