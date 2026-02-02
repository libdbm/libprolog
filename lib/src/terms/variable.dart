import 'term.dart';

/// A Prolog logic variable.
///
/// Variables are placeholders that can be bound to other terms during unification.
/// Each variable has a unique ID and an optional name for display purposes.
///
/// Examples: X, Y, _, _Foo
class Variable extends Term {
  /// Unique identifier for this variable instance.
  final int id;

  /// Optional name for display (e.g., "X", "Y", "_").
  /// Anonymous variables typically use "_".
  final String name;

  /// Internal counter for generating unique variable IDs.
  /// Used by the Variable() factory and VariableFactory to ensure
  /// all variables across the system have unique IDs.
  static int _nextId = 0;

  /// Creates a new variable with a globally unique ID.
  ///
  /// This factory is used by all components that need variables.
  /// The global counter ensures every variable has a unique ID for its
  /// entire lifetime, preventing collisions in unification and substitution.
  /// If [name] is not provided, generates a name like "_G123".
  factory Variable([String? name]) {
    final id = _nextId++;
    return Variable.withId(id, name ?? '_G$id');
  }

  /// Creates a variable with a specific ID (for testing or deserialization).
  const Variable.withId(this.id, this.name);

  @override
  bool get isVariable => true;

  @override
  bool get isGround => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Variable && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
