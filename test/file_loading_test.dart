import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';
import 'dart:io';

void main() {
  group('File Loading -', () {
    late PrologEngine engine;

    setUp(() {
      engine = PrologEngine();
    });

    test('loads file with multi-line clauses and comments', () async {
      // Create test file
      final testFile = File('test_data/test_load.pl');

      if (!testFile.existsSync()) {
        testFile.createSync(recursive: true);
        testFile.writeAsStringSync('''
% Test file for file loading
% Simple facts
parent(tom, bob).
parent(bob, ann).

% Multi-line rule
grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z).

% List fact
likes(john, [pizza, pasta, icecream]).
''');
      }

      // Load using Parser.parse()
      final content = testFile.readAsStringSync();
      final clauses = Parser.parse(content);

      expect(clauses.length, greaterThan(0));

      // Assert all clauses
      for (final clause in clauses) {
        engine.assertz(clause);
      }

      // Verify loaded correctly
      final parentSolutions = await engine.queryAll('parent(tom, X)');
      expect(parentSolutions.length, equals(1));
      expect(parentSolutions[0]['X'].toString(), equals('bob'));

      final grandparentSolutions = await engine.queryAll('grandparent(tom, X)');
      expect(grandparentSolutions.length, greaterThan(0));
      // Should find ann as one of the grandchildren
      final hasAnn = grandparentSolutions.any(
        (s) => s['X'].toString() == 'ann',
      );
      expect(hasAnn, isTrue);
    });

    test('handles complex nested structures', () async {
      final content = '''
complex(
    foo(
        bar(1, 2),
        baz([a, b, c])
    )
).
''';

      final clauses = Parser.parse(content);
      expect(clauses.length, equals(1));

      engine.assertz(clauses[0]);

      final solutions = await engine.queryAll('complex(X)');
      expect(solutions.length, equals(1));
      expect(solutions[0]['X'].toString(), contains('foo'));
    });

    test('handles multiple clauses for same predicate', () async {
      final content = '''
member(X, [X|_]).
member(X, [_|T]) :- member(X, T).
''';

      final clauses = Parser.parse(content);
      expect(clauses.length, equals(2));

      for (final clause in clauses) {
        engine.assertz(clause);
      }

      final solutions = await engine.queryAll('member(2, [1,2,3])');
      expect(solutions.length, greaterThan(0));
    });

    test('handles empty lines and whitespace', () async {
      final content = '''

parent(a, b).


parent(b, c).

''';

      final clauses = Parser.parse(content);
      expect(clauses.length, equals(2));

      for (final clause in clauses) {
        engine.assertz(clause);
      }

      final solutions = await engine.queryAll('parent(X, Y)');
      expect(solutions.length, equals(2));
    });

    test('handles operator syntax', () async {
      final content = '''
test(X) :- X = 1, X > 0.
test2(X, Y) :- X is Y + 1.
''';

      final clauses = Parser.parse(content);
      expect(clauses.length, equals(2));

      for (final clause in clauses) {
        engine.assertz(clause);
      }

      final solutions = await engine.queryAll('test(1)');
      expect(solutions.length, greaterThan(0));
    });
  });
}
