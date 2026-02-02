import '../terms/term.dart';
import '../terms/compound.dart';
import '../terms/number.dart';
import '../unification/substitution.dart';
import '../unification/trail.dart';
import '../unification/unify.dart';

/// Result of executing a built-in predicate.
sealed class BuiltinResult {
  const BuiltinResult();
}

/// Built-in succeeded with no choice points (deterministic success).
class BuiltinSuccess extends BuiltinResult {
  const BuiltinSuccess();
}

/// Built-in failed (no solutions).
class BuiltinFailure extends BuiltinResult {
  const BuiltinFailure();
}

/// Built-in succeeded with multiple solutions (non-deterministic).
///
/// Provides a stream of substitutions representing different solutions.
class BuiltinStream extends BuiltinResult {
  final Stream<Substitution> solutions;

  const BuiltinStream(this.solutions);
}

/// Built-in is not recognized (let resolver try database).
class BuiltinNotFound extends BuiltinResult {
  const BuiltinNotFound();
}

/// Built-in threw an error (ISO exception).
///
/// The error term should be in ISO format: error(ErrorTerm, Context)
/// For example: error(instantiation_error, is/2)
class BuiltinError extends BuiltinResult {
  /// The ISO error term to throw.
  final Term error;

  const BuiltinError(this.error);
}

/// Context provided to built-in predicates during execution.
class BuiltinContext {
  /// Current substitution (variable bindings).
  final Substitution substitution;

  /// Trail for backtracking.
  final Trail trail;

  /// The goal arguments (already dereferenced).
  final List<Term> args;

  const BuiltinContext({
    required this.substitution,
    required this.trail,
    required this.args,
  });

  /// Returns the dereferenced argument at the given index.
  Term arg(final int index) {
    if (index < 0 || index >= args.length) {
      throw ArgumentError('Argument index $index out of bounds');
    }
    return args[index];
  }

  /// Returns the number of arguments.
  int get arity => args.length;

  /// Unifies two terms and returns appropriate builtin result.
  ///
  /// This is a convenience method that:
  /// 1. Marks the trail
  /// 2. Attempts unification
  /// 3. Returns BuiltinSuccess if unification succeeds, BuiltinFailure otherwise
  BuiltinResult unifyAndReturn(final Term left, final Term right) {
    trail.mark();
    return Unify.unify(left, right, substitution, trail)
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  }
}

/// A built-in predicate implementation.
///
/// Built-ins receive a context and return a result indicating
/// success, failure, multiple solutions, or that the predicate is not built-in.
typedef BuiltinPredicate = BuiltinResult Function(BuiltinContext context);

/// Registry of built-in predicates.
///
/// Maps predicate indicators (name/arity) to their implementations.
class BuiltinRegistry {
  final Map<String, BuiltinPredicate> _builtins = {};

  /// Creates an empty builtin registry.
  BuiltinRegistry();

  /// Registers a built-in predicate.
  void register(
    final String name,
    final int arity,
    final BuiltinPredicate predicate,
  ) {
    final indicator = '$name/$arity';
    _builtins[indicator] = predicate;
  }

  /// Looks up a built-in predicate by name and arity.
  BuiltinPredicate? lookup(final String name, final int arity) {
    final indicator = '$name/$arity';
    return _builtins[indicator];
  }

  /// Returns true if a predicate is built-in.
  bool isBuiltin(final String name, final int arity) {
    return _builtins.containsKey('$name/$arity');
  }

  /// Returns all registered built-in indicators.
  Iterable<String> get indicators => _builtins.keys;

  /// Creates a registry with standard ISO built-ins.
  factory BuiltinRegistry.standard() {
    final registry = BuiltinRegistry();

    // Register all standard built-ins
    _registerControlBuiltins(registry);
    _registerTypeTestingBuiltins(registry);
    _registerUnificationBuiltins(registry);

    // Arithmetic is registered separately to avoid circular imports
    // Call registerArithmeticBuiltins(registry) after importing

    return registry;
  }
}

/// Registers control flow built-ins.
void _registerControlBuiltins(final BuiltinRegistry registry) {
  // true/0 - always succeeds
  registry.register('true', 0, (context) => const BuiltinSuccess());

  // fail/0 - always fails
  registry.register('fail', 0, (context) => const BuiltinFailure());

  // Note: !/0 (cut) is handled specially in the resolver
  // Note: ,/2, ;/2, ->/2 are handled as operators by the parser
}

/// Registers type testing built-ins.
void _registerTypeTestingBuiltins(final BuiltinRegistry registry) {
  // var/1 - succeeds if argument is an unbound variable
  registry.register('var', 1, (context) {
    final term = context.arg(0);
    return term.isVariable ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // nonvar/1 - succeeds if argument is not an unbound variable
  registry.register('nonvar', 1, (context) {
    final term = context.arg(0);
    return !term.isVariable ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // atom/1 - succeeds if argument is an atom
  registry.register('atom', 1, (context) {
    final term = context.arg(0);
    return term.isAtom ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // number/1 - succeeds if argument is a number
  registry.register('number', 1, (context) {
    final term = context.arg(0);
    return term.isNumber ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // integer/1 - succeeds if argument is an integer
  registry.register('integer', 1, (context) {
    final term = context.arg(0);
    return (term is PrologInteger)
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  });

  // float/1 - succeeds if argument is a float
  registry.register('float', 1, (context) {
    final term = context.arg(0);
    return (term is PrologFloat)
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  });

  // atomic/1 - succeeds if argument is atomic (atom or number)
  registry.register('atomic', 1, (context) {
    final term = context.arg(0);
    return term.isAtomic ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // compound/1 - succeeds if argument is a compound term
  registry.register('compound', 1, (context) {
    final term = context.arg(0);
    return term.isCompound ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // callable/1 - succeeds if argument can be called (atom or compound)
  registry.register('callable', 1, (context) {
    final term = context.arg(0);
    return term.isCallable ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // ground/1 - succeeds if term contains no unbound variables
  registry.register('ground', 1, (context) {
    final term = context.arg(0);
    return term.isGround ? const BuiltinSuccess() : const BuiltinFailure();
  });

  // is_list/1 - succeeds if term is a proper list
  registry.register('is_list', 1, (context) {
    final term = context.arg(0);
    // A term is a proper list if it's nil or Compound.toList succeeds
    final isList = term.isNil || Compound.toList(term) != null;
    return isList ? const BuiltinSuccess() : const BuiltinFailure();
  });
}

/// Registers unification built-ins.
void _registerUnificationBuiltins(final BuiltinRegistry registry) {
  // =/2 - unification WITHOUT occur check (ISO standard)
  // Note: Also handled specially in resolver, but kept here for completeness.
  // ISO Prolog specifies that =/2 does NOT perform occur check, allowing
  // unification of X = f(X) which creates cyclic/rational trees.
  registry.register('=', 2, (context) {
    context.trail.mark();
    if (Unify.unifyNoOccurCheck(
      context.arg(0),
      context.arg(1),
      context.substitution,
      context.trail,
    )) {
      context.trail.commit();
      return const BuiltinSuccess();
    } else {
      context.trail.undo(context.substitution);
      return const BuiltinFailure();
    }
  });

  // \=/2 - not unifiable (tests if terms cannot unify without occur check)
  // ISO standard: Uses same unification semantics as =/2 (no occur check)
  registry.register('\\=', 2, (context) {
    // Create a temporary trail marker to test unification
    context.trail.mark();
    final canUnify = Unify.unifyNoOccurCheck(
      context.arg(0),
      context.arg(1),
      context.substitution,
      context.trail,
    );

    // Undo any bindings from the unification test
    context.trail.undo(context.substitution);

    // Succeed if cannot unify, fail if can unify
    return canUnify ? const BuiltinFailure() : const BuiltinSuccess();
  });

  // unify_with_occurs_check/2 - unification WITH explicit occur check (ISO standard)
  // ISO Prolog specifies that this predicate MUST perform occur check,
  // so X = f(X) fails instead of creating a cyclic structure.
  registry.register('unify_with_occurs_check', 2, (context) {
    return context.unifyAndReturn(context.arg(0), context.arg(1));
  });
}
