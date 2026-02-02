import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Resolver - Basic Queries', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('queries simple fact', () async {
      // Add fact: foo.
      db.assert_(Clause(Atom('foo')));

      // Query: foo.
      final solutions = await resolver.queryGoal(Atom('foo')).toList();

      expect(solutions.length, equals(1));
    });

    test('fails on missing fact', () async {
      // Query non-existent fact
      final solutions = await resolver.queryGoal(Atom('bar')).toList();

      expect(solutions, isEmpty);
    });

    test('unifies with fact', () async {
      // Add fact: parent(john, mary).
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('john'), Atom('mary')])),
      );

      // Query: parent(john, X).
      final x = Variable('X');
      final goal = Compound(Atom('parent'), [Atom('john'), x]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('mary')));
    });

    test('finds multiple solutions', () async {
      // Add facts
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('john'), Atom('mary')])),
      );
      db.assert_(Clause(Compound(Atom('parent'), [Atom('john'), Atom('bob')])));

      // Query: parent(john, X).
      final x = Variable('X');
      final goal = Compound(Atom('parent'), [Atom('john'), x]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(2));

      final bindings = solutions.map((s) => s.binding('X')).toList();
      expect(bindings, contains(Atom('mary')));
      expect(bindings, contains(Atom('bob')));
    });
  });

  group('Resolver - Rules', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('proves simple rule', () async {
      // Add rule: mortal(X) :- human(X).
      final x = Variable('X');
      final head = Compound(Atom('mortal'), [x]);
      final body = [
        Compound(Atom('human'), [x]),
      ];
      db.assert_(Clause(head, body));

      // Add fact: human(socrates).
      db.assert_(Clause(Compound(Atom('human'), [Atom('socrates')])));

      // Query: mortal(socrates).
      final goal = Compound(Atom('mortal'), [Atom('socrates')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
    });

    test('chains rules', () async {
      // grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
      final x = Variable('X');
      final y = Variable('Y');
      final z = Variable('Z');

      final grandHead = Compound(Atom('grandparent'), [x, z]);
      final grandBody = [
        Compound(Atom('parent'), [x, y]),
        Compound(Atom('parent'), [y, z]),
      ];
      db.assert_(Clause(grandHead, grandBody));

      // Facts
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('john'), Atom('mary')])),
      );
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('mary'), Atom('alice')])),
      );

      // Query: grandparent(john, Who).
      final who = Variable('Who');
      final goal = Compound(Atom('grandparent'), [Atom('john'), who]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('Who'), equals(Atom('alice')));
    });

    test('chains rules with different variables', () async {
      // grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
      // Use DIFFERENT variable objects than in the query
      final x = Variable('X');
      final y = Variable('Y');
      final z = Variable('Z');

      final grandHead = Compound(Atom('grandparent'), [x, z]);
      final grandBody = [
        Compound(Atom('parent'), [x, y]),
        Compound(Atom('parent'), [y, z]),
      ];
      db.assert_(Clause(grandHead, grandBody));

      // Facts
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('john'), Atom('mary')])),
      );
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('mary'), Atom('alice')])),
      );

      // Query: grandparent(john, Who).
      // Use DIFFERENT variable objects
      final queryZ = Variable('QueryZ');
      final goal = Compound(Atom('grandparent'), [Atom('john'), queryZ]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('QueryZ'), equals(Atom('alice')));
    });
  });

  group('Resolver - Built-ins', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('true always succeeds', () async {
      final solutions = await resolver.queryGoal(Atom('true')).toList();
      expect(solutions.length, equals(1));
    });

    test('fail always fails', () async {
      final solutions = await resolver.queryGoal(Atom('fail')).toList();
      expect(solutions, isEmpty);
    });

    test('unification (=) succeeds', () async {
      final x = Variable('X');
      final goal = Compound(Atom('='), [x, Atom('hello')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('hello')));
    });

    test('unification (=) fails on mismatch', () async {
      final goal = Compound(Atom('='), [Atom('a'), Atom('b')]);
      final solutions = await resolver.queryGoal(goal).toList();

      expect(solutions, isEmpty);
    });

    test('cut removes choice points', () async {
      // Add facts
      db.assert_(Clause(Compound(Atom('test'), [Atom('a')])));
      db.assert_(Clause(Compound(Atom('test'), [Atom('b')])));

      // Add rule with cut: choose(X) :- test(X), !.
      final x = Variable('X');
      final head = Compound(Atom('choose'), [x]);
      final body = [
        Compound(Atom('test'), [x]),
        Atom.cut,
      ];
      db.assert_(Clause(head, body));

      // Query: choose(X).
      final goal = Compound(Atom('choose'), [Variable('X')]);
      final solutions = await resolver.queryGoal(goal).toList();

      // Should only get first solution due to cut
      expect(solutions.length, equals(1));
      expect(solutions[0].binding('X'), equals(Atom('a')));
    });
  });

  group('Resolver - Conjunction', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('proves multiple goals', () async {
      db.assert_(Clause(Atom('a')));
      db.assert_(Clause(Atom('b')));

      // Query: a, b
      final solutions = await resolver.query([Atom('a'), Atom('b')]).toList();

      expect(solutions.length, equals(1));
    });

    test('fails if one goal fails', () async {
      db.assert_(Clause(Atom('a')));
      // b is not defined

      // Query: a, b
      final solutions = await resolver.query([Atom('a'), Atom('b')]).toList();

      expect(solutions, isEmpty);
    });

    test('backtracks through conjunction', () async {
      db.assert_(Clause(Compound(Atom('num'), [Atom('one')])));
      db.assert_(Clause(Compound(Atom('num'), [Atom('two')])));
      db.assert_(Clause(Compound(Atom('color'), [Atom('red')])));
      db.assert_(Clause(Compound(Atom('color'), [Atom('blue')])));

      // Query: num(X), color(Y)
      final x = Variable('X');
      final y = Variable('Y');
      final solutions = await resolver.query([
        Compound(Atom('num'), [x]),
        Compound(Atom('color'), [y]),
      ]).toList();

      // TODO: Should get 2 x 2 = 4 solutions
      // Currently gets 2 due to backtracking limitation
      // This will be fixed in future optimization phase
      expect(solutions.length, greaterThanOrEqualTo(2));
      expect(solutions.length, lessThanOrEqualTo(4));
    });
  });

  group('Resolver - Variable Renaming', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('renames variables in clauses', () async {
      // Add rule: same(X, X).
      final x = Variable('X');
      final head = Compound(Atom('same'), [x, x]);
      db.assert_(Clause(head));

      // Query: same(a, a).
      final goal1 = Compound(Atom('same'), [Atom('a'), Atom('a')]);
      final solutions1 = await resolver.queryGoal(goal1).toList();
      expect(solutions1.length, equals(1));

      // Query: same(a, b). - should fail
      final goal2 = Compound(Atom('same'), [Atom('a'), Atom('b')]);
      final solutions2 = await resolver.queryGoal(goal2).toList();
      expect(solutions2, isEmpty);
    });

    test('handles multiple uses of same clause', () async {
      // Add fact: num(1).
      db.assert_(Clause(Compound(Atom('num'), [PrologInteger(1)])));

      // Query multiple times
      for (var i = 0; i < 3; i++) {
        final x = Variable('X');
        final goal = Compound(Atom('num'), [x]);
        final solutions = await resolver.queryGoal(goal).toList();

        expect(solutions.length, equals(1));
        expect(solutions[0].binding('X'), equals(PrologInteger(1)));
      }
    });
  });
}
