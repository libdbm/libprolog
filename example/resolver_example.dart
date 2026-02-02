import 'package:libprolog/libprolog.dart';

/// Example: SLD Resolution Engine
///
/// Demonstrates the core Prolog execution engine including:
/// - Facts and rules in the database
/// - Queries with variables
/// - Backtracking for multiple solutions
/// - Built-in predicates (true, fail, =, cut)
/// - Rule chaining
void main() async {
  print('=== SLD Resolution Engine ===\n');

  // Example 1: Simple Facts
  print('--- Example 1: Simple Facts ---');
  await simpleFactsExample();

  // Example 2: Unification and Variables
  print('\n--- Example 2: Unification and Variables ---');
  await unificationExample();

  // Example 3: Multiple Solutions
  print('\n--- Example 3: Multiple Solutions (Backtracking) ---');
  await multipleSolutionsExample();

  // Example 4: Rules and Chaining
  print('\n--- Example 4: Rules and Chaining ---');
  await rulesExample();

  // Example 5: Built-in Predicates
  print('\n--- Example 5: Built-in Predicates ---');
  await builtinsExample();

  // Example 6: Cut Operator
  print('\n--- Example 6: Cut Operator ---');
  await cutExample();

  // Example 7: Family Tree
  print('\n--- Example 7: Family Tree (Complex Example) ---');
  await familyTreeExample();
}

/// Demonstrates querying simple facts.
Future<void> simpleFactsExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // Add facts: cat(tom), cat(felix), dog(rex)
  db.assert_(Clause(Compound(Atom('cat'), [Atom('tom')])));
  db.assert_(Clause(Compound(Atom('cat'), [Atom('felix')])));
  db.assert_(Clause(Compound(Atom('dog'), [Atom('rex')])));

  print('Facts: cat(tom). cat(felix). dog(rex).');

  // Query: cat(tom)
  print('\nQuery: cat(tom).');
  final solutions1 = await resolver
      .queryGoal(Compound(Atom('cat'), [Atom('tom')]))
      .toList();
  print('Result: ${solutions1.length == 1 ? "yes" : "no"}');

  // Query: dog(tom)
  print('\nQuery: dog(tom).');
  final solutions2 = await resolver
      .queryGoal(Compound(Atom('dog'), [Atom('tom')]))
      .toList();
  print('Result: ${solutions2.length == 1 ? "yes" : "no"}');
}

/// Demonstrates unification with variables.
Future<void> unificationExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // Add facts: likes(mary, food), likes(john, wine)
  db.assert_(Clause(Compound(Atom('likes'), [Atom('mary'), Atom('food')])));
  db.assert_(Clause(Compound(Atom('likes'), [Atom('john'), Atom('wine')])));

  print('Facts: likes(mary, food). likes(john, wine).');

  // Query: likes(mary, X)
  print('\nQuery: likes(mary, X).');
  final x = Variable('X');
  final solutions = await resolver
      .queryGoal(Compound(Atom('likes'), [Atom('mary'), x]))
      .toList();

  if (solutions.isNotEmpty) {
    final binding = solutions[0].binding('X');
    print('X = $binding');
  }
}

/// Demonstrates backtracking through multiple solutions.
Future<void> multipleSolutionsExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // Add facts: color(red), color(green), color(blue)
  db.assert_(Clause(Compound(Atom('color'), [Atom('red')])));
  db.assert_(Clause(Compound(Atom('color'), [Atom('green')])));
  db.assert_(Clause(Compound(Atom('color'), [Atom('blue')])));

  print('Facts: color(red). color(green). color(blue).');

  // Query: color(X)
  print('\nQuery: color(X).');
  final x = Variable('X');
  final solutions = await resolver
      .queryGoal(Compound(Atom('color'), [x]))
      .toList();

  print('Found ${solutions.length} solutions:');
  for (var i = 0; i < solutions.length; i++) {
    final binding = solutions[i].binding('X');
    print('  Solution ${i + 1}: X = $binding');
  }
}

/// Demonstrates rules and chaining.
Future<void> rulesExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // Add rule: mortal(X) :- human(X)
  final x1 = Variable('X');
  db.assert_(
    Clause(Compound(Atom('mortal'), [x1]), [
      Compound(Atom('human'), [x1]),
    ]),
  );

  // Add fact: human(socrates)
  db.assert_(Clause(Compound(Atom('human'), [Atom('socrates')])));

  print('Rule: mortal(X) :- human(X).');
  print('Fact: human(socrates).');

  // Query: mortal(socrates)
  print('\nQuery: mortal(socrates).');
  final solutions = await resolver
      .queryGoal(Compound(Atom('mortal'), [Atom('socrates')]))
      .toList();
  print('Result: ${solutions.length == 1 ? "yes" : "no"}');

  // Query: mortal(X)
  print('\nQuery: mortal(X).');
  final x2 = Variable('X');
  final solutions2 = await resolver
      .queryGoal(Compound(Atom('mortal'), [x2]))
      .toList();

  if (solutions2.isNotEmpty) {
    final binding = solutions2[0].binding('X');
    print('X = $binding');
  }
}

/// Demonstrates built-in predicates.
Future<void> builtinsExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // true/0 - always succeeds
  print('Query: true.');
  final solutions1 = await resolver.queryGoal(Atom('true')).toList();
  print('Result: ${solutions1.length == 1 ? "yes" : "no"}');

  // fail/0 - always fails
  print('\nQuery: fail.');
  final solutions2 = await resolver.queryGoal(Atom('fail')).toList();
  print('Result: ${solutions2.length == 1 ? "yes" : "no"}');

  // =/2 - unification
  print('\nQuery: X = hello.');
  final x = Variable('X');
  final solutions3 = await resolver
      .queryGoal(Compound(Atom('='), [x, Atom('hello')]))
      .toList();

  if (solutions3.isNotEmpty) {
    final binding = solutions3[0].binding('X');
    print('X = $binding');
  }

  // Unification failure
  print('\nQuery: a = b.');
  final solutions4 = await resolver
      .queryGoal(Compound(Atom('='), [Atom('a'), Atom('b')]))
      .toList();
  print('Result: ${solutions4.length == 1 ? "yes" : "no"}');
}

/// Demonstrates the cut operator.
Future<void> cutExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // Add facts: option(a), option(b), option(c)
  db.assert_(Clause(Compound(Atom('option'), [Atom('a')])));
  db.assert_(Clause(Compound(Atom('option'), [Atom('b')])));
  db.assert_(Clause(Compound(Atom('option'), [Atom('c')])));

  // Add rule with cut: first(X) :- option(X), !
  final x1 = Variable('X');
  db.assert_(
    Clause(Compound(Atom('first'), [x1]), [
      Compound(Atom('option'), [x1]),
      Atom.cut,
    ]),
  );

  print('Facts: option(a). option(b). option(c).');
  print('Rule: first(X) :- option(X), !.');

  // Query without cut: option(X)
  print('\nQuery: option(X). (no cut)');
  final x2 = Variable('X');
  final solutions1 = await resolver
      .queryGoal(Compound(Atom('option'), [x2]))
      .toList();
  print('Found ${solutions1.length} solutions');

  // Query with cut: first(X)
  print('\nQuery: first(X). (with cut)');
  final x3 = Variable('X');
  final solutions2 = await resolver
      .queryGoal(Compound(Atom('first'), [x3]))
      .toList();
  print('Found ${solutions2.length} solution (cut removed other choices)');
  if (solutions2.isNotEmpty) {
    final binding = solutions2[0].binding('X');
    print('X = $binding');
  }
}

/// Demonstrates a more complex family tree example.
Future<void> familyTreeExample() async {
  final db = Database();
  final resolver = Resolver(db);

  // Facts: parent relationships
  db.assert_(Clause(Compound(Atom('parent'), [Atom('john'), Atom('mary')])));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('john'), Atom('tom')])));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('mary'), Atom('alice')])));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('mary'), Atom('bob')])));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('tom'), Atom('charlie')])));

  // Rule: grandparent(X, Z) :- parent(X, Y), parent(Y, Z)
  final x1 = Variable('X');
  final y1 = Variable('Y');
  final z1 = Variable('Z');
  db.assert_(
    Clause(Compound(Atom('grandparent'), [x1, z1]), [
      Compound(Atom('parent'), [x1, y1]),
      Compound(Atom('parent'), [y1, z1]),
    ]),
  );

  // Rule: sibling(X, Y) :- parent(P, X), parent(P, Y), X \= Y
  // (simplified version without \= check for now)
  final x2 = Variable('X');
  final y2 = Variable('Y');
  final p = Variable('P');
  db.assert_(
    Clause(Compound(Atom('sibling'), [x2, y2]), [
      Compound(Atom('parent'), [p, x2]),
      Compound(Atom('parent'), [p, y2]),
    ]),
  );

  print('Family tree:');
  print('  parent(john, mary).');
  print('  parent(john, tom).');
  print('  parent(mary, alice).');
  print('  parent(mary, bob).');
  print('  parent(tom, charlie).');
  print('\nRules:');
  print('  grandparent(X, Z) :- parent(X, Y), parent(Y, Z).');
  print('  sibling(X, Y) :- parent(P, X), parent(P, Y).');

  // Query: grandparent(john, Who)
  print('\nQuery: grandparent(john, Who).');
  final who = Variable('Who');
  final solutions1 = await resolver
      .queryGoal(Compound(Atom('grandparent'), [Atom('john'), who]))
      .toList();

  print('Found ${solutions1.length} grandchildren:');
  for (var i = 0; i < solutions1.length; i++) {
    final binding = solutions1[i].binding('Who');
    print('  Who = $binding');
  }

  // Query: grandparent(Who, alice)
  print('\nQuery: grandparent(Who, alice).');
  final who2 = Variable('Who');
  final solutions2 = await resolver
      .queryGoal(Compound(Atom('grandparent'), [who2, Atom('alice')]))
      .toList();

  if (solutions2.isNotEmpty) {
    final binding = solutions2[0].binding('Who');
    print('Who = $binding');
  }
}
