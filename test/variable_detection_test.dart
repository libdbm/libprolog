import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('Variable detection', () {
    test('detects variable in simple compound', () {
      final term = Parser.parseTerm('parent(X, bob).');
      expect(term.isGround, isFalse);
    });

    test('detects no variables in ground term', () {
      final term = Parser.parseTerm('parent(tom, bob).');
      expect(term.isGround, isTrue);
    });

    test('detects variable in first argument', () {
      final term = Parser.parseTerm('likes(X, alice).');
      expect(term.isGround, isFalse);
    });

    test('detects variable in second argument', () {
      final term = Parser.parseTerm('likes(alice, Y).');
      expect(term.isGround, isFalse);
    });

    test('detects multiple variables', () {
      final term = Parser.parseTerm('parent(X, Y).');
      expect(term.isGround, isFalse);
    });

    test('detects variable in nested compound', () {
      final term = Parser.parseTerm(
        'grandparent(X, Z) :- parent(X, Y), parent(Y, Z).',
      );
      expect(term.isGround, isFalse);
    });

    test('detects no variables in nested ground term', () {
      final term = Parser.parseTerm('foo(bar(baz)).');
      expect(term.isGround, isTrue);
    });

    test('detects variable in list head', () {
      final term = Parser.parseTerm('member(X, [1, 2, 3]).');
      expect(term.isGround, isFalse);
    });

    test('detects variable in list tail', () {
      final term = Parser.parseTerm('append([1], Tail).');
      expect(term.isGround, isFalse);
    });

    test('detects variable in list construction', () {
      final term = Parser.parseTerm('list([H|T]).');
      expect(term.isGround, isFalse);
    });

    test('detects no variables in ground list', () {
      final term = Parser.parseTerm('numbers([1, 2, 3]).');
      expect(term.isGround, isTrue);
    });

    test('detects variable in arithmetic expression', () {
      final term = Parser.parseTerm('X is 2 + 3.');
      expect(term.isGround, isFalse);
    });

    test('detects variable in unification', () {
      final term = Parser.parseTerm('X = Y.');
      expect(term.isGround, isFalse);
    });

    test('detects variable as standalone term', () {
      final term = Parser.parseTerm('X.');
      expect(term.isGround, isFalse);
    });

    test('detects no variables in atom', () {
      final term = Parser.parseTerm('true.');
      expect(term.isGround, isTrue);
    });

    test('detects no variables in number', () {
      final term = Parser.parseTerm('42.');
      expect(term.isGround, isTrue);
    });

    test('detects variable in deeply nested structure', () {
      final term = Parser.parseTerm('foo(bar(baz(X))).');
      expect(term.isGround, isFalse);
    });

    test('detects variable with underscore name', () {
      final term = Parser.parseTerm('ignore(_X).');
      expect(term.isGround, isFalse);
    });

    test('detects anonymous variable', () {
      final term = Parser.parseTerm('ignore(_).');
      expect(term.isGround, isFalse);
    });

    test('detects variable in comparison', () {
      final term = Parser.parseTerm('X < 10.');
      expect(term.isGround, isFalse);
    });

    test('detects variable in conjunction', () {
      final term = Parser.parseTerm('atom(X), number(Y).');
      expect(term.isGround, isFalse);
    });

    test('detects no variables in ground conjunction', () {
      final term = Parser.parseTerm('atom(foo), number(42).');
      expect(term.isGround, isTrue);
    });
  });

  group('Variable detection integration with REPL behavior', () {
    late PrologEngine engine;

    setUp(() {
      engine = PrologEngine();
    });

    test('ground terms should be asserted as facts', () {
      final term = Parser.parseTerm('parent(tom, bob).');
      expect(
        term.isGround,
        isTrue,
        reason: 'Ground term should not contain variables',
      );

      // Assert as fact
      engine.assertz(term);

      // Verify it was stored
      final results = engine.query(term).toList();
      expect(results, completion(hasLength(1)));
    });

    test('terms with variables should be treated as queries', () async {
      final fact = Parser.parseTerm('parent(tom, bob).');
      final query = Parser.parseTerm('parent(X, bob).');

      expect(fact.isGround, isTrue);
      expect(
        query.isGround,
        isFalse,
        reason: 'Query with variable should contain variables',
      );

      // Setup: assert the fact
      engine.assertz(fact);

      // Execute as query
      final results = await engine.query(query).toList();
      expect(results, hasLength(1));
      expect(results[0].bindings['X']?.toString(), equals('tom'));
    });

    test('multiple variables in query', () async {
      final fact1 = Parser.parseTerm('parent(tom, bob).');
      final fact2 = Parser.parseTerm('parent(bob, ann).');
      final query = Parser.parseTerm('parent(X, Y).');

      expect(query.isGround, isFalse);

      engine.assertz(fact1);
      engine.assertz(fact2);

      final results = await engine.query(query).toList();
      expect(results, hasLength(2));
    });

    test('nested variables in query', () async {
      final rule = Parser.parseTerm(
        'grandparent(X, Z) :- parent(X, Y), parent(Y, Z).',
      );
      final fact1 = Parser.parseTerm('parent(tom, bob).');
      final fact2 = Parser.parseTerm('parent(bob, ann).');

      expect(rule.isGround, isFalse);

      engine.assertz(rule);
      engine.assertz(fact1);
      engine.assertz(fact2);

      final query = Parser.parseTerm('grandparent(G, C).');
      expect(query.isGround, isFalse);

      final results = await engine.query(query).toList();
      expect(results, hasLength(1));
      expect(results[0].bindings['G']?.toString(), equals('tom'));
      expect(results[0].bindings['C']?.toString(), equals('ann'));
    });

    test('ground builtin should be query not fact', () {
      final term = Parser.parseTerm('2 < 3.');
      expect(term.isGround, isTrue);

      // Even though it has no variables, builtins should be queries
      // This is handled by _isBuiltinQuery in REPL, not isGround
      expect(term is Compound && term.functor.value == '<', isTrue);
    });

    test('arithmetic with variable is query', () {
      final term = Parser.parseTerm('X is 2 + 3.');
      expect(term.isGround, isFalse);
    });
  });
}
