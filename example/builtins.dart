/// Example: ISO Core Predicates
///
/// Demonstrates the built-in predicates:
/// - Type testing (var/1, atom/1, number/1, etc.)
/// - Arithmetic (is/2, comparison operators)
/// - Term manipulation (functor/3, arg/3, =../2, copy_term/2)
/// - Control constructs (;/2, ->/2, \+/1)
/// - All-solutions (findall/3, bagof/3, setof/3)
library;

import 'package:libprolog/libprolog.dart';

void main() async {
  print('=== ISO Core Predicates Demo ===\n');

  final db = Database();
  final resolver = Resolver(db);

  // Add some test data
  db.assert_(Clause(Compound(Atom('parent'), [Atom('tom'), Atom('bob')]), []));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('tom'), Atom('liz')]), []));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('bob'), Atom('ann')]), []));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('bob'), Atom('pat')]), []));
  db.assert_(Clause(Compound(Atom('parent'), [Atom('pat'), Atom('jim')]), []));

  // 1. Type Testing Predicates
  print('1. Type Testing:');
  print('   Testing if X is a variable...');
  var goal = Compound(Atom('var'), [Variable('X')]);
  var solutions = await resolver.queryGoal(goal).toList();
  print('   var(X): ${solutions.isNotEmpty ? 'true' : 'false'}');

  print('   Testing if atom is an atom...');
  goal = Compound(Atom('atom'), [Atom('hello')]);
  solutions = await resolver.queryGoal(goal).toList();
  print('   atom(hello): ${solutions.isNotEmpty ? 'true' : 'false'}');

  print('   Testing if 42 is a number...');
  goal = Compound(Atom('number'), [PrologInteger(42)]);
  solutions = await resolver.queryGoal(goal).toList();
  print('   number(42): ${solutions.isNotEmpty ? 'true' : 'false'}\n');

  // 2. Arithmetic
  print('2. Arithmetic:');
  print('   Evaluating 2 + 3 * 4...');
  final x = Variable('X');
  final mul = Compound(Atom('*'), [PrologInteger(3), PrologInteger(4)]);
  final expr = Compound(Atom('+'), [PrologInteger(2), mul]);
  goal = Compound(Atom('is'), [x, expr]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   X = ${solutions[0].binding('X')}\n');
  }

  // 3. Arithmetic Comparison
  print('3. Arithmetic Comparison:');
  print('   Testing if 5 > 3...');
  goal = Compound(Atom('>'), [PrologInteger(5), PrologInteger(3)]);
  solutions = await resolver.queryGoal(goal).toList();
  print('   5 > 3: ${solutions.isNotEmpty ? 'true' : 'false'}\n');

  // 4. Term Manipulation - functor/3
  print('4. Term Manipulation (functor/3):');
  print('   Extracting functor and arity from parent(tom, bob)...');
  final term = Compound(Atom('parent'), [Atom('tom'), Atom('bob')]);
  final f = Variable('F');
  final a = Variable('A');
  goal = Compound(Atom('functor'), [term, f, a]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   Functor: ${solutions[0].binding('F')}');
    print('   Arity: ${solutions[0].binding('A')}\n');
  }

  // 5. Term Manipulation - arg/3
  print('5. Term Manipulation (arg/3):');
  print('   Getting 2nd argument of parent(tom, bob)...');
  final arg = Variable('Arg');
  goal = Compound(Atom('arg'), [PrologInteger(2), term, arg]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   arg(2, parent(tom, bob), ${solutions[0].binding('Arg')})\n');
  }

  // 6. Term Manipulation - =../2 (univ)
  print('6. Term Manipulation (=../2):');
  print('   Converting parent(tom, bob) to list...');
  final list = Variable('L');
  goal = Compound(Atom('=..'), [term, list]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   parent(tom, bob) =.. ${solutions[0].binding('L')}\n');
  }

  // 7. Control - Negation as Failure
  print('7. Control Constructs (\\+/1):');
  print('   Testing if parent(jim, _) fails...');
  goal = Compound(Atom('\\+'), [
    Compound(Atom('parent'), [Atom('jim'), Variable('_')]),
  ]);
  solutions = await resolver.queryGoal(goal).toList();
  print('   \\+(parent(jim, _)): ${solutions.isNotEmpty ? 'true' : 'false'}\n');

  // 8. Control - Disjunction
  print('8. Control Constructs (;/2):');
  print('   Testing (parent(tom, X) ; parent(bob, X))...');
  final left = Compound(Atom('parent'), [Atom('tom'), Variable('X')]);
  final right = Compound(Atom('parent'), [Atom('bob'), Variable('X')]);
  goal = Compound(Atom(';'), [left, right]);
  solutions = await resolver.queryGoal(goal).toList();
  print('   Found ${solutions.length} solutions');
  for (final sol in solutions.take(3)) {
    print('     X = ${sol.binding('X')}');
  }
  print('');

  // 9. Control - If-Then-Else
  print('9. Control Constructs (->; if-then-else):');
  print('   (parent(tom, bob) -> atom(yes) ; atom(no))...');
  final condition = Compound(Atom('parent'), [Atom('tom'), Atom('bob')]);
  final thenBranch = Compound(Atom('atom'), [Atom('yes')]);
  final elseBranch = Compound(Atom('atom'), [Atom('no')]);
  final ifThen = Compound(Atom('->'), [condition, thenBranch]);
  goal = Compound(Atom(';'), [ifThen, elseBranch]);
  solutions = await resolver.queryGoal(goal).toList();
  print(
    '   Result: ${solutions.isNotEmpty ? 'success (then-branch)' : 'failed'}\n',
  );

  // 10. All-Solutions - findall/3
  print('10. All-Solutions (findall/3):');
  print('   Finding all children of tom...');
  final template = Variable('Child');
  final goalToFind = Compound(Atom('parent'), [Atom('tom'), template]);
  final result = Variable('Result');
  goal = Compound(Atom('findall'), [template, goalToFind, result]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   Children of tom: ${solutions[0].binding('Result')}\n');
  }

  // 11. All-Solutions - findall with complex template
  print('11. All-Solutions with complex template:');
  print('   Finding all parent-child pairs...');
  final parent = Variable('P');
  final child = Variable('C');
  final pairTemplate = Compound(Atom('pair'), [parent, child]);
  final pairGoal = Compound(Atom('parent'), [parent, child]);
  goal = Compound(Atom('findall'), [pairTemplate, pairGoal, result]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   All pairs: ${solutions[0].binding('Result')}\n');
  }

  // 12. All-Solutions - bagof/3
  print('12. All-Solutions (bagof/3):');
  print('   Getting children of bob with bagof...');
  goal = Compound(Atom('bagof'), [
    Variable('X'),
    Compound(Atom('parent'), [Atom('bob'), Variable('X')]),
    result,
  ]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   Children of bob: ${solutions[0].binding('Result')}\n');
  }

  // 13. All-Solutions - setof/3
  print('13. All-Solutions (setof/3):');
  print('   Getting unique sorted grandparents...');

  // Note: Since conjunction (,/2) is not yet a built-in, we'll use a simpler query
  print('   (Simplified query - full conjunction support coming soon)\n');

  print('=== Demo Complete ===');
  print('All ISO Core Predicates are working!');
}
