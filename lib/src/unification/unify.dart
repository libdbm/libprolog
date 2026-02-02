import '../terms/term.dart';
import '../terms/variable.dart';
import '../terms/atom.dart';
import '../terms/number.dart';
import '../terms/compound.dart';
import 'substitution.dart';
import 'trail.dart';

/// Unification algorithm implementing Robinson's algorithm with occur check.
///
/// Uses an iterative approach with explicit stack to avoid stack overflow
/// on deeply nested terms.
class Unify {
  /// Unifies two terms with occur check enabled.
  ///
  /// Returns true if unification succeeds, false otherwise.
  /// The [substitution] is modified in place with new bindings.
  /// The [trail] records new bindings for backtracking.
  static bool unify(
    final Term term1,
    final Term term2,
    final Substitution substitution,
    final Trail trail,
  ) {
    return _unify(term1, term2, substitution, trail, occurCheck: true);
  }

  /// Unifies two terms without occur check.
  ///
  /// Faster but may create infinite structures. Use with caution.
  static bool unifyNoOccurCheck(
    final Term term1,
    final Term term2,
    final Substitution substitution,
    final Trail trail,
  ) {
    return _unify(term1, term2, substitution, trail, occurCheck: false);
  }

  /// Iterative unification using explicit stack.
  ///
  /// Avoids stack overflow for deeply nested terms by maintaining
  /// a work list of term pairs to unify.
  static bool _unify(
    final Term t1,
    final Term t2,
    final Substitution subst,
    final Trail trail, {
    required final bool occurCheck,
  }) {
    // Work list of term pairs to unify
    final stack = <(Term, Term)>[(t1, t2)];

    while (stack.isNotEmpty) {
      final (left, right) = stack.removeLast();

      // Dereference both terms
      final term1 = subst.deref(left);
      final term2 = subst.deref(right);

      // Same term - always unifies
      if (identical(term1, term2)) continue;

      // Both variables
      if (term1 is Variable && term2 is Variable) {
        // Bind first to second
        subst.bind(term1, term2);
        trail.record(term1);
        continue;
      }

      // First is variable
      if (term1 is Variable) {
        if (occurCheck && _occurs(term1, term2, subst)) {
          return false; // Occur check failed
        }
        subst.bind(term1, term2);
        trail.record(term1);
        continue;
      }

      // Second is variable
      if (term2 is Variable) {
        if (occurCheck && _occurs(term2, term1, subst)) {
          return false; // Occur check failed
        }
        subst.bind(term2, term1);
        trail.record(term2);
        continue;
      }

      // Both atoms
      if (term1 is Atom && term2 is Atom) {
        if (term1 != term2) return false;
        continue;
      }

      // Both numbers
      if (term1 is PrologNumber && term2 is PrologNumber) {
        if (term1 != term2) return false;
        continue;
      }

      // Both compounds
      if (term1 is Compound && term2 is Compound) {
        // Must have same functor and arity
        if (term1.functor != term2.functor) return false;
        if (term1.arity != term2.arity) return false;

        // Push all argument pairs onto the stack (in reverse order
        // so first argument is processed first)
        for (var i = term1.arity - 1; i >= 0; i--) {
          stack.add((term1.args[i], term2.args[i]));
        }
        continue;
      }

      // Different types - unification fails
      return false;
    }

    return true;
  }

  /// Iterative occur check: Returns true if [variable] occurs in [term].
  ///
  /// Prevents creating infinite structures like X = f(X).
  /// Uses explicit stack to avoid recursion.
  static bool _occurs(
    final Variable variable,
    final Term term,
    final Substitution subst,
  ) {
    final stack = <Term>[term];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final derefed = subst.deref(current);

      if (derefed is Variable) {
        if (derefed == variable) return true;
        continue;
      }

      if (derefed is Compound) {
        // Add all arguments to the stack for checking
        for (final arg in derefed.args) {
          stack.add(arg);
        }
      }
    }

    return false;
  }
}
