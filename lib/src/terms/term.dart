/// Base class for all Prolog terms.
///
/// Terms are immutable data structures representing Prolog values.
/// The term hierarchy includes:
/// - [Variable]: Logic variables (e.g., X, Y, _)
/// - [Atom]: Atomic constants (e.g., foo, 'Hello World')
/// - [PrologInteger]: Integer numbers (e.g., 42, -17)
/// - [PrologFloat]: Floating-point numbers (e.g., 3.14, -2.5)
/// - [Compound]: Compound terms/structures (e.g., f(a,b), [1,2,3])
abstract class Term {
  const Term();

  /// Returns true if this term is a variable.
  bool get isVariable => false;

  /// Returns true if this term is an atom.
  bool get isAtom => false;

  /// Returns true if this term is a number (integer or float).
  bool get isNumber => false;

  /// Returns true if this term is an integer.
  bool get isInteger => false;

  /// Returns true if this term is a float.
  bool get isFloat => false;

  /// Returns true if this term is a compound term.
  bool get isCompound => false;

  /// Returns true if this term is atomic (atom or number).
  bool get isAtomic => isAtom || isNumber;

  /// Returns true if this term is callable (atom or compound).
  bool get isCallable => isAtom || isCompound;

  /// Returns true if this term is a list (including empty list).
  bool get isList => isNil;

  /// Returns true if this term is the empty list [].
  bool get isNil => false;

  /// Returns true if this term is ground (contains no unbound variables).
  ///
  /// A ground term is one that contains no variables. This is equivalent
  /// to the ISO Prolog ground/1 predicate.
  ///
  /// Examples:
  /// - `atom(foo)` → true (no variables)
  /// - `f(a, b)` → true (no variables)
  /// - `f(X, b)` → false (contains variable X)
  /// - `[1, 2, 3]` → true (no variables)
  /// - `[H|T]` → false (contains variables H and T)
  bool get isGround => true;

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
