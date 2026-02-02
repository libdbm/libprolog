import 'package:libprolog/libprolog.dart';

/// DCG (Definite Clause Grammar) Support
///
/// Demonstrates:
/// - DCG rule syntax (-->)
/// - Automatic translation to difference lists
/// - Terminal sequences [a, b, c]
/// - Non-terminal composition
/// - DCG with arguments
/// - Grammar-based parsing
void main() async {
  print('=== DCG (Definite Clause Grammar) ===\n');

  final db = Database();
  final resolver = Resolver(db);

  // Example 1: Simple terminal recognition
  print('--- Example 1: Terminal Recognition ---');
  // Define: hello --> [h, e, l, l, o].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('hello'),
      Compound.fromList([
        Atom('h'),
        Atom('e'),
        Atom('l'),
        Atom('l'),
        Atom('o'),
      ]),
    ]),
  );

  // Query: hello([h,e,l,l,o], [])
  final query1 = Compound(Atom('hello'), [
    Compound.fromList([Atom('h'), Atom('e'), Atom('l'), Atom('l'), Atom('o')]),
    Atom.nil,
  ]);

  final solutions1 = await resolver.queryGoal(query1).toList();
  print('hello([h,e,l,l,o], []) => ${solutions1.length == 1 ? 'yes' : 'no'}');

  // Query with remainder
  final r1 = Variable('R');
  final query2 = Compound(Atom('hello'), [
    Compound.fromList([
      Atom('h'),
      Atom('e'),
      Atom('l'),
      Atom('l'),
      Atom('o'),
      Atom('!'),
    ]),
    r1,
  ]);

  final solutions2 = await resolver.queryGoal(query2).toList();
  if (solutions2.isNotEmpty) {
    final remainder = solutions2[0].binding('R');
    print('hello([h,e,l,l,o,!], R) => R = $remainder');
  }

  // Example 2: Sequence composition
  print('\n--- Example 2: Sequence Composition ---');
  // Define: a --> [a].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('a'),
      Compound.fromList([Atom('a')]),
    ]),
  );

  // Define: b --> [b].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('b'),
      Compound.fromList([Atom('b')]),
    ]),
  );

  // Define: ab --> a, b.
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('ab'),
      Compound(Atom(','), [Atom('a'), Atom('b')]),
    ]),
  );

  final query3 = Compound(Atom('ab'), [
    Compound.fromList([Atom('a'), Atom('b')]),
    Atom.nil,
  ]);

  final solutions3 = await resolver.queryGoal(query3).toList();
  print('ab([a,b], []) => ${solutions3.length == 1 ? 'yes' : 'no'}');

  // Example 3: Simple sentence grammar
  print('\n--- Example 3: Simple Sentence Grammar ---');
  // Define determiners, nouns, verbs
  // det --> [the].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('det'),
      Compound.fromList([Atom('the')]),
    ]),
  );

  // noun --> [cat].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('noun'),
      Compound.fromList([Atom('cat')]),
    ]),
  );

  // noun --> [dog].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('noun'),
      Compound.fromList([Atom('dog')]),
    ]),
  );

  // verb --> [runs].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('verb'),
      Compound.fromList([Atom('runs')]),
    ]),
  );

  // verb --> [sleeps].
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('verb'),
      Compound.fromList([Atom('sleeps')]),
    ]),
  );

  // np --> det, noun.
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('np'),
      Compound(Atom(','), [Atom('det'), Atom('noun')]),
    ]),
  );

  // vp --> verb.
  db.assertTerm(Compound(Atom('-->'), [Atom('vp'), Atom('verb')]));

  // sentence --> np, vp.
  db.assertTerm(
    Compound(Atom('-->'), [
      Atom('sentence'),
      Compound(Atom(','), [Atom('np'), Atom('vp')]),
    ]),
  );

  // Query: sentence([the, cat, runs], [])
  final query4 = Compound(Atom('sentence'), [
    Compound.fromList([Atom('the'), Atom('cat'), Atom('runs')]),
    Atom.nil,
  ]);

  final solutions4 = await resolver.queryGoal(query4).toList();
  print(
    'sentence([the, cat, runs], []) => ${solutions4.length == 1 ? 'yes' : 'no'}',
  );

  // Query: sentence([the, dog, sleeps], [])
  final query5 = Compound(Atom('sentence'), [
    Compound.fromList([Atom('the'), Atom('dog'), Atom('sleeps')]),
    Atom.nil,
  ]);

  final solutions5 = await resolver.queryGoal(query5).toList();
  print(
    'sentence([the, dog, sleeps], []) => ${solutions5.length == 1 ? 'yes' : 'no'}',
  );

  // Example 4: DCG with arguments
  print('\n--- Example 4: DCG with Arguments ---');
  // Define: digit(0) --> [zero].
  db.assertTerm(
    Compound(Atom('-->'), [
      Compound(Atom('digit'), [PrologInteger(0)]),
      Compound.fromList([Atom('zero')]),
    ]),
  );

  // digit(1) --> [one].
  db.assertTerm(
    Compound(Atom('-->'), [
      Compound(Atom('digit'), [PrologInteger(1)]),
      Compound.fromList([Atom('one')]),
    ]),
  );

  // digit(2) --> [two].
  db.assertTerm(
    Compound(Atom('-->'), [
      Compound(Atom('digit'), [PrologInteger(2)]),
      Compound.fromList([Atom('two')]),
    ]),
  );

  // Query: digit(N, [one], [])
  final n = Variable('N');
  final query6 = Compound(Atom('digit'), [
    n,
    Compound.fromList([Atom('one')]),
    Atom.nil,
  ]);

  final solutions6 = await resolver.queryGoal(query6).toList();
  if (solutions6.isNotEmpty) {
    final value = solutions6[0].binding('N');
    print('digit(N, [one], []) => N = $value');
  }

  // Query: digit(2, S, [])
  final s = Variable('S');
  final query7 = Compound(Atom('digit'), [PrologInteger(2), s, Atom.nil]);

  final solutions7 = await resolver.queryGoal(query7).toList();
  if (solutions7.isNotEmpty) {
    final input = solutions7[0].binding('S');
    print('digit(2, S, []) => S = $input');
  }

  // Example 5: Number list grammar
  print('\n--- Example 5: Number List Grammar ---');
  // nums([]) --> [].
  db.assertTerm(
    Compound(Atom('-->'), [
      Compound(Atom('nums'), [Atom.nil]),
      Atom.nil,
    ]),
  );

  // nums([N|Ns]) --> digit(N), nums(Ns).
  final nVar = Variable('N');
  final nsVar = Variable('Ns');
  db.assertTerm(
    Compound(Atom('-->'), [
      Compound(Atom('nums'), [
        Compound(Atom.dot, [nVar, nsVar]),
      ]),
      Compound(Atom(','), [
        Compound(Atom('digit'), [nVar]),
        Compound(Atom('nums'), [nsVar]),
      ]),
    ]),
  );

  // Query: nums([1,0,2], [one, zero, two], [])
  final query8 = Compound(Atom('nums'), [
    Compound.fromList([PrologInteger(1), PrologInteger(0), PrologInteger(2)]),
    Compound.fromList([Atom('one'), Atom('zero'), Atom('two')]),
    Atom.nil,
  ]);

  final solutions8 = await resolver.queryGoal(query8).toList();
  print(
    'nums([1,0,2], [one, zero, two], []) => ${solutions8.length == 1 ? 'yes' : 'no'}',
  );

  print('\n=== Complete! ===');
  print('DCG rules are automatically translated to difference lists.');
  print('This enables elegant grammar-based parsing in Prolog.');
}
