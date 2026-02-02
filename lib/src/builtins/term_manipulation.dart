import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/variable.dart';
import '../terms/compound.dart';
import '../terms/number.dart';
import '../unification/unify.dart';
import 'builtin.dart';

/// Creates an ISO instantiation_error.
BuiltinError _instantiationError(final String context) {
  return BuiltinError(
    Compound(Atom('error'), [Atom('instantiation_error'), Atom(context)]),
  );
}

/// Creates an ISO type_error.
BuiltinError _typeError(
  final String expected,
  final Term culprit,
  final String context,
) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('type_error'), [Atom(expected), culprit]),
      Atom(context),
    ]),
  );
}

/// Creates an ISO domain_error.
BuiltinError _domainError(
  final String domain,
  final Term culprit,
  final String context,
) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('domain_error'), [Atom(domain), culprit]),
      Atom(context),
    ]),
  );
}

/// Creates an ISO representation_error.
BuiltinError _representationError(final String flag, final String context) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('representation_error'), [Atom(flag)]),
      Atom(context),
    ]),
  );
}

/// Registers ISO Prolog term manipulation built-in predicates.
///
/// These predicates allow inspection and construction of Prolog terms.
/// All predicates follow ISO/IEC 13211-1:1995 standard.
///
/// **Predicates registered:**
/// - `functor/3` - Relates term to functor name and arity
/// - `arg/3` - Accesses argument of compound term (1-indexed)
/// - `=../2` (univ) - Converts between term and list `[functor|args]`
/// - `copy_term/2` - Creates term copy with renamed variables
/// - `term_variables/2` - Collects all variables in term
///
/// **Examples:**
/// ```prolog
/// ?- functor(foo(a,b), F, A).  % F=foo, A=2
/// ?- arg(2, foo(a,b,c), X).    % X=b
/// ?- foo(a,b) =.. L.           % L=[foo,a,b]
/// ```
void registerTermManipulationBuiltins(final BuiltinRegistry registry) {
  // functor/3 - relates a term to its functor and arity
  registry.register('functor', 3, _functorBuiltin);

  // arg/3 - accesses arguments of a compound term
  registry.register('arg', 3, _argBuiltin);

  // =../2 (univ) - converts between term and list representation
  registry.register('=..', 2, _univBuiltin);

  // copy_term/2 - creates a copy with fresh variables
  registry.register('copy_term', 2, _copyTermBuiltin);

  // term_variables/2 - collects all variables in a term
  registry.register('term_variables', 2, _termVariablesBuiltin);
}

/// Implements `functor/3`: relates term to functor and arity.
///
/// **Signature:** `functor(?Term, ?Functor, ?Arity)`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §8.5.1
///
/// **Modes:**
/// - `functor(+Term, ?F, ?A)` - Extract functor/arity
/// - `functor(?Term, +F, +A)` - Construct term with fresh variables
///
/// **ISO errors:**
/// - instantiation_error if Term is variable and Name or Arity is variable
/// - type_error(integer, Arity) if Arity is not an integer
/// - type_error(atom, Name) if Name is not atom (for arity > 0)
/// - type_error(atomic, Name) if Name is not atomic (for arity = 0)
/// - domain_error(not_less_than_zero, Arity) if Arity is negative
/// - representation_error(max_arity) if Arity exceeds max
///
/// **Examples:**
/// ```prolog
/// ?- functor(foo(a,b), F, A).  % F=foo, A=2
/// ?- functor(T, bar, 3).       % T=bar(_,_,_)
/// ?- functor(atom, F, A).      % F=atom, A=0
/// ```
BuiltinResult _functorBuiltin(final BuiltinContext context) {
  final term = context.arg(0);
  final functor = context.arg(1);
  final arity = context.arg(2);

  // Mode 1: Term is compound, extract functor and arity
  if (term is Compound) {
    context.trail.mark();
    final success =
        Unify.unify(
          functor,
          term.functor,
          context.substitution,
          context.trail,
        ) &&
        Unify.unify(
          arity,
          PrologInteger(term.arity),
          context.substitution,
          context.trail,
        );
    return success ? const BuiltinSuccess() : const BuiltinFailure();
  }

  // Mode 2: Term is atom (arity 0)
  if (term is Atom) {
    context.trail.mark();
    final success =
        Unify.unify(functor, term, context.substitution, context.trail) &&
        Unify.unify(
          arity,
          PrologInteger(0),
          context.substitution,
          context.trail,
        );
    return success ? const BuiltinSuccess() : const BuiltinFailure();
  }

  // Mode 3: Term is number (functor is the number itself, arity 0)
  if (term is PrologInteger || term is PrologFloat) {
    context.trail.mark();
    final success =
        Unify.unify(functor, term, context.substitution, context.trail) &&
        Unify.unify(
          arity,
          PrologInteger(0),
          context.substitution,
          context.trail,
        );
    return success ? const BuiltinSuccess() : const BuiltinFailure();
  }

  // Mode 4: Term is variable, construct term from functor and arity
  if (term is Variable) {
    // ISO: If Term is variable, both Name and Arity must be instantiated
    if (functor is Variable) {
      return _instantiationError('functor/3');
    }
    if (arity is Variable) {
      return _instantiationError('functor/3');
    }

    // ISO: Arity must be an integer
    if (arity is! PrologInteger) {
      return _typeError('integer', arity, 'functor/3');
    }

    final arityVal = arity.value;

    // ISO: Arity must be non-negative
    if (arityVal < 0) {
      return _domainError('not_less_than_zero', arity, 'functor/3');
    }

    // ISO: Check max arity (use reasonable limit)
    if (arityVal > 255) {
      return _representationError('max_arity', 'functor/3');
    }

    if (arityVal == 0) {
      // ISO: For arity 0, Name must be atomic
      if (!functor.isAtomic) {
        return _typeError('atomic', functor, 'functor/3');
      }
      return context.unifyAndReturn(term, functor);
    } else {
      // ISO: For arity > 0, Name must be an atom
      if (functor is! Atom) {
        return _typeError('atom', functor, 'functor/3');
      }
      // Create compound with fresh variables
      final args = List.generate(arityVal, (i) => Variable('_G$i'));
      final newTerm = Compound(functor, args);
      return context.unifyAndReturn(term, newTerm);
    }
  }

  return const BuiltinFailure();
}

/// Implements `arg/3`: accesses compound term arguments.
///
/// **Signature:** `arg(+N, +Term, ?Arg)`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §8.5.2
///
/// Unifies `Arg` with the N-th argument of `Term` (1-indexed).
///
/// **ISO errors:**
/// - instantiation_error if N or Term is a variable
/// - type_error(integer, N) if N is not an integer
/// - type_error(compound, Term) if Term is not a compound term
/// - domain_error(not_less_than_zero, N) if N is negative
///
/// **Example:** `?- arg(2, foo(a,b,c), X).  % X=b`
BuiltinResult _argBuiltin(final BuiltinContext context) {
  final n = context.arg(0);
  final term = context.arg(1);
  final arg = context.arg(2);

  // ISO: N must be instantiated
  if (n is Variable) {
    return _instantiationError('arg/3');
  }

  // ISO: Term must be instantiated
  if (term is Variable) {
    return _instantiationError('arg/3');
  }

  // ISO: N must be an integer
  if (n is! PrologInteger) {
    return _typeError('integer', n, 'arg/3');
  }

  // ISO: Term must be compound
  if (term is! Compound) {
    return _typeError('compound', term, 'arg/3');
  }

  // ISO: N must be positive (negative is domain error)
  if (n.value < 0) {
    return _domainError('not_less_than_zero', n, 'arg/3');
  }

  final index = n.value - 1; // Convert to 0-indexed
  // Out of bounds (0 or > arity) - just fail, not an error per ISO
  if (index < 0 || index >= term.arity) {
    return const BuiltinFailure();
  }

  // Unify with the argument
  return context.unifyAndReturn(arg, term.args[index]);
}

/// Implements `=../2` (univ): term/list conversion.
///
/// **Signature:** `?Term =.. ?List`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §8.5.3
///
/// Converts between term and list `[Functor|Args]`.
///
/// **ISO errors:**
/// - instantiation_error if Term is variable and List is partial list or variable
/// - type_error(list, List) if List is not a list
/// - type_error(atom, Head) if List head is not atom (for arity > 0)
/// - type_error(atomic, Head) if List head is not atomic (for length 1)
/// - domain_error(non_empty_list, List) if List is empty
///
/// **Examples:**
/// ```prolog
/// ?- foo(a,b,c) =.. L.  % L=[foo,a,b,c]
/// ?- T =.. [bar,1,2].   % T=bar(1,2)
/// ?- atom =.. L.        % L=[atom]
/// ```
BuiltinResult _univBuiltin(final BuiltinContext context) {
  final term = context.arg(0);
  final list = context.arg(1);

  // Mode 1: Term to list
  if (term is Compound) {
    // Build list: [functor, arg1, arg2, ...]
    final elements = [term.functor, ...term.args];
    final resultList = Compound.fromList(elements);

    return context.unifyAndReturn(list, resultList);
  }

  if (term is Atom || term is PrologInteger || term is PrologFloat) {
    // Atomic terms: [term]
    final resultList = Compound.fromList([term]);

    return context.unifyAndReturn(list, resultList);
  }

  // Mode 2: List to term (Term is variable)
  if (term is Variable) {
    // ISO: List must be instantiated if Term is variable
    if (list is Variable) {
      return _instantiationError('=../2');
    }

    // ISO: List must be a proper list
    if (list is! Compound && list is! Atom) {
      return _typeError('list', list, '=../2');
    }

    // Extract list elements
    final elements = Compound.toList(list);
    if (elements == null) {
      return _typeError('list', list, '=../2');
    }

    // ISO: List must be non-empty
    if (elements.isEmpty) {
      return _domainError('non_empty_list', list, '=../2');
    }

    final head = elements.first;

    // ISO: Head must be instantiated
    if (head is Variable) {
      return _instantiationError('=../2');
    }

    // If only one element, it's an atom/number
    if (elements.length == 1) {
      // ISO: For length-1 list, head must be atomic
      if (!head.isAtomic) {
        return _typeError('atomic', head, '=../2');
      }
      return context.unifyAndReturn(term, head);
    }

    // Multiple elements: first is functor, rest are args
    // ISO: Functor must be an atom for arity > 0
    if (head is! Atom) {
      return _typeError('atom', head, '=../2');
    }

    final args = elements.sublist(1);
    final newTerm = Compound(head, args);

    return context.unifyAndReturn(term, newTerm);
  }

  return const BuiltinFailure();
}

/// Implements `copy_term/2`: creates term copy with fresh variables.
///
/// **Signature:** `copy_term(+Term, ?Copy)`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §8.5.4
///
/// **Example:** `?- copy_term(foo(X,X), C).  % C=foo(_1,_1)`
BuiltinResult _copyTermBuiltin(final BuiltinContext context) {
  final term = context.arg(0);
  final copy = context.arg(1);

  // Create a copy with renamed variables
  final varMapping = <Variable, Variable>{};
  final copiedTerm = _copyTerm(term, varMapping);

  return context.unifyAndReturn(copy, copiedTerm);
}

/// Creates a copy of a term with fresh variables.
Term _copyTerm(final Term term, final Map<Variable, Variable> varMapping) {
  if (term is Variable) {
    // Return mapped variable or create new one
    return varMapping.putIfAbsent(
      term,
      () => Variable('_C${varMapping.length}'),
    );
  } else if (term is Compound) {
    final copiedArgs = term.args
        .map((arg) => _copyTerm(arg, varMapping))
        .toList();
    return Compound(term.functor, copiedArgs);
  } else {
    // Atoms and numbers are immutable
    return term;
  }
}

/// Implements `term_variables/2`: collects term variables.
///
/// **Signature:** `term_variables(+Term, ?Variables)`
///
/// **ISO compliance:** Full ISO/IEC 13211-1:1995 §8.5.5
///
/// Unifies `Variables` with list of all variables in `Term`.
/// Variables appear in left-to-right order, duplicates listed once.
///
/// **Example:** `?- term_variables(foo(X,Y,X), V).  % V=[X,Y]`
BuiltinResult _termVariablesBuiltin(final BuiltinContext context) {
  final term = context.arg(0);
  final variables = context.arg(1);

  // Collect all unique variables in left-to-right order
  final seen = <Variable>{};
  final varList = <Variable>[];
  _collectVariables(term, seen, varList);

  // Convert to Prolog list
  final prologList = Compound.fromList(varList);

  return context.unifyAndReturn(variables, prologList);
}

/// Collects all unique variables from a term in left-to-right order.
void _collectVariables(
  final Term term,
  final Set<Variable> seen,
  final List<Variable> result,
) {
  if (term is Variable) {
    if (!seen.contains(term)) {
      seen.add(term);
      result.add(term);
    }
  } else if (term is Compound) {
    for (final arg in term.args) {
      _collectVariables(arg, seen, result);
    }
  }
  // Atoms and numbers have no variables
}
