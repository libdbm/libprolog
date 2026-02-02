import 'builtin.dart';

/// Registers control flow built-ins.
///
/// Note: Most control predicates (!, ,/2, ;/2, ->/2, \+/1, call/1, once/1, etc.)
/// are meta-predicates that require access to the resolver's goal stack and
/// choice points. They are implemented directly in the resolver rather than
/// as registered built-ins.
///
/// This function exists for future control predicates that don't need
/// resolver access.
void registerControlBuiltins(final BuiltinRegistry registry) {
  // Most control predicates are handled directly in the resolver:
  // - !/0 (cut) - manipulates choice point stack
  // - ,/2 (conjunction) - pushes goals
  // - ;/2 (disjunction) - creates choice points
  // - ->/2 (if-then) - conditional execution
  // - \+/1 (negation) - sub-query with isolated state
  // - call/1 (meta-call) - pushes goal
  // - once/1 - commits after first solution
  // - repeat/0 - infinite choice point
  // - catch/3, throw/1 - exception handling
}
