import '../engine/clause.dart';
import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../dcg/dcg_translator.dart';
import '../utils/clause_utils.dart';
import 'storage.dart';
import 'memory_storage.dart';

/// A Prolog clause database.
///
/// The database manages clauses (facts and rules) and supports:
/// - Adding/removing clauses (assert/retract)
/// - Retrieving clauses that match a goal
/// - Pluggable storage engines
///
/// By default, uses in-memory storage with first-argument indexing.
class Database {
  /// The underlying storage engine.
  final Storage _storage;

  /// DCG translator for handling --> rules.
  final DCGTranslator _dcgTranslator = DCGTranslator();

  /// Creates a database with the given storage engine.
  ///
  /// If no storage is provided, uses [MemoryStorage] by default.
  Database([Storage? storage]) : _storage = storage ?? MemoryStorage();

  /// Creates a database with custom storage.
  factory Database.withStorage(final Storage storage) => Database(storage);

  /// Handles DCG rule translation and adds to storage if needed.
  ///
  /// Returns true if the term was a DCG rule and was handled.
  bool _handleDCGRule(final Term term, final bool prepend) {
    if (isDCGRule(term)) {
      final translated = _dcgTranslator.translateRule(term);
      if (translated != null) {
        if (prepend) {
          _storage.prepend(translated);
        } else {
          _storage.add(translated);
        }
        return true;
      }
    }
    return false;
  }

  /// Adds a clause to the database (assert).
  ///
  /// The clause is added at the end (asserta would add at beginning).
  /// If the clause head is a DCG rule (-->), it is automatically translated.
  void assert_(final Clause clause) {
    if (_handleDCGRule(clause.head, false)) return;
    _storage.add(clause);
  }

  /// Adds a term as a clause, handling DCG rules automatically.
  void assertTerm(final Term term) {
    if (_handleDCGRule(term, false)) return;

    // Regular clause (fact or rule)
    if (term is Compound && term.functor == Atom(':-') && term.arity == 2) {
      // Rule: Head :- Body
      final head = term.args[0];
      final body = term.args[1];
      final bodyGoals = ClauseUtils.expandBody(body);
      _storage.add(Clause(head, bodyGoals));
    } else {
      // Fact
      _storage.add(Clause(term, []));
    }
  }

  /// Adds a clause at the beginning of the database (asserta).
  ///
  /// The clause is prepended to maintain proper Prolog semantics where
  /// asserta/1 adds clauses before existing ones.
  void asserta(final Clause clause) {
    if (_handleDCGRule(clause.head, true)) return;
    _storage.prepend(clause);
  }

  /// Adds a clause at the end of the database (assertz).
  void assertz(final Clause clause) {
    if (_handleDCGRule(clause.head, false)) return;
    _storage.add(clause);
  }

  /// Removes a clause from the database (retract).
  ///
  /// Returns true if a clause was removed.
  bool retract(final Clause clause) {
    return _storage.remove(clause);
  }

  /// Removes all clauses matching the given head pattern (retractall).
  ///
  /// Returns the number of clauses removed.
  int retractAll(final Term head) {
    return _storage.removeAll(head);
  }

  /// Retrieves all clauses that potentially match the given goal.
  ///
  /// Uses the storage engine's indexing for efficient retrieval.
  Iterable<Clause> retrieve(final Term goal) {
    return _storage.retrieve(goal);
  }

  /// Retrieves all clauses for a given functor/arity indicator.
  ///
  /// Example: `retrieve byIndicator('parent/2')`
  Iterable<Clause> retrieveByIndicator(final String indicator) {
    return _storage.retrieveByIndicator(indicator);
  }

  /// Returns all clauses in the database.
  Iterable<Clause> get clauses => _storage.all;

  /// Returns the total number of clauses.
  int get count => _storage.count;

  /// Clears all clauses from the database.
  void clear() {
    _storage.clear();
  }

  /// Returns true if the database is empty.
  bool get isEmpty => _storage.isEmpty;

  /// Returns true if the database contains the given clause.
  bool contains(final Clause clause) {
    return _storage.contains(clause);
  }

  /// Returns the underlying storage engine.
  ///
  /// Useful for accessing storage-specific features.
  Storage get storage => _storage;

  @override
  String toString() {
    final clauseList = clauses.map((c) => c.toString()).join('\n');
    return 'Database($count clauses):\n$clauseList';
  }
}
