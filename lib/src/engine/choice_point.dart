import '../terms/term.dart';
import 'goal.dart';
import 'clause.dart';

/// Catch frame for ISO exception handling.
///
/// Stores the catcher pattern, recovery goal, and state needed
/// to restore execution when an exception is caught.
class CatchFrame {
  /// The pattern to match against thrown exceptions.
  final Term catcher;

  /// The recovery goal to execute when exception is caught.
  final Term recovery;

  const CatchFrame({required this.catcher, required this.recovery});
}

/// A choice point for backtracking.
///
/// Choice points represent decision points in the search where multiple
/// alternatives exist. They store the state needed to backtrack and try
/// the next alternative.
///
/// Each choice point records:
/// - The goal being proven
/// - Remaining alternative clauses to try
/// - The trail marker for undoing bindings
/// - The goal stack state
class ChoicePoint {
  /// The goal this choice point is trying to prove.
  final Goal goal;

  /// Remaining clauses to try (mutable).
  final List<Clause> alternatives;

  /// Trail marker for backtracking.
  final int trailMarker;

  /// Copy of the goal stack at this choice point.
  final GoalStack goals;

  /// Number of goals on stack when this choice point was created.
  final int goalCount;

  /// Flag indicating if this is a control construct (empty alternatives list means goal is alternative).
  final bool isControlConstruct;

  /// Flag indicating if this choice point has been cut.
  /// When true, backtracking will not consider this choice point.
  bool isCut = false;

  /// Flag indicating this choice point should be removed by any cut within its scope.
  /// Used for disjunction: cut in left branch should prevent trying right branch.
  final bool removableByCut;

  /// Optional catch frame for ISO exception handling.
  /// Non-null if this choice point is a catch/3 frame.
  final CatchFrame? catchFrame;

  /// Creates a choice point.
  ChoicePoint({
    required this.goal,
    required this.alternatives,
    required this.trailMarker,
    required this.goals,
    required this.goalCount,
    bool? isControlConstruct,
    this.removableByCut = false,
    this.catchFrame,
  }) : isControlConstruct = isControlConstruct ?? alternatives.isEmpty;

  /// Returns true if this is a catch/3 exception handler frame.
  bool get isCatchFrame => catchFrame != null;

  /// Returns true if there are more alternatives to try.
  bool get hasAlternatives => alternatives.isNotEmpty;

  /// Removes and returns the next alternative.
  Clause? popAlternative() {
    if (alternatives.isEmpty) return null;
    return alternatives.removeAt(0);
  }

  @override
  String toString() =>
      'ChoicePoint(goal: $goal, trail: $trailMarker, '
      'goals: $goalCount, cut: $isCut, alts: ${alternatives.length}, control: $isControlConstruct)';
}

/// Stack of choice points for backtracking.
class ChoicePointStack {
  final List<ChoicePoint> _stack = [];

  /// Pushes a choice point onto the stack.
  void push(final ChoicePoint point) {
    _stack.add(point);
  }

  /// Pops a choice point from the stack.
  ///
  /// Returns null if the stack is empty.
  ChoicePoint? pop() {
    if (_stack.isEmpty) return null;
    return _stack.removeLast();
  }

  /// Returns the top choice point without removing it.
  ///
  /// Returns null if the stack is empty.
  ChoicePoint? peek() {
    if (_stack.isEmpty) return null;
    return _stack.last;
  }

  /// Returns true if the stack is empty.
  bool get isEmpty => _stack.isEmpty;

  /// Returns true if the stack is not empty.
  bool get isNotEmpty => _stack.isNotEmpty;

  /// Returns the number of choice points on the stack.
  int get size => _stack.length;

  /// Clears all choice points from the stack.
  void clear() {
    _stack.clear();
  }

  /// Removes all choice points up to and including the one with the given
  /// goal count (used for cut).
  ///
  /// Also removes all choice points marked as removableByCut, regardless of depth.
  /// This implements ISO Prolog cut semantics in disjunction.
  void cutTo(final int goalCount) {
    while (_stack.isNotEmpty &&
        (_stack.last.goalCount >= goalCount || _stack.last.removableByCut)) {
      _stack.removeLast();
    }
  }

  @override
  String toString() {
    if (_stack.isEmpty) return 'ChoicePointStack([])';
    return 'ChoicePointStack(${_stack.length} points)';
  }
}
