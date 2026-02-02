import 'package:libprolog/libprolog.dart';

void main() {
  print('=== libprolog Unification Examples ===\n');

  // Example 1: Basic terms
  basicTerms();

  // Example 2: Simple unification
  simpleUnification();

  // Example 3: Compound terms
  compoundTerms();

  // Example 4: Lists
  lists();

  // Example 5: Complex unification
  complexUnification();

  // Example 6: Occur check
  occurCheck();

  // Example 7: Backtracking with trail
  backtracking();
}

void basicTerms() {
  print('--- Example 1: Basic Terms ---');

  final atom = Atom('hello');
  final integer = PrologInteger(42);
  final float = PrologFloat(3.14);
  final variable = Variable('X');

  print('Atom: $atom');
  print('Integer: $integer');
  print('Float: $float');
  print('Variable: $variable');
  print('');
}

void simpleUnification() {
  print('--- Example 2: Simple Unification ---');

  final x = Variable('X');
  final atom = Atom('hello');

  final subst = Substitution();
  final trail = Trail();

  print('Before: X = $x');
  print('Unifying X with hello...');

  if (Unify.unify(x, atom, subst, trail)) {
    print('Success! X = ${subst.deref(x)}');
    print('Substitution: $subst');
  } else {
    print('Unification failed');
  }

  print('');
}

void compoundTerms() {
  print('--- Example 3: Compound Terms ---');

  // Create: person(john, 25)
  final person = Compound(Atom('person'), [Atom('john'), PrologInteger(25)]);

  print('Compound term: $person');
  print('Functor: ${person.functor.value}');
  print('Arity: ${person.arity}');
  print('Indicator: ${person.indicator}');
  print('');
}

void lists() {
  print('--- Example 4: Lists ---');

  // Create [1, 2, 3]
  final list = Compound.fromList([
    PrologInteger(1),
    PrologInteger(2),
    PrologInteger(3),
  ]);

  print('List: $list');
  print('Is list? ${list.isList}');

  // Convert back to Dart list
  final elements = Compound.toList(list);
  if (elements != null) {
    print('Elements: ${elements.map((e) => e.toString()).join(', ')}');
  }

  // List with variable tail: [1, 2 | X]
  final x = Variable('X');
  final openList = Compound.fromList([PrologInteger(1), PrologInteger(2)], x);
  print('Open list: $openList');

  print('');
}

void complexUnification() {
  print('--- Example 5: Complex Unification ---');

  final x = Variable('X');
  final y = Variable('Y');

  // Create: foo(X, b)
  final term1 = Compound(Atom('foo'), [x, Atom('b')]);

  // Create: foo(a, Y)
  final term2 = Compound(Atom('foo'), [Atom('a'), y]);

  final subst = Substitution();
  final trail = Trail();

  print('Term 1: $term1');
  print('Term 2: $term2');
  print('Unifying...');

  if (Unify.unify(term1, term2, subst, trail)) {
    print('Success!');
    print('X = ${subst.deref(x)}');
    print('Y = ${subst.deref(y)}');
    print('Substitution: $subst');
  } else {
    print('Unification failed');
  }

  print('');
}

void occurCheck() {
  print('--- Example 6: Occur Check ---');

  final x = Variable('X');

  // Create: f(X)
  final compound = Compound(Atom('f'), [x]);

  final subst = Substitution();
  final trail = Trail();

  print('Trying to unify X = f(X)...');

  if (Unify.unify(x, compound, subst, trail)) {
    print('Success (would create infinite structure)');
  } else {
    print('Failed (occur check prevented infinite structure) ✓');
  }

  print('');
}

void backtracking() {
  print('--- Example 7: Backtracking with Trail ---');

  final x = Variable('X');
  final y = Variable('Y');
  final z = Variable('Z');

  final subst = Substitution();
  final trail = Trail();

  print('Initial state: $subst');

  // First choice point
  trail.mark();
  Unify.unify(x, Atom('a'), subst, trail);
  Unify.unify(y, Atom('b'), subst, trail);
  print('After first choice: $subst');

  // Second choice point
  trail.mark();
  Unify.unify(z, Atom('c'), subst, trail);
  print('After second choice: $subst');

  // Backtrack second choice
  print('Backtracking...');
  trail.undo(subst);
  print('After undo: $subst');

  // Backtrack first choice
  print('Backtracking again...');
  trail.undo(subst);
  print('After second undo: $subst');

  print('');
}
