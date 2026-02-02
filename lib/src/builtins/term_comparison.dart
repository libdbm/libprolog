import '../terms/atom.dart';
import '../utils/term_comparison.dart';
import 'builtin.dart';

/// Registers ISO Prolog term comparison built-in predicates.
///
/// Provides standard term ordering and structural equality tests.
/// All predicates follow ISO/IEC 13211-1:1995 standard.
///
/// **Predicates registered:**
/// - `@</2`, `@=</2`, `@>/2`, `@>=/2` - Standard term ordering
/// - `==/2`, `\==/2` - Structural equality (no unification)
/// - `compare/3` - Three-way comparison returning `<`, `=`, or `>`
///
/// **ISO standard term order:** Variables < Numbers < Atoms < Compounds
///
/// **Examples:**
/// ```prolog
/// ?- 1 @< atom.           % succeeds (number < atom)
/// ?- X == Y.              % fails (different variables)
/// ?- compare(O, a, b).    % O = <
/// ```
void registerTermComparisonBuiltins(final BuiltinRegistry registry) {
  // Standard term ordering predicates
  registry.register('@<', 2, _termLessThan);
  registry.register('@=<', 2, _termLessOrEqual);
  registry.register('@>', 2, _termGreaterThan);
  registry.register('@>=', 2, _termGreaterOrEqual);

  // Structural equality (already have ==/2 from unification)
  registry.register('==', 2, _structuralEquality);
  registry.register('\\==', 2, _structuralInequality);

  // Three-way comparison
  registry.register('compare', 3, _compare);
}

/// Implements @</2: Term1 @< Term2 (standard term ordering).
BuiltinResult _termLessThan(final BuiltinContext context) {
  final order = TermComparison.compare(context.arg(0), context.arg(1));
  return order < 0 ? const BuiltinSuccess() : const BuiltinFailure();
}

/// Implements @=</2: Term1 @=< Term2 (standard term ordering).
BuiltinResult _termLessOrEqual(final BuiltinContext context) {
  final order = TermComparison.compare(context.arg(0), context.arg(1));
  return order <= 0 ? const BuiltinSuccess() : const BuiltinFailure();
}

/// Implements @>/2: Term1 @> Term2 (standard term ordering).
BuiltinResult _termGreaterThan(final BuiltinContext context) {
  final order = TermComparison.compare(context.arg(0), context.arg(1));
  return order > 0 ? const BuiltinSuccess() : const BuiltinFailure();
}

/// Implements @>=/2: Term1 @>= Term2 (standard term ordering).
BuiltinResult _termGreaterOrEqual(final BuiltinContext context) {
  final order = TermComparison.compare(context.arg(0), context.arg(1));
  return order >= 0 ? const BuiltinSuccess() : const BuiltinFailure();
}

/// Implements ==/2: Term1 == Term2 (structural equality).
BuiltinResult _structuralEquality(final BuiltinContext context) {
  return TermComparison.equals(context.arg(0), context.arg(1))
      ? const BuiltinSuccess()
      : const BuiltinFailure();
}

/// Implements \==/2: Term1 \== Term2 (structural inequality).
BuiltinResult _structuralInequality(final BuiltinContext context) {
  return !TermComparison.equals(context.arg(0), context.arg(1))
      ? const BuiltinSuccess()
      : const BuiltinFailure();
}

/// Implements compare/3: compare(Order, Term1, Term2).
///
/// Unifies Order with <, =, or > depending on standard term ordering.
BuiltinResult _compare(final BuiltinContext context) {
  final order = TermComparison.compare(context.arg(1), context.arg(2));

  final result = order < 0
      ? Atom('<')
      : order > 0
      ? Atom('>')
      : Atom('=');

  return context.unifyAndReturn(context.arg(0), result);
}
