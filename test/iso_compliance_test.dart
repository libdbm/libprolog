import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

/// ISO/IEC 13211-1:1995 Prolog Core Standard Compliance Tests
///
/// These tests verify compliance with the ISO Prolog standard.
void main() {
  group('ISO - Unification (8.2)', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('(=)/2 - unify identical integers', () async {
      final query = Compound(Atom('='), [PrologInteger(1), PrologInteger(1)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(=)/2 - unify variable with integer', () async {
      final x = Variable('X');
      final query = Compound(Atom('='), [x, PrologInteger(1)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('(=)/2 - unify two variables', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final query = Compound(Atom('='), [x, y]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(=)/2 - chained unification', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final eq1 = Compound(Atom('='), [x, y]);
      final eq2 = Compound(Atom('='), [x, Atom('abc')]);
      final query = Compound(Atom(','), [eq1, eq2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('abc')));
      expect(solutions[0].binding('Y'), equals(Atom('abc')));
    });

    test('(=)/2 - unify compound terms', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final left = Compound(Atom('f'), [x, Atom('def')]);
      final right = Compound(Atom('f'), [Atom('def'), y]);
      final query = Compound(Atom('='), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('def')));
      expect(solutions[0].binding('Y'), equals(Atom('def')));
    });

    test('(=)/2 - fail on different integers', () async {
      final query = Compound(Atom('='), [PrologInteger(1), PrologInteger(2)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(=)/2 - fail on integer vs float', () async {
      final query = Compound(Atom('='), [PrologInteger(1), PrologFloat(1.0)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(=)/2 - fail on different functors', () async {
      final x = Variable('X');
      final left = Compound(Atom('g'), [x]);
      final right = Compound(Atom('f'), [
        Compound(Atom('f'), [x]),
      ]);
      final query = Compound(Atom('='), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(=)/2 - fail on arity mismatch', () async {
      final x = Variable('X');
      final left = Compound(Atom('f'), [x, PrologInteger(1)]);
      final right = Compound(Atom('f'), [
        Compound(Atom('a'), [x]),
      ]);
      final query = Compound(Atom('='), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(=)/2 - unify lists with tail', () async {
      final x = Variable('X');
      final left = Compound.fromList([Atom('a'), Atom('b'), Atom('c')], x);
      final right = Compound.fromList([
        Atom('a'),
        Atom('b'),
        Atom('c'),
        Atom('d'),
      ]);
      final query = Compound(Atom('='), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final result = solutions[0].binding('X');
      expect(result, isA<Compound>());
      expect((result as Compound).args[0], equals(Atom('d')));
    });

    test('(=)/2 - unify list element', () async {
      final x = Variable('X');
      final left = Compound.fromList([Atom('a'), Atom('b'), Atom('c'), x]);
      final right = Compound.fromList([
        Atom('a'),
        Atom('b'),
        Atom('c'),
        Atom('d'),
      ]);
      final query = Compound(Atom('='), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('d')));
    });

    test('8.2.1 (=)/2 - unify identical atoms', () async {
      final query = Compound(Atom('='), [Atom('a'), Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('8.2.1 (=)/2 - fail on different atoms', () async {
      final query = Compound(Atom('='), [Atom('a'), Atom('b')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('8.2.1 (=)/2 - unify variable with atom', () async {
      final x = Variable('X');
      final query = Compound(Atom('='), [x, Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('a')));
    });

    test('8.2.1 (=)/2 - unify two variables', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final query = Compound(Atom('='), [x, y]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('8.2.2 (\\=)/2 - succeed on different atoms', () async {
      final query = Compound(Atom('\\='), [Atom('a'), Atom('b')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('8.2.2 (\\=)/2 - fail on identical atoms', () async {
      final query = Compound(Atom('\\='), [Atom('a'), Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });
  });

  group('ISO - Type Testing (8.3)', () {
    late Resolver resolver;

    setUp(() {
      resolver = Resolver(Database());
    });

    // atom/1 tests (from INRIA suite)
    test('atom/1 - succeeds on atom', () async {
      final query = Compound(Atom('atom'), [Atom('atom')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('atom/1 - succeeds on quoted string', () async {
      final query = Compound(Atom('atom'), [Atom('string')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('atom/1 - fails on compound', () async {
      final query = Compound(Atom('atom'), [
        Compound(Atom('a'), [Atom('b')]),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('atom/1 - fails on variable', () async {
      final query = Compound(Atom('atom'), [Variable('Var')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('atom/1 - succeeds on empty list', () async {
      final query = Compound(Atom('atom'), [Atom.nil]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('atom/1 - fails on integer', () async {
      final query = Compound(Atom('atom'), [PrologInteger(6)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('atom/1 - fails on float', () async {
      final query = Compound(Atom('atom'), [PrologFloat(3.3)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // integer/1 tests
    test('integer/1 - succeeds on integer', () async {
      final query = Compound(Atom('integer'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('integer/1 - fails on float', () async {
      final query = Compound(Atom('integer'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('integer/1 - fails on atom', () async {
      final query = Compound(Atom('integer'), [Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // float/1 tests
    test('float/1 - succeeds on float', () async {
      final query = Compound(Atom('float'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('float/1 - fails on integer', () async {
      final query = Compound(Atom('float'), [PrologInteger(3)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // number/1 tests
    test('number/1 - succeeds on integer', () async {
      final query = Compound(Atom('number'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('number/1 - succeeds on float', () async {
      final query = Compound(Atom('number'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('number/1 - fails on atom', () async {
      final query = Compound(Atom('number'), [Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // atomic/1 tests
    test('atomic/1 - succeeds on atom', () async {
      final query = Compound(Atom('atomic'), [Atom('atom')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('atomic/1 - succeeds on integer', () async {
      final query = Compound(Atom('atomic'), [PrologInteger(42)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('atomic/1 - succeeds on float', () async {
      final query = Compound(Atom('atomic'), [PrologFloat(3.14)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('atomic/1 - fails on compound', () async {
      final query = Compound(Atom('atomic'), [
        Compound(Atom('f'), [Atom('a')]),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // compound/1 tests
    test('compound/1 - succeeds on compound', () async {
      final query = Compound(Atom('compound'), [
        Compound(Atom('f'), [Atom('a')]),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('compound/1 - fails on atom', () async {
      final query = Compound(Atom('compound'), [Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('compound/1 - fails on integer', () async {
      final query = Compound(Atom('compound'), [PrologInteger(33)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // var/1 tests
    test('var/1 - succeeds on variable', () async {
      final x = Variable('X');
      final query = Compound(Atom('var'), [x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('var/1 - fails on atom', () async {
      final query = Compound(Atom('var'), [Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('var/1 - fails on integer', () async {
      final query = Compound(Atom('var'), [PrologInteger(3)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // nonvar/1 tests
    test('nonvar/1 - succeeds on atom', () async {
      final query = Compound(Atom('nonvar'), [Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('nonvar/1 - succeeds on integer', () async {
      final query = Compound(Atom('nonvar'), [PrologInteger(33)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('nonvar/1 - fails on variable', () async {
      final x = Variable('X');
      final query = Compound(Atom('nonvar'), [x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });
  });

  group('ISO - Term Comparison (8.4)', () {
    late Resolver resolver;

    setUp(() {
      resolver = Resolver(Database());
    });

    // Standard term ordering tests (from vanilla suite)
    test('(@=<)/2 - float @=< integer', () async {
      final query = Compound(Atom('@=<'), [PrologFloat(1.0), PrologInteger(1)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(@<)/2 - float @< integer', () async {
      final query = Compound(Atom('@<'), [PrologFloat(1.0), PrologInteger(1)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(\\==)/2 - integer not identical to itself fails', () async {
      final query = Compound(Atom('\\=='), [
        PrologInteger(1),
        PrologInteger(1),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(@=<)/2 - atom ordering', () async {
      final query = Compound(Atom('@=<'), [Atom('aardvark'), Atom('zebra')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(@=<)/2 - same atom', () async {
      final query = Compound(Atom('@=<'), [Atom('short'), Atom('short')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(@=<)/2 - atom prefix ordering', () async {
      final query = Compound(Atom('@=<'), [Atom('short'), Atom('shorter')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(@>=)/2 - shorter atom not >= longer', () async {
      final query = Compound(Atom('@>='), [Atom('short'), Atom('shorter')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(@<)/2 - compound comparison by arity first', () async {
      final left = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final right = Compound(Atom('north'), [Atom('a')]);
      final query = Compound(Atom('@<'), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(@>)/2 - compound comparison by arguments', () async {
      final left = Compound(Atom('foo'), [Atom('b')]);
      final right = Compound(Atom('foo'), [Atom('a')]);
      final query = Compound(Atom('@>'), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(@<)/2 - compound with variables', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final left = Compound(Atom('foo'), [Atom('a'), x]);
      final right = Compound(Atom('foo'), [Atom('b'), y]);
      final query = Compound(Atom('@<'), [left, right]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(@=<)/2 - variable to itself', () async {
      final x = Variable('X');
      final query = Compound(Atom('@=<'), [x, x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(==)/2 - variable identical to itself', () async {
      final x = Variable('X');
      final query = Compound(Atom('=='), [x, x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(==)/2 - different variables not identical', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final query = Compound(Atom('=='), [x, y]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(\\==)/2 - different anonymous variables', () async {
      final v1 = Variable('_');
      final v2 = Variable('_');
      final query = Compound(Atom('\\=='), [v1, v2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(==)/2 - same anonymous variables fails', () async {
      final v1 = Variable('_');
      final v2 = Variable('_');
      final query = Compound(Atom('=='), [v1, v2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });
  });

  group('ISO - Arithmetic Evaluation (9.1)', () {
    late Resolver resolver;

    setUp(() {
      resolver = Resolver(Database());
    });

    test('9.1.7 is/2 - evaluates addition', () async {
      final x = Variable('X');
      final expr = Compound(Atom('+'), [PrologInteger(2), PrologInteger(3)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(5)));
    });

    test('9.1.7 is/2 - evaluates subtraction', () async {
      final x = Variable('X');
      final expr = Compound(Atom('-'), [PrologInteger(5), PrologInteger(3)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(2)));
    });

    test('9.1.7 is/2 - evaluates multiplication', () async {
      final x = Variable('X');
      final expr = Compound(Atom('*'), [PrologInteger(3), PrologInteger(4)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(12)));
    });

    test('9.1.7 is/2 - evaluates division', () async {
      final x = Variable('X');
      final expr = Compound(Atom('/'), [PrologInteger(10), PrologInteger(2)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologFloat(5.0)));
    });

    test('9.1.7 is/2 - evaluates modulo', () async {
      final x = Variable('X');
      final expr = Compound(Atom('mod'), [PrologInteger(10), PrologInteger(3)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('9.1.7 is/2 - evaluates nested expression', () async {
      final x = Variable('X');
      // X is (2 + 3) * 4
      final inner = Compound(Atom('+'), [PrologInteger(2), PrologInteger(3)]);
      final expr = Compound(Atom('*'), [inner, PrologInteger(4)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(20)));
    });

    // Additional arithmetic function tests from vanilla suite
    test('is/2 - unary plus', () async {
      final x = Variable('X');
      final expr = Compound(Atom('+'), [PrologInteger(7), PrologInteger(35)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(42)));
    });

    test('is/2 - nested addition', () async {
      final x = Variable('X');
      final inner = Compound(Atom('+'), [PrologInteger(3), PrologInteger(11)]);
      final expr = Compound(Atom('+'), [PrologInteger(0), inner]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(14)));
    });

    test('is/2 - unary minus', () async {
      final x = Variable('X');
      final expr = Compound(Atom('-'), [PrologInteger(7)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(-7)));
    });

    test('is/2 - binary subtraction', () async {
      final x = Variable('X');
      final expr = Compound(Atom('-'), [PrologInteger(7), PrologInteger(35)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(-28)));
    });

    test('is/2 - multiplication', () async {
      final x = Variable('X');
      final expr = Compound(Atom('*'), [PrologInteger(7), PrologInteger(35)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(245)));
    });

    test('is/2 - multiplication by zero', () async {
      final x = Variable('X');
      final inner = Compound(Atom('+'), [PrologInteger(3), PrologInteger(11)]);
      final expr = Compound(Atom('*'), [PrologInteger(0), inner]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(0)));
    });

    test('is/2 - division returns float', () async {
      final x = Variable('X');
      final expr = Compound(Atom('/'), [PrologInteger(7), PrologInteger(35)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final result = solutions[0].binding('X') as PrologFloat;
      expect((result.value - 0.2).abs() < 0.0001, isTrue);
    });

    test('is/2 - mod function', () async {
      final x = Variable('X');
      final expr = Compound(Atom('mod'), [PrologInteger(7), PrologInteger(3)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('is/2 - mod with zero', () async {
      final x = Variable('X');
      final inner = Compound(Atom('+'), [PrologInteger(3), PrologInteger(11)]);
      final expr = Compound(Atom('mod'), [PrologInteger(0), inner]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(0)));
    });

    test('is/2 - mod with negative divisor', () async {
      final x = Variable('X');
      final expr = Compound(Atom('mod'), [PrologInteger(7), PrologInteger(-2)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(-1)));
    });

    test('is/2 - floor function', () async {
      final x = Variable('X');
      final expr = Compound(Atom('floor'), [PrologFloat(7.4)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(7)));
    });

    test('is/2 - floor negative', () async {
      final x = Variable('X');
      final expr = Compound(Atom('floor'), [PrologFloat(-0.4)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(-1)));
    });

    test('is/2 - round function', () async {
      final x = Variable('X');
      final expr = Compound(Atom('round'), [PrologFloat(7.5)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(8)));
    });

    test('is/2 - ceiling function', () async {
      final x = Variable('X');
      final expr = Compound(Atom('ceiling'), [PrologFloat(-0.5)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(0)));
    });

    test('is/2 - truncate function', () async {
      final x = Variable('X');
      final expr = Compound(Atom('truncate'), [PrologFloat(-0.5)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(0)));
    });

    test('is/2 - float conversion', () async {
      final x = Variable('X');
      final expr = Compound(Atom('float'), [PrologInteger(7)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologFloat(7.0)));
    });

    test('is/2 - abs function positive', () async {
      final x = Variable('X');
      final expr = Compound(Atom('abs'), [PrologInteger(7)]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(7)));
    });

    test('is/2 - abs function negative', () async {
      final x = Variable('X');
      final inner = Compound(Atom('-'), [PrologInteger(3), PrologInteger(11)]);
      final expr = Compound(Atom('abs'), [inner]);
      final query = Compound(Atom('is'), [x, expr]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(8)));
    });
  });

  group('ISO - Arithmetic Comparison (9.3)', () {
    late Resolver resolver;

    setUp(() {
      resolver = Resolver(Database());
    });

    test('9.3.1 (<)/2 - succeeds when less', () async {
      final query = Compound(Atom('<'), [PrologInteger(1), PrologInteger(2)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('9.3.1 (<)/2 - fails when greater', () async {
      final query = Compound(Atom('<'), [PrologInteger(2), PrologInteger(1)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('9.3.2 (=<)/2 - succeeds when less or equal', () async {
      final query1 = Compound(Atom('=<'), [PrologInteger(1), PrologInteger(2)]);
      final solutions1 = await resolver.queryGoal(query1).toList();
      expect(solutions1.length, equals(1));

      final query2 = Compound(Atom('=<'), [PrologInteger(2), PrologInteger(2)]);
      final solutions2 = await resolver.queryGoal(query2).toList();
      expect(solutions2.length, equals(1));
    });

    test('9.3.3 (>)/2 - succeeds when greater', () async {
      final query = Compound(Atom('>'), [PrologInteger(2), PrologInteger(1)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('9.3.4 (>=)/2 - succeeds when greater or equal', () async {
      final query1 = Compound(Atom('>='), [PrologInteger(2), PrologInteger(1)]);
      final solutions1 = await resolver.queryGoal(query1).toList();
      expect(solutions1.length, equals(1));

      final query2 = Compound(Atom('>='), [PrologInteger(2), PrologInteger(2)]);
      final solutions2 = await resolver.queryGoal(query2).toList();
      expect(solutions2.length, equals(1));
    });

    test('9.3.5 (=:=)/2 - succeeds on arithmetic equality', () async {
      final query = Compound(Atom('=:='), [PrologInteger(2), PrologInteger(2)]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('9.3.6 (=\\=)/2 - succeeds on arithmetic inequality', () async {
      final query = Compound(Atom('=\\='), [
        PrologInteger(1),
        PrologInteger(2),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });
  });

  group('ISO - Term Manipulation (8.5)', () {
    late Resolver resolver;

    setUp(() {
      resolver = Resolver(Database());
    });

    // functor/3 tests (from INRIA suite)
    test('functor/3 - check functor and arity', () async {
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b'), Atom('c')]);
      final query = Compound(Atom('functor'), [
        term,
        Atom('foo'),
        PrologInteger(3),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('functor/3 - extract functor and arity', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b'), Atom('c')]);
      final query = Compound(Atom('functor'), [term, x, y]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('foo')));
      expect(solutions[0].binding('Y'), equals(PrologInteger(3)));
    });

    test('functor/3 - construct term', () async {
      final x = Variable('X');
      final query = Compound(Atom('functor'), [
        x,
        Atom('foo'),
        PrologInteger(3),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final result = solutions[0].binding('X');
      expect(result, isA<Compound>());
      final compound = result as Compound;
      expect(compound.functor, equals(Atom('foo')));
      expect(compound.arity, equals(3));
    });

    test('functor/3 - construct atom (arity 0)', () async {
      final x = Variable('X');
      final query = Compound(Atom('functor'), [
        x,
        Atom('foo'),
        PrologInteger(0),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('foo')));
    });

    test('functor/3 - simultaneous binding', () async {
      final a = Variable('A');
      final b = Variable('B');
      final term = Compound(Atom('mats'), [a, b]);
      final query = Compound(Atom('functor'), [term, a, b]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('A'), equals(Atom('mats')));
      expect(solutions[0].binding('B'), equals(PrologInteger(2)));
    });

    test('functor/3 - fail on wrong arity', () async {
      final term = Compound(Atom('foo'), [Atom('a')]);
      final query = Compound(Atom('functor'), [
        term,
        Atom('foo'),
        PrologInteger(2),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('functor/3 - fail on wrong functor', () async {
      final term = Compound(Atom('foo'), [Atom('a')]);
      final query = Compound(Atom('functor'), [
        term,
        Atom('fo'),
        PrologInteger(1),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('functor/3 - number as functor', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final query = Compound(Atom('functor'), [PrologInteger(1), x, y]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
      expect(solutions[0].binding('Y'), equals(PrologInteger(0)));
    });

    test('functor/3 - construct float (arity 0)', () async {
      final x = Variable('X');
      final query = Compound(Atom('functor'), [
        x,
        PrologFloat(1.1),
        PrologInteger(0),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologFloat(1.1)));
    });

    test('functor/3 - list functor', () async {
      final list = Compound.fromList([Variable('_'), Variable('_')]);
      final query = Compound(Atom('functor'), [
        list,
        Atom('.'),
        PrologInteger(2),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('functor/3 - empty list', () async {
      final query = Compound(Atom('functor'), [
        Atom.nil,
        Atom.nil,
        PrologInteger(0),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    // arg/3 tests (from INRIA suite)
    test('arg/3 - extract first argument', () async {
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final query = Compound(Atom('arg'), [PrologInteger(1), term, Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('arg/3 - extract argument to variable', () async {
      final x = Variable('X');
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final query = Compound(Atom('arg'), [PrologInteger(1), term, x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('a')));
    });

    test('arg/3 - unify with argument', () async {
      final x = Variable('X');
      final term = Compound(Atom('foo'), [x]);
      final query = Compound(Atom('arg'), [PrologInteger(1), term, Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('a')));
    });

    test('arg/3 - unify first of two args', () async {
      final x = Variable('X');
      final term = Compound(Atom('foo'), [x, Atom('b')]);
      final query = Compound(Atom('arg'), [PrologInteger(1), term, Atom('a')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('a')));
    });

    test('arg/3 - extract nested compound', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final inner = Compound(Atom('f'), [x, Atom('b')]);
      final term = Compound(Atom('foo'), [Atom('a'), inner, Atom('c')]);
      final query = Compound(Atom('arg'), [
        PrologInteger(2),
        term,
        Compound(Atom('f'), [Atom('a'), y]),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('a')));
      expect(solutions[0].binding('Y'), equals(Atom('b')));
    });

    test('arg/3 - two variables', () async {
      final x = Variable('X');
      final y = Variable('Y');
      final term = Compound(Atom('foo'), [x, Atom('b')]);
      final query = Compound(Atom('arg'), [PrologInteger(1), term, y]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('arg/3 - fail on wrong argument', () async {
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final query = Compound(Atom('arg'), [PrologInteger(1), term, Atom('b')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('arg/3 - fail on arg 0', () async {
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final query = Compound(Atom('arg'), [
        PrologInteger(0),
        term,
        Atom('foo'),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('arg/3 - fail on out of range', () async {
      final n = Variable('N');
      final term = Compound(Atom('foo'), [PrologInteger(3), PrologInteger(4)]);
      final query = Compound(Atom('arg'), [PrologInteger(3), term, n]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('8.5.1 functor/3 - extracts functor and arity', () async {
      final f = Variable('F');
      final a = Variable('A');
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final query = Compound(Atom('functor'), [term, f, a]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('F'), equals(Atom('foo')));
      expect(solutions[0].binding('A'), equals(PrologInteger(2)));
    });

    test('8.5.1 functor/3 - constructs term', () async {
      final t = Variable('T');
      final query = Compound(Atom('functor'), [
        t,
        Atom('foo'),
        PrologInteger(2),
      ]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final result = solutions[0].binding('T');
      expect(result, isA<Compound>());
      final compound = result as Compound;
      expect(compound.functor, equals(Atom('foo')));
      expect(compound.arity, equals(2));
    });

    test('8.5.2 arg/3 - extracts argument', () async {
      final x = Variable('X');
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b'), Atom('c')]);
      final query = Compound(Atom('arg'), [PrologInteger(2), term, x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('b')));
    });

    test('8.5.3 (=..)/2 - univ decomposes term', () async {
      final l = Variable('L');
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final query = Compound(Atom('=..'), [term, l]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final list = solutions[0].binding('L') as Compound;
      expect(list.functor, equals(Atom.dot));
      expect(list.args[0], equals(Atom('foo')));
    });

    test('8.5.3 (=..)/2 - univ constructs term', () async {
      final t = Variable('T');
      final list = Compound.fromList([Atom('foo'), Atom('a'), Atom('b')]);
      final query = Compound(Atom('=..'), [t, list]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final result = solutions[0].binding('T');
      expect(result, isA<Compound>());
      final compound = result as Compound;
      expect(compound.functor, equals(Atom('foo')));
      expect(compound.arity, equals(2));
    });
  });

  group('ISO - Control Constructs (7.8)', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    // Cut tests (from INRIA suite)
    test('!/0 - cut succeeds', () async {
      final query = Atom('!');
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('!/0 - cut in disjunction', () async {
      // (!,fail;true) should fail
      final cutFail = Compound(Atom(','), [Atom('!'), Atom('fail')]);
      final query = Compound(Atom(';'), [cutFail, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    // Conjunction tests (from INRIA suite)
    test('(,)/2 - X=1, var(X) fails', () async {
      final x = Variable('X');
      final eq = Compound(Atom('='), [x, PrologInteger(1)]);
      final varTest = Compound(Atom('var'), [x]);
      final query = Compound(Atom(','), [eq, varTest]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(,)/2 - var(X), X=1 succeeds', () async {
      final x = Variable('X');
      final varTest = Compound(Atom('var'), [x]);
      final eq = Compound(Atom('='), [x, PrologInteger(1)]);
      final query = Compound(Atom(','), [varTest, eq]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('(,)/2 - fail, call(3) fails early', () async {
      final call3 = Compound(Atom('call'), [PrologInteger(3)]);
      final query = Compound(Atom(','), [Atom('fail'), call3]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(,)/2 - X=true, call(X) succeeds', () async {
      final x = Variable('X');
      final eq = Compound(Atom('='), [x, Atom('true')]);
      final call = Compound(Atom('call'), [x]);
      final query = Compound(Atom(','), [eq, call]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('true')));
    });

    // Disjunction tests (from INRIA suite)
    test('(;)/2 - true;fail succeeds', () async {
      final query = Compound(Atom(';'), [Atom('true'), Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(;)/2 - (!,fail);true fails (cut prevents backtrack)', () async {
      final cutFail = Compound(Atom(','), [Atom('!'), Atom('fail')]);
      final query = Compound(Atom(';'), [cutFail, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(;)/2 - !;call(3) succeeds on cut', () async {
      final call3 = Compound(Atom('call'), [PrologInteger(3)]);
      final query = Compound(Atom(';'), [Atom('!'), call3]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(;)/2 - (X=1,!);X=2 binds X to 1', () async {
      final x1 = Variable('X');
      final x2 = Variable('X');
      final eq1 = Compound(Atom('='), [x1, PrologInteger(1)]);
      final left = Compound(Atom(','), [eq1, Atom('!')]);
      final eq2 = Compound(Atom('='), [x2, PrologInteger(2)]);
      final query = Compound(Atom(';'), [left, eq2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('(;)/2 - X=1;X=2 gives two solutions', () async {
      final x1 = Variable('X');
      final x2 = Variable('X');
      final eq1 = Compound(Atom('='), [x1, PrologInteger(1)]);
      final eq2 = Compound(Atom('='), [x2, PrologInteger(2)]);
      final query = Compound(Atom(';'), [eq1, eq2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(2));
    });

    // If-then-else tests (from INRIA suite)
    test('(->)/2 - true->true;fail succeeds', () async {
      final ifThen = Compound(Atom('->'), [Atom('true'), Atom('true')]);
      final query = Compound(Atom(';'), [ifThen, Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(->)/2 - fail->true;true succeeds on else', () async {
      final ifThen = Compound(Atom('->'), [Atom('fail'), Atom('true')]);
      final query = Compound(Atom(';'), [ifThen, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('(->)/2 - true->fail;fail fails', () async {
      final ifThen = Compound(Atom('->'), [Atom('true'), Atom('fail')]);
      final query = Compound(Atom(';'), [ifThen, Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(->)/2 - fail->true;fail fails', () async {
      final ifThen = Compound(Atom('->'), [Atom('fail'), Atom('true')]);
      final query = Compound(Atom(';'), [ifThen, Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('(->)/2 - true->X=1;X=2 binds X to 1', () async {
      final x1 = Variable('X');
      final x2 = Variable('X');
      final eq1 = Compound(Atom('='), [x1, PrologInteger(1)]);
      final ifThen = Compound(Atom('->'), [Atom('true'), eq1]);
      final eq2 = Compound(Atom('='), [x2, PrologInteger(2)]);
      final query = Compound(Atom(';'), [ifThen, eq2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('(->)/2 - fail->X=1;X=2 binds X to 2', () async {
      final x1 = Variable('X');
      final x2 = Variable('X');
      final eq1 = Compound(Atom('='), [x1, PrologInteger(1)]);
      final ifThen = Compound(Atom('->'), [Atom('fail'), eq1]);
      final eq2 = Compound(Atom('='), [x2, PrologInteger(2)]);
      final query = Compound(Atom(';'), [ifThen, eq2]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(2)));
    });

    test('(->)/2 - true->(X=1;X=2);true gives two solutions', () async {
      final x1 = Variable('X');
      final x2 = Variable('X');
      final eq1 = Compound(Atom('='), [x1, PrologInteger(1)]);
      final eq2 = Compound(Atom('='), [x2, PrologInteger(2)]);
      final or = Compound(Atom(';'), [eq1, eq2]);
      final ifThen = Compound(Atom('->'), [Atom('true'), or]);
      final query = Compound(Atom(';'), [ifThen, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(2));
    });

    test('(->)/2 - (X=1;X=2)->true;true binds X to 1', () async {
      final x1 = Variable('X');
      final x2 = Variable('X');
      final eq1 = Compound(Atom('='), [x1, PrologInteger(1)]);
      final eq2 = Compound(Atom('='), [x2, PrologInteger(2)]);
      final cond = Compound(Atom(';'), [eq1, eq2]);
      final ifThen = Compound(Atom('->'), [cond, Atom('true')]);
      final query = Compound(Atom(';'), [ifThen, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(PrologInteger(1)));
    });

    test('7.8.1 true/0 - always succeeds', () async {
      final query = Atom('true');
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('7.8.2 fail/0 - always fails', () async {
      final query = Atom('fail');
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('7.8.3 !/0 - cut removes choice points', () async {
      // p(1). p(2).
      db.assertz(Clause(Compound(Atom('p'), [PrologInteger(1)]), []));
      db.assertz(Clause(Compound(Atom('p'), [PrologInteger(2)]), []));

      // q(X) :- p(X), !.
      final x1 = Variable('X');
      final x2 = Variable('X');
      db.assertz(
        Clause(Compound(Atom('q'), [x1]), [
          Compound(Atom('p'), [x2]),
          Atom('!'),
        ]),
      );

      final query = Compound(Atom('q'), [Variable('Y')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1)); // Cut prevents second solution
    });

    test(
      '7.8.6 (,)/2 - conjunction succeeds when both goals succeed',
      () async {
        final query = Compound(Atom(','), [Atom('true'), Atom('true')]);
        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
      },
    );

    test('7.8.6 (,)/2 - conjunction fails when any goal fails', () async {
      final query = Compound(Atom(','), [Atom('true'), Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('7.8.7 (;)/2 - disjunction succeeds on first branch', () async {
      final query = Compound(Atom(';'), [Atom('true'), Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, greaterThan(0));
    });

    test('7.8.7 (;)/2 - disjunction succeeds on second branch', () async {
      final query = Compound(Atom(';'), [Atom('fail'), Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, greaterThan(0));
    });

    test('7.8.9 (\\+)/1 - negation succeeds when goal fails', () async {
      final query = Compound(Atom('\\+'), [Atom('fail')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('7.8.9 (\\+)/1 - negation fails when goal succeeds', () async {
      final query = Compound(Atom('\\+'), [Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });
  });

  group('ISO - All Solutions (8.10)', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
      // Define test data: num(1). num(2). num(3).
      db.assertz(Clause(Compound(Atom('num'), [PrologInteger(1)]), []));
      db.assertz(Clause(Compound(Atom('num'), [PrologInteger(2)]), []));
      db.assertz(Clause(Compound(Atom('num'), [PrologInteger(3)]), []));
    });

    test('8.10.1 findall/3 - collects all solutions', () async {
      final x = Variable('X');
      final result = Variable('Result');
      final goal = Compound(Atom('num'), [x]);
      final query = Compound(Atom('findall'), [x, goal, result]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final list = solutions[0].binding('Result');
      expect(list, isA<Compound>());
    });

    test('8.10.2 bagof/3 - collects solutions', () async {
      final x = Variable('X');
      final result = Variable('Result');
      final goal = Compound(Atom('num'), [x]);
      final query = Compound(Atom('bagof'), [x, goal, result]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, greaterThan(0));
    });

    test('8.10.3 setof/3 - collects sorted unique solutions', () async {
      final x = Variable('X');
      final result = Variable('Result');
      final goal = Compound(Atom('num'), [x]);
      final query = Compound(Atom('setof'), [x, goal, result]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, greaterThan(0));
    });
  });

  group('ISO - List Operations', () {
    late Resolver resolver;

    setUp(() {
      resolver = Resolver(Database());
    });

    test('List unification - [H|T] pattern', () async {
      final h = Variable('H');
      final t = Variable('T');
      final pattern = Compound(Atom.dot, [h, t]);
      final list = Compound.fromList([Atom('a'), Atom('b'), Atom('c')]);
      final query = Compound(Atom('='), [pattern, list]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('H'), equals(Atom('a')));
    });

    test('Empty list unification', () async {
      final query = Compound(Atom('='), [Atom.nil, Atom.nil]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('List construction', () async {
      final result = Variable('R');
      final list = Compound(Atom.dot, [
        Atom('a'),
        Compound(Atom.dot, [Atom('b'), Atom.nil]),
      ]);
      final query = Compound(Atom('='), [result, list]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });
  });

  group('ISO - Clause Retrieval and Information', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('Database modification - assert and retract', () async {
      // Assert a fact
      db.assertz(Clause(Compound(Atom('fact'), [Atom('a')]), []));
      expect(db.count, equals(1));

      // Query it
      final query1 = Compound(Atom('fact'), [Atom('a')]);
      final solutions1 = await resolver.queryGoal(query1).toList();
      expect(solutions1.length, equals(1));

      // Retract it
      db.retract(Clause(Compound(Atom('fact'), [Atom('a')]), []));
      expect(db.count, equals(0));

      // Query again - should fail
      final solutions2 = await resolver.queryGoal(query1).toList();
      expect(solutions2.length, equals(0));
    });

    test('Multiple clauses for same predicate', () async {
      db.assertz(Clause(Compound(Atom('color'), [Atom('red')]), []));
      db.assertz(Clause(Compound(Atom('color'), [Atom('green')]), []));
      db.assertz(Clause(Compound(Atom('color'), [Atom('blue')]), []));

      final x = Variable('X');
      final query = Compound(Atom('color'), [x]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(3));
    });
  });

  group('ISO - Occur Check Behavior (8.2)', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test(
      '(=)/2 - allows cyclic unification X = f(X) (no occur check)',
      () async {
        // ISO: =/2 does NOT perform occur check, allowing cyclic terms
        final x = Variable('X');
        final term = Compound(Atom('f'), [x]);
        final query = Compound(Atom('='), [x, term]);
        final solutions = await resolver.queryGoal(query).toList();
        // Should succeed - cyclic unification is allowed
        expect(solutions.length, equals(1));
      },
    );

    test('unify_with_occurs_check/2 - fails on X = f(X)', () async {
      // ISO: unify_with_occurs_check/2 MUST perform occur check
      final x = Variable('X');
      final term = Compound(Atom('f'), [x]);
      final query = Compound(Atom('unify_with_occurs_check'), [x, term]);
      final solutions = await resolver.queryGoal(query).toList();
      // Should fail - occur check prevents cyclic term
      expect(solutions.length, equals(0));
    });

    test(
      'unify_with_occurs_check/2 - succeeds on normal unification',
      () async {
        final x = Variable('X');
        final query = Compound(Atom('unify_with_occurs_check'), [x, Atom('a')]);
        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        expect(solutions[0].binding('X'), equals(Atom('a')));
      },
    );

    test('(\\=)/2 - uses no occur check (same as =)', () async {
      // X \= f(X) should fail because X = f(X) succeeds (no occur check)
      final x = Variable('X');
      final term = Compound(Atom('f'), [x]);
      final query = Compound(Atom('\\='), [x, term]);
      final solutions = await resolver.queryGoal(query).toList();
      // Should fail because the terms CAN unify (without occur check)
      expect(solutions.length, equals(0));
    });
  });

  group('ISO - Error Reporting', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test(
      'atom_length/2 - throws instantiation_error on variable atom',
      () async {
        final e = Variable('E');
        final x = Variable('X');
        final goal = Compound(Atom('atom_length'), [x, PrologInteger(5)]);
        final query = Compound(Atom('catch'), [goal, e, Atom('true')]);
        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        final error = solutions[0].substitution.deref(e) as Compound;
        expect(error.functor, equals(Atom('error')));
        expect(error.args[0], equals(Atom('instantiation_error')));
      },
    );

    test('atom_length/2 - throws type_error on non-atom', () async {
      final e = Variable('E');
      final goal = Compound(Atom('atom_length'), [
        PrologInteger(123),
        Variable('L'),
      ]);
      final query = Compound(Atom('catch'), [goal, e, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      final inner = error.args[0] as Compound;
      expect(inner.functor, equals(Atom('type_error')));
      expect(inner.args[0], equals(Atom('atom')));
    });

    test(
      'functor/3 - throws instantiation_error when Term and Name both var',
      () async {
        final e = Variable('E');
        final t = Variable('T');
        final n = Variable('N');
        final goal = Compound(Atom('functor'), [t, n, PrologInteger(2)]);
        final query = Compound(Atom('catch'), [goal, e, Atom('true')]);
        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        final error = solutions[0].substitution.deref(e) as Compound;
        expect(error.functor, equals(Atom('error')));
        expect(error.args[0], equals(Atom('instantiation_error')));
      },
    );

    test('arg/3 - throws instantiation_error on variable N', () async {
      final e = Variable('E');
      final n = Variable('N');
      final term = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final goal = Compound(Atom('arg'), [n, term, Variable('X')]);
      final query = Compound(Atom('catch'), [goal, e, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      expect(error.args[0], equals(Atom('instantiation_error')));
    });

    test('arg/3 - throws type_error on non-compound Term', () async {
      final e = Variable('E');
      final goal = Compound(Atom('arg'), [
        PrologInteger(1),
        Atom('atom'),
        Variable('X'),
      ]);
      final query = Compound(Atom('catch'), [goal, e, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      final inner = error.args[0] as Compound;
      expect(inner.functor, equals(Atom('type_error')));
      expect(inner.args[0], equals(Atom('compound')));
    });

    test('=../2 - throws instantiation_error when both args var', () async {
      final e = Variable('E');
      final t = Variable('T');
      final l = Variable('L');
      final goal = Compound(Atom('=..'), [t, l]);
      final query = Compound(Atom('catch'), [goal, e, Atom('true')]);
      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      expect(error.args[0], equals(Atom('instantiation_error')));
    });
  });

  group('ISO - bagof/setof Witness Backtracking (8.10)', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
      // Define: foo(1, a). foo(1, b). foo(2, c). foo(2, d).
      db.assertz(
        Clause(Compound(Atom('foo'), [PrologInteger(1), Atom('a')]), []),
      );
      db.assertz(
        Clause(Compound(Atom('foo'), [PrologInteger(1), Atom('b')]), []),
      );
      db.assertz(
        Clause(Compound(Atom('foo'), [PrologInteger(2), Atom('c')]), []),
      );
      db.assertz(
        Clause(Compound(Atom('foo'), [PrologInteger(2), Atom('d')]), []),
      );
    });

    test('bagof/3 - returns multiple witness groups on backtracking', () async {
      // bagof(Y, foo(X, Y), Ys) should produce two solutions:
      // X = 1, Ys = [a, b]
      // X = 2, Ys = [c, d]
      final x = Variable('X');
      final y = Variable('Y');
      final ys = Variable('Ys');
      final goal = Compound(Atom('foo'), [x, y]);
      final query = Compound(Atom('bagof'), [y, goal, ys]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(2));

      // Check first solution: X = 1, Ys = [a, b]
      final x1 = solutions[0].binding('X');
      expect(x1, equals(PrologInteger(1)));

      // Check second solution: X = 2, Ys = [c, d]
      final x2 = solutions[1].binding('X');
      expect(x2, equals(PrologInteger(2)));
    });

    test('setof/3 - returns multiple witness groups on backtracking', () async {
      // setof(Y, foo(X, Y), Ys) should produce two solutions with sorted results
      final x = Variable('X');
      final y = Variable('Y');
      final ys = Variable('Ys');
      final goal = Compound(Atom('foo'), [x, y]);
      final query = Compound(Atom('setof'), [y, goal, ys]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(2));

      // Check that we get two different witness values
      final x1 = solutions[0].binding('X');
      final x2 = solutions[1].binding('X');
      expect(x1, isNot(equals(x2)));
    });

    test('bagof/3 - no free variables returns single solution', () async {
      // bagof(Y, foo(1, Y), Ys) should return single solution: Ys = [a, b]
      final y = Variable('Y');
      final ys = Variable('Ys');
      final goal = Compound(Atom('foo'), [PrologInteger(1), y]);
      final query = Compound(Atom('bagof'), [y, goal, ys]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('bagof/3 - fails when no solutions', () async {
      final y = Variable('Y');
      final ys = Variable('Ys');
      final goal = Compound(Atom('foo'), [PrologInteger(99), y]);
      final query = Compound(Atom('bagof'), [y, goal, ys]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(0));
    });

    test('findall/3 - collects all solutions (no witness grouping)', () async {
      // findall(Y, foo(X, Y), Ys) should return all Y values in single list
      final x = Variable('X');
      final y = Variable('Y');
      final ys = Variable('Ys');
      final goal = Compound(Atom('foo'), [x, y]);
      final query = Compound(Atom('findall'), [y, goal, ys]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      // List should contain [a, b, c, d]
      final list = solutions[0].binding('Ys');
      final elements = Compound.toList(list as Compound);
      expect(elements?.length, equals(4));
    });
  });

  group('ISO - DCG (Definite Clause Grammars)', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('DCG - simple terminal', () {
      // a --> [x].
      final rule = Compound(Atom('-->'), [
        Atom('a'),
        Compound.fromList([Atom('x')]),
      ]);

      db.assertTerm(rule);

      // Verify translation created a/2
      final clauses = db.retrieveByIndicator('a/2').toList();
      expect(clauses.length, equals(1));
    });

    test('DCG - sequence of non-terminals', () {
      // Define: a --> [x].
      db.assertTerm(
        Compound(Atom('-->'), [
          Atom('a'),
          Compound.fromList([Atom('x')]),
        ]),
      );

      // Define: b --> [y].
      db.assertTerm(
        Compound(Atom('-->'), [
          Atom('b'),
          Compound.fromList([Atom('y')]),
        ]),
      );

      // Define: ab --> a, b.
      db.assertTerm(
        Compound(Atom('-->'), [
          Atom('ab'),
          Compound(Atom(','), [Atom('a'), Atom('b')]),
        ]),
      );

      final clauses = db.retrieveByIndicator('ab/2').toList();
      expect(clauses.length, equals(1));
    });

    test('DCG - query acceptance', () async {
      // Define: hello --> [h, e, l, l, o].
      db.assertTerm(
        Compound(Atom('-->'), [
          Atom('hello'),
          Compound.fromList([
            Atom('h'),
            Atom('e'),
            Atom('l'),
            Atom('l'),
            Atom('o'),
          ]),
        ]),
      );

      // Query: hello([h,e,l,l,o], [])
      final query = Compound(Atom('hello'), [
        Compound.fromList([
          Atom('h'),
          Atom('e'),
          Atom('l'),
          Atom('l'),
          Atom('o'),
        ]),
        Atom.nil,
      ]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });
  });
}
