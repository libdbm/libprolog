import '../terms/term.dart';
import '../unification/substitution.dart';

/// A solution to a query.
///
/// Contains the variable bindings that make the query true.
class Solution {
  /// The substitution containing variable bindings.
  final Substitution substitution;

  /// Creates a solution with the given substitution.
  const Solution(this.substitution);

  /// Returns the binding for a variable by name as a Term.
  ///
  /// Returns null if the variable is not bound or doesn't exist.
  Term? binding(final String name) {
    // Find variable in substitution by name
    for (final entry in substitution.bindings.entries) {
      if (entry.key.name == name) {
        return substitution.deref(entry.key);
      }
    }
    return null;
  }

  /// Returns all variable bindings as a map (name -> Term).
  Map<String, Term> get bindings {
    final result = <String, Term>{};
    for (final entry in substitution.bindings.entries) {
      result[entry.key.name] = substitution.deref(entry.key);
    }
    return result;
  }

  /// Returns true if this solution has any bindings.
  bool get hasBindings => substitution.bindings.isNotEmpty;

  /// Returns the number of bindings in this solution.
  int get length => substitution.bindings.length;

  @override
  String toString() => bindings.toString();
}
