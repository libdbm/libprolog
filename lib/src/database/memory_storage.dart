import '../engine/clause.dart';
import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../unification/unify.dart';
import '../unification/substitution.dart';
import '../unification/trail.dart';
import 'storage.dart';

/// In-memory clause storage with first-argument indexing.
///
/// This is the default storage implementation, optimized for:
/// - Fast clause retrieval using first-argument indexing
/// - Maintaining clause order (for Prolog semantics)
/// - Low memory overhead
///
/// Indexing strategy:
/// - Groups clauses by functor/arity
/// - Within each group, further indexes by first argument (if ground)
/// - Maintains insertion order for proper Prolog semantics
class MemoryStorage implements StorageWithStats {
  /// All clauses in insertion order.
  final List<Clause> _clauses = [];

  /// Index: functor/arity -> list of clauses
  final Map<String, List<Clause>> _indicatorIndex = {};

  /// Index: functor/arity -> first-arg-value -> list of clauses
  /// Only for clauses where the first argument is ground (not a variable).
  final Map<String, Map<String, List<Clause>>> _firstArgIndex = {};

  @override
  final StorageStats stats = StorageStats();

  @override
  void add(final Clause clause) {
    stats.additions++;

    _clauses.add(clause);

    // Add to indicator index
    final indicator = clause.indicator;
    _indicatorIndex.putIfAbsent(indicator, () => []).add(clause);

    // Add to first-argument index if applicable
    _indexFirstArg(clause);
  }

  @override
  void prepend(final Clause clause) {
    stats.additions++;

    _clauses.insert(0, clause);

    // Add to indicator index at beginning
    final indicator = clause.indicator;
    _indicatorIndex.putIfAbsent(indicator, () => []).insert(0, clause);

    // Add to first-argument index if applicable
    _indexFirstArgPrepend(clause);
  }

  @override
  bool remove(final Clause clause) {
    stats.removals++;

    if (!_clauses.remove(clause)) {
      return false;
    }

    // Remove from indicator index
    final indicator = clause.indicator;
    final indicatorClauses = _indicatorIndex[indicator];
    if (indicatorClauses != null) {
      indicatorClauses.remove(clause);
      if (indicatorClauses.isEmpty) {
        _indicatorIndex.remove(indicator);
      }
    }

    // Remove from first-argument index
    _removeFromFirstArgIndex(clause);

    return true;
  }

  @override
  int removeAll(final Term head) {
    stats.removals++;

    final indicator = _getIndicator(head);
    final candidates = _indicatorIndex[indicator]?.toList() ?? [];

    // Only remove clauses whose head unifies with the pattern
    final toRemove = <Clause>[];
    for (final clause in candidates) {
      // Check if clause head unifies with the pattern
      final subst = Substitution();
      final trail = Trail();
      if (Unify.unify(clause.head, head, subst, trail)) {
        toRemove.add(clause);
      }
    }

    for (final clause in toRemove) {
      remove(clause);
    }

    return toRemove.length;
  }

  @override
  Iterable<Clause> retrieve(final Term goal) {
    stats.retrievals++;

    final indicator = _getIndicator(goal);
    final indicatorClauses = _indicatorIndex[indicator];

    if (indicatorClauses == null || indicatorClauses.isEmpty) {
      stats.indexMisses++;
      return const [];
    }

    // Try first-argument indexing if goal has ground first argument
    if (goal is Compound && goal.arity > 0) {
      final firstArg = goal.args[0];
      if (!firstArg.isVariable) {
        final firstArgKey = _firstArgKey(firstArg);
        final firstArgMap = _firstArgIndex[indicator];

        if (firstArgMap != null) {
          final indexed = firstArgMap[firstArgKey];
          if (indexed != null && indexed.isNotEmpty) {
            stats.indexHits++;
            // Also include clauses with variable first argument
            final varClauses = firstArgMap['_VAR_'] ?? [];
            return [...indexed, ...varClauses];
          }
          // First-argument indexing failed - key not found in index
          stats.indexMisses++;
        } else {
          // No first-argument index for this indicator
          stats.indexMisses++;
        }
      }
    }

    // Fallback to all clauses with same functor/arity (no first-arg index used)
    return indicatorClauses;
  }

  @override
  Iterable<Clause> retrieveByIndicator(final String indicator) {
    return _indicatorIndex[indicator] ?? const [];
  }

  @override
  Iterable<Clause> get all => List.unmodifiable(_clauses);

  @override
  int get count => _clauses.length;

  @override
  void clear() {
    _clauses.clear();
    _indicatorIndex.clear();
    _firstArgIndex.clear();
  }

  @override
  bool get isEmpty => _clauses.isEmpty;

  @override
  bool contains(final Clause clause) => _clauses.contains(clause);

  @override
  void resetStats() {
    stats.reset();
  }

  /// Indexes a clause by its first argument (if ground).
  void _indexFirstArg(final Clause clause) {
    if (clause.head is! Compound) return;

    final compound = clause.head as Compound;
    if (compound.arity == 0) return;

    final indicator = clause.indicator;
    final firstArg = compound.args[0];
    final firstArgMap = _firstArgIndex.putIfAbsent(indicator, () => {});

    final key = firstArg.isVariable ? '_VAR_' : _firstArgKey(firstArg);
    firstArgMap.putIfAbsent(key, () => []).add(clause);
  }

  /// Indexes a clause by its first argument at beginning (for prepend).
  void _indexFirstArgPrepend(final Clause clause) {
    if (clause.head is! Compound) return;

    final compound = clause.head as Compound;
    if (compound.arity == 0) return;

    final indicator = clause.indicator;
    final firstArg = compound.args[0];
    final firstArgMap = _firstArgIndex.putIfAbsent(indicator, () => {});

    final key = firstArg.isVariable ? '_VAR_' : _firstArgKey(firstArg);
    firstArgMap.putIfAbsent(key, () => []).insert(0, clause);
  }

  /// Removes a clause from the first-argument index.
  void _removeFromFirstArgIndex(final Clause clause) {
    if (clause.head is! Compound) return;

    final compound = clause.head as Compound;
    if (compound.arity == 0) return;

    final indicator = clause.indicator;
    final firstArgMap = _firstArgIndex[indicator];
    if (firstArgMap == null) return;

    final firstArg = compound.args[0];
    final key = firstArg.isVariable ? '_VAR_' : _firstArgKey(firstArg);

    final clauses = firstArgMap[key];
    if (clauses != null) {
      clauses.remove(clause);
      if (clauses.isEmpty) {
        firstArgMap.remove(key);
      }
    }

    if (firstArgMap.isEmpty) {
      _firstArgIndex.remove(indicator);
    }
  }

  /// Generates a key for first-argument indexing.
  String _firstArgKey(final Term term) {
    if (term is Atom) {
      return 'atom:${term.value}';
    } else if (term is Compound) {
      return 'compound:${term.functor.value}/${term.arity}';
    } else {
      // Numbers, etc.
      return 'other:${term.toString()}';
    }
  }

  /// Gets the functor/arity indicator for a term.
  String _getIndicator(final Term term) {
    if (term is Compound) {
      return '${term.functor.value}/${term.arity}';
    } else if (term is Atom) {
      return '${term.value}/0';
    }
    throw ArgumentError('Cannot get indicator for term: $term');
  }
}
