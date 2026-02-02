import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Built-ins - Type Testing', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('var/1 succeeds on variable', () async {
      final x = Variable('X');
      final goal = Compound(Atom('var'), [x]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('var/1 fails on atom', () async {
      final goal = Compound(Atom('var'), [Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('nonvar/1 fails on variable', () async {
      final x = Variable('X');
      final goal = Compound(Atom('nonvar'), [x]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('nonvar/1 succeeds on atom', () async {
      final goal = Compound(Atom('nonvar'), [Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('atom/1 succeeds on atom', () async {
      final goal = Compound(Atom('atom'), [Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('atom/1 fails on number', () async {
      final goal = Compound(Atom('atom'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('number/1 succeeds on integer', () async {
      final goal = Compound(Atom('number'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('number/1 succeeds on float', () async {
      final goal = Compound(Atom('number'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('integer/1 succeeds on integer', () async {
      final goal = Compound(Atom('integer'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('integer/1 fails on float', () async {
      final goal = Compound(Atom('integer'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('float/1 succeeds on float', () async {
      final goal = Compound(Atom('float'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('float/1 fails on integer', () async {
      final goal = Compound(Atom('float'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('atomic/1 succeeds on atom', () async {
      final goal = Compound(Atom('atomic'), [Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('atomic/1 succeeds on number', () async {
      final goal = Compound(Atom('atomic'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('atomic/1 fails on compound', () async {
      final goal = Compound(Atom('atomic'), [
        Compound(Atom('f'), [Atom('x')]),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('compound/1 succeeds on compound', () async {
      final goal = Compound(Atom('compound'), [
        Compound(Atom('f'), [Atom('x')]),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('compound/1 fails on atom', () async {
      final goal = Compound(Atom('compound'), [Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('callable/1 succeeds on atom', () async {
      final goal = Compound(Atom('callable'), [Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('callable/1 succeeds on compound', () async {
      final goal = Compound(Atom('callable'), [
        Compound(Atom('f'), [Atom('x')]),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('callable/1 fails on number', () async {
      final goal = Compound(Atom('callable'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });
  });

  group('Built-ins - Arithmetic', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('is/2 evaluates simple expression', () async {
      final x = Variable('X');
      final goal = Compound(Atom('is'), [x, PrologInteger(42)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(42)));
    });

    test('is/2 evaluates addition', () async {
      final x = Variable('X');
      final expr = Compound(Atom('+'), [PrologInteger(2), PrologInteger(3)]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(5)));
    });

    test('is/2 evaluates subtraction', () async {
      final x = Variable('X');
      final expr = Compound(Atom('-'), [PrologInteger(10), PrologInteger(3)]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(7)));
    });

    test('is/2 evaluates multiplication', () async {
      final x = Variable('X');
      final expr = Compound(Atom('*'), [PrologInteger(6), PrologInteger(7)]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(42)));
    });

    test('is/2 evaluates division', () async {
      final x = Variable('X');
      final expr = Compound(Atom('/'), [PrologFloat(10.0), PrologFloat(4.0)]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect((solutions[0].binding('X') as PrologFloat).value, equals(2.5));
    });

    test('is/2 evaluates integer division', () async {
      final x = Variable('X');
      final expr = Compound(Atom('//'), [PrologInteger(10), PrologInteger(3)]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(3)));
    });

    test('is/2 evaluates modulo', () async {
      final x = Variable('X');
      final expr = Compound(Atom('mod'), [PrologInteger(10), PrologInteger(3)]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('is/2 evaluates nested expression', () async {
      final x = Variable('X');
      // X is 2 + 3 * 4
      final mul = Compound(Atom('*'), [PrologInteger(3), PrologInteger(4)]);
      final expr = Compound(Atom('+'), [PrologInteger(2), mul]);
      final goal = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(14)));
    });

    test('</2 compares numbers', () async {
      final goal = Compound(Atom('<'), [PrologInteger(3), PrologInteger(5)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('</2 fails when not less', () async {
      final goal = Compound(Atom('<'), [PrologInteger(5), PrologInteger(3)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('>/2 compares numbers', () async {
      final goal = Compound(Atom('>'), [PrologInteger(5), PrologInteger(3)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('=</2 succeeds on less or equal', () async {
      final goal1 = Compound(Atom('=<'), [PrologInteger(3), PrologInteger(5)]);
      final solutions1 = await resolver.queryGoal(goal1).toList();
      expect(solutions1.length, equals(1));

      final goal2 = Compound(Atom('=<'), [PrologInteger(5), PrologInteger(5)]);
      final solutions2 = await resolver.queryGoal(goal2).toList();
      expect(solutions2.length, equals(1));
    });

    test('>=/2 succeeds on greater or equal', () async {
      final goal1 = Compound(Atom('>='), [PrologInteger(5), PrologInteger(3)]);
      final solutions1 = await resolver.queryGoal(goal1).toList();
      expect(solutions1.length, equals(1));

      final goal2 = Compound(Atom('>='), [PrologInteger(5), PrologInteger(5)]);
      final solutions2 = await resolver.queryGoal(goal2).toList();
      expect(solutions2.length, equals(1));
    });

    test('=:=/2 succeeds on arithmetic equality', () async {
      final goal = Compound(Atom('=:='), [
        PrologFloat(5.0),
        Compound(Atom('+'), [PrologInteger(2), PrologInteger(3)]),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('=\\=/2 succeeds on arithmetic inequality', () async {
      final goal = Compound(Atom('=\\='), [PrologInteger(5), PrologInteger(3)]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });
  });

  group('Built-ins - Term Manipulation', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('functor/3 extracts functor and arity from compound', () async {
      final f = Variable('F');
      final a = Variable('A');
      final term = Compound(Atom('parent'), [Atom('john'), Atom('mary')]);
      final goal = Compound(Atom('functor'), [term, f, a]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('F'), equals(Atom('parent')));
      expect(solutions[0].binding('A'), equals(PrologInteger(2)));
    });

    test('functor/3 extracts functor from atom', () async {
      final f = Variable('F');
      final a = Variable('A');
      final goal = Compound(Atom('functor'), [Atom('hello'), f, a]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('F'), equals(Atom('hello')));
      expect(solutions[0].binding('A'), equals(PrologInteger(0)));
    });

    test('functor/3 constructs term from functor and arity', () async {
      final t = Variable('T');
      final goal = Compound(Atom('functor'), [
        t,
        Atom('foo'),
        PrologInteger(2),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      final result = solutions[0].binding('T');
      expect(result, isA<Compound>());
      expect((result as Compound).functor, equals(Atom('foo')));
      expect(result.arity, equals(2));
    });

    test('arg/3 accesses compound argument', () async {
      final x = Variable('X');
      final term = Compound(Atom('f'), [Atom('a'), Atom('b'), Atom('c')]);
      final goal = Compound(Atom('arg'), [PrologInteger(2), term, x]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('b')));
    });

    test('arg/3 fails on out of bounds', () async {
      final x = Variable('X');
      final term = Compound(Atom('f'), [Atom('a')]);
      final goal = Compound(Atom('arg'), [PrologInteger(2), term, x]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('=../2 converts compound to list', () async {
      final l = Variable('L');
      final term = Compound(Atom('f'), [Atom('a'), Atom('b')]);
      final goal = Compound(Atom('=..'), [term, l]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      final result = solutions[0].binding('L');
      expect(result, isA<Compound>()); // List representation

      // Should be [f, a, b]
      final list = result as Compound;
      expect(list.functor, equals(Atom.dot));
      expect(list.args[0], equals(Atom('f')));
    });

    test('=../2 converts atom to list', () async {
      final l = Variable('L');
      final goal = Compound(Atom('=..'), [Atom('hello'), l]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      final result = solutions[0].binding('L');

      // Should be [hello]
      final list = result as Compound;
      expect(list.functor, equals(Atom.dot));
      expect(list.args[0], equals(Atom('hello')));
      expect(list.args[1], equals(Atom.nil));
    });

    test('=../2 constructs term from list', () async {
      final t = Variable('T');
      // List: [f, a, b]
      final list = Compound.fromList([Atom('f'), Atom('a'), Atom('b')]);
      final goal = Compound(Atom('=..'), [t, list]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      final result = solutions[0].binding('T');
      expect(result, isA<Compound>());
      expect((result as Compound).functor, equals(Atom('f')));
      expect(result.arity, equals(2));
      expect(result.args[0], equals(Atom('a')));
      expect(result.args[1], equals(Atom('b')));
    });

    test('copy_term/2 creates copy with fresh variables', () async {
      final original = Compound(Atom('f'), [Variable('X'), Variable('Y')]);
      final copy = Variable('Copy');
      final goal = Compound(Atom('copy_term'), [original, copy]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      final result = solutions[0].binding('Copy');
      expect(result, isA<Compound>());

      final resultCompound = result as Compound;
      expect(resultCompound.functor, equals(Atom('f')));
      expect(resultCompound.args[0], isA<Variable>());
      expect(resultCompound.args[1], isA<Variable>());

      // Variables should be fresh (different from original)
      expect((resultCompound.args[0] as Variable).name, isNot(equals('X')));
      expect((resultCompound.args[1] as Variable).name, isNot(equals('Y')));
    });
  });

  group('Built-ins - Control Constructs', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('\\+/1 succeeds on failing goal', () async {
      final goal = Compound(Atom('\\+'), [Atom('fail')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('\\+/1 fails on succeeding goal', () async {
      final goal = Compound(Atom('\\+'), [Atom('true')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('\\+/1 fails when goal can be proven', () async {
      // Add a fact: likes(mary, wine)
      db.assert_(
        Clause(Compound(Atom('likes'), [Atom('mary'), Atom('wine')]), []),
      );

      final goal = Compound(Atom('\\+'), [
        Compound(Atom('likes'), [Atom('mary'), Atom('wine')]),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('\\+/1 succeeds when goal cannot be proven', () async {
      final goal = Compound(Atom('\\+'), [
        Compound(Atom('likes'), [Atom('john'), Atom('beer')]),
      ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test(';/2 succeeds on either branch (simple disjunction)', () async {
      // true ; fail should succeed
      final goal1 = Compound(Atom(';'), [Atom('true'), Atom('fail')]);
      final solutions1 = await resolver.queryGoal(goal1).toList();
      expect(solutions1.length, greaterThanOrEqualTo(1));

      // fail ; true should succeed
      final goal2 = Compound(Atom(';'), [Atom('fail'), Atom('true')]);
      final solutions2 = await resolver.queryGoal(goal2).toList();
      expect(solutions2.length, equals(1));
    });

    test(';/2 fails when both branches fail', () async {
      final goal = Compound(Atom(';'), [Atom('fail'), Atom('fail')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('->/2 succeeds when condition succeeds', () async {
      // true -> true should succeed
      final goal = Compound(Atom('->'), [Atom('true'), Atom('true')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('->/2 fails when condition succeeds but then-branch fails', () async {
      // true -> fail should fail
      final goal = Compound(Atom('->'), [Atom('true'), Atom('fail')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('if-then-else (Cond -> Then ; Else) with true condition', () async {
      // (true -> atom(a) ; atom(1)) should succeed via then-branch
      final condition = Atom('true');
      final thenBranch = Compound(Atom('atom'), [Atom('a')]);
      final elseBranch = Compound(Atom('atom'), [PrologInteger(1)]);
      final ifThen = Compound(Atom('->'), [condition, thenBranch]);
      final goal = Compound(Atom(';'), [ifThen, elseBranch]);

      final solutions = await resolver.queryGoal(goal).toList();
      expect(solutions.length, greaterThanOrEqualTo(1));
    });

    test('if-then-else (Cond -> Then ; Else) with false condition', () async {
      // (fail -> atom(a) ; atom(b)) should succeed via else-branch
      final condition = Atom('fail');
      final thenBranch = Compound(Atom('atom'), [Atom('a')]);
      final elseBranch = Compound(Atom('atom'), [Atom('b')]);
      final ifThen = Compound(Atom('->'), [condition, thenBranch]);
      final goal = Compound(Atom(';'), [ifThen, elseBranch]);

      final solutions = await resolver.queryGoal(goal).toList();
      expect(solutions.length, equals(1));
    });
  });

  group('Built-ins - All-Solutions', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);

      // Add test data: likes(mary, wine), likes(john, wine), likes(john, mary)
      db.assert_(
        Clause(Compound(Atom('likes'), [Atom('mary'), Atom('wine')]), []),
      );
      db.assert_(
        Clause(Compound(Atom('likes'), [Atom('john'), Atom('wine')]), []),
      );
      db.assert_(
        Clause(Compound(Atom('likes'), [Atom('john'), Atom('mary')]), []),
      );
    });

    test('findall/3 collects all solutions', () async {
      final x = Variable('X');
      final template = x;
      final goal = Compound(Atom('likes'), [Atom('john'), x]);
      final result = Variable('Result');
      final findallGoal = Compound(Atom('findall'), [template, goal, result]);

      final solutions = await resolver.queryGoal(findallGoal).toList();

      expect(solutions.length, equals(1));
      final list = solutions[0].binding('Result');
      expect(list, isA<Compound>());

      // Should be [wine, mary]
      final listCompound = list as Compound;
      expect(listCompound.functor, equals(Atom.dot));
    });

    test('findall/3 returns empty list when no solutions', () async {
      final x = Variable('X');
      final template = x;
      final goal = Compound(Atom('likes'), [Atom('bob'), x]);
      final result = Variable('Result');
      final findallGoal = Compound(Atom('findall'), [template, goal, result]);

      final solutions = await resolver.queryGoal(findallGoal).toList();

      expect(solutions.length, equals(1));
      final list = solutions[0].binding('Result');
      expect(list, equals(Atom.nil)); // Empty list
    });

    test('findall/3 collects complex templates', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final template = Compound(Atom('pair'), [x, y]);
      final goal = Compound(Atom('likes'), [x, y]);
      final result = Variable('Result');
      final findallGoal = Compound(Atom('findall'), [template, goal, result]);

      final solutions = await resolver.queryGoal(findallGoal).toList();

      expect(solutions.length, equals(1));
      final list = solutions[0].binding('Result');
      expect(list, isA<Compound>());
    });

    test('bagof/3 collects solutions', () async {
      final x = Variable('X');
      final template = x;
      final goal = Compound(Atom('likes'), [Atom('john'), x]);
      final result = Variable('Result');
      final bagofGoal = Compound(Atom('bagof'), [template, goal, result]);

      final solutions = await resolver.queryGoal(bagofGoal).toList();

      expect(solutions.length, equals(1));
      final list = solutions[0].binding('Result');
      expect(list, isA<Compound>());
    });

    test('bagof/3 fails when no solutions', () async {
      final x = Variable('X');
      final template = x;
      final goal = Compound(Atom('likes'), [Atom('bob'), x]);
      final result = Variable('Result');
      final bagofGoal = Compound(Atom('bagof'), [template, goal, result]);

      final solutions = await resolver.queryGoal(bagofGoal).toList();

      expect(solutions, isEmpty); // bagof fails when no solutions
    });

    test('setof/3 collects sorted unique solutions', () async {
      final x = Variable('X');
      final template = x;
      final goal = Compound(Atom('likes'), [x, Atom('wine')]);
      final result = Variable('Result');
      final setofGoal = Compound(Atom('setof'), [template, goal, result]);

      final solutions = await resolver.queryGoal(setofGoal).toList();

      expect(solutions.length, equals(1));
      final list = solutions[0].binding('Result');
      expect(list, isA<Compound>());
    });

    test('setof/3 fails when no solutions', () async {
      final x = Variable('X');
      final template = x;
      final goal = Compound(Atom('likes'), [Atom('bob'), x]);
      final result = Variable('Result');
      final setofGoal = Compound(Atom('setof'), [template, goal, result]);

      final solutions = await resolver.queryGoal(setofGoal).toList();

      expect(solutions, isEmpty); // setof fails when no solutions
    });
  });
}
