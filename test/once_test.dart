import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('once/1 -', () {
    late PrologEngine engine;

    setUp(() {
      engine = PrologEngine();
    });

    test('succeeds once for goal with multiple solutions', () async {
      engine.assertz('member(1, [1,2,3])');
      engine.assertz('member(2, [1,2,3])');
      engine.assertz('member(3, [1,2,3])');

      final solutions = await engine.queryAll('once(member(X, [1,2,3]))');

      expect(solutions.length, equals(1));
      expect(solutions[0]['X'].toString(), equals('1'));
    });

    test('succeeds once for built-in with multiple solutions', () async {
      final solutions = await engine.queryAll('once((X = 1 ; X = 2 ; X = 3))');

      expect(solutions.length, equals(1));
      expect(solutions[0]['X'].toString(), equals('1'));
    });

    test('fails if goal fails', () async {
      final solutions = await engine.queryAll('once(fail)');

      expect(solutions.length, equals(0));
    });

    test('succeeds if goal succeeds', () async {
      final solutions = await engine.queryAll('once(true)');

      expect(solutions.length, equals(1));
    });

    test('prevents backtracking into goal', () async {
      engine.assertz('p(1)');
      engine.assertz('p(2)');
      engine.assertz('p(3)');

      // once/1 should only find first solution for p(X)
      final solutions = await engine.queryAll('once(p(X))');

      expect(solutions.length, equals(1));
      expect(solutions[0]['X'].toString(), equals('1'));
    });

    test('nested once/1', () async {
      final solutions = await engine.queryAll('once(once((X = a ; X = b)))');

      expect(solutions.length, equals(1));
      expect(solutions[0]['X'].toString(), equals('a'));
    });

    test('combined with other goals', () async {
      engine.assertz('p(1)');
      engine.assertz('p(2)');
      engine.assertz('q(a)');
      engine.assertz('q(b)');

      // once(p(X)) finds p(1), then q(Y) finds both q(a) and q(b)
      final solutions = await engine.queryAll('once(p(X)), q(Y)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'].toString(), equals('1'));
      expect(solutions[0]['Y'].toString(), equals('a'));
      expect(solutions[1]['X'].toString(), equals('1'));
      expect(solutions[1]['Y'].toString(), equals('b'));
    });
  });
}
