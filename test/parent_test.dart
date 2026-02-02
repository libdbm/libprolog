import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  test('parent query', () async {
    final prolog = PrologEngine();

    // Load the facts using assertTerm
    prolog.assertTerm('father(john, mary)');
    prolog.assertTerm('mother(mary, peter)');
    prolog.assertTerm('father(john, tom)');
    prolog.assertTerm('parent(X, Y) :- father(X, Y)');
    prolog.assertTerm('parent(X, Y) :- mother(X, Y)');
    prolog.assertTerm('grandparent(X, Z) :- parent(X, Y), parent(Y, Z)');

    print('\n=== Query: parent(X, peter) ===');
    print('(Who is a parent of peter?)');
    var solutions = await prolog.queryAll('parent(X, peter)');
    for (var sol in solutions) {
      print('  X = ${sol.binding('X')}');
    }
    print('Total: ${solutions.length} solution(s)\n');

    print('=== Query: parent(john, Y) ===');
    print('(Who is john a parent of?)');
    solutions = await prolog.queryAll('parent(john, Y)');
    for (var sol in solutions) {
      print('  Y = ${sol.binding('Y')}');
    }
    print('Total: ${solutions.length} solution(s)\n');

    print('=== Query: grandparent(john, Z) ===');
    print('(Who is john a grandparent of?)');
    solutions = await prolog.queryAll('grandparent(john, Z)');
    for (var sol in solutions) {
      print('  Z = ${sol.binding('Z')}');
    }
    print('Total: ${solutions.length} solution(s)\n');

    print('=== All father facts ===');
    solutions = await prolog.queryAll('father(X, Y)');
    for (var sol in solutions) {
      print('  father(${sol.binding('X')}, ${sol.binding('Y')})');
    }

    print('\n=== All mother facts ===');
    solutions = await prolog.queryAll('mother(X, Y)');
    for (var sol in solutions) {
      print('  mother(${sol.binding('X')}, ${sol.binding('Y')})');
    }
  });
}
