/// Base class for all Prolog-related exceptions.
///
/// Follows ISO/IEC 13211-1:1995 error classification where applicable.
/// All Prolog exceptions inherit from this base class for consistent handling.
abstract class PrologException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional context information (e.g., predicate name, line number).
  final String? context;

  const PrologException(this.message, {this.context});

  @override
  String toString() {
    if (context != null) {
      return '$runtimeType: $message (in $context)';
    }
    return '$runtimeType: $message';
  }
}

/// ISO 7.2.3.a: Error when argument is not sufficiently instantiated.
///
/// Example: `X is Y + 1` when Y is unbound.
class InstantiationError extends PrologException {
  const InstantiationError(super.message, {super.context});
}

/// ISO 7.2.3.b: Error when argument is of wrong type.
///
/// Example: `atom(123)` - expecting atom, got integer.
class TypeError extends PrologException {
  /// Expected type (e.g., 'atom', 'integer', 'list').
  final String expected;

  /// Actual type received.
  final String actual;

  const TypeError({
    required this.expected,
    required this.actual,
    required String message,
    String? context,
  }) : super(message, context: context);

  @override
  String toString() {
    var msg = 'TypeError: expected $expected, got $actual';
    if (context != null) {
      msg += ' (in $context)';
    }
    return msg;
  }
}

/// ISO 7.2.3.c: Error when argument is out of valid domain.
///
/// Example: `log(-1)` - negative number invalid for logarithm.
class DomainError extends PrologException {
  /// The domain that was expected (e.g., 'positive_number', 'non_empty_list').
  final String domain;

  const DomainError({
    required this.domain,
    required String message,
    String? context,
  }) : super(message, context: context);

  @override
  String toString() {
    var msg = 'DomainError: $message (expected $domain)';
    if (context != null) {
      msg += ' (in $context)';
    }
    return msg;
  }
}

/// ISO 7.2.3.e: Error when representation is outside implementation limits.
///
/// Example: Integer overflow, atom too long, etc.
class RepresentationError extends PrologException {
  /// The representation limit that was exceeded.
  final String limit;

  const RepresentationError({
    required this.limit,
    required String message,
    String? context,
  }) : super(message, context: context);
}

/// ISO 7.2.3.f: Error when evaluation fails.
///
/// Example: Division by zero, undefined arithmetic operation.
class EvaluationError extends PrologException {
  /// The specific evaluation error (e.g., 'zero_divisor', 'undefined').
  final String error;

  const EvaluationError({
    required this.error,
    required String message,
    String? context,
  }) : super(message, context: context);
}

/// ISO 7.2.3.h: Error when permission is denied.
///
/// Example: Trying to modify a built-in predicate.
class PermissionError extends PrologException {
  /// The operation attempted (e.g., 'modify', 'access').
  final String operation;

  /// The type of object (e.g., 'static_procedure', 'private_procedure').
  final String type;

  const PermissionError({
    required this.operation,
    required this.type,
    required String message,
    String? context,
  }) : super(message, context: context);

  @override
  String toString() {
    var msg = 'PermissionError: cannot $operation $type';
    if (context != null) {
      msg += ' (in $context)';
    }
    return msg;
  }
}

/// ISO 7.2.3.i: Error when predicate does not exist.
///
/// Example: Calling undefined predicate.
class ExistenceError extends PrologException {
  /// The type of object that doesn't exist (e.g., 'procedure', 'source_sink').
  final String type;

  /// The object identifier (e.g., 'foo/2').
  final String object;

  const ExistenceError({
    required this.type,
    required this.object,
    required String message,
    String? context,
  }) : super(message, context: context);

  @override
  String toString() {
    var msg = 'ExistenceError: $type $object does not exist';
    if (context != null) {
      msg += ' (in $context)';
    }
    return msg;
  }
}

/// Parser error for syntax problems.
///
/// Used when parsing Prolog source code fails.
class ParserError extends PrologException {
  /// Line number where error occurred (if known).
  final int? line;

  /// Column number where error occurred (if known).
  final int? column;

  const ParserError(super.message, {this.line, this.column, super.context});

  @override
  String toString() {
    var msg = 'ParserError: $message';
    if (line != null && column != null) {
      msg += ' at line $line, column $column';
    } else if (line != null) {
      msg += ' at line $line';
    }
    if (context != null) {
      msg += ' (in $context)';
    }
    return msg;
  }
}

/// Argument error for invalid API usage (Dart-level).
///
/// Used when Dart code calls Prolog API incorrectly.
class ArgumentError extends PrologException {
  const ArgumentError(super.message, {super.context});
}

/// Resource error when system resource is exhausted.
///
/// Example: Out of memory, stack overflow.
class ResourceError extends PrologException {
  /// The resource that was exhausted.
  final String resource;

  const ResourceError({
    required this.resource,
    required String message,
    String? context,
  }) : super(message, context: context);
}
