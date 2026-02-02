import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Parser - Atoms', () {
    test('parses simple atom', () {
      final term = Parser.parseTerm('hello');
      expect(term, isA<Atom>());
      expect((term as Atom).value, equals('hello'));
    });

    test('parses quoted atom', () {
      final term = Parser.parseTerm("'Hello World'");
      expect(term, isA<Atom>());
      expect((term as Atom).value, equals('Hello World'));
    });

    test('parses symbolic atom', () {
      final term = Parser.parseTerm('[]');
      expect(term, isA<Atom>());
      expect(term, equals(Atom.nil));
    });
  });

  group('Parser - Variables', () {
    test('parses variable', () {
      final term = Parser.parseTerm('X');
      expect(term, isA<Variable>());
      expect((term as Variable).name, equals('X'));
    });

    test('parses anonymous variable', () {
      final term = Parser.parseTerm('_');
      expect(term, isA<Variable>());
      expect((term as Variable).name, equals('_'));
    });
  });

  group('Parser - Numbers', () {
    test('parses integer', () {
      final term = Parser.parseTerm('42');
      expect(term, isA<PrologInteger>());
      expect((term as PrologInteger).value, equals(42));
    });

    test('parses float', () {
      final term = Parser.parseTerm('3.14');
      expect(term, isA<PrologFloat>());
      expect((term as PrologFloat).value, equals(3.14));
    });

    test('parses negative integer', () {
      final term = Parser.parseTerm('-5');
      expect(term, isA<Compound>());
      final compound = term as Compound;
      expect(compound.functor, equals(Atom('-')));
      expect(compound.arity, equals(1));
      expect(compound.args[0], isA<PrologInteger>());
      expect((compound.args[0] as PrologInteger).value, equals(5));
    });
  });

  group('Parser - Compound Terms', () {
    test('parses simple compound', () {
      final term = Parser.parseTerm('foo(bar)');
      expect(term, isA<Compound>());
      final compound = term as Compound;
      expect(compound.functor, equals(Atom('foo')));
      expect(compound.arity, equals(1));
      expect(compound.args[0], equals(Atom('bar')));
    });

    test('parses compound with multiple args', () {
      final term = Parser.parseTerm('parent(john, mary)');
      expect(term, isA<Compound>());
      final compound = term as Compound;
      expect(compound.functor, equals(Atom('parent')));
      expect(compound.arity, equals(2));
      expect(compound.args[0], equals(Atom('john')));
      expect(compound.args[1], equals(Atom('mary')));
    });

    test('parses nested compound', () {
      final term = Parser.parseTerm('f(g(x))');
      expect(term, isA<Compound>());
      final outer = term as Compound;
      expect(outer.functor, equals(Atom('f')));
      final inner = outer.args[0] as Compound;
      expect(inner.functor, equals(Atom('g')));
      expect(inner.args[0], equals(Atom('x')));
    });
  });

  group('Parser - Lists', () {
    test('parses empty list', () {
      final term = Parser.parseTerm('[]');
      expect(term, equals(Atom.nil));
    });

    test('parses list with elements', () {
      final term = Parser.parseTerm('[1, 2, 3]');
      expect(term, isA<Compound>());

      // Should be: '.'(1, '.'(2, '.'(3, [])))
      final list = term as Compound;
      expect(list.functor, equals(Atom.dot));
      expect((list.args[0] as PrologInteger).value, equals(1));

      final tail1 = list.args[1] as Compound;
      expect((tail1.args[0] as PrologInteger).value, equals(2));

      final tail2 = tail1.args[1] as Compound;
      expect((tail2.args[0] as PrologInteger).value, equals(3));
      expect(tail2.args[1], equals(Atom.nil));
    });

    test('parses list with tail', () {
      final term = Parser.parseTerm('[H|T]');
      expect(term, isA<Compound>());

      final list = term as Compound;
      expect(list.functor, equals(Atom.dot));
      expect((list.args[0] as Variable).name, equals('H'));
      expect((list.args[1] as Variable).name, equals('T'));
    });

    test('parses list with multiple elements and tail', () {
      final term = Parser.parseTerm('[1, 2|T]');
      expect(term, isA<Compound>());

      final list = term as Compound;
      expect(list.functor, equals(Atom.dot));
      expect((list.args[0] as PrologInteger).value, equals(1));

      final tail1 = list.args[1] as Compound;
      expect((tail1.args[0] as PrologInteger).value, equals(2));
      expect((tail1.args[1] as Variable).name, equals('T'));
    });
  });

  group('Parser - Operators', () {
    test('parses infix operator', () {
      final term = Parser.parseTerm('X = Y');
      expect(term, isA<Compound>());
      final compound = term as Compound;
      expect(compound.functor, equals(Atom('=')));
      expect(compound.arity, equals(2));
      expect((compound.args[0] as Variable).name, equals('X'));
      expect((compound.args[1] as Variable).name, equals('Y'));
    });

    test('parses prefix operator', () {
      final term = Parser.parseTerm('- X');
      expect(term, isA<Compound>());
      final compound = term as Compound;
      expect(compound.functor, equals(Atom('-')));
      expect(compound.arity, equals(1));
      expect((compound.args[0] as Variable).name, equals('X'));
    });

    test('parses operator precedence', () {
      final term = Parser.parseTerm('X + Y * Z');
      expect(term, isA<Compound>());

      // Should parse as: X + (Y * Z)
      final plus = term as Compound;
      expect(plus.functor, equals(Atom('+')));
      expect((plus.args[0] as Variable).name, equals('X'));

      final times = plus.args[1] as Compound;
      expect(times.functor, equals(Atom('*')));
      expect((times.args[0] as Variable).name, equals('Y'));
      expect((times.args[1] as Variable).name, equals('Z'));
    });

    test('parses associativity - left', () {
      final term = Parser.parseTerm('A + B + C');
      expect(term, isA<Compound>());

      // Should parse as: (A + B) + C (left-associative)
      final outer = term as Compound;
      expect(outer.functor, equals(Atom('+')));
      expect((outer.args[1] as Variable).name, equals('C'));

      final inner = outer.args[0] as Compound;
      expect(inner.functor, equals(Atom('+')));
      expect((inner.args[0] as Variable).name, equals('A'));
      expect((inner.args[1] as Variable).name, equals('B'));
    });

    test('parses associativity - right', () {
      // Use comma operator which is xfy (right-associative)
      final term = Parser.parseTerm('(A, B, C)');
      expect(term, isA<Compound>());

      // Should parse as: A, (B, C) (right-associative)
      final outer = term as Compound;
      expect(outer.functor, equals(Atom(',')));
      expect((outer.args[0] as Variable).name, equals('A'));

      final inner = outer.args[1] as Compound;
      expect(inner.functor, equals(Atom(',')));
      expect((inner.args[0] as Variable).name, equals('B'));
      expect((inner.args[1] as Variable).name, equals('C'));
    });

    test('parses parentheses override precedence', () {
      final term = Parser.parseTerm('(X + Y) * Z');
      expect(term, isA<Compound>());

      // Should parse as: (X + Y) * Z
      final times = term as Compound;
      expect(times.functor, equals(Atom('*')));
      expect((times.args[1] as Variable).name, equals('Z'));

      final plus = times.args[0] as Compound;
      expect(plus.functor, equals(Atom('+')));
      expect((plus.args[0] as Variable).name, equals('X'));
      expect((plus.args[1] as Variable).name, equals('Y'));
    });
  });

  group('Parser - Special Syntax', () {
    test('parses curly braces', () {
      final term = Parser.parseTerm('{goal}');
      expect(term, isA<Compound>());
      final compound = term as Compound;
      expect(compound.functor, equals(Atom('{}')));
      expect(compound.arity, equals(1));
      expect(compound.args[0], equals(Atom('goal')));
    });

    test('parses empty curly braces', () {
      final term = Parser.parseTerm('{}');
      expect(term, isA<Atom>());
      expect(term, equals(Atom('{}')));
    });
  });

  group('Parser - Clauses', () {
    test('parses fact', () {
      final clauses = Parser.parse('foo.');
      expect(clauses.length, equals(1));
      expect(clauses[0].isFact, isTrue);
      expect(clauses[0].head, equals(Atom('foo')));
    });

    test('parses rule', () {
      final clauses = Parser.parse('mortal(X) :- human(X).');
      expect(clauses.length, equals(1));
      expect(clauses[0].isRule, isTrue);

      final clause = clauses[0];
      expect(clause.head, isA<Compound>());
      expect((clause.head as Compound).functor, equals(Atom('mortal')));

      expect(clause.body.length, equals(1));
      expect(clause.body[0], isA<Compound>());
      expect((clause.body[0] as Compound).functor, equals(Atom('human')));
    });

    test('parses rule with multiple goals', () {
      final clauses = Parser.parse(
        'grandparent(X, Z) :- parent(X, Y), parent(Y, Z).',
      );
      expect(clauses.length, equals(1));

      final clause = clauses[0];
      expect(clause.isRule, isTrue);
      expect(clause.body.length, equals(2));

      expect((clause.body[0] as Compound).functor, equals(Atom('parent')));
      expect((clause.body[1] as Compound).functor, equals(Atom('parent')));
    });

    test('parses multiple clauses', () {
      final source = '''
        foo(a).
        foo(b).
        bar(X) :- foo(X).
      ''';

      final clauses = Parser.parse(source);
      expect(clauses.length, equals(3));
      expect(clauses[0].isFact, isTrue);
      expect(clauses[1].isFact, isTrue);
      expect(clauses[2].isRule, isTrue);
    });
  });

  group('Parser - Complex Examples', () {
    test('parses arithmetic expression', () {
      final term = Parser.parseTerm('Result is X + Y * 2');
      expect(term, isA<Compound>());
      final is_ = term as Compound;
      expect(is_.functor, equals(Atom('is')));

      final expr = is_.args[1] as Compound;
      expect(expr.functor, equals(Atom('+')));
    });

    test('parses comparison', () {
      final term = Parser.parseTerm('X < Y');
      expect(term, isA<Compound>());
      final lt = term as Compound;
      expect(lt.functor, equals(Atom('<')));
      expect(lt.arity, equals(2));
    });

    test('parses conjunction', () {
      final term = Parser.parseTerm('(a, b, c)');
      expect(term, isA<Compound>());

      // Should parse as: a, (b, c)
      final outer = term as Compound;
      expect(outer.functor, equals(Atom(',')));
      expect(outer.args[0], equals(Atom('a')));

      final inner = outer.args[1] as Compound;
      expect(inner.functor, equals(Atom(',')));
      expect(inner.args[0], equals(Atom('b')));
      expect(inner.args[1], equals(Atom('c')));
    });

    test('parses negation', () {
      final term = Parser.parseTerm(r'\+ goal');
      expect(term, isA<Compound>());
      final neg = term as Compound;
      expect(neg.functor, equals(Atom(r'\+')));
      expect(neg.arity, equals(1));
      expect(neg.args[0], equals(Atom('goal')));
    });
  });

  group('Parser - Strings', () {
    test('parses string as character code list', () {
      final term = Parser.parseTerm('"hi"');
      expect(term, isA<Compound>());

      // Should be: '.'(104, '.'(105, []))
      final list = term as Compound;
      expect(list.functor, equals(Atom.dot));
      expect((list.args[0] as PrologInteger).value, equals(104)); // 'h'

      final tail = list.args[1] as Compound;
      expect((tail.args[0] as PrologInteger).value, equals(105)); // 'i'
      expect(tail.args[1], equals(Atom.nil));
    });
  });

  group('Parser - Variable Identity Regression', () {
    test('variables in different clauses have unique IDs', () {
      // Parse two clauses with same-named variables
      final clauses = Parser.parse('''
        parent(X, Y) :- father(X, Y).
        sibling(A, B) :- parent(P, A), parent(P, B).
      ''');

      expect(clauses.length, equals(2));

      // Extract variables from first clause
      final clause1 = clauses[0];
      final clause1Head = clause1.head as Compound;
      final xFromClause1 = clause1Head.args[0] as Variable;
      final yFromClause1 = clause1Head.args[1] as Variable;

      // Extract variables from second clause
      final clause2 = clauses[1];
      final clause2Head = clause2.head as Compound;
      final aFromClause2 = clause2Head.args[0] as Variable;
      final bFromClause2 = clause2Head.args[1] as Variable;

      // Verify all variables have unique IDs
      final ids = {
        xFromClause1.id,
        yFromClause1.id,
        aFromClause2.id,
        bFromClause2.id,
      };
      expect(
        ids.length,
        equals(4),
        reason: 'All variables from different clauses must have unique IDs',
      );

      // Also verify the variables are not equal
      expect(xFromClause1, isNot(equals(aFromClause2)));
      expect(yFromClause1, isNot(equals(bFromClause2)));
    });

    test('same-named variables within a clause share identity', () {
      // Parse a clause where same variable appears multiple times
      final clauses = Parser.parse('foo(X, Y, X).');

      final clause = clauses[0];
      final head = clause.head as Compound;
      final firstX = head.args[0] as Variable;
      final y = head.args[1] as Variable;
      final secondX = head.args[2] as Variable;

      // Within same clause, same-named variables should be identical
      expect(
        identical(firstX, secondX),
        isTrue,
        reason: 'Same variable name in clause should produce same object',
      );
      expect(firstX.id, equals(secondX.id));

      // Different variable names should have different IDs
      expect(firstX.id, isNot(equals(y.id)));
    });
  });
}
