import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Clause', () {
    test('creates fact', () {
      final clause = Clause(Atom('foo'));
      expect(clause.isFact, isTrue);
      expect(clause.isRule, isFalse);
      expect(clause.body, isEmpty);
    });

    test('creates rule', () {
      final head = Compound(Atom('parent'), [Atom('X'), Atom('Y')]);
      final body = [
        Compound(Atom('father'), [Atom('X'), Atom('Y')]),
      ];
      final clause = Clause(head, body);

      expect(clause.isRule, isTrue);
      expect(clause.isFact, isFalse);
      expect(clause.body.length, equals(1));
    });

    test('gets functor and arity from atom head', () {
      final clause = Clause(Atom('foo'));
      expect(clause.functor, equals(Atom('foo')));
      expect(clause.arity, equals(0));
      expect(clause.indicator, equals('foo/0'));
    });

    test('gets functor and arity from compound head', () {
      final head = Compound(Atom('parent'), [Atom('john'), Atom('mary')]);
      final clause = Clause(head);

      expect(clause.functor, equals(Atom('parent')));
      expect(clause.arity, equals(2));
      expect(clause.indicator, equals('parent/2'));
    });

    test('toString for fact', () {
      final clause = Clause(Atom('foo'));
      expect(clause.toString(), equals('foo.'));
    });

    test('toString for rule', () {
      final head = Atom('a');
      final body = [Atom('b'), Atom('c')];
      final clause = Clause(head, body);

      expect(clause.toString(), equals('a :- b, c.'));
    });
  });

  group('Database', () {
    late Database db;

    setUp(() {
      db = Database();
    });

    test('starts empty', () {
      expect(db.isEmpty, isTrue);
      expect(db.count, equals(0));
    });

    test('adds and retrieves facts', () {
      final clause = Clause(Atom('foo'));
      db.assert_(clause);

      expect(db.isEmpty, isFalse);
      expect(db.count, equals(1));
      expect(db.contains(clause), isTrue);
    });

    test('retrieves clauses by goal', () {
      final clause1 = Clause(
        Compound(Atom('parent'), [Atom('john'), Atom('mary')]),
      );
      final clause2 = Clause(
        Compound(Atom('parent'), [Atom('bob'), Atom('alice')]),
      );
      final clause3 = Clause(
        Compound(Atom('sibling'), [Atom('mary'), Atom('alice')]),
      );

      db.assert_(clause1);
      db.assert_(clause2);
      db.assert_(clause3);

      final goal = Compound(Atom('parent'), [Variable('X'), Variable('Y')]);
      final results = db.retrieve(goal).toList();

      expect(results.length, equals(2));
      expect(results, contains(clause1));
      expect(results, contains(clause2));
    });

    test('retrieves by indicator', () {
      final clause1 = Clause(Compound(Atom('foo'), [Atom('a')]));
      final clause2 = Clause(Compound(Atom('foo'), [Atom('b')]));
      final clause3 = Clause(Compound(Atom('bar'), [Atom('c')]));

      db.assert_(clause1);
      db.assert_(clause2);
      db.assert_(clause3);

      final results = db.retrieveByIndicator('foo/1').toList();

      expect(results.length, equals(2));
      expect(results, contains(clause1));
      expect(results, contains(clause2));
    });

    test('removes clause', () {
      final clause = Clause(Atom('foo'));
      db.assert_(clause);

      expect(db.count, equals(1));

      final removed = db.retract(clause);

      expect(removed, isTrue);
      expect(db.count, equals(0));
      expect(db.contains(clause), isFalse);
    });

    test('removes all matching clauses', () {
      final clause1 = Clause(
        Compound(Atom('parent'), [Atom('john'), Atom('mary')]),
      );
      final clause2 = Clause(
        Compound(Atom('parent'), [Atom('bob'), Atom('alice')]),
      );
      final clause3 = Clause(Atom('other'));

      db.assert_(clause1);
      db.assert_(clause2);
      db.assert_(clause3);

      final head = Compound(Atom('parent'), [Variable('X'), Variable('Y')]);
      final removed = db.retractAll(head);

      expect(removed, equals(2));
      expect(db.count, equals(1));
      expect(db.contains(clause3), isTrue);
    });

    test('clears database', () {
      db.assert_(Clause(Atom('foo')));
      db.assert_(Clause(Atom('bar')));

      expect(db.count, equals(2));

      db.clear();

      expect(db.isEmpty, isTrue);
      expect(db.count, equals(0));
    });
  });

  group('MemoryStorage indexing', () {
    late Database db;

    setUp(() {
      db = Database();
    });

    test('first-argument indexing for compounds', () {
      // Add clauses with different first arguments
      final c1 = Clause(Compound(Atom('test'), [Atom('a'), Atom('x')]));
      final c2 = Clause(Compound(Atom('test'), [Atom('b'), Atom('y')]));
      final c3 = Clause(Compound(Atom('test'), [Atom('a'), Atom('z')]));

      db.assert_(c1);
      db.assert_(c2);
      db.assert_(c3);

      // Query with ground first argument
      final goal = Compound(Atom('test'), [Atom('a'), Variable('Y')]);
      final results = db.retrieve(goal).toList();

      // Should retrieve only clauses with first arg = 'a'
      expect(results.length, equals(2));
      expect(results, contains(c1));
      expect(results, contains(c3));
    });

    test('retrieves variable first-arg clauses', () {
      final x = Variable('X');
      final c1 = Clause(Compound(Atom('test'), [x, Atom('val1')]));
      final c2 = Clause(Compound(Atom('test'), [Atom('a'), Atom('val2')]));

      db.assert_(c1);
      db.assert_(c2);

      // Query with ground first argument should get both
      final goal = Compound(Atom('test'), [Atom('a'), Variable('Y')]);
      final results = db.retrieve(goal).toList();

      expect(results.length, equals(2));
    });

    test('storage statistics', () {
      final storage = db.storage as StorageWithStats;
      storage.resetStats();

      db.assert_(Clause(Atom('foo')));
      expect(storage.stats.additions, equals(1));

      db.retrieve(Atom('foo'));
      expect(storage.stats.retrievals, equals(1));

      db.retract(Clause(Atom('foo')));
      expect(storage.stats.removals, greaterThan(0));
    });
  });
}
