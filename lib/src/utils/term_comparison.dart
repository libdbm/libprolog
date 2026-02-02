import '../terms/term.dart';
import '../terms/variable.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../terms/number.dart';

/// Utilities for structural term comparison and ordering.
///
/// Implements ISO Prolog standard term ordering:
/// Variables < Numbers < Atoms < Compound terms
class TermComparison {
  /// Compares two terms structurally according to ISO standard order.
  ///
  /// Returns:
  /// - negative if term1 < term2
  /// - zero if term1 == term2
  /// - positive if term1 > term2
  ///
  /// Standard term order (ISO 7.2):
  /// 1. Variables (ordered by age/creation)
  /// 2. Numbers (ordered by value)
  /// 3. Atoms (ordered lexicographically)
  /// 4. Compound terms (ordered by: arity, then functor, then arguments)
  static int compare(final Term term1, final Term term2) {
    // Same object
    if (identical(term1, term2)) return 0;

    // Get type order
    final order1 = _typeOrder(term1);
    final order2 = _typeOrder(term2);

    if (order1 != order2) {
      return order1.compareTo(order2);
    }

    // Same type, compare within type
    if (term1 is Variable && term2 is Variable) {
      return term1.id.compareTo(term2.id);
    }

    if (term1 is PrologNumber && term2 is PrologNumber) {
      // ISO: Floats @< Integers when numerically equal
      final isFloat1 = term1 is PrologFloat;
      final isFloat2 = term2 is PrologFloat;

      // First compare numerically
      final val1 = term1 is PrologInteger
          ? term1.value.toDouble()
          : (term1 as PrologFloat).value;
      final val2 = term2 is PrologInteger
          ? term2.value.toDouble()
          : (term2 as PrologFloat).value;
      final numCmp = val1.compareTo(val2);

      // If numerically different, return that comparison
      if (numCmp != 0) return numCmp;

      // If numerically equal but different types, float < integer
      if (isFloat1 && !isFloat2) return -1;
      if (!isFloat1 && isFloat2) return 1;

      // Same type and numerically equal
      return 0;
    }

    if (term1 is Atom && term2 is Atom) {
      return term1.value.compareTo(term2.value);
    }

    if (term1 is Compound && term2 is Compound) {
      // First compare by arity
      final arityCmp = term1.arity.compareTo(term2.arity);
      if (arityCmp != 0) return arityCmp;

      // Then compare by functor
      final functorCmp = term1.functor.value.compareTo(term2.functor.value);
      if (functorCmp != 0) return functorCmp;

      // Finally compare arguments left-to-right
      for (var i = 0; i < term1.arity; i++) {
        final argCmp = compare(term1.args[i], term2.args[i]);
        if (argCmp != 0) return argCmp;
      }

      return 0;
    }

    // Fallback (shouldn't reach here)
    return 0;
  }

  /// Returns type order for standard term ordering.
  static int _typeOrder(final Term term) {
    if (term is Variable) return 0;
    if (term is PrologNumber) return 1;
    if (term is Atom) return 2;
    if (term is Compound) return 3;
    return 4; // Unknown
  }

  /// Checks if two terms are structurally equal.
  static bool equals(final Term term1, final Term term2) {
    return compare(term1, term2) == 0;
  }

  /// Sorts a list of terms in standard order.
  static List<Term> sort(final List<Term> terms) {
    final sorted = List<Term>.from(terms);
    sorted.sort(compare);
    return sorted;
  }

  /// Removes duplicate terms from a sorted list using structural equality.
  static List<Term> removeDuplicates(final List<Term> sortedTerms) {
    if (sortedTerms.isEmpty) return [];

    final result = <Term>[sortedTerms[0]];
    for (var i = 1; i < sortedTerms.length; i++) {
      if (!equals(sortedTerms[i], sortedTerms[i - 1])) {
        result.add(sortedTerms[i]);
      }
    }
    return result;
  }
}
