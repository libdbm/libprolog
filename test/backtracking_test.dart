import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Backtracking with Conjunctions', () {
    late PrologEngine prolog;

    setUp(() {
      prolog = PrologEngine();
    });

    test('backtracks through first goal with second goal succeeding', () async {
      // This is the pattern that exposed the bug
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('q(a)');

      final solutions = await prolog.queryAll('p(X), q(a)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals('a'));
      expect(solutions[1]['X'], equals('b'));
    });

    test('backtracks through both goals in conjunction', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('q(a)');
      prolog.assertz('q(b)');

      final solutions = await prolog.queryAll('p(X), q(X)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals('a'));
      expect(solutions[1]['X'], equals('b'));
    });

    test('backtracks with different variables in conjunction', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('q(1)');
      prolog.assertz('q(2)');

      final solutions = await prolog.queryAll('p(X), q(Y)');

      expect(solutions.length, equals(4));
      // All combinations: (a,1), (a,2), (b,1), (b,2)
      expect(solutions[0]['X'], equals('a'));
      expect(solutions[0]['Y'], equals(1));
      expect(solutions[1]['X'], equals('a'));
      expect(solutions[1]['Y'], equals(2));
      expect(solutions[2]['X'], equals('b'));
      expect(solutions[2]['Y'], equals(1));
      expect(solutions[3]['X'], equals('b'));
      expect(solutions[3]['Y'], equals(2));
    });

    test('sibling pattern - shared parent relationship', () async {
      prolog.assertz('parent(john, david)');
      prolog.assertz('parent(john, susan)');
      prolog.assertz('parent(mary, david)');
      prolog.assertz('parent(mary, susan)');
      prolog.assertz('sibling(X, Y) :- parent(P, X), parent(P, Y), X \\= Y');

      final solutions = await prolog.queryAll('sibling(X, david)');

      // Should find susan twice (once for each parent)
      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals('susan'));
      expect(solutions[1]['X'], equals('susan'));
    });

    test('backtracks through three goals', () async {
      prolog.assertz('a(1)');
      prolog.assertz('a(2)');
      prolog.assertz('b(1)');
      prolog.assertz('b(2)');
      prolog.assertz('c(1)');
      prolog.assertz('c(2)');

      final solutions = await prolog.queryAll('a(X), b(X), c(X)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals(1));
      expect(solutions[1]['X'], equals(2));
    });

    test('backtracks with rule in conjunction', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('q(X) :- r(X)');
      prolog.assertz('r(a)');
      prolog.assertz('r(b)');

      final solutions = await prolog.queryAll('p(X), q(X)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals('a'));
      expect(solutions[1]['X'], equals('b'));
    });

    test('backtracks with nested conjunctions', () async {
      prolog.assertz('p(1)');
      prolog.assertz('p(2)');
      prolog.assertz('q(1)');
      prolog.assertz('q(2)');
      prolog.assertz('r(1)');
      prolog.assertz('r(2)');

      final solutions = await prolog.queryAll('p(X), (q(X), r(X))');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals(1));
      expect(solutions[1]['X'], equals(2));
    });

    test('backtracks with failing middle goal', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('p(c)');
      prolog.assertz('q(b)'); // Only b matches
      prolog.assertz('r(a)');
      prolog.assertz('r(b)');
      prolog.assertz('r(c)');

      final solutions = await prolog.queryAll('p(X), q(X), r(X)');

      expect(solutions.length, equals(1));
      expect(solutions[0]['X'], equals('b'));
    });

    test('backtracks with \\= constraint', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('p(c)');

      final solutions = await prolog.queryAll('p(X), p(Y), X \\= Y');

      // Should get all pairs where X != Y
      expect(solutions.length, equals(6));
      // (a,b), (a,c), (b,a), (b,c), (c,a), (c,b)
    });

    test('backtracks through choice points created by rules', () async {
      prolog.assertz('direct(a, b)');
      prolog.assertz('direct(b, c)');
      prolog.assertz('direct(a, d)');
      prolog.assertz('path(X, Y) :- direct(X, Y)');
      prolog.assertz('path(X, Y) :- direct(X, Z), direct(Z, Y)');

      final solutions = await prolog.queryAll('path(a, X)');

      // Direct: b, d
      // Indirect: c (via b)
      expect(solutions.length, equals(3));
      final results = solutions.map((s) => s['X']).toList();
      expect(results, contains('b'));
      expect(results, contains('d'));
      expect(results, contains('c'));
    });

    test('backtracks correctly after unification in conjunction', () async {
      prolog.assertz('p(1, a)');
      prolog.assertz('p(2, b)');
      prolog.assertz('q(a, x)');
      prolog.assertz('q(b, y)');

      final solutions = await prolog.queryAll('p(N, L), q(L, R)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['N'], equals(1));
      expect(solutions[0]['L'], equals('a'));
      expect(solutions[0]['R'], equals('x'));
      expect(solutions[1]['N'], equals(2));
      expect(solutions[1]['L'], equals('b'));
      expect(solutions[1]['R'], equals('y'));
    });

    test('backtracks with repeated variable in different positions', () async {
      prolog.assertz('edge(a, b)');
      prolog.assertz('edge(b, c)');
      prolog.assertz('edge(c, d)');
      prolog.assertz('edge(a, c)');

      final solutions = await prolog.queryAll('edge(a, X), edge(X, Y)');

      // a->b, b->c gives (X=b, Y=c)
      // a->c, c->d gives (X=c, Y=d)
      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals('b'));
      expect(solutions[0]['Y'], equals('c'));
      expect(solutions[1]['X'], equals('c'));
      expect(solutions[1]['Y'], equals('d'));
    });

    test('backtracks with ground and variable goals', () async {
      prolog.assertz('element(1)');
      prolog.assertz('element(2)');
      prolog.assertz('element(3)');
      prolog.assertz('valid(1)');
      prolog.assertz('valid(3)');

      final solutions = await prolog.queryAll('element(X), valid(X)');

      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals(1));
      expect(solutions[1]['X'], equals(3));
    });
  });

  group('Backtracking Edge Cases', () {
    late PrologEngine prolog;

    setUp(() {
      prolog = PrologEngine();
    });

    test('empty conjunction backtracking', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');

      final solutions = await prolog.queryAll('p(X), true');

      expect(solutions.length, equals(2));
    });

    test('backtracking with cut should stop at cut point', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('p(c)');

      final solutions = await prolog.queryAll('p(X), !, p(Y)');

      // Cut after first solution of p(X), so X=a, then all Y solutions
      expect(solutions.length, equals(3));
      expect(solutions.every((s) => s['X'] == 'a'), isTrue);
    });

    test('backtracking with fail forces backtrack', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('q(b)');

      final solutions = await prolog.queryAll('p(X), (X = a -> fail ; q(X))');

      // X=a triggers fail in then-branch, X=b goes to else-branch and succeeds
      expect(solutions.length, equals(1));
      expect(solutions[0]['X'], equals('b'));
    });

    test('backtracking through single-clause predicates', () async {
      prolog.assertz('p(a)');
      prolog.assertz('p(b)');
      prolog.assertz('q(x)'); // Single clause

      final solutions = await prolog.queryAll('p(X), q(Y)');

      expect(solutions.length, equals(2));
      expect(solutions.every((s) => s['Y'] == 'x'), isTrue);
    });

    test('deep backtracking with multiple choice points', () async {
      prolog.assertz('a(1)');
      prolog.assertz('a(2)');
      prolog.assertz('b(1)');
      prolog.assertz('b(2)');
      prolog.assertz('c(1)');
      prolog.assertz('c(2)');
      prolog.assertz('d(1)');
      prolog.assertz('d(2)');

      final solutions = await prolog.queryAll('a(W), b(X), c(Y), d(Z), W = Z');

      // W can be 1 or 2, Z must equal W, X can be 1 or 2, Y can be 1 or 2
      // So: 2 (W) * 2 (X) * 2 (Y) = 8 solutions
      expect(solutions.length, equals(8));

      // Verify all solutions have W = Z
      for (final sol in solutions) {
        expect(sol['W'], equals(sol['Z']));
      }
    });
  });
}
