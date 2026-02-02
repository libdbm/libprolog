import 'atom.dart';
import 'term.dart';

/// A Prolog compound term (structure).
///
/// Compound terms have a functor (atom) and zero or more arguments.
/// They represent structures like: f(a,b), person(john, 25), +(1,2)
///
/// Special cases:
/// - Arity 0: Equivalent to an atom (but represented as Atom, not Compound)
/// - Lists: Use functor '.' with arity 2 (head and tail)
///
/// Examples: foo(bar), f(X, Y), [H|T] (represented as '.'(H, T))
class Compound extends Term {
  /// The functor (name) of this compound term.
  final Atom functor;

  /// The arguments of this compound term.
  final List<Term> args;

  /// Creates a compound term with the given functor and arguments.
  Compound(this.functor, this.args) {
    if (args.isEmpty) {
      throw ArgumentError(
        'Compound terms must have at least one argument. '
        'Use Atom for zero-arity functors.',
      );
    }
  }

  /// The arity (number of arguments) of this compound term.
  int get arity => args.length;

  /// Returns the functor/arity indicator (e.g., "foo/2").
  String get indicator => '${functor.value}/$arity';

  @override
  bool get isCompound => true;

  @override
  bool get isList {
    // A proper list is either [] or .(Head, Tail) where Tail is a list
    if (functor == Atom.dot && arity == 2) {
      final tail = args[1];
      return tail.isList || tail.isVariable;
    }
    return false;
  }

  @override
  bool get isGround {
    for (final arg in args) {
      if (!arg.isGround) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Compound) return false;
    if (functor != other.functor) return false;
    if (arity != other.arity) return false;

    for (var i = 0; i < arity; i++) {
      if (args[i] != other.args[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    var hash = functor.hashCode;
    for (final arg in args) {
      hash = hash ^ arg.hashCode;
    }
    return hash;
  }

  @override
  String toString() {
    // Special handling for lists
    if (functor == Atom.dot && arity == 2) {
      return _listToString();
    }

    // Regular compound term
    final argStr = args.map((a) => a.toString()).join(', ');
    return '${functor.value}($argStr)';
  }

  /// Converts a list structure to readable list notation.
  String _listToString() {
    final elements = <String>[];
    Term current = this;

    while (current is Compound &&
        current.functor == Atom.dot &&
        current.arity == 2) {
      elements.add(current.args[0].toString());
      current = current.args[1];
    }

    if (current.isNil) {
      // Proper list: [1, 2, 3]
      return '[${elements.join(', ')}]';
    } else {
      // Improper list: [1, 2 | Tail]
      return '[${elements.join(', ')} | ${current.toString()}]';
    }
  }

  /// Converts a Dart list of terms to a Prolog list.
  static Term fromList(final List<Term> elements, [final Term? tail]) {
    Term result = tail ?? Atom.nil;

    // Build list from right to left
    for (var i = elements.length - 1; i >= 0; i--) {
      result = Compound(Atom.dot, [elements[i], result]);
    }

    return result;
  }

  /// Converts a Prolog list to a Dart list of terms.
  /// Returns null if the term is not a proper list.
  static List<Term>? toList(Term term) {
    final elements = <Term>[];

    while (term is Compound && term.functor == Atom.dot && term.arity == 2) {
      elements.add(term.args[0]);
      term = term.args[1];
    }

    // Must end with []
    if (term.isNil) {
      return elements;
    }

    return null; // Not a proper list
  }
}
