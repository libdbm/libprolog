/// DCG (Definite Clause Grammar) translator.
///
/// Transforms DCG rules (-->) into regular Prolog clauses using difference lists.
library;

import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/variable.dart';
import '../terms/compound.dart';
import '../engine/clause.dart';

/// Translates a DCG rule into a regular Prolog clause.
///
/// DCG rules have the form: Head --> Body
/// They are translated to: Head(S0, S) :- TranslatedBody
///
/// Where S0 and S are the difference list variables representing
/// the input and output state.
class DCGTranslator {
  int _varCounter = 0;

  /// Translates a DCG rule to a Prolog clause.
  ///
  /// Returns null if the term is not a DCG rule.
  Clause? translateRule(final Term term) {
    if (term is! Compound) return null;
    if (term.functor != Atom('-->')) return null;
    if (term.arity != 2) return null;

    _varCounter = 0;

    final head = term.args[0];
    final body = term.args[1];

    // Create difference list variables
    final s0 = _freshVar('S');
    final sN = _freshVar('S');

    // Translate head
    final translatedHead = _translateHead(head, s0, sN);

    // Translate body
    final translatedBody = _translateBody(body, s0, sN);

    return Clause(translatedHead, translatedBody);
  }

  /// Translates the head of a DCG rule.
  Term _translateHead(final Term head, final Variable s0, final Variable sN) {
    if (head is Atom) {
      // Simple atom head: foo --> ...
      // Becomes: foo(S0, SN)
      return Compound(head, [s0, sN]);
    } else if (head is Compound) {
      // Compound head: foo(X, Y) --> ...
      // Becomes: foo(X, Y, S0, SN)
      final newArgs = [...head.args, s0, sN];
      return Compound(head.functor, newArgs);
    } else {
      throw ArgumentError('Invalid DCG rule head: $head');
    }
  }

  /// Translates the body of a DCG rule.
  List<Term> _translateBody(
    final Term body,
    final Variable s0,
    final Variable sN,
  ) {
    if (body is Atom) {
      if (body == Atom('[]')) {
        // Empty production: S0 = SN
        return [
          Compound(Atom('='), [s0, sN]),
        ];
      } else {
        // Non-terminal: foo
        // Becomes: foo(S0, SN)
        return [
          Compound(body, [s0, sN]),
        ];
      }
    }

    if (body is Compound) {
      // Handle different DCG constructs
      if (body.functor == Atom(',') && body.arity == 2) {
        // Sequence: A, B
        final sMid = _freshVar('S');
        final leftGoals = _translateBody(body.args[0], s0, sMid);
        final rightGoals = _translateBody(body.args[1], sMid, sN);
        return [...leftGoals, ...rightGoals];
      } else if ((body.functor == Atom(';') || body.functor == Atom('|')) &&
          body.arity == 2) {
        // Disjunction: A ; B or A | B
        final leftGoals = _translateBody(body.args[0], s0, sN);
        final rightGoals = _translateBody(body.args[1], s0, sN);

        // Create disjunctive goal (normalize to semicolon)
        final leftConj = _makeConjunction(leftGoals);
        final rightConj = _makeConjunction(rightGoals);
        return [
          Compound(Atom(';'), [leftConj, rightConj]),
        ];
      } else if (body.functor == Atom.dot && body.arity == 2) {
        // Terminal list: [a, b, c]
        // Becomes: S0 = [a, b, c | SN]
        return [_makeListUnification(body, s0, sN)];
      } else if (body.functor == Atom('{}') && body.arity == 1) {
        // Grammar goal: { Goal }
        // Becomes: Goal (executed without consuming input)
        // S0 = SN, Goal
        return [
          Compound(Atom('='), [s0, sN]),
          body.args[0],
        ];
      } else {
        // Non-terminal with arguments: foo(X, Y)
        // Becomes: foo(X, Y, S0, SN)
        final newArgs = [...body.args, s0, sN];
        return [Compound(body.functor, newArgs)];
      }
    }

    if (body is Variable) {
      // Variable non-terminal (meta-call)
      return [
        Compound(Atom('call'), [body, s0, sN]),
      ];
    }

    throw ArgumentError('Invalid DCG body: $body');
  }

  /// Creates a unification with a terminal list.
  ///
  /// [a, b, c] with S0 and SN becomes: S0 = [a, b, c | SN]
  Term _makeListUnification(
    final Term list,
    final Variable s0,
    final Variable sN,
  ) {
    // Append SN to the end of the list
    final listWithTail = _appendTail(list, sN);
    return Compound(Atom('='), [s0, listWithTail]);
  }

  /// Appends a tail to a list term.
  ///
  /// Uses iterative approach to avoid stack overflow for long lists.
  Term _appendTail(final Term list, final Term tail) {
    // Collect all elements iteratively
    final elements = <Term>[];
    var current = list;

    while (current is Compound &&
        current.functor == Atom.dot &&
        current.arity == 2) {
      elements.add(current.args[0]);
      current = current.args[1];
    }

    if (current != Atom.nil) {
      throw ArgumentError('Not a proper list: $list');
    }

    // Build result from end to start
    var result = tail;
    for (var i = elements.length - 1; i >= 0; i--) {
      result = Compound(Atom.dot, [elements[i], result]);
    }

    return result;
  }

  /// Creates a conjunction from a list of goals.
  Term _makeConjunction(final List<Term> goals) {
    if (goals.isEmpty) {
      return Atom('true');
    }
    if (goals.length == 1) {
      return goals[0];
    }

    // Right-associate: (a, (b, c))
    var result = goals.last;
    for (var i = goals.length - 2; i >= 0; i--) {
      result = Compound(Atom(','), [goals[i], result]);
    }
    return result;
  }

  /// Generates a fresh variable.
  Variable _freshVar(final String prefix) {
    return Variable('$prefix${_varCounter++}');
  }
}

/// Helper to check if a clause is a DCG rule.
bool isDCGRule(final Term term) {
  return term is Compound && term.functor == Atom('-->') && term.arity == 2;
}
