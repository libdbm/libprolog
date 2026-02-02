import '../engine/clause.dart';
import '../terms/term.dart';

/// Abstract interface for clause storage engines.
///
/// This allows pluggable storage implementations:
/// - In-memory storage (default)
/// - Persistent storage (file-based, database)
/// - Distributed storage
/// - Custom implementations
abstract class Storage {
  /// Adds a clause to the end of the storage (assertz).
  void add(final Clause clause);

  /// Adds a clause to the beginning of the storage (asserta).
  void prepend(final Clause clause);

  /// Removes a clause from the storage.
  /// Returns true if the clause was found and removed.
  bool remove(final Clause clause);

  /// Removes all clauses matching the given head pattern.
  /// Returns the number of clauses removed.
  int removeAll(final Term head);

  /// Retrieves all clauses that potentially match the given goal.
  ///
  /// Implementations may use indexing to optimize this operation.
  /// The returned iterable should be lazy when possible.
  Iterable<Clause> retrieve(final Term goal);

  /// Retrieves all clauses for a given functor/arity.
  Iterable<Clause> retrieveByIndicator(final String indicator);

  /// Returns all clauses in the storage.
  Iterable<Clause> get all;

  /// Returns the total number of clauses.
  int get count;

  /// Clears all clauses from storage.
  void clear();

  /// Returns true if the storage contains any clauses.
  bool get isEmpty;

  /// Returns true if the storage contains the given clause.
  bool contains(final Clause clause);
}

/// Statistics about storage operations (for optimization).
class StorageStats {
  int retrievals = 0;
  int additions = 0;
  int removals = 0;
  int indexHits = 0;
  int indexMisses = 0;

  void reset() {
    retrievals = 0;
    additions = 0;
    removals = 0;
    indexHits = 0;
    indexMisses = 0;
  }

  @override
  String toString() =>
      'StorageStats('
      'retrievals: $retrievals, '
      'additions: $additions, '
      'removals: $removals, '
      'index hits: $indexHits, '
      'index misses: $indexMisses)';
}

/// Optional interface for storage implementations that support statistics.
abstract class StorageWithStats extends Storage {
  /// Returns statistics about storage operations.
  StorageStats get stats;

  /// Resets the statistics counters.
  void resetStats();
}

/// Optional interface for storage implementations that support persistence.
abstract class PersistentStorage extends Storage {
  /// Loads clauses from persistent storage.
  Future<void> load();

  /// Saves clauses to persistent storage.
  Future<void> save();

  /// Returns true if the storage has unsaved changes.
  bool get isDirty;
}

/// Optional interface for storage implementations that support transactions.
abstract class TransactionalStorage extends Storage {
  /// Begins a new transaction.
  void begin();

  /// Commits the current transaction.
  void commit();

  /// Rolls back the current transaction.
  void rollback();

  /// Returns true if a transaction is currently active.
  bool get inTransaction;
}
