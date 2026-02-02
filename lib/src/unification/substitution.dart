import '../terms/term.dart';
import '../terms/variable.dart';
import '../terms/compound.dart';

/// A substitution (environment) mapping variables to terms.
///
/// Represents the current variable bindings during unification and execution.
/// Supports dereferencing (following variable chains) and term application.
class Substitution {
  /// The variable bindings map.
  final Map<Variable, Term> _bindings;

  /// Creates an empty substitution.
  Substitution() : _bindings = {};

  /// Creates a substitution with initial bindings.
  Substitution.from(final Map<Variable, Term> bindings)
    : _bindings = Map.from(bindings);

  /// Creates a copy of this substitution.
  Substitution copy() => Substitution.from(_bindings);

  /// Returns the number of bindings.
  int get size => _bindings.length;

  /// Returns true if this substitution is empty.
  bool get isEmpty => _bindings.isEmpty;

  /// Returns true if the variable is bound.
  bool isBound(final Variable variable) => _bindings.containsKey(variable);

  /// Binds a variable to a term.
  void bind(final Variable variable, final Term term) {
    _bindings[variable] = term;
  }

  /// Unbinds a variable (removes its binding).
  void unbind(final Variable variable) {
    _bindings.remove(variable);
  }

  /// Returns the binding for a variable, or null if unbound.
  Term? lookup(final Variable variable) => _bindings[variable];

  /// Dereferences a term by following variable bindings.
  ///
  /// Follows chains of variables until reaching a non-variable or unbound variable.
  /// Example: If X -> Y and Y -> Z and Z -> 42, then deref(X) returns 42.
  Term deref(Term term) {
    var current = term;
    while (current is Variable) {
      final binding = _bindings[current];
      if (binding == null) {
        return current; // Unbound variable
      }
      current = binding;
    }
    return current;
  }

  /// Applies this substitution to a term, returning a new term with
  /// all variables replaced by their bindings (recursively).
  ///
  /// Unbound variables remain as variables.
  Term apply(final Term term) {
    final derefed = deref(term);

    if (derefed is Variable) {
      return derefed; // Unbound variable
    } else if (derefed is Compound) {
      // Recursively apply to arguments
      final newArgs = derefed.args.map(apply).toList();
      return Compound(derefed.functor, newArgs);
    } else {
      // Atom or number - no substitution needed
      return derefed;
    }
  }

  /// Returns all bindings as a map (unmodifiable view).
  Map<Variable, Term> get bindings => Map.unmodifiable(_bindings);

  /// Returns the internal bindings map (for internal use only).
  Map<Variable, Term> get internalBindings => _bindings;

  /// Returns all bindings with dereferenced values.
  Map<Variable, Term> get dereferencedBindings {
    return _bindings.map((key, value) => MapEntry(key, deref(value)));
  }

  @override
  String toString() {
    if (_bindings.isEmpty) return '{}';

    final entries = _bindings.entries
        .map((e) => '${e.key} = ${deref(e.value)}')
        .join(', ');
    return '{$entries}';
  }
}
