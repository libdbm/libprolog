export '../engine/solution.dart';

import '../engine/solution.dart';
import 'term_conversion.dart';

/// Extension methods for Solution to provide Dart-friendly access.
extension SolutionExtensions on Solution {
  /// Gets the binding for a variable name as a Dart value.
  ///
  /// Returns null if the variable is not bound.
  dynamic operator [](final String name) {
    final term = binding(name);
    if (term == null) return null;
    return TermConversion.toDart(term);
  }

  /// Gets all variable bindings as a map of variable names to Dart values.
  Map<String, dynamic> get values {
    final result = <String, dynamic>{};
    for (final entry in bindings.entries) {
      result[entry.key] = TermConversion.toDart(entry.value);
    }
    return result;
  }
}

/// Represents the result of a query that expects at most one solution.
class QueryResult {
  /// The solution, or null if the query failed.
  final Solution? solution;

  /// Creates a query result.
  QueryResult(this.solution);

  /// Returns true if the query succeeded.
  bool get success => solution != null;

  /// Returns true if the query failed.
  bool get failure => solution == null;

  /// Gets the binding for a variable name.
  ///
  /// Returns null if there is no solution or the variable is not bound.
  dynamic operator [](final String name) {
    return solution?[name];
  }

  @override
  String toString() {
    if (solution == null) return 'false';
    return solution.toString();
  }
}
