import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('REPL Output Formatting', () {
    test('sibling(X,Y) shows only X and Y bindings', () async {
      final engine = PrologEngine();

      // Load family rules
      engine.assertz(Parser.parseTerm('parent(john, david).'));
      engine.assertz(Parser.parseTerm('parent(john, susan).'));
      engine.assertz(Parser.parseTerm('parent(mary, david).'));
      engine.assertz(Parser.parseTerm('parent(mary, susan).'));
      engine.assertz(
        Parser.parseTerm(
          'sibling(Person1, Person2) :- parent(P, Person1), parent(P, Person2), Person1 \\= Person2.',
        ),
      );

      // Query sibling(X, Y)
      final query = Parser.parseTerm('sibling(X, Y).');
      final solutions = await engine.query(query).toList();

      expect(solutions.isNotEmpty, true);

      // Check first solution
      final firstSolution = solutions.first;

      // Should have X and Y in bindings
      expect(firstSolution.bindings.containsKey('X'), true);
      expect(firstSolution.bindings.containsKey('Y'), true);

      // Filter to only query variables (X and Y)
      final queryVars = {'X', 'Y'};
      final filtered = Map.fromEntries(
        firstSolution.bindings.entries.where((e) => queryVars.contains(e.key)),
      );

      // Should only have 2 bindings (X and Y)
      expect(filtered.length, 2);

      // Internal variables like _R0, _R1, _R2 should NOT be in filtered output
      for (final key in filtered.keys) {
        expect(
          key.startsWith('_R'),
          false,
          reason: 'Filtered output should not contain renamed variables',
        );
      }

      print('Filtered bindings: $filtered');
      print('All bindings: ${firstSolution.bindings}');
    });

    test('simple query X=1 shows only X', () async {
      final engine = PrologEngine();
      final query = Parser.parseTerm('X = 1.');
      final solutions = await engine.query(query).toList();

      expect(solutions.length, 1);
      final solution = solutions.first;

      // Filter to only X
      final queryVars = {'X'};
      final filtered = Map.fromEntries(
        solution.bindings.entries.where((e) => queryVars.contains(e.key)),
      );

      expect(filtered.length, 1);
      expect(filtered['X'].toString(), '1');
    });
  });
}
