import 'variable.dart';

/// A factory for creating variables.
///
/// This factory ensures all variables created have globally unique IDs
/// by using the Variable class's global counter. The reset() method is
/// a no-op maintained for API compatibility with existing parser code.
class VariableFactory {
  /// Creates a new variable using the global Variable counter.
  /// IDs are globally unique across all factories and direct Variable() calls.
  Variable createVariable([String? name]) {
    // Use Variable's global counter to ensure uniqueness
    return Variable(name);
  }

  /// No-op reset for API compatibility.
  /// The parser resets its _variables map (which maps names to Variable objects)
  /// to start a fresh scope for each clause. The global ID counter continues
  /// incrementing to ensure variables from different clauses never share IDs.
  void reset() {
    // Intentionally empty - global counter never resets
  }
}
