/// DCG built-in predicates.
library;

import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import 'builtin.dart';

/// Registers DCG built-in predicates.
void registerDCGBuiltins(final BuiltinRegistry registry) {
  // phrase/2 - Call a DCG rule with a list
  registry.register('phrase', 2, _phrase2);

  // phrase/3 - Call a DCG rule with a list and remainder
  registry.register('phrase', 3, _phrase3);
}

/// Implements phrase/2: phrase(RuleBody, List).
///
/// Calls a DCG rule body with the given list, expecting to consume all of it.
/// Equivalent to: phrase(RuleBody, List, [])
BuiltinResult _phrase2(final BuiltinContext context) {
  final ruleBody = context.arg(0);
  final list = context.arg(1);

  // phrase(RuleBody, List) is equivalent to phrase(RuleBody, List, [])
  // Which means: call RuleBody with List as S0 and [] as SN

  // Create the expanded goal: RuleBody(List, [])
  _expandPhraseGoal(ruleBody, list, Atom.nil);

  // We can't directly execute the goal here - we need resolver support
  // For now, return BuiltinNotFound to let the resolver handle it
  // In a full implementation, this would be handled specially in the resolver
  return const BuiltinNotFound();
}

/// Implements phrase/3: phrase(RuleBody, List, Remainder).
///
/// Calls a DCG rule body with the given list, leaving Remainder unconsumed.
BuiltinResult _phrase3(final BuiltinContext context) {
  final ruleBody = context.arg(0);
  final list = context.arg(1);
  final remainder = context.arg(2);

  // Create the expanded goal: RuleBody(List, Remainder)
  _expandPhraseGoal(ruleBody, list, remainder);

  // Same as phrase/2 - needs resolver support
  return const BuiltinNotFound();
}

/// Expands a phrase goal into a regular goal with difference list arguments.
Term _expandPhraseGoal(final Term ruleBody, final Term s0, final Term sN) {
  if (ruleBody is Atom) {
    // Simple atom: foo
    // Becomes: foo(S0, SN)
    return Compound(ruleBody, [s0, sN]);
  } else if (ruleBody is Compound) {
    // Compound: foo(X, Y)
    // Becomes: foo(X, Y, S0, SN)
    final newArgs = [...ruleBody.args, s0, sN];
    return Compound(ruleBody.functor, newArgs);
  } else {
    throw ArgumentError('Invalid phrase goal: $ruleBody');
  }
}
