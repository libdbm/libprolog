import '../terms/term.dart';

/// A goal to be proven during execution.
///
/// Goals are terms that need to be satisfied. They can be:
/// - Simple goals: atoms or compounds (e.g., `parent(john, mary)`)
/// - Conjunctions: multiple goals (handled as list)
/// - Built-in predicates: special handling
///
/// In the execution engine, goals are processed left-to-right.
class Goal {
  /// The term representing this goal.
  final Term term;

  /// Creates a goal from a term.
  const Goal(this.term);

  @override
  String toString() => term.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Goal && other.term == term);

  @override
  int get hashCode => term.hashCode;
}

/// A goal stack representing the current execution state.
///
/// Goals are processed in LIFO order (last-in, first-out).
/// This represents the current proof state.
class GoalStack {
  final List<Goal> _goals;

  /// Creates an empty goal stack.
  GoalStack() : _goals = [];

  /// Creates a goal stack with initial goals.
  GoalStack.from(final List<Goal> goals) : _goals = List.from(goals);

  /// Pushes a goal onto the stack.
  void push(final Goal goal) {
    _goals.add(goal);
  }

  /// Pushes multiple goals onto the stack (in order).
  void pushAll(final List<Goal> goals) {
    _goals.addAll(goals);
  }

  /// Pops a goal from the stack.
  ///
  /// Returns null if the stack is empty.
  Goal? pop() {
    if (_goals.isEmpty) return null;
    return _goals.removeLast();
  }

  /// Returns the top goal without removing it.
  ///
  /// Returns null if the stack is empty.
  Goal? peek() {
    if (_goals.isEmpty) return null;
    return _goals.last;
  }

  /// Returns true if the stack is empty.
  bool get isEmpty => _goals.isEmpty;

  /// Returns true if the stack is not empty.
  bool get isNotEmpty => _goals.isNotEmpty;

  /// Returns the number of goals on the stack.
  int get size => _goals.length;

  /// Clears all goals from the stack.
  void clear() {
    _goals.clear();
  }

  /// Creates a copy of this goal stack.
  GoalStack copy() => GoalStack.from(_goals);

  /// Returns all goals as a list (for inspection/copying).
  List<Goal> get goals => List.unmodifiable(_goals);

  @override
  String toString() {
    if (_goals.isEmpty) return '[]';
    return '[${_goals.map((g) => g.toString()).join(', ')}]';
  }
}
