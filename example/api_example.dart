import 'package:libprolog/libprolog.dart';

/// Demonstrates the clean, idiomatic Dart API for using the Prolog engine.
///
/// Shows how to use libprolog from Dart applications, including queries,
/// assertions, rules, and foreign predicates.
void main() async {
  print('=== libprolog API Examples ===\n');

  // Example 1: Basic usage
  print('--- Example 1: Basic Usage ---');
  final prolog = PrologEngine();

  // Assert facts using strings
  prolog.assertz(Compound(Atom('parent'), [Atom('tom'), Atom('bob')]));
  prolog.assertz(Compound(Atom('parent'), [Atom('tom'), Atom('liz')]));
  prolog.assertz(Compound(Atom('parent'), [Atom('bob'), Atom('ann')]));

  print('Asserted 3 parent facts');
  print('Database contains ${prolog.clauseCount} clauses\n');

  // Example 2: Query with stream
  print('--- Example 2: Query with Stream ---');
  final x = Variable('X');
  final query1 = Compound(Atom('parent'), [Atom('tom'), x]);

  await for (final solution in prolog.query(query1)) {
    print('Tom is parent of: ${solution['X']}');
  }

  // Example 3: Query once
  print('\n--- Example 3: Query Once ---');
  final y = Variable('Y');
  final query2 = Compound(Atom('parent'), [Atom('bob'), y]);
  final result = await prolog.queryOnce(query2);

  if (result.success) {
    print('Bob is parent of: ${result['Y']}');
  }

  // Example 4: Query all solutions
  print('\n--- Example 4: Query All Solutions ---');
  final z = Variable('Z');
  final query3 = Compound(Atom('parent'), [Atom('tom'), z]);
  final solutions = await prolog.queryAll(query3);

  print('Tom has ${solutions.length} children:');
  for (final solution in solutions) {
    print('  - ${solution['Z']}');
  }

  // Example 5: Term conversion
  print('\n--- Example 5: Term Conversion ---');
  final intTerm = TermConversion.fromDart(42);
  final doubleTerm = TermConversion.fromDart(3.14);
  final listTerm = TermConversion.fromDart([1, 2, 3]);

  print('int → term: $intTerm');
  print('double → term: $doubleTerm');
  print('list → term: $listTerm');

  print('term → int: ${TermConversion.toDart(intTerm)}');
  print('term → double: ${TermConversion.toDart(doubleTerm)}');
  print('term → list: ${TermConversion.toDart(listTerm)}');

  // Example 6: Rules
  print('\n--- Example 6: Rules ---');
  // grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
  final xVar = Variable('X');
  final yVar = Variable('Y');
  final zVar = Variable('Z');

  final grandparentHead = Compound(Atom('grandparent'), [xVar, zVar]);
  final parent1 = Compound(Atom('parent'), [xVar, yVar]);
  final parent2 = Compound(Atom('parent'), [yVar, zVar]);
  final grandparentBody = Compound(Atom(','), [parent1, parent2]);
  final grandparentRule = Compound(Atom(':-'), [
    grandparentHead,
    grandparentBody,
  ]);

  prolog.assertz(grandparentRule);

  final gpVar = Variable('GP');
  final gcVar = Variable('GC');
  final gpQuery = Compound(Atom('grandparent'), [gpVar, gcVar]);
  final gpSolutions = await prolog.queryAll(gpQuery);

  print('Grandparent relationships:');
  for (final solution in gpSolutions) {
    print('  ${solution['GP']} is grandparent of ${solution['GC']}');
  }

  // Example 7: Retract
  print('\n--- Example 7: Retract ---');
  print('Before retract: ${prolog.clauseCount} clauses');

  final retractClause = Clause(
    Compound(Atom('parent'), [Atom('tom'), Atom('bob')]),
    [],
  );
  prolog.retract(retractClause);

  print('After retract: ${prolog.clauseCount} clauses');

  // Example 8: Foreign predicates
  print('\n--- Example 8: Foreign Predicates ---');
  prolog.registerForeign('always_succeeds', 0, (context) {
    return const BuiltinSuccess();
  });

  final foreignResult = await prolog.queryOnce(Atom('always_succeeds'));
  print(
    'Foreign predicate result: ${foreignResult.success ? "success" : "failure"}',
  );

  print('\n=== Examples Complete! ===');
  print('The libprolog API makes Prolog easy to use from Dart!');
}
