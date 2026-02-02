import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('DCG - Translation', () {
    test('translates simple terminal rule', () {
      // a --> [x].
      final rule = Compound(Atom('-->'), [
        Atom('a'),
        Compound.fromList([Atom('x')]),
      ]);

      final translator = DCGTranslator();
      final result = translator.translateRule(rule);

      expect(result, isNotNull);
      expect(result!.head, isA<Compound>());
      final head = result.head as Compound;
      expect(head.functor, equals(Atom('a')));
      expect(head.arity, equals(2)); // a(S0, S1)
    });

    test('translates non-terminal rule', () {
      // sentence --> noun.
      final rule = Compound(Atom('-->'), [Atom('sentence'), Atom('noun')]);

      final translator = DCGTranslator();
      final result = translator.translateRule(rule);

      expect(result, isNotNull);
      expect(result!.head, isA<Compound>());
      final head = result.head as Compound;
      expect(head.functor, equals(Atom('sentence')));
      expect(head.arity, equals(2)); // sentence(S0, S1)

      expect(result.body.length, equals(1));
      final bodyGoal = result.body[0] as Compound;
      expect(bodyGoal.functor, equals(Atom('noun')));
      expect(bodyGoal.arity, equals(2)); // noun(S0, S1)
    });

    test('translates sequence rule', () {
      // sentence --> noun, verb.
      final rule = Compound(Atom('-->'), [
        Atom('sentence'),
        Compound(Atom(','), [Atom('noun'), Atom('verb')]),
      ]);

      final translator = DCGTranslator();
      final result = translator.translateRule(rule);

      expect(result, isNotNull);
      expect(result!.body.length, equals(2));

      final first = result.body[0] as Compound;
      expect(first.functor, equals(Atom('noun')));

      final second = result.body[1] as Compound;
      expect(second.functor, equals(Atom('verb')));
    });

    test('translates rule with arguments', () {
      // number(N) --> [N].
      final rule = Compound(Atom('-->'), [
        Compound(Atom('number'), [Variable('N')]),
        Compound.fromList([Variable('N')]),
      ]);

      final translator = DCGTranslator();
      final result = translator.translateRule(rule);

      expect(result, isNotNull);
      final head = result!.head as Compound;
      expect(head.functor, equals(Atom('number')));
      expect(head.arity, equals(3)); // number(N, S0, S1)
      expect(head.args[0], isA<Variable>());
      expect((head.args[0] as Variable).name, equals('N'));
    });
  });

  group('DCG - Database Integration', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('assertTerm handles DCG rules', () {
      // Define: digit --> [0].
      final rule = Compound(Atom('-->'), [
        Atom('digit'),
        Compound.fromList([PrologInteger(0)]),
      ]);

      db.assertTerm(rule);

      // The translated clause should be in the database
      final clauses = db.retrieveByIndicator('digit/2').toList();
      expect(clauses.length, equals(1));

      final clause = clauses[0];
      expect(clause.head, isA<Compound>());
      final head = clause.head as Compound;
      expect(head.functor, equals(Atom('digit')));
      expect(head.arity, equals(2));
    });

    test('DCG rule can be queried after assertion', () async {
      // Define: a --> [x].
      final rule = Compound(Atom('-->'), [
        Atom('a'),
        Compound.fromList([Atom('x')]),
      ]);

      db.assertTerm(rule);

      // Query: a([x], [])
      final query = Compound(Atom('a'), [
        Compound.fromList([Atom('x')]),
        Atom.nil,
      ]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('DCG sequence rule works', () async {
      // Define: ab --> [a], [b].
      final rule = Compound(Atom('-->'), [
        Atom('ab'),
        Compound(Atom(','), [
          Compound.fromList([Atom('a')]),
          Compound.fromList([Atom('b')]),
        ]),
      ]);

      db.assertTerm(rule);

      // Query: ab([a, b], [])
      final query = Compound(Atom('ab'), [
        Compound.fromList([Atom('a'), Atom('b')]),
        Atom.nil,
      ]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('DCG with non-terminals', () async {
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

      // Define: c --> a, b.
      db.assertTerm(
        Compound(Atom('-->'), [
          Atom('c'),
          Compound(Atom(','), [Atom('a'), Atom('b')]),
        ]),
      );

      // Query: c([x, y], [])
      final query = Compound(Atom('c'), [
        Compound.fromList([Atom('x'), Atom('y')]),
        Atom.nil,
      ]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));
    });

    test('DCG with remainder', () async {
      // Define: a --> [x].
      db.assertTerm(
        Compound(Atom('-->'), [
          Atom('a'),
          Compound.fromList([Atom('x')]),
        ]),
      );

      // Query: a([x, y, z], R) should unify R with [y, z]
      final remainder = Variable('R');
      final query = Compound(Atom('a'), [
        Compound.fromList([Atom('x'), Atom('y'), Atom('z')]),
        remainder,
      ]);

      final solutions = await resolver.queryGoal(query).toList();
      expect(solutions.length, equals(1));

      final result = solutions[0].binding('R');
      expect(result, isA<Compound>());
      // Should be [y, z]
      final resultList = result as Compound;
      expect(resultList.functor, equals(Atom.dot));
      expect(resultList.args[0], equals(Atom('y')));
    });
  });
}
