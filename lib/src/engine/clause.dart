import '../terms/term.dart';
import '../terms/compound.dart';
import '../terms/atom.dart';

/// A Prolog clause (fact or rule).
///
/// Clauses have the form: Head :- Body
/// - Facts: Head only (body is implicitly true)
/// - Rules: Head :- Body
///
/// Examples:
/// - Fact: `parent(john, mary).`
/// - Rule: `grandparent(X, Z) :- parent(X, Y), parent(Y, Z).`
class Clause {
  /// The head of the clause (the consequent).
  final Term head;

  /// The body of the clause (the antecedent).
  /// Empty list for facts, list of goals for rules.
  final List<Term> body;

  /// Creates a clause with the given head and body.
  Clause(this.head, [List<Term>? body]) : body = body ?? [];

  /// Returns true if this is a fact (no body).
  bool get isFact => body.isEmpty;

  /// Returns true if this is a rule (has body).
  bool get isRule => body.isNotEmpty;

  /// Returns the functor of the head (for indexing).
  Atom get functor {
    if (head is Compound) {
      return (head as Compound).functor;
    } else if (head is Atom) {
      return head as Atom;
    }
    throw StateError('Clause head must be atom or compound: $head');
  }

  /// Returns the arity of the head (for indexing).
  int get arity {
    if (head is Compound) {
      return (head as Compound).arity;
    } else if (head is Atom) {
      return 0;
    }
    throw StateError('Clause head must be atom or compound: $head');
  }

  /// Returns the functor/arity indicator (e.g., "foo/2").
  String get indicator => '$functor/$arity';

  @override
  String toString() {
    if (isFact) {
      return '$head.';
    } else {
      final bodyStr = body.map((g) => g.toString()).join(', ');
      return '$head :- $bodyStr.';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Clause && other.head == head && _listEquals(other.body, body));

  @override
  int get hashCode => head.hashCode ^ body.length.hashCode;

  static bool _listEquals(final List<Term> a, final List<Term> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
