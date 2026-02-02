import '../terms/term.dart';
import '../terms/variable.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../unification/substitution.dart';
import '../unification/trail.dart';
import '../unification/unify.dart';
import '../database/database.dart';
import '../builtins/builtins.dart';
import '../io/stream_manager.dart';
import '../utils/term_comparison.dart';
import 'clause.dart';
import 'goal.dart';
import 'choice_point.dart';
import 'solution.dart';

/// Trace port types for debugging.
enum TracePort {
  /// Goal is being called
  call,

  /// Goal succeeded
  exit,

  /// Backtracking into goal
  redo,

  /// Goal failed
  fail,
}

/// Callback for trace events.
///
/// [port] indicates the trace port type.
/// [depth] is the current call depth.
/// [goal] is the goal being traced.
/// Returns true to continue, false to abort.
typedef TraceCallback = bool Function(TracePort port, int depth, Term goal);

/// SLD Resolution engine.
///
/// Implements the core Prolog execution algorithm:
/// - SLD (Selective Linear Definite clause) resolution
/// - Left-to-right goal selection
/// - Depth-first search with backtracking
/// - Cut support
class Resolver {
  /// The clause database.
  final Database database;

  /// The built-in predicate registry.
  final BuiltinRegistry builtins;

  /// The stream manager for I/O operations.
  final StreamManager streamManager;

  /// The current substitution.
  final Substitution substitution = Substitution();

  /// The trail for backtracking.
  final Trail trail = Trail();

  /// The goal stack.
  final GoalStack goals = GoalStack();

  /// The choice point stack.
  final ChoicePointStack choicePoints = ChoicePointStack();

  /// Counter for generating fresh variables (for renaming).
  int _varCounter = 0;

  /// Whether tracing is enabled.
  bool _tracing = false;

  /// Current call depth for tracing.
  int _traceDepth = 0;

  /// Optional trace callback for custom handling.
  TraceCallback? _traceCallback;

  /// Enables tracing with optional custom callback.
  ///
  /// If no callback is provided, uses default console output.
  void trace([final TraceCallback? callback]) {
    _tracing = true;
    _traceCallback = callback;
  }

  /// Disables tracing.
  void notrace() {
    _tracing = false;
    _traceCallback = null;
  }

  /// Returns true if tracing is currently enabled.
  bool get isTracing => _tracing;

  /// Creates a resolver with the given database and optional builtin registry.
  factory Resolver(
    final Database database, {
    BuiltinRegistry? builtins,
    StreamManager? streamManager,
  }) {
    final sm = streamManager ?? StreamManager();
    final br =
        builtins ??
        createStandardRegistry(streamManager: sm, database: database);
    return Resolver._(database, br, sm);
  }

  Resolver._(this.database, this.builtins, this.streamManager);

  /// Executes a query and returns all solutions as a stream.
  ///
  /// The query can be a single goal or a list of goals.
  Stream<Solution> query(final List<Term> queryGoals) async* {
    // Reset state
    _reset();

    // Add query goals to goal stack in reverse order
    // (since we pop from the end, this ensures left-to-right execution)
    for (var i = queryGoals.length - 1; i >= 0; i--) {
      goals.push(Goal(queryGoals[i]));
    }

    // Search for solutions
    yield* _solve();
  }

  /// Executes a single goal query.
  Stream<Solution> queryGoal(final Term goal) => query([goal]);

  /// Executes a goal in a sub-context, inheriting current bindings.
  ///
  /// This is used by meta-predicates like negation, findall, bagof, setof
  /// to run goals in isolation while preserving the parent environment.
  /// Unlike query(), this does NOT reset state first.
  Stream<Solution> _querySubgoal(final Term goal) async* {
    // Push goal onto stack
    goals.push(Goal(goal));

    // Search for solutions (without resetting first)
    yield* _solve();
  }

  /// Main resolution loop.
  Stream<Solution> _solve() async* {
    while (true) {
      // Success: no more goals
      if (goals.isEmpty) {
        yield Solution(substitution.copy());

        // Backtrack to find more solutions
        if (!_backtrack()) {
          return; // No more solutions
        }
        continue;
      }

      // Select leftmost goal
      final goal = goals.pop()!;

      // Skip tracing for internal markers
      final isInternal =
          goal.term is _IfThenCommit ||
          goal.term is _OnceCommit ||
          goal.term is _IgnoreCommit ||
          goal.term is _CatchCleanup;

      // Trace call port
      if (!isInternal) {
        _traceDepth++;
        _trace(TracePort.call, goal.term);
      }

      // Handle built-ins
      final builtinResult = await _handleBuiltin(goal);
      if (builtinResult == _BuiltinResult.handled) {
        // Trace exit port for built-ins
        if (!isInternal) {
          _trace(TracePort.exit, goal.term);
          _traceDepth--;
        }
        continue; // Built-in succeeded
      } else if (builtinResult == _BuiltinResult.failed) {
        // Trace fail port
        if (!isInternal) {
          _trace(TracePort.fail, goal.term);
          _traceDepth--;
        }
        // Built-in failed, backtrack
        if (!_backtrack()) {
          return;
        }
        continue;
      }

      // Try to prove the goal using clauses
      if (!_proveGoal(goal)) {
        // Trace fail port
        if (!isInternal) {
          _trace(TracePort.fail, goal.term);
          _traceDepth--;
        }
        // No matching clause found, backtrack
        if (!_backtrack()) {
          return;
        }
      } else if (!isInternal) {
        // Trace exit port for clause match
        _trace(TracePort.exit, goal.term);
        _traceDepth--;
      }
    }
  }

  /// Attempts to prove a goal using clauses from the database.
  bool _proveGoal(final Goal goal) {
    // Retrieve matching clauses
    final clauses = database.retrieve(goal.term).toList();

    if (clauses.isEmpty) {
      return false; // No matching clauses
    }

    // If multiple clauses, create choice point for alternatives
    if (clauses.length > 1) {
      final marker = trail.mark();

      // Save goal stack for backtracking
      // IMPORTANT: The current goal has already been popped from the stack,
      // but we need to re-prove it with the alternative clause on backtrack,
      // so we save the stack WITHOUT the current goal. The goal itself is
      // stored separately in the choice point.
      final savedGoals = goals.copy();

      choicePoints.push(
        ChoicePoint(
          goal: goal,
          alternatives: clauses.sublist(1), // Remaining clauses
          trailMarker: marker,
          goals: savedGoals,
          goalCount: goals.size,
        ),
      );
    } else {
      trail.mark(); // Mark for this attempt
    }

    // Try first clause
    return _tryClause(goal, clauses[0]);
  }

  /// Tries to use a clause to prove a goal.
  bool _tryClause(final Goal goal, final Clause clause) {
    // Rename variables in the clause to avoid conflicts
    final renamedClause = _renameClause(clause);

    // Unify goal with clause head
    // ISO: Clause matching uses no occur check, allowing rational trees
    if (!Unify.unifyNoOccurCheck(
      goal.term,
      renamedClause.head,
      substitution,
      trail,
    )) {
      return false;
    }

    // Add clause body goals to goal stack (in reverse order)
    for (var i = renamedClause.body.length - 1; i >= 0; i--) {
      goals.push(Goal(renamedClause.body[i]));
    }

    return true;
  }

  /// Backtracks to the most recent choice point.
  bool _backtrack() {
    while (choicePoints.isNotEmpty) {
      final point = choicePoints.pop();
      if (point == null) break;

      // Try next alternative clause
      final nextClause = point.popAlternative();

      if (nextClause != null) {
        // We have a clause to try
        // Re-add choice point if more alternatives remain
        if (point.hasAlternatives) {
          choicePoints.push(point);
        }

        // Restore state
        trail.undoToMarker(point.trailMarker, substitution);
        goals.clear();
        for (final g in point.goals.goals) {
          goals.push(g);
        }

        trail.mark();
        if (_tryClause(point.goal, nextClause)) {
          return true;
        }
        // If this clause failed, continue backtracking
      } else if (point.isControlConstruct) {
        // This is a control construct - the goal itself is the alternative
        // For control constructs (disjunction, if-then-else), when there are
        // no clause alternatives, the goal is executed as the alternative
        trail.undoToMarker(point.trailMarker, substitution);
        goals.clear();
        for (final g in point.goals.goals) {
          goals.push(g);
        }

        // Push the alternative goal
        trail.mark();
        goals.push(point.goal);
        return true;
      }
      // else: No more alternatives for this choice point - continue to next
    }

    return false; // No more choice points
  }

  /// Handles built-in predicates.
  ///
  /// Returns the result of the built-in execution.
  Future<_BuiltinResult> _handleBuiltin(final Goal goal) async {
    final term = goal.term;

    // Handle if-then commit marker (internal use only)
    if (term is _IfThenCommit) {
      // Remove all choice points created after the saved count
      // This commits to the then-branch and prevents else-branch
      while (choicePoints.size > term.choicePointCount) {
        choicePoints.pop();
      }
      return _BuiltinResult.handled;
    }

    // Handle once commit marker (internal use only)
    if (term is _OnceCommit) {
      // Remove all choice points created after the saved count
      // This commits to the first solution of the goal
      while (choicePoints.size > term.choicePointCount) {
        choicePoints.pop();
      }
      return _BuiltinResult.handled;
    }

    // Handle ignore commit marker (internal use only)
    if (term is _IgnoreCommit) {
      // Remove all choice points created after the saved count
      // This removes goal's choice points AND the fallback 'true' choice point
      while (choicePoints.size > term.choicePointCount) {
        choicePoints.pop();
      }
      return _BuiltinResult.handled;
    }

    // Handle catch cleanup marker (internal use only)
    if (term is _CatchCleanup) {
      // Goal in catch/3 succeeded - remove the catch frame
      // Pop catch frames down to the saved count
      while (choicePoints.size > term.choicePointCount) {
        final point = choicePoints.pop();
        // Stop if we removed a catch frame (the one we care about)
        if (point != null && point.isCatchFrame) {
          break;
        }
      }
      return _BuiltinResult.handled;
    }

    // Handle cut specially (not in registry)
    if (term is Atom && term == Atom.cut) {
      _cut();
      return _BuiltinResult.handled;
    }

    // Handle =/2 specially (needs to be in resolver for now)
    // ISO standard: =/2 does NOT perform occur check (allows rational trees)
    // Unification is deterministic - no choice points needed
    if (term is Compound && term.functor == Atom('=') && term.arity == 2) {
      if (Unify.unifyNoOccurCheck(
        term.args[0],
        term.args[1],
        substitution,
        trail,
      )) {
        return _BuiltinResult.handled;
      } else {
        return _BuiltinResult.failed;
      }
    }

    // Handle ,/2 (conjunction)
    if (term is Compound && term.functor == Atom(',') && term.arity == 2) {
      // Push goals in reverse order (right-to-left) so they execute left-to-right
      goals.push(Goal(term.args[1]));
      goals.push(Goal(term.args[0]));
      return _BuiltinResult.handled;
    }

    // Handle call/1 (meta-call)
    if (term is Compound && term.functor == Atom('call') && term.arity == 1) {
      final goal = substitution.deref(term.args[0]);
      goals.push(Goal(goal));
      return _BuiltinResult.handled;
    }

    // Handle \+/1 (negation as failure)
    if (term is Compound && term.functor == Atom('\\+') && term.arity == 1) {
      return await _handleNegation(term.args[0]);
    }

    // Handle ;/2 (disjunction / if-then-else)
    if (term is Compound && term.functor == Atom(';') && term.arity == 2) {
      return _handleDisjunction(term.args[0], term.args[1]);
    }

    // Handle ->/2 (if-then) when not part of if-then-else
    if (term is Compound && term.functor == Atom('->') && term.arity == 2) {
      return _handleIfThen(term.args[0], term.args[1]);
    }

    // Handle findall/3 (all-solutions)
    if (term is Compound &&
        term.functor == Atom('findall') &&
        term.arity == 3) {
      return await _handleFindall(term.args[0], term.args[1], term.args[2]);
    }

    // Handle bagof/3 (all-solutions with free variables)
    if (term is Compound && term.functor == Atom('bagof') && term.arity == 3) {
      return await _handleBagof(term.args[0], term.args[1], term.args[2]);
    }

    // Handle setof/3 (sorted unique solutions)
    if (term is Compound && term.functor == Atom('setof') && term.arity == 3) {
      return await _handleSetof(term.args[0], term.args[1], term.args[2]);
    }

    // Handle repeat/0 - infinite choice point
    if (term is Atom && term.value == 'repeat') {
      return _handleRepeat();
    }

    // Handle trace/0 - enable tracing
    if (term is Atom && term.value == 'trace') {
      trace();
      return _BuiltinResult.handled;
    }

    // Handle notrace/0 - disable tracing
    if (term is Atom && term.value == 'notrace') {
      notrace();
      return _BuiltinResult.handled;
    }

    // Handle once/1 - execute goal at most once
    if (term is Compound && term.functor == Atom('once') && term.arity == 1) {
      return _handleOnce(term.args[0]);
    }

    // Handle ignore/1 - execute goal, always succeed
    if (term is Compound && term.functor == Atom('ignore') && term.arity == 1) {
      return _handleIgnore(term.args[0]);
    }

    // Handle member/2 - non-deterministic list membership
    if (term is Compound && term.functor == Atom('member') && term.arity == 2) {
      return _handleMember(term.args[0], term.args[1]);
    }

    // Handle append/3 - non-deterministic list concatenation
    if (term is Compound && term.functor == Atom('append') && term.arity == 3) {
      return _handleAppend(term.args[0], term.args[1], term.args[2]);
    }

    // Handle phrase/2 - execute DCG rule
    if (term is Compound && term.functor == Atom('phrase') && term.arity == 2) {
      return _handlePhrase2(term.args[0], term.args[1]);
    }

    // Handle phrase/3 - execute DCG rule with remainder
    if (term is Compound && term.functor == Atom('phrase') && term.arity == 3) {
      return _handlePhrase3(term.args[0], term.args[1], term.args[2]);
    }

    // Handle catch/3 - ISO exception handling
    if (term is Compound && term.functor == Atom('catch') && term.arity == 3) {
      return _handleCatch(term.args[0], term.args[1], term.args[2]);
    }

    // Handle throw/1 - throw exception
    if (term is Compound && term.functor == Atom('throw') && term.arity == 1) {
      return _handleThrow(term.args[0]);
    }

    // Try builtin registry
    String name;
    int arity;
    List<Term> args;

    if (term is Atom) {
      name = term.value;
      arity = 0;
      args = [];
    } else if (term is Compound) {
      name = term.functor.value;
      arity = term.arity;
      // Dereference all arguments
      args = term.args.map((arg) => substitution.deref(arg)).toList();
    } else {
      return _BuiltinResult.notBuiltin;
    }

    final builtin = builtins.lookup(name, arity);
    if (builtin == null) {
      return _BuiltinResult.notBuiltin;
    }

    // Execute builtin
    final context = BuiltinContext(
      substitution: substitution,
      trail: trail,
      args: args,
    );

    final result = builtin(context);

    // Convert builtin result to resolver result
    return switch (result) {
      BuiltinSuccess() => _BuiltinResult.handled,
      BuiltinFailure() => _BuiltinResult.failed,
      BuiltinNotFound() => _BuiltinResult.notBuiltin,
      BuiltinError(error: final e) => _pushThrow(e),
      BuiltinStream() => throw UnimplementedError(
        'Non-deterministic built-ins not yet supported',
      ),
    };
  }

  /// Pushes a throw goal for the given error term.
  _BuiltinResult _pushThrow(final Term error) {
    goals.push(Goal(Compound(Atom('throw'), [error])));
    return _BuiltinResult.handled;
  }

  /// Implements the cut operation.
  ///
  /// Cut removes all choice points created since entering the current clause.
  void _cut() {
    // Remove all choice points at or above the current goal depth
    // ISO semantics: cut removes all younger choice points
    choicePoints.cutTo(goals.size);
    trail.commit();
  }

  /// Handles \+/1 (negation as failure).
  ///
  /// Succeeds if goal fails, fails if goal succeeds.
  /// Does not bind any variables.
  ///
  /// Note: This is a simplified implementation that creates a sub-query.
  /// A full implementation would integrate more deeply with the resolution engine.
  Future<_BuiltinResult> _handleNegation(final Term goal) async {
    // Save current state (goals stack, choice points count, trail position)
    final savedGoals = goals.copy();
    final savedChoicePointCount = choicePoints.size;
    final trailMark = trail.mark();

    // Try to prove the goal in current environment
    bool succeeded = false;
    await for (final _ in _querySubgoal(goal)) {
      succeeded = true;
      break; // We only need to know if it succeeds once
    }

    // Restore state (negation doesn't bind variables or affect environment)
    // Undo any bindings made during the subgoal
    trail.undoToMarker(trailMark, substitution);

    // Restore goal stack
    goals.clear();
    goals.pushAll(savedGoals.goals);

    // Remove any choice points created during subgoal execution
    while (choicePoints.size > savedChoicePointCount) {
      choicePoints.pop();
    }

    // Negation succeeds if the goal failed
    return succeeded ? _BuiltinResult.failed : _BuiltinResult.handled;
  }

  /// Handles ;/2 (disjunction or if-then-else).
  ///
  /// If left side is (Cond -> Then), this is if-then-else: (Cond -> Then ; Else)
  /// Otherwise, this is simple disjunction: (A ; B)
  _BuiltinResult _handleDisjunction(final Term left, final Term right) {
    // Check if this is if-then-else: (Cond -> Then ; Else)
    if (left is Compound && left.functor == Atom('->') && left.arity == 2) {
      final condition = left.args[0];
      final thenBranch = left.args[1];
      final elseBranch = right;

      // ISO semantics for if-then-else:
      // 1. Try condition
      // 2. If condition succeeds at least once:
      //    - Remove all choice points created by condition
      //    - Execute then-branch
      //    - Don't try else-branch
      // 3. If condition fails:
      //    - Execute else-branch

      final marker = trail.mark();
      final savedGoals = goals.copy();
      final choicePointCount = choicePoints.size;

      // Create choice point for else-branch (empty list, goal is alternative)
      choicePoints.push(
        ChoicePoint(
          goal: Goal(elseBranch),
          alternatives: <Clause>[],
          trailMarker: marker,
          goals: savedGoals,
          goalCount: goals.size,
        ),
      );

      // Push: then-branch, commit, condition
      // When condition succeeds, commit removes the else choice point
      goals.push(Goal(thenBranch));
      goals.push(Goal(_IfThenCommit(choicePointCount)));
      goals.push(Goal(condition));

      return _BuiltinResult.handled;
    }

    // Simple disjunction: try left, with right as alternative
    final marker = trail.mark();
    final savedGoals = goals.copy();

    // Create choice point for right alternative
    // ISO semantics: cut in left branch should remove this choice point
    choicePoints.push(
      ChoicePoint(
        goal: Goal(right),
        alternatives: <Clause>[], // No clauses, goal is alternative
        trailMarker: marker,
        goals: savedGoals,
        goalCount: goals.size,
        removableByCut: true, // Cut in left branch removes this
      ),
    );

    // Try left first
    goals.push(Goal(left));

    return _BuiltinResult.handled;
  }

  /// Handles ->/2 (if-then).
  ///
  /// Succeeds if condition succeeds and commits to then-branch.
  /// ISO semantics: Once condition succeeds, choice points created
  /// during condition evaluation are removed (committed).
  _BuiltinResult _handleIfThen(final Term condition, final Term thenBranch) {
    // Save current choice point count for commit
    final count = choicePoints.size;

    // Try condition
    trail.mark();

    // Push: then-branch, commit marker, condition
    // When condition succeeds, commit removes choice points created during condition
    goals.push(Goal(thenBranch));
    goals.push(Goal(_IfThenCommit(count)));
    goals.push(Goal(condition));

    return _BuiltinResult.handled;
  }

  /// Collects all solutions for a goal with a given template.
  ///
  /// This helper method encapsulates state management for all-solutions predicates:
  /// - Saves current state (goals, choice points, trail)
  /// - Executes goal and collects template instantiations
  /// - Restores state (ensuring goal doesn't bind caller variables)
  /// - Returns list of collected solutions
  Future<List<Term>> _collectSolutions(
    final Term template,
    final Term goal,
  ) async {
    // Save current state
    final saved = goals.copy();
    final savedCount = choicePoints.size;
    final mark = trail.mark();

    // Collect all solutions
    final solutions = <Term>[];
    await for (final solution in _querySubgoal(goal)) {
      final instantiated = solution.substitution.apply(template);
      solutions.add(instantiated);
    }

    // Restore state (doesn't bind goal variables to caller)
    trail.undoToMarker(mark, substitution);
    goals.clear();
    goals.pushAll(saved.goals);
    while (choicePoints.size > savedCount) {
      choicePoints.pop();
    }

    return solutions;
  }

  /// A witness group containing free variable bindings and solutions.
  ///
  /// Used by bagof/setof to group solutions by free variable bindings
  /// and support backtracking over different witness sets.

  /// Collects solutions grouped by free variable bindings (witness sets).
  ///
  /// Free variables are variables in the goal that don't appear in the template
  /// and are not existentially quantified with ^.
  /// For bagof/setof, solutions are grouped by unique bindings of free vars.
  ///
  /// Returns a list of witness groups, where each group contains:
  /// - The free variables (in consistent order)
  /// - The binding values for those variables (witness)
  /// - The list of solutions for that witness
  Future<List<_WitnessGroup>> _collectSolutionsGroupedWithWitness(
    final Term template,
    final Term goal,
  ) async {
    // Extract existentially quantified variables and inner goal
    final (existential, inner) = _extractExistential(goal);

    // Find free variables (in goal but not in template and not existentially quantified)
    final templateVars = _collectVariables(template);
    final goalVars = _collectVariables(inner);
    final freeVars = goalVars
        .where((v) => !templateVars.contains(v) && !existential.contains(v))
        .toList();
    // Sort for consistent ordering
    freeVars.sort((a, b) => a.name.compareTo(b.name));

    // Save current state
    final saved = goals.copy();
    final savedCount = choicePoints.size;
    final mark = trail.mark();

    // Collect solutions grouped by witness (free variable bindings)
    // Use string key for grouping, but store actual bindings
    final grouped = <String, _WitnessGroup>{};

    // Execute the inner goal (without the ^ wrapper)
    await for (final solution in _querySubgoal(inner)) {
      // Create witness key and bindings from free variable bindings
      final bindings = <Term>[];
      final parts = <String>[];

      for (final v in freeVars) {
        final value = solution.substitution.deref(v);
        bindings.add(value);
        parts.add('${v.name}=$value');
      }

      final key = '[${parts.join(',')}]';

      // Add instantiated template to this witness group
      final instantiated = solution.substitution.apply(template);
      if (!grouped.containsKey(key)) {
        grouped[key] = _WitnessGroup(freeVars, bindings, []);
      }
      grouped[key]!.solutions.add(instantiated);
    }

    // Restore state
    trail.undoToMarker(mark, substitution);
    goals.clear();
    goals.pushAll(saved.goals);
    while (choicePoints.size > savedCount) {
      choicePoints.pop();
    }

    return grouped.values.toList();
  }

  /// Collects all variables in a term.
  Set<Variable> _collectVariables(final Term term) {
    final vars = <Variable>{};

    void collect(final Term t) {
      final deref = substitution.deref(t);
      if (deref is Variable) {
        vars.add(deref);
      } else if (deref is Compound) {
        for (final arg in deref.args) {
          collect(arg);
        }
      }
    }

    collect(term);
    return vars;
  }

  /// Extracts existentially quantified variables from a goal.
  ///
  /// In bagof/setof, the ^ operator marks variables as existentially
  /// quantified, meaning they should be excluded from witness grouping.
  /// For example, in `bagof(X, Y^foo(X,Y,Z), Xs)`, Y is existentially
  /// quantified and only Z determines witness groups.
  ///
  /// Returns a tuple of (existentially quantified variables, inner goal).
  (Set<Variable>, Term) _extractExistential(final Term goal) {
    final quantified = <Variable>{};
    var current = goal;

    // Keep extracting V^Goal until no more ^ operators
    while (current is Compound &&
        current.functor == Atom('^') &&
        current.arity == 2) {
      // Left side can be a variable or a tuple of variables
      _collectQuantifiedVars(current.args[0], quantified);
      current = current.args[1];
    }

    return (quantified, current);
  }

  /// Collects variables from the left side of ^ operator.
  /// Handles both single variables and tuples like (A,B)^Goal.
  void _collectQuantifiedVars(final Term term, final Set<Variable> vars) {
    final deref = substitution.deref(term);
    if (deref is Variable) {
      vars.add(deref);
    } else if (deref is Compound &&
        deref.functor == Atom(',') &&
        deref.arity == 2) {
      // Tuple: (A,B)
      _collectQuantifiedVars(deref.args[0], vars);
      _collectQuantifiedVars(deref.args[1], vars);
    }
  }

  /// Handles findall/3: findall(Template, Goal, List).
  ///
  /// Collects all instantiations of Template for which Goal succeeds.
  Future<_BuiltinResult> _handleFindall(
    final Term template,
    final Term goal,
    final Term resultList,
  ) async {
    final solutions = await _collectSolutions(template, goal);

    // Convert solutions to Prolog list
    final list = Compound.fromList(solutions);

    // Unify with result
    final marker = trail.mark();
    if (Unify.unify(resultList, list, substitution, trail)) {
      trail.commit();
      return _BuiltinResult.handled;
    } else {
      trail.undoToMarker(marker, substitution);
      return _BuiltinResult.failed;
    }
  }

  /// Handles bagof/3: bagof(Template, Goal, List).
  ///
  /// Like findall but fails if no solutions and groups by free variables.
  ///
  /// Free variables (variables in Goal but not in Template) create witness sets.
  /// Each unique binding of free variables produces a separate solution on backtracking.
  ///
  /// ISO compliance: Creates choice points for multiple witness groups.
  Future<_BuiltinResult> _handleBagof(
    final Term template,
    final Term goal,
    final Term resultList,
  ) async {
    final groups = await _collectSolutionsGroupedWithWitness(template, goal);

    // Fail if no solutions (unlike findall)
    if (groups.isEmpty) {
      return _BuiltinResult.failed;
    }

    // Create choice points for remaining witness groups (in reverse order)
    // so that backtracking processes them in forward order.
    if (groups.length > 1) {
      final marker = trail.mark();
      final savedGoals = goals.copy();

      for (var i = groups.length - 1; i > 0; i--) {
        final group = groups[i];
        final list = Compound.fromList(group.solutions);

        // Create a goal that unifies witness variables and result list
        final unifyGoal = group.createUnificationGoal(resultList, list);

        choicePoints.push(
          ChoicePoint(
            goal: Goal(unifyGoal),
            alternatives: <Clause>[],
            trailMarker: marker,
            goals: savedGoals,
            goalCount: goals.size,
          ),
        );
      }
    }

    // Process first witness group immediately
    final firstGroup = groups[0];
    final list = Compound.fromList(firstGroup.solutions);

    // Unify witness variables with their bindings
    final marker = trail.mark();
    var success = true;
    for (var i = 0; i < firstGroup.variables.length && success; i++) {
      success = Unify.unify(
        firstGroup.variables[i],
        firstGroup.bindings[i],
        substitution,
        trail,
      );
    }

    // Unify result list
    if (success) {
      success = Unify.unify(resultList, list, substitution, trail);
    }

    if (success) {
      trail.commit();
      return _BuiltinResult.handled;
    } else {
      trail.undoToMarker(marker, substitution);
      return _BuiltinResult.failed;
    }
  }

  /// Handles setof/3: setof(Template, Goal, List).
  ///
  /// Like bagof but sorts and removes duplicates using structural comparison.
  ///
  /// Free variables (variables in Goal but not in Template) create witness sets.
  /// Each unique binding of free variables produces a separate solution on backtracking.
  ///
  /// ISO compliance: Creates choice points for multiple witness groups.
  Future<_BuiltinResult> _handleSetof(
    final Term template,
    final Term goal,
    final Term resultList,
  ) async {
    final groups = await _collectSolutionsGroupedWithWitness(template, goal);

    // Fail if no solutions
    if (groups.isEmpty) {
      return _BuiltinResult.failed;
    }

    // Helper to sort and remove duplicates for a solution list
    List<Term> sortAndUnique(final List<Term> solutions) {
      final sorted = TermComparison.sort(solutions);
      return TermComparison.removeDuplicates(sorted);
    }

    // Create choice points for remaining witness groups (in reverse order)
    // so that backtracking processes them in forward order.
    if (groups.length > 1) {
      final marker = trail.mark();
      final savedGoals = goals.copy();

      for (var i = groups.length - 1; i > 0; i--) {
        final group = groups[i];
        final unique = sortAndUnique(group.solutions);
        final list = Compound.fromList(unique);

        // Create a goal that unifies witness variables and result list
        final unifyGoal = group.createUnificationGoal(resultList, list);

        choicePoints.push(
          ChoicePoint(
            goal: Goal(unifyGoal),
            alternatives: <Clause>[],
            trailMarker: marker,
            goals: savedGoals,
            goalCount: goals.size,
          ),
        );
      }
    }

    // Process first witness group immediately
    final firstGroup = groups[0];
    final unique = sortAndUnique(firstGroup.solutions);
    final list = Compound.fromList(unique);

    // Unify witness variables with their bindings
    final marker = trail.mark();
    var success = true;
    for (var i = 0; i < firstGroup.variables.length && success; i++) {
      success = Unify.unify(
        firstGroup.variables[i],
        firstGroup.bindings[i],
        substitution,
        trail,
      );
    }

    // Unify result list
    if (success) {
      success = Unify.unify(resultList, list, substitution, trail);
    }

    if (success) {
      trail.commit();
      return _BuiltinResult.handled;
    } else {
      trail.undoToMarker(marker, substitution);
      return _BuiltinResult.failed;
    }
  }

  /// Handles repeat/0 - infinite choice point.
  ///
  /// Always succeeds and creates an infinite choice point for backtracking.
  _BuiltinResult _handleRepeat() {
    final marker = trail.mark();
    final savedGoals = goals.copy();

    // Create an infinite choice point that always offers repeat again
    choicePoints.push(
      ChoicePoint(
        goal: Goal(Atom('repeat')),
        alternatives: <Clause>[], // No clauses, goal itself is alternative
        trailMarker: marker,
        goals: savedGoals,
        goalCount: goals.size,
      ),
    );

    return _BuiltinResult.handled;
  }

  /// Handles once/1 - execute goal at most once.
  ///
  /// Succeeds if Goal succeeds, but prevents backtracking into Goal.
  /// Similar to (Goal -> true ; fail) - commits to first solution.
  _BuiltinResult _handleOnce(final Term goal) {
    // Save current choice point count
    final count = choicePoints.size;

    // Push goal followed by a commit marker
    // When the goal succeeds, the commit marker will cut choice points
    goals.push(Goal(_OnceCommit(count)));
    goals.push(Goal(goal));

    return _BuiltinResult.handled;
  }

  /// Handles ignore/1 - execute goal, always succeed.
  ///
  /// Executes Goal but always succeeds whether Goal succeeds or fails.
  /// ISO semantics: ignore(G) is equivalent to (G -> true ; true)
  /// - If G succeeds, commit to that solution (don't backtrack into G)
  /// - If G fails, still succeed
  _BuiltinResult _handleIgnore(final Term goal) {
    final marker = trail.mark();
    final savedGoals = goals.copy();
    final count = choicePoints.size;

    // Create a choice point that succeeds even if goal fails
    // The else-branch is just 'true'
    choicePoints.push(
      ChoicePoint(
        goal: Goal(Atom('true')),
        alternatives: <Clause>[],
        trailMarker: marker,
        goals: savedGoals,
        goalCount: goals.size,
      ),
    );

    // Push commit marker to remove goal's choice points AND the fallback
    // when goal succeeds (similar to once/1 but also removes fallback)
    goals.push(Goal(_IgnoreCommit(count)));
    goals.push(Goal(goal));

    return _BuiltinResult.handled;
  }

  /// Handles member/2: member(Element, List).
  ///
  /// Non-deterministic predicate that succeeds if Element is in List.
  /// Creates choice points to enumerate all elements on backtracking.
  ///
  /// ISO semantics:
  /// - member(X, [X|_]).
  /// - member(X, [_|T]) :- member(X, T).
  _BuiltinResult _handleMember(final Term element, final Term list) {
    final deref = substitution.deref(list);

    // List must be a proper list
    if (deref is! Compound || deref.functor != Atom.dot || deref.arity != 2) {
      if (deref == Atom.nil) {
        return _BuiltinResult.failed; // Empty list has no members
      }
      return _BuiltinResult.notBuiltin; // Not a list, try database
    }

    final head = deref.args[0];
    final tail = deref.args[1];

    // Create choice point for remaining elements (if tail is non-empty)
    final derefTail = substitution.deref(tail);
    if (derefTail is Compound && derefTail.functor == Atom.dot) {
      final marker = trail.mark();
      final saved = goals.copy();

      // Choice point: member(Element, Tail)
      choicePoints.push(
        ChoicePoint(
          goal: Goal(Compound(Atom('member'), [element, tail])),
          alternatives: <Clause>[],
          trailMarker: marker,
          goals: saved,
          goalCount: goals.size,
        ),
      );
    }

    // Try to unify element with head
    final marker = trail.mark();
    if (Unify.unify(element, head, substitution, trail)) {
      trail.commit();
      return _BuiltinResult.handled;
    }
    trail.undoToMarker(marker, substitution);

    // Head didn't match - if we have a choice point, backtrack will try tail
    // If no choice point (tail is empty), fail
    return _BuiltinResult.failed;
  }

  /// Handles append/3: append(List1, List2, List3).
  ///
  /// Non-deterministic predicate for list concatenation.
  /// Supports the common modes with proper backtracking for splits.
  ///
  /// ISO semantics:
  /// - append([], L, L).
  /// - append([H|T], L, [H|R]) :- append(T, L, R).
  _BuiltinResult _handleAppend(
    final Term list1,
    final Term list2,
    final Term list3,
  ) {
    final deref1 = substitution.deref(list1);
    final deref3 = substitution.deref(list3);

    // Case 1: list1 is [] - unify list2 with list3
    if (deref1 == Atom.nil) {
      final marker = trail.mark();
      if (Unify.unify(list2, list3, substitution, trail)) {
        trail.commit();
        return _BuiltinResult.handled;
      }
      trail.undoToMarker(marker, substitution);
      return _BuiltinResult.failed;
    }

    // Case 2: list1 is [H|T] - need list3 to be [H|R] and recurse
    if (deref1 is Compound && deref1.functor == Atom.dot && deref1.arity == 2) {
      final h1 = deref1.args[0];
      final t1 = deref1.args[1];

      // list3 is a non-empty list - match heads and recurse on tails
      if (deref3 is Compound &&
          deref3.functor == Atom.dot &&
          deref3.arity == 2) {
        final h3 = deref3.args[0];
        final r = deref3.args[1];

        final marker = trail.mark();
        // Unify heads
        if (Unify.unify(h1, h3, substitution, trail)) {
          // Recurse: append(T, List2, R)
          goals.push(Goal(Compound(Atom('append'), [t1, list2, r])));
          trail.commit();
          return _BuiltinResult.handled;
        }
        trail.undoToMarker(marker, substitution);
        return _BuiltinResult.failed;
      }

      // list3 is a variable - construct [H1|R] and recurse
      if (deref3.isVariable) {
        final r = Variable('_R${_varCounter++}');
        final marker = trail.mark();
        if (Unify.unify(
          list3,
          Compound(Atom.dot, [h1, r]),
          substitution,
          trail,
        )) {
          goals.push(Goal(Compound(Atom('append'), [t1, list2, r])));
          trail.commit();
          return _BuiltinResult.handled;
        }
        trail.undoToMarker(marker, substitution);
        return _BuiltinResult.failed;
      }

      // list3 is empty but list1 is not - fail
      return _BuiltinResult.failed;
    }

    // Case 3: list1 is variable, list3 is a list - generate splits
    // This is the non-deterministic case: append(X, Y, [1,2,3])
    if (deref1.isVariable && deref3 is Compound && deref3.functor == Atom.dot) {
      // Use helper to enumerate splits via recursive goal transformation
      // First clause: append([], L, L) - try list1 = [], list2 = list3
      final marker = trail.mark();
      final saved = goals.copy();

      // Create choice point for second clause attempt
      // Second clause: append([H|T], L, [H|R]) :- append(T, L, R)
      final h = deref3.args[0];
      final r = deref3.args[1];
      final t = Variable('_T${_varCounter++}');

      choicePoints.push(
        ChoicePoint(
          goal: Goal(
            Compound(Atom(','), [
              Compound(Atom('='), [
                list1,
                Compound(Atom.dot, [h, t]),
              ]),
              Compound(Atom('append'), [t, list2, r]),
            ]),
          ),
          alternatives: <Clause>[],
          trailMarker: marker,
          goals: saved,
          goalCount: goals.size,
        ),
      );

      // First try: list1 = [], list2 = list3
      if (Unify.unify(list1, Atom.nil, substitution, trail) &&
          Unify.unify(list2, list3, substitution, trail)) {
        trail.commit();
        return _BuiltinResult.handled;
      }
      trail.undoToMarker(marker, substitution);
      return _BuiltinResult.failed;
    }

    // Case 4: list1 is variable, list3 is []
    if (deref1.isVariable && deref3 == Atom.nil) {
      final marker = trail.mark();
      if (Unify.unify(list1, Atom.nil, substitution, trail) &&
          Unify.unify(list2, Atom.nil, substitution, trail)) {
        trail.commit();
        return _BuiltinResult.handled;
      }
      trail.undoToMarker(marker, substitution);
      return _BuiltinResult.failed;
    }

    // Case 5: Other modes - fall through to builtin for now
    return _BuiltinResult.notBuiltin;
  }

  /// Handles phrase/2: phrase(RuleSet, List).
  ///
  /// Executes a DCG rule to parse the entire List.
  _BuiltinResult _handlePhrase2(final Term ruleSet, final Term list) {
    // phrase(RuleSet, List) is equivalent to calling RuleSet(List, [])
    // where RuleSet is the name of a DCG-translated predicate

    // Create the goal: RuleSet(List, [])
    Term goal;
    if (ruleSet is Atom) {
      goal = Compound(ruleSet, [list, Atom.nil]);
    } else if (ruleSet is Compound) {
      // RuleSet might be something like rule(X), convert to rule(X, List, [])
      final args = [...ruleSet.args, list, Atom.nil];
      goal = Compound(ruleSet.functor, args);
    } else {
      return _BuiltinResult.failed;
    }

    // Push the goal for execution
    goals.push(Goal(goal));
    return _BuiltinResult.handled;
  }

  /// Handles phrase/3: phrase(RuleSet, List, Remainder).
  ///
  /// Executes a DCG rule to parse List with Remainder left over.
  _BuiltinResult _handlePhrase3(
    final Term ruleSet,
    final Term list,
    final Term remainder,
  ) {
    // phrase(RuleSet, List, Remainder) is equivalent to calling RuleSet(List, Remainder)

    // Create the goal: RuleSet(List, Remainder)
    Term goal;
    if (ruleSet is Atom) {
      goal = Compound(ruleSet, [list, remainder]);
    } else if (ruleSet is Compound) {
      // RuleSet might be something like rule(X), convert to rule(X, List, Remainder)
      final args = [...ruleSet.args, list, remainder];
      goal = Compound(ruleSet.functor, args);
    } else {
      return _BuiltinResult.failed;
    }

    // Push the goal for execution
    goals.push(Goal(goal));
    return _BuiltinResult.handled;
  }

  /// Handles catch/3: catch(Goal, Catcher, Recovery).
  ///
  /// Implements ISO Prolog exception handling:
  /// - Executes Goal
  /// - If Goal throws an exception that unifies with Catcher, execute Recovery
  /// - If Goal succeeds or fails normally, catch/3 behaves like call(Goal)
  _BuiltinResult _handleCatch(
    final Term goal,
    final Term catcher,
    final Term recovery,
  ) {
    final marker = trail.mark();
    final saved = goals.copy();
    final count = choicePoints.size;

    // Create a choice point with the catch frame
    // This acts as an exception handler - if throw/1 is called,
    // we search for matching catch frames on the choice point stack
    // NOTE: isControlConstruct must be false so backtracking skips this frame
    choicePoints.push(
      ChoicePoint(
        goal: Goal(Atom('true')), // Placeholder, not used for catch
        alternatives: <Clause>[],
        trailMarker: marker,
        goals: saved,
        goalCount: goals.size,
        isControlConstruct: false, // Don't treat as backtrack alternative
        catchFrame: CatchFrame(catcher: catcher, recovery: recovery),
      ),
    );

    // Push a marker to remove the catch frame when goal succeeds
    // This ensures catch/3 doesn't create spurious choice points
    goals.push(Goal(_CatchCleanup(count)));
    goals.push(Goal(goal));
    return _BuiltinResult.handled;
  }

  /// Handles throw/1: throw(Exception).
  ///
  /// Implements ISO Prolog exception throwing:
  /// - Searches the choice point stack for a matching catch/3
  /// - If found, restores state and executes the recovery goal
  /// - If not found, propagates as an unhandled exception
  _BuiltinResult _handleThrow(final Term exception) {
    // Dereference the exception term
    final exc = substitution.deref(exception);

    // Search for a matching catch frame on the choice point stack
    while (choicePoints.isNotEmpty) {
      final point = choicePoints.pop();
      if (point == null) break;

      if (point.isCatchFrame) {
        final frame = point.catchFrame!;

        // Restore state to the catch point
        trail.undoToMarker(point.trailMarker, substitution);
        goals.clear();
        for (final g in point.goals.goals) {
          goals.push(g);
        }

        // Try to unify exception with catcher pattern
        trail.mark();
        final catcher = substitution.deref(frame.catcher);
        if (Unify.unify(exc, catcher, substitution, trail)) {
          // Match found - execute recovery goal
          goals.push(Goal(frame.recovery));
          return _BuiltinResult.handled;
        }
        // No match - continue searching for another catch frame
      }
      // Non-catch choice points are discarded during exception propagation
    }

    // No matching catch frame found - propagate as unhandled
    throw _UnhandledPrologException(exc);
  }

  /// Renames all variables in a clause to fresh variables.
  Clause _renameClause(final Clause clause) {
    final renaming = <Variable, Variable>{};

    final newHead = _renameTerm(clause.head, renaming);
    final newBody = clause.body.map((g) => _renameTerm(g, renaming)).toList();

    return Clause(newHead, newBody);
  }

  /// Renames variables in a term.
  Term _renameTerm(final Term term, final Map<Variable, Variable> renaming) {
    if (term is Variable) {
      return renaming.putIfAbsent(term, () => Variable('_R${_varCounter++}'));
    } else if (term is Compound) {
      final newArgs = term.args
          .map((arg) => _renameTerm(arg, renaming))
          .toList();
      return Compound(term.functor, newArgs);
    } else {
      return term; // Atoms and numbers don't need renaming
    }
  }

  /// Resets the resolver state for a new query.
  void _reset() {
    substitution.internalBindings.clear();
    trail.reset();
    goals.clear();
    choicePoints.clear();
    _varCounter = 0;
    _traceDepth = 0;
  }

  /// Emits a trace event if tracing is enabled.
  ///
  /// Returns false if execution should be aborted (callback returned false).
  bool _trace(final TracePort port, final Term goal) {
    if (!_tracing) return true;

    if (_traceCallback != null) {
      return _traceCallback!(port, _traceDepth, goal);
    }

    // Default console output
    final indent = '   ' * _traceDepth;
    final portName = switch (port) {
      TracePort.call => 'Call',
      TracePort.exit => 'Exit',
      TracePort.redo => 'Redo',
      TracePort.fail => 'Fail',
    };

    // Dereference variables in the goal for display
    final display = _derefGoal(goal);
    print('$indent($portName) $display');
    return true;
  }

  /// Dereferences a goal for display, substituting bound variables.
  Term _derefGoal(final Term term) {
    final derefed = substitution.deref(term);

    if (derefed is Compound) {
      final args = derefed.args.map(_derefGoal).toList();
      return Compound(derefed.functor, args);
    }

    return derefed;
  }
}

/// Result of built-in predicate execution.
enum _BuiltinResult {
  handled, // Built-in succeeded
  failed, // Built-in failed
  notBuiltin, // Not a built-in predicate
}

/// Internal marker term for if-then-else commit.
///
/// This is not a real Prolog term - it's used internally to implement
/// the cut-like behavior of if-then-else when the condition succeeds.
class _IfThenCommit extends Term {
  final int choicePointCount;

  _IfThenCommit(this.choicePointCount);

  @override
  String toString() => '<if-then-commit>';

  @override
  bool operator ==(final Object other) =>
      other is _IfThenCommit && choicePointCount == other.choicePointCount;

  @override
  int get hashCode => choicePointCount.hashCode;
}

/// Internal marker term for once/1 commit.
///
/// This is not a real Prolog term - it's used internally to implement
/// once/1 by cutting choice points created during goal execution.
class _OnceCommit extends Term {
  final int choicePointCount;

  _OnceCommit(this.choicePointCount);

  @override
  String toString() => '<once-commit>';

  @override
  bool operator ==(final Object other) =>
      other is _OnceCommit && choicePointCount == other.choicePointCount;

  @override
  int get hashCode => choicePointCount.hashCode;
}

/// Internal marker term for ignore/1 commit.
///
/// This is not a real Prolog term - it's used internally to implement
/// ignore/1 by cutting choice points created during goal execution,
/// including the fallback 'true' choice point.
class _IgnoreCommit extends Term {
  final int choicePointCount;

  _IgnoreCommit(this.choicePointCount);

  @override
  String toString() => '<ignore-commit>';

  @override
  bool operator ==(final Object other) =>
      other is _IgnoreCommit && choicePointCount == other.choicePointCount;

  @override
  int get hashCode => choicePointCount.hashCode;
}

/// Exception thrown when a Prolog throw/1 has no matching catch/3.
///
/// This propagates up to _solve() which handles it appropriately.
class _UnhandledPrologException implements Exception {
  final Term exception;

  _UnhandledPrologException(this.exception);

  @override
  String toString() => 'Uncaught Prolog exception: $exception';
}

/// Internal marker for catch/3 cleanup.
///
/// When goal in catch(Goal, Catcher, Recovery) succeeds, this marker
/// removes the catch frame choice point to prevent spurious backtracking.
class _CatchCleanup extends Term {
  final int choicePointCount;

  _CatchCleanup(this.choicePointCount);

  @override
  String toString() => '<catch-cleanup>';

  @override
  bool operator ==(final Object other) =>
      other is _CatchCleanup && choicePointCount == other.choicePointCount;

  @override
  int get hashCode => choicePointCount.hashCode;
}

/// A witness group for bagof/setof.
///
/// Stores the free variables, their bindings for this witness, and
/// the list of solutions that match this witness.
class _WitnessGroup {
  /// The free variables in consistent order.
  final List<Variable> variables;

  /// The binding values for each free variable (same order as [variables]).
  final List<Term> bindings;

  /// The solutions (instantiated templates) for this witness.
  final List<Term> solutions;

  _WitnessGroup(this.variables, this.bindings, this.solutions);

  /// Creates a unification goal that binds all free variables to their witness values.
  ///
  /// Returns a conjunction goal: (Var1 = Val1, Var2 = Val2, ..., ResultVar = SolutionList)
  Term createUnificationGoal(final Term result, final Term list) {
    // Start with the result unification
    Term goal = Compound(Atom('='), [result, list]);

    // Add witness variable unifications (in reverse order for proper conjunction)
    for (var i = variables.length - 1; i >= 0; i--) {
      final unify = Compound(Atom('='), [variables[i], bindings[i]]);
      goal = Compound(Atom(','), [unify, goal]);
    }

    return goal;
  }
}
