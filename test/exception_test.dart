import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('ISO Exception Handling', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    group('catch/3', () {
      test('catches matching exception', () async {
        // catch(throw(my_error), E, E = my_error)
        final e = Variable('E');
        final throw1 = Compound(Atom('throw'), [Atom('my_error')]);
        final recovery = Compound(Atom('='), [e, Atom('my_error')]);
        final query = Compound(Atom('catch'), [throw1, e, recovery]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        expect(solutions[0].substitution.deref(e), equals(Atom('my_error')));
      });

      test('catches exception with variable pattern', () async {
        // catch(throw(error(test, context)), error(E, _), true)
        final e = Variable('E');
        final err = Compound(Atom('error'), [Atom('test'), Atom('context')]);
        final throw1 = Compound(Atom('throw'), [err]);
        final pattern = Compound(Atom('error'), [e, Variable('_')]);
        final query = Compound(Atom('catch'), [throw1, pattern, Atom('true')]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        expect(solutions[0].substitution.deref(e), equals(Atom('test')));
      });

      test('succeeds if goal succeeds without throwing', () async {
        // catch(true, _, fail)
        final query = Compound(Atom('catch'), [
          Atom('true'),
          Variable('_'),
          Atom('fail'),
        ]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
      });

      test('fails if goal fails without throwing', () async {
        // catch(fail, _, true)
        final query = Compound(Atom('catch'), [
          Atom('fail'),
          Variable('_'),
          Atom('true'),
        ]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(0));
      });

      test('nested catch - inner catches first', () async {
        // catch(catch(throw(inner), inner, true), outer, fail)
        final throw1 = Compound(Atom('throw'), [Atom('inner')]);
        final inner = Compound(Atom('catch'), [
          throw1,
          Atom('inner'),
          Atom('true'),
        ]);
        final outer = Compound(Atom('catch'), [
          inner,
          Atom('outer'),
          Atom('fail'),
        ]);

        final solutions = await resolver.queryGoal(outer).toList();
        expect(solutions.length, equals(1));
      });

      test('nested catch - propagates when inner does not match', () async {
        // catch(catch(throw(error), nomatch, fail), E, E = error)
        final e = Variable('E');
        final throw1 = Compound(Atom('throw'), [Atom('error')]);
        final inner = Compound(Atom('catch'), [
          throw1,
          Atom('nomatch'),
          Atom('fail'),
        ]);
        final recovery = Compound(Atom('='), [e, Atom('error')]);
        final outer = Compound(Atom('catch'), [inner, e, recovery]);

        final solutions = await resolver.queryGoal(outer).toList();
        expect(solutions.length, equals(1));
        expect(solutions[0].substitution.deref(e), equals(Atom('error')));
      });

      test('preserves bindings from goal on success', () async {
        // catch((X = 5, true), _, fail)
        final x = Variable('X');
        final unify = Compound(Atom('='), [x, PrologInteger(5)]);
        final conj = Compound(Atom(','), [unify, Atom('true')]);
        final query = Compound(Atom('catch'), [
          conj,
          Variable('_'),
          Atom('fail'),
        ]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        expect(solutions[0].substitution.deref(x), equals(PrologInteger(5)));
      });
    });

    group('throw/1', () {
      test('throws unhandled exception', () async {
        final query = Compound(Atom('throw'), [Atom('unhandled_error')]);

        expect(
          () async => await resolver.queryGoal(query).toList(),
          throwsA(isA<Exception>()),
        );
      });

      test('throws with compound term', () async {
        final err = Compound(Atom('error'), [
          Compound(Atom('type_error'), [Atom('integer'), Atom('foo')]),
          Atom('is/2'),
        ]);
        final throw1 = Compound(Atom('throw'), [err]);
        final e = Variable('E');
        final query = Compound(Atom('catch'), [throw1, e, Atom('true')]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        final caught = solutions[0].substitution.deref(e) as Compound;
        expect(caught.functor, equals(Atom('error')));
      });
    });

    group('exception interaction with control flow', () {
      test('cut before throw removes choice points', () async {
        // Define: foo :- throw(err). foo :- true.
        db.assertTerm(
          Compound(Atom(':-'), [
            Atom('foo'),
            Compound(Atom('throw'), [Atom('err')]),
          ]),
        );
        db.assertTerm(Compound(Atom(':-'), [Atom('foo'), Atom('true')]));

        // catch((!, foo), E, E = err) - cut then throw
        final e = Variable('E');
        final goal = Compound(Atom(','), [Atom('!'), Atom('foo')]);
        final recovery = Compound(Atom('='), [e, Atom('err')]);
        final query = Compound(Atom('catch'), [goal, e, recovery]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        expect(solutions[0].substitution.deref(e), equals(Atom('err')));
      });

      test('exception in disjunction left branch', () async {
        // catch((throw(err) ; true), E, true) - E binds to err
        final e = Variable('E');
        final left = Compound(Atom('throw'), [Atom('err')]);
        final disj = Compound(Atom(';'), [left, Atom('true')]);
        final query = Compound(Atom('catch'), [disj, e, Atom('true')]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        // ISO semantics: E is bound to the exception term
        expect(solutions[0].substitution.deref(e), equals(Atom('err')));
      });

      test('exception in if-then-else condition', () async {
        // catch((throw(err) -> fail ; true), E, true)
        final e = Variable('E');
        final cond = Compound(Atom('throw'), [Atom('err')]);
        final ifThen = Compound(Atom('->'), [cond, Atom('fail')]);
        final ite = Compound(Atom(';'), [ifThen, Atom('true')]);
        final query = Compound(Atom('catch'), [ite, e, Atom('true')]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));
        // ISO semantics: E is bound to the exception term
        expect(solutions[0].substitution.deref(e), equals(Atom('err')));
      });
    });
  });

  group('ISO Arithmetic Errors', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('division by zero throws evaluation_error(zero_divisor)', () async {
      final e = Variable('E');
      final x = Variable('X');
      final expr = Compound(Atom('/'), [PrologInteger(1), PrologInteger(0)]);
      final isGoal = Compound(Atom('is'), [x, expr]);
      final query = Compound(Atom('catch'), [isGoal, e, Atom('true')]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      expect(error.args[0], isA<Compound>());
      final inner = error.args[0] as Compound;
      expect(inner.functor, equals(Atom('evaluation_error')));
      expect(inner.args[0], equals(Atom('zero_divisor')));
    });

    test('unbound variable throws instantiation_error', () async {
      final e = Variable('E');
      final x = Variable('X');
      final y = Variable('Y');
      final expr = Compound(Atom('+'), [x, PrologInteger(1)]);
      final isGoal = Compound(Atom('is'), [y, expr]);
      final query = Compound(Atom('catch'), [isGoal, e, Atom('true')]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      expect(error.args[0], equals(Atom('instantiation_error')));
    });

    test('non-numeric atom throws type_error', () async {
      final e = Variable('E');
      final x = Variable('X');
      final expr = Compound(Atom('+'), [Atom('foo'), PrologInteger(1)]);
      final isGoal = Compound(Atom('is'), [x, expr]);
      final query = Compound(Atom('catch'), [isGoal, e, Atom('true')]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
      expect(error.args[0], isA<Compound>());
      final inner = error.args[0] as Compound;
      expect(inner.functor, equals(Atom('type_error')));
    });

    test('integer division by zero throws evaluation_error', () async {
      final e = Variable('E');
      final x = Variable('X');
      final expr = Compound(Atom('//'), [PrologInteger(5), PrologInteger(0)]);
      final isGoal = Compound(Atom('is'), [x, expr]);
      final query = Compound(Atom('catch'), [isGoal, e, Atom('true')]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
    });

    test('mod by zero throws evaluation_error', () async {
      final e = Variable('E');
      final x = Variable('X');
      final expr = Compound(Atom('mod'), [PrologInteger(5), PrologInteger(0)]);
      final isGoal = Compound(Atom('is'), [x, expr]);
      final query = Compound(Atom('catch'), [isGoal, e, Atom('true')]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final error = solutions[0].substitution.deref(e) as Compound;
      expect(error.functor, equals(Atom('error')));
    });

    test(
      'comparison with unbound variable throws instantiation_error',
      () async {
        final e = Variable('E');
        final x = Variable('X');
        final cmp = Compound(Atom('<'), [x, PrologInteger(5)]);
        final query = Compound(Atom('catch'), [cmp, e, Atom('true')]);

        final solutions = await resolver.queryGoal(query).toList();
        expect(solutions.length, equals(1));

        final error = solutions[0].substitution.deref(e) as Compound;
        expect(error.functor, equals(Atom('error')));
        expect(error.args[0], equals(Atom('instantiation_error')));
      },
    );
  });
}
