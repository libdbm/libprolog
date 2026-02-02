import '../database/database.dart';
import '../engine/resolver.dart';
import '../engine/clause.dart';
import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../parser/parser.dart';
import '../parser/lexer.dart';
import '../builtins/builtins.dart';
import '../io/stream_manager.dart';
import '../utils/clause_utils.dart';
import '../exceptions/prolog_exception.dart';
import 'solution.dart';

/// High-level Dart API for the Prolog engine.
///
/// Provides a clean, idiomatic interface for embedding Prolog in Dart applications.
///
/// Example:
/// ```dart
/// final prolog = PrologEngine();
/// prolog.assertz('parent(tom, bob)');
/// prolog.assertz('parent(bob, ann)');
///
/// await for (final solution in prolog.query('parent(X, Y)')) {
///   print('${solution['X']} is parent of ${solution['Y']}');
/// }
/// ```
class PrologEngine {
  /// The clause database.
  final Database _database;

  /// The resolver for executing queries.
  late final Resolver _resolver;

  /// The built-in registry.
  final BuiltinRegistry _builtins;

  /// The stream manager for I/O operations.
  final StreamManager _io;

  /// Creates a new Prolog engine.
  ///
  /// Optionally accepts a custom database and built-in registry.
  factory PrologEngine({
    Database? database,
    BuiltinRegistry? builtins,
    StreamManager? streamManager,
  }) {
    final db = database ?? Database();
    final sm = streamManager ?? StreamManager();
    final br =
        builtins ?? createStandardRegistry(streamManager: sm, database: db);
    return PrologEngine._(db, br, sm);
  }

  PrologEngine._(this._database, this._builtins, this._io) {
    // Create resolver with the same database and stream manager instances
    _resolver = Resolver(_database, builtins: _builtins, streamManager: _io);
  }

  /// Asserts a clause at the end of the database.
  ///
  /// The input can be:
  /// - A String (parsed as Prolog syntax)
  /// - A Term
  /// - A Clause
  ///
  /// Example:
  /// ```dart
  /// prolog.assertz('parent(tom, bob)');
  /// prolog.assertz(Compound(Atom('parent'), [Atom('tom'), Atom('bob')]));
  /// ```
  void assertz(final dynamic input) {
    final clause = _toClause(input);
    _database.assertz(clause);
  }

  /// Asserts a clause at the beginning of the database.
  ///
  /// See [assertz] for input formats.
  void asserta(final dynamic input) {
    final clause = _toClause(input);
    _database.asserta(clause);
  }

  /// Asserts a term (handles DCG rules automatically).
  ///
  /// Example:
  /// ```dart
  /// prolog.assertTerm('a --> [x]'); // DCG rule
  /// prolog.assertTerm('parent(tom, bob)'); // Fact
  /// ```
  void assertTerm(final dynamic input) {
    if (input is String) {
      final term = _parseTerm(input);
      _database.assertTerm(term);
    } else if (input is Term) {
      _database.assertTerm(input);
    } else if (input is Clause) {
      _database.assert_(input);
    } else {
      throw TypeError(
        expected: 'String, Term, or Clause',
        actual: input.runtimeType.toString(),
        message: 'Cannot assert term',
        context: 'assertTerm',
      );
    }
  }

  /// Retracts the first clause matching the given pattern.
  ///
  /// Returns true if a clause was retracted.
  bool retract(final dynamic input) {
    final clause = _toClause(input);
    return _database.retract(clause);
  }

  /// Retracts all clauses matching the given head pattern.
  ///
  /// Returns the number of clauses retracted.
  int retractAll(final dynamic input) {
    final term = input is String ? _parseTerm(input) : input as Term;
    return _database.retractAll(term);
  }

  /// Clears all clauses from the database.
  void clear() {
    _database.clear();
  }

  /// Queries the database and returns a stream of solutions.
  ///
  /// The input can be:
  /// - A String (parsed as Prolog syntax)
  /// - A Term
  ///
  /// Example:
  /// ```dart
  /// await for (final solution in prolog.query('parent(X, bob)')) {
  ///   print('X = ${solution['X']}');
  /// }
  /// ```
  Stream<Solution> query(final dynamic input) {
    final term = input is String ? _parseTerm(input) : input as Term;
    return _resolver.queryGoal(term);
  }

  /// Queries the database and returns the first solution, or null if none.
  ///
  /// Example:
  /// ```dart
  /// final result = await prolog.queryOnce('parent(tom, bob)');
  /// if (result.success) {
  ///   print('Yes!');
  /// }
  /// ```
  Future<QueryResult> queryOnce(final dynamic input) async {
    final solutions = await query(input).take(1).toList();
    return QueryResult(solutions.isNotEmpty ? solutions[0] : null);
  }

  /// Queries the database and returns all solutions.
  ///
  /// Example:
  /// ```dart
  /// final solutions = await prolog.queryAll('parent(tom, X)');
  /// for (final solution in solutions) {
  ///   print('X = ${solution['X']}');
  /// }
  /// ```
  Future<List<Solution>> queryAll(final dynamic input) async {
    return await query(input).toList();
  }

  /// Registers a foreign predicate (Dart function callable from Prolog).
  ///
  /// Example:
  /// ```dart
  /// prolog.registerForeign('add', 3, (context) {
  ///   final a = (context.arg(0) as PrologInteger).value;
  ///   final b = (context.arg(1) as PrologInteger).value;
  ///   final result = PrologInteger(a + b);
  ///   return BuiltinSuccess([
  ///     Compound(Atom('='), [context.arg(2), result])
  ///   ]);
  /// });
  /// ```
  void registerForeign(
    final String name,
    final int arity,
    final BuiltinPredicate implementation,
  ) {
    _builtins.register(name, arity, implementation);
  }

  /// Converts input to a clause.
  Clause _toClause(final dynamic input) {
    if (input is Clause) {
      return input;
    }

    if (input is Term) {
      // Check if it's a rule (Head :- Body)
      if (input is Compound &&
          input.functor == Atom(':-') &&
          input.arity == 2) {
        final head = input.args[0];
        final body = input.args[1];
        final bodyGoals = ClauseUtils.expandBody(body);
        return Clause(head, bodyGoals);
      }
      // Otherwise it's a fact
      return Clause(input, []);
    }

    if (input is String) {
      final term = _parseTerm(input);
      return _toClause(term);
    }

    throw TypeError(
      expected: 'String, Term, or Clause',
      actual: input.runtimeType.toString(),
      message: 'Cannot convert to clause',
      context: 'assertz/asserta',
    );
  }

  /// Parses a Prolog term from a string.
  Term _parseTerm(final String source) {
    final lexer = Lexer(source);
    final tokens = lexer.scanTokens();
    final parser = Parser(tokens);
    return parser.term();
  }

  /// Returns the number of clauses in the database.
  int get clauseCount => _database.count;

  /// Returns true if the database is empty.
  bool get isEmpty => _database.isEmpty;

  /// Returns the database (for advanced usage).
  Database get database => _database;

  /// Returns the resolver (for advanced usage).
  Resolver get resolver => _resolver;

  /// Returns the built-in registry (for advanced usage).
  BuiltinRegistry get builtins => _builtins;

  /// Returns the stream manager (for I/O operations).
  StreamManager get streamManager => _io;

  /// Lists all clauses in the database.
  ///
  /// Returns an iterable of clauses that can be displayed or processed.
  Iterable<Clause> listAll() {
    return _database.clauses;
  }

  /// Lists all clauses for a specific predicate indicator (e.g., 'parent/2').
  ///
  /// Returns an iterable of clauses matching the given functor/arity.
  Iterable<Clause> listByIndicator(final String indicator) {
    return _database.retrieveByIndicator(indicator);
  }

  /// Returns all unique predicate indicators in the database.
  ///
  /// Example: ['parent/2', 'grandparent/2', 'age/2']
  Set<String> predicateIndicators() {
    final indicators = <String>{};
    for (final clause in _database.clauses) {
      indicators.add(clause.indicator);
    }
    return indicators;
  }

  /// Returns clauses grouped by predicate indicator.
  ///
  /// Returns a map where keys are predicate indicators and values are lists of clauses.
  Map<String, List<Clause>> clausesByPredicate() {
    final result = <String, List<Clause>>{};
    for (final clause in _database.clauses) {
      result.putIfAbsent(clause.indicator, () => []).add(clause);
    }
    return result;
  }
}
