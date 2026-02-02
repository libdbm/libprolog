import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('API - TermConversion', () {
    test('converts int to PrologInteger', () {
      final term = TermConversion.fromDart(42);
      expect(term, isA<PrologInteger>());
      expect((term as PrologInteger).value, equals(42));
    });

    test('converts double to PrologFloat', () {
      final term = TermConversion.fromDart(3.14);
      expect(term, isA<PrologFloat>());
      expect((term as PrologFloat).value, equals(3.14));
    });

    test('converts String to Atom', () {
      final term = TermConversion.fromDart('hello');
      expect(term, isA<Atom>());
      expect((term as Atom).value, equals('hello'));
    });

    test('converts bool to Atom', () {
      final trueTerm = TermConversion.fromDart(true);
      expect(trueTerm, equals(Atom('true')));

      final falseTerm = TermConversion.fromDart(false);
      expect(falseTerm, equals(Atom('false')));
    });

    test('converts null to Atom', () {
      final term = TermConversion.fromDart(null);
      expect(term, equals(Atom('null')));
    });

    test('converts List to Prolog list', () {
      final term = TermConversion.fromDart([1, 2, 3]);
      expect(term, isA<Compound>());
      final list = term as Compound;
      expect(list.functor, equals(Atom.dot));
      expect(list.arity, equals(2));
    });

    test('converts empty List to nil', () {
      final term = TermConversion.fromDart([]);
      expect(term, equals(Atom.nil));
    });

    test('converts PrologInteger to int', () {
      final value = TermConversion.toDart(PrologInteger(42));
      expect(value, equals(42));
    });

    test('converts PrologFloat to double', () {
      final value = TermConversion.toDart(PrologFloat(3.14));
      expect(value, equals(3.14));
    });

    test('converts Atom to String', () {
      final value = TermConversion.toDart(Atom('hello'));
      expect(value, equals('hello'));
    });

    test('converts true/false atoms to bool', () {
      final trueValue = TermConversion.toDart(Atom('true'));
      expect(trueValue, equals(true));

      final falseValue = TermConversion.toDart(Atom('false'));
      expect(falseValue, equals(false));
    });

    test('converts Prolog list to Dart list', () {
      final list = Compound.fromList([
        PrologInteger(1),
        PrologInteger(2),
        PrologInteger(3),
      ]);
      final value = TermConversion.toDart(list);
      expect(value, equals([1, 2, 3]));
    });
  });

  group('API - Solution Extensions', () {
    test('provides access to bindings as Dart values', () {
      final subst = Substitution();
      final x = Variable('X');
      subst.bind(x, Atom('hello'));

      final solution = Solution(subst);
      expect(solution.binding('X'), equals(Atom('hello')));
      expect(solution['X'], equals('hello'));
    });

    test('provides values map with Dart conversion', () {
      final subst = Substitution();
      final x = Variable('X');
      final y = Variable('Y');
      subst.bind(x, PrologInteger(42));
      subst.bind(y, Atom('hello'));

      final solution = Solution(subst);
      final values = solution.values;
      expect(values['X'], equals(42));
      expect(values['Y'], equals('hello'));
    });
  });

  group('API - PrologEngine', () {
    late PrologEngine prolog;

    setUp(() {
      prolog = PrologEngine();
    });

    test('assertz adds facts', () {
      prolog.assertz('parent(tom, bob)');
      expect(prolog.clauseCount, equals(1));
    });

    test('assertz with multiple facts', () {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(bob, ann)');
      expect(prolog.clauseCount, equals(2));
    });

    test('query returns solutions', () async {
      prolog.assertz('parent(tom, bob)');

      final solutions = await prolog.queryAll('parent(tom, X)');
      expect(solutions.length, equals(1));
      expect(solutions[0]['X'], equals('bob'));
    });

    test('query with multiple solutions', () async {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(tom, liz)');

      final solutions = await prolog.queryAll('parent(tom, X)');
      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals('bob'));
      expect(solutions[1]['X'], equals('liz'));
    });

    test('queryOnce returns first solution', () async {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(tom, liz)');

      final result = await prolog.queryOnce('parent(tom, X)');
      expect(result.success, isTrue);
      expect(result['X'], equals('bob'));
    });

    test('queryOnce returns failure for no solutions', () async {
      final result = await prolog.queryOnce('parent(tom, X)');
      expect(result.failure, isTrue);
      expect(result['X'], isNull);
    });

    test('query with rules', () async {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(bob, ann)');
      prolog.assertz('grandparent(X, Z) :- parent(X, Y), parent(Y, Z)');

      final solutions = await prolog.queryAll('grandparent(tom, Z)');
      expect(solutions.length, equals(1));
      expect(solutions[0]['Z'], equals('ann'));
    });

    test('retract removes clauses', () async {
      prolog.assertz('parent(tom, bob)');
      expect(prolog.clauseCount, equals(1));

      final removed = prolog.retract('parent(tom, bob)');
      expect(removed, isTrue);
      expect(prolog.clauseCount, equals(0));
    });

    test('retractAll removes all matching clauses', () async {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(tom, liz)');
      prolog.assertz('parent(bob, ann)');

      final count = prolog.retractAll('parent(tom, _)');
      expect(count, equals(2));
      expect(prolog.clauseCount, equals(1));
    });

    test('abolish removes all clauses of arity 0', () async {
      prolog.assertz('fact1');
      prolog.assertz('fact2');
      prolog.assertz('fact1');
      expect(prolog.clauseCount, equals(3));

      // Abolish all fact1/0 clauses
      final result = await prolog.queryOnce('abolish(fact1/0)');
      expect(result.success, isTrue);

      // Verify fact1 clauses removed but fact2 remains
      expect(prolog.clauseCount, equals(1));
      final remaining = await prolog.queryOnce('fact2');
      expect(remaining.success, isTrue);
    });

    test('abolish removes all clauses of arity > 0', () async {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(tom, liz)');
      prolog.assertz('parent(bob, ann)');
      prolog.assertz('sibling(bob, liz)');
      prolog.assertz('sibling(liz, bob)');
      expect(prolog.clauseCount, equals(5));

      // Abolish all parent/2 clauses
      final result = await prolog.queryOnce('abolish(parent/2)');
      expect(result.success, isTrue);

      // Verify only sibling/2 clauses remain
      expect(prolog.clauseCount, equals(2));
      final parentGone = await prolog.queryOnce('parent(_, _)');
      expect(parentGone.success, isFalse);
      final siblingRemains = await prolog.queryOnce('sibling(bob, liz)');
      expect(siblingRemains.success, isTrue);
    });

    test('abolish with different arities', () async {
      // Add predicates with same name but different arities
      prolog.assertz('foo');
      prolog.assertz('foo(a)');
      prolog.assertz('foo(a, b)');
      prolog.assertz('foo(a, b, c)');
      expect(prolog.clauseCount, equals(4));

      // Abolish only foo/2
      final result = await prolog.queryOnce('abolish(foo/2)');
      expect(result.success, isTrue);

      // Verify foo/2 is gone but others remain
      expect(prolog.clauseCount, equals(3));
      final foo0 = await prolog.queryOnce('foo');
      expect(foo0.success, isTrue);
      final foo1 = await prolog.queryOnce('foo(a)');
      expect(foo1.success, isTrue);
      final foo2 = await prolog.queryOnce('foo(a, b)');
      expect(foo2.success, isFalse);
      final foo3 = await prolog.queryOnce('foo(a, b, c)');
      expect(foo3.success, isTrue);
    });

    test('clear removes all clauses', () {
      prolog.assertz('parent(tom, bob)');
      prolog.assertz('parent(bob, ann)');
      expect(prolog.clauseCount, equals(2));

      prolog.clear();
      expect(prolog.isEmpty, isTrue);
    });

    test('handles DCG rules', () async {
      prolog.assertTerm('a --> [x]');
      prolog.assertTerm('b --> [y]');
      prolog.assertTerm('ab --> a, b');

      final result = await prolog.queryOnce('ab([x, y], [])');
      expect(result.success, isTrue);
    });

    test('query with stream iteration', () async {
      prolog.assertz('num(1)');
      prolog.assertz('num(2)');
      prolog.assertz('num(3)');

      final results = <int>[];
      await for (final solution in prolog.query('num(X)')) {
        results.add(solution['X'] as int);
      }

      expect(results, equals([1, 2, 3]));
    });

    test('supports variables in queries', () async {
      prolog.assertz('likes(mary, wine)');
      prolog.assertz('likes(john, wine)');
      prolog.assertz('likes(john, mary)');

      final solutions = await prolog.queryAll('likes(X, Y)');
      expect(solutions.length, equals(3));
    });

    test('handles complex terms', () async {
      prolog.assertz('point(p(1, 2))');
      prolog.assertz('point(p(3, 4))');

      final solutions = await prolog.queryAll('point(p(X, Y))');
      expect(solutions.length, equals(2));
      expect(solutions[0]['X'], equals(1));
      expect(solutions[0]['Y'], equals(2));
    });

    test('registerForeign adds custom predicates', () async {
      prolog.registerForeign('always_true', 0, (context) {
        return const BuiltinSuccess();
      });

      final result = await prolog.queryOnce('always_true');
      expect(result.success, isTrue);
    });

    test('foreign predicate with arguments', () async {
      prolog.registerForeign('double', 2, (context) {
        final input = context.arg(0);
        if (input is PrologInteger) {
          final result = PrologInteger(input.value * 2);
          // Unify the second argument with the computed result
          context.trail.mark();
          if (Unify.unify(
            context.arg(1),
            result,
            context.substitution,
            context.trail,
          )) {
            return const BuiltinSuccess();
          }
        }
        return const BuiltinFailure();
      });

      final result = await prolog.queryOnce('double(5, X)');
      expect(result.success, isTrue);
      expect(result['X'], equals(10));
    });
  });

  group('API - QueryResult', () {
    test('success returns true for valid solution', () async {
      final prolog = PrologEngine();
      prolog.assertz('fact(true)');
      final result = await prolog.queryOnce('fact(true)');
      expect(result.success, isTrue);
      expect(result.failure, isFalse);
    });

    test('failure returns true for no solution', () async {
      final prolog = PrologEngine();
      final result = await prolog.queryOnce('nonexistent(X)');
      expect(result.success, isFalse);
      expect(result.failure, isTrue);
    });

    test('provides access to solution bindings', () async {
      final prolog = PrologEngine();
      prolog.assertz('value(test)');
      final result = await prolog.queryOnce('value(X)');
      expect(result['X'], equals('test'));
    });

    test('returns null for missing solution', () async {
      final prolog = PrologEngine();
      final result = await prolog.queryOnce('nonexistent(X)');
      expect(result['X'], isNull);
    });
  });
}
