import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/number.dart';
import '../terms/compound.dart';
import '../terms/variable.dart';
import '../unification/substitution.dart';
import '../unification/unify.dart';
import 'dart:math' as math;

import 'builtin.dart';

/// Registers ISO Prolog arithmetic built-in predicates.
///
/// Provides arithmetic evaluation via `is/2` and comparison predicates.
/// All predicates follow ISO/IEC 13211-1:1995 standard.
///
/// **Predicates registered:**
/// - `is/2` - Arithmetic evaluation
/// - `</2`, `=</2`, `>/2`, `>=/2` - Numeric comparison
/// - `=:=/2`, `=\=/2` - Arithmetic equality/inequality
///
/// **Supported arithmetic expressions:**
/// - Binary: `+, -, *, /, //, mod, rem, ^, **, min, max`
/// - Bitwise: `<<, >>, /\, \/, xor`
/// - Unary: `+, -, \, abs, sign, float, floor, ceiling, round, truncate`
/// - Functions: `sqrt, sin, cos, tan, asin, acos, atan, exp, log, ln, log10`
/// - Constants: `pi, e`
void registerArithmeticBuiltins(final BuiltinRegistry registry) {
  // is/2 - arithmetic evaluation
  registry.register('is', 2, _isBuiltin);

  // Arithmetic comparisons
  registry.register('<', 2, _lessThanBuiltin);
  registry.register('=<', 2, _lessOrEqualBuiltin);
  registry.register('>', 2, _greaterThanBuiltin);
  registry.register('>=', 2, _greaterOrEqualBuiltin);
  registry.register('=:=', 2, _arithmeticEqualBuiltin);
  registry.register('=\\=', 2, _arithmeticNotEqualBuiltin);
}

/// Implements `is/2`: arithmetic evaluation and unification.
///
/// **Signature:** `?Result is +Expression`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// Evaluates `Expression` as an arithmetic expression and unifies
/// the result with `Result`. Variables in `Expression` must be bound.
///
/// **Examples:**
/// ```prolog
/// ?- X is 2 + 3.        % X = 5
/// ?- X is sqrt(16).     % X = 4.0
/// ?- X is pi * 2.       % X = 6.283185307179586
/// ?- X is 10 mod 3.     % X = 1
/// ```
BuiltinResult _isBuiltin(final BuiltinContext context) {
  try {
    final result = context.arg(0);
    final expression = context.arg(1);

    // Evaluate the arithmetic expression
    final value = evaluateArithmetic(expression, context.substitution, 'is/2');

    // Unify with result
    context.trail.mark();
    if (Unify.unify(result, value, context.substitution, context.trail)) {
      return const BuiltinSuccess();
    } else {
      return const BuiltinFailure();
    }
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Implements `</2`: numeric less-than comparison.
///
/// **Signature:** `+X < +Y`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// Succeeds if `X` evaluates to less than `Y`. Both must be arithmetic.
///
/// **Example:** `?- 2 < 3.  % succeeds`
BuiltinResult _lessThanBuiltin(final BuiltinContext context) {
  try {
    final left = evaluateArithmetic(
      context.arg(0),
      context.substitution,
      '</2',
    );
    final right = evaluateArithmetic(
      context.arg(1),
      context.substitution,
      '</2',
    );

    final leftVal = _getNumericValue(left, '</2');
    final rightVal = _getNumericValue(right, '</2');

    return leftVal < rightVal ? const BuiltinSuccess() : const BuiltinFailure();
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Implements `=</2`: numeric less-than-or-equal comparison.
///
/// **Signature:** `+X =< +Y`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// **Example:** `?- 2 =< 2.  % succeeds`
BuiltinResult _lessOrEqualBuiltin(final BuiltinContext context) {
  try {
    final left = evaluateArithmetic(
      context.arg(0),
      context.substitution,
      '=</2',
    );
    final right = evaluateArithmetic(
      context.arg(1),
      context.substitution,
      '=</2',
    );

    final leftVal = _getNumericValue(left, '=</2');
    final rightVal = _getNumericValue(right, '=</2');

    return leftVal <= rightVal
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Implements `>/2`: numeric greater-than comparison.
///
/// **Signature:** `+X > +Y`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// **Example:** `?- 3 > 2.  % succeeds`
BuiltinResult _greaterThanBuiltin(final BuiltinContext context) {
  try {
    final left = evaluateArithmetic(
      context.arg(0),
      context.substitution,
      '>/2',
    );
    final right = evaluateArithmetic(
      context.arg(1),
      context.substitution,
      '>/2',
    );

    final leftVal = _getNumericValue(left, '>/2');
    final rightVal = _getNumericValue(right, '>/2');

    return leftVal > rightVal ? const BuiltinSuccess() : const BuiltinFailure();
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Implements `>=/2`: numeric greater-than-or-equal comparison.
///
/// **Signature:** `+X >= +Y`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// **Example:** `?- 3 >= 3.  % succeeds`
BuiltinResult _greaterOrEqualBuiltin(final BuiltinContext context) {
  try {
    final left = evaluateArithmetic(
      context.arg(0),
      context.substitution,
      '>=/2',
    );
    final right = evaluateArithmetic(
      context.arg(1),
      context.substitution,
      '>=/2',
    );

    final leftVal = _getNumericValue(left, '>=/2');
    final rightVal = _getNumericValue(right, '>=/2');

    return leftVal >= rightVal
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Implements `=:=/2`: arithmetic equality.
///
/// **Signature:** `+X =:= +Y`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// Succeeds if `X` and `Y` evaluate to equal numbers.
/// Uses epsilon comparison for floats (1e-10 tolerance).
///
/// **Example:** `?- 2.0 =:= 2.  % succeeds`
BuiltinResult _arithmeticEqualBuiltin(final BuiltinContext context) {
  try {
    final left = evaluateArithmetic(
      context.arg(0),
      context.substitution,
      '=:=/2',
    );
    final right = evaluateArithmetic(
      context.arg(1),
      context.substitution,
      '=:=/2',
    );

    final leftVal = _getNumericValue(left, '=:=/2');
    final rightVal = _getNumericValue(right, '=:=/2');

    return (leftVal - rightVal).abs() < 1e-10
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Implements `=\=/2`: arithmetic inequality.
///
/// **Signature:** `+X =\= +Y`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §9.3
///
/// **Example:** `?- 2 =\= 3.  % succeeds`
BuiltinResult _arithmeticNotEqualBuiltin(final BuiltinContext context) {
  try {
    final left = evaluateArithmetic(
      context.arg(0),
      context.substitution,
      '=\\=/2',
    );
    final right = evaluateArithmetic(
      context.arg(1),
      context.substitution,
      '=\\=/2',
    );

    final leftVal = _getNumericValue(left, '=\\=/2');
    final rightVal = _getNumericValue(right, '=\\=/2');

    return (leftVal - rightVal).abs() >= 1e-10
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  } on ArithmeticException catch (e) {
    return BuiltinError(e.error);
  }
}

/// Evaluates an arithmetic expression to a numeric term.
///
/// **Supported expressions:**
/// - Numbers: integers and floats evaluate to themselves
/// - Variables: must be bound to arithmetic expressions
/// - Constants: `pi`, `e`
/// - Binary ops: `+, -, *, /, //, mod, rem, ^, **, min, max`
/// - Bitwise: `<<, >>, /\, \/, xor`
/// - Unary ops: `+X, -X, \X, abs, sign, float`
/// - Rounding: `floor, ceiling, round, truncate`
/// - Transcendental: `sqrt, sin, cos, tan, asin, acos, atan`
/// - Exponential: `exp, log, ln, log10`
///
/// **Note:** ISO `mod` has sign of divisor; `rem` has sign of dividend.
///
/// **Throws:** [ArithmeticException] if evaluation fails.
Term evaluateArithmetic(
  final Term term,
  final Substitution substitution, [
  final String context = 'is/2',
]) {
  // Dereference the term
  final deref = substitution.deref(term);

  // Numbers evaluate to themselves
  if (deref is PrologInteger || deref is PrologFloat) {
    return deref;
  }

  // Variables must be instantiated
  if (deref is Variable) {
    throw ArithmeticException.instantiation(context);
  }

  // Atoms can be numeric constants
  if (deref is Atom) {
    // Check for special constants
    if (deref.value == 'pi') return PrologFloat(math.pi);
    if (deref.value == 'e') return PrologFloat(math.e);
    throw ArithmeticException.type('evaluable', deref, context);
  }

  // Compound terms are arithmetic expressions
  if (deref is Compound) {
    return _evaluateCompound(deref, substitution, context);
  }

  throw ArithmeticException.type('evaluable', deref, context);
}

/// Evaluates a compound arithmetic expression.
Term _evaluateCompound(
  final Compound compound,
  final Substitution substitution, [
  final String context = 'is/2',
]) {
  final functor = compound.functor.value;
  final arity = compound.arity;

  // Binary operators
  if (arity == 2) {
    final left = evaluateArithmetic(compound.args[0], substitution, context);
    final right = evaluateArithmetic(compound.args[1], substitution, context);

    final leftVal = _getNumericValue(left, context);
    final rightVal = _getNumericValue(right, context);

    switch (functor) {
      case '+':
        return _makeNumber(leftVal + rightVal);
      case '-':
        return _makeNumber(leftVal - rightVal);
      case '*':
        return _makeNumber(leftVal * rightVal);
      case '/':
        if (rightVal == 0) {
          throw ArithmeticException.evaluation('zero_divisor', context);
        }
        return PrologFloat(leftVal / rightVal);
      case '//':
        if (rightVal == 0) {
          throw ArithmeticException.evaluation('zero_divisor', context);
        }
        return PrologInteger(leftVal ~/ rightVal);
      case 'mod':
        if (rightVal == 0) {
          throw ArithmeticException.evaluation('zero_divisor', context);
        }
        // ISO Prolog mod: result has same sign as divisor
        final left = leftVal.toInt();
        final right = rightVal.toInt();
        final remainder = left % right;
        // If signs differ and there's a remainder, adjust result
        if (remainder != 0 && (left < 0) != (right < 0)) {
          return PrologInteger(remainder + right);
        }
        return PrologInteger(remainder);
      case 'rem':
        if (rightVal == 0) {
          throw ArithmeticException.evaluation('zero_divisor', context);
        }
        return PrologInteger(leftVal.toInt().remainder(rightVal.toInt()));
      case '^':
      case '**':
        return _makeNumber(math.pow(leftVal, rightVal));
      case 'min':
        return _makeNumber(math.min(leftVal, rightVal));
      case 'max':
        return _makeNumber(math.max(leftVal, rightVal));
      case '<<':
        return PrologInteger(leftVal.toInt() << rightVal.toInt());
      case '>>':
        return PrologInteger(leftVal.toInt() >> rightVal.toInt());
      case '/\\':
        return PrologInteger(leftVal.toInt() & rightVal.toInt());
      case '\\/':
        return PrologInteger(leftVal.toInt() | rightVal.toInt());
      case 'xor':
        return PrologInteger(leftVal.toInt() ^ rightVal.toInt());
    }
  }

  // Unary operators
  if (arity == 1) {
    final arg = evaluateArithmetic(compound.args[0], substitution, context);
    final argVal = _getNumericValue(arg, context);

    switch (functor) {
      case '+':
        return _makeNumber(argVal);
      case '-':
        return _makeNumber(-argVal);
      case '\\':
        return PrologInteger(~argVal.toInt());
      case 'abs':
        return _makeNumber(argVal.abs());
      case 'sign':
        return PrologInteger(argVal.sign.toInt());
      case 'float':
        return PrologFloat(argVal.toDouble());
      case 'floor':
        return PrologInteger(argVal.floor());
      case 'ceiling':
        return PrologInteger(argVal.ceil());
      case 'round':
        return PrologInteger(argVal.round());
      case 'truncate':
        return PrologInteger(argVal.truncate());
      case 'sqrt':
        return PrologFloat(math.sqrt(argVal));
      case 'sin':
        return PrologFloat(math.sin(argVal));
      case 'cos':
        return PrologFloat(math.cos(argVal));
      case 'tan':
        return PrologFloat(math.tan(argVal));
      case 'asin':
        return PrologFloat(math.asin(argVal));
      case 'acos':
        return PrologFloat(math.acos(argVal));
      case 'atan':
        return PrologFloat(math.atan(argVal));
      case 'exp':
        return PrologFloat(math.exp(argVal));
      case 'log':
        return PrologFloat(math.log(argVal));
      case 'ln':
        return PrologFloat(math.log(argVal));
      case 'log10':
        return PrologFloat(math.log(argVal) / math.ln10);
    }
  }

  throw ArithmeticException.type(
    'evaluable',
    Compound(Atom(functor), compound.args),
    context,
  );
}

/// Extracts numeric value from a term.
num _getNumericValue(final Term term, [final String context = 'is/2']) {
  if (term is PrologInteger) {
    return term.value;
  } else if (term is PrologFloat) {
    return term.value;
  } else {
    throw ArithmeticException.type('number', term, context);
  }
}

/// Creates appropriate number term (integer or float).
Term _makeNumber(final num value) {
  if (value is int) {
    return PrologInteger(value);
  } else if (value % 1 == 0) {
    return PrologInteger(value.toInt());
  } else {
    return PrologFloat(value.toDouble());
  }
}

/// Exception thrown during arithmetic evaluation.
///
/// Contains an ISO-compliant error term for integration with catch/3.
class ArithmeticException implements Exception {
  /// The ISO error term (e.g., error(evaluation_error(zero_divisor), is/2))
  final Term error;

  ArithmeticException(this.error);

  /// Creates an instantiation error (variable not bound).
  factory ArithmeticException.instantiation(final String context) {
    return ArithmeticException(
      Compound(Atom('error'), [Atom('instantiation_error'), Atom(context)]),
    );
  }

  /// Creates a type error (wrong type for arithmetic).
  factory ArithmeticException.type(
    final String expected,
    final Term actual,
    final String context,
  ) {
    return ArithmeticException(
      Compound(Atom('error'), [
        Compound(Atom('type_error'), [Atom(expected), actual]),
        Atom(context),
      ]),
    );
  }

  /// Creates an evaluation error (e.g., division by zero).
  factory ArithmeticException.evaluation(
    final String error,
    final String context,
  ) {
    return ArithmeticException(
      Compound(Atom('error'), [
        Compound(Atom('evaluation_error'), [Atom(error)]),
        Atom(context),
      ]),
    );
  }

  @override
  String toString() => 'Arithmetic error: $error';
}

// For backwards compatibility, keep the old name as an alias
typedef ArithmeticError = ArithmeticException;
