import 'term.dart';

/// Base class for numeric terms.
abstract class PrologNumber extends Term {
  const PrologNumber();

  @override
  bool get isNumber => true;

  /// Returns the numeric value as a Dart num.
  num get value;

  /// Returns the numeric value as an int (may lose precision for floats).
  int get intValue;

  /// Returns the numeric value as a double.
  double get floatValue;
}

/// A Prolog integer number.
///
/// Represents integer values (unbounded in ISO Prolog, but using Dart int here).
///
/// Examples: 42, -17, 0, 1000000
class PrologInteger extends PrologNumber {
  @override
  final int value;

  const PrologInteger(this.value);

  @override
  bool get isInteger => true;

  @override
  int get intValue => value;

  @override
  double get floatValue => value.toDouble();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrologInteger && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

/// A Prolog floating-point number.
///
/// Represents floating-point values using Dart's double type.
///
/// Examples: 3.14, -2.5, 1.0e10, -0.001
class PrologFloat extends PrologNumber {
  @override
  final double value;

  const PrologFloat(this.value);

  @override
  bool get isFloat => true;

  @override
  int get intValue => value.truncate();

  @override
  double get floatValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PrologFloat && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}
