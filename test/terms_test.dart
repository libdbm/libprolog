import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Variable', () {
    test('creates unique IDs', () {
      final x = Variable('X');
      final y = Variable('Y');
      expect(x.id, isNot(equals(y.id)));
    });

    test('equality based on ID', () {
      final x1 = Variable('X');
      final x2 = Variable('X');
      expect(x1, isNot(equals(x2))); // Different IDs
      expect(x1, equals(x1)); // Same instance
    });

    test('generates default names', () {
      final v = Variable();
      expect(v.name, startsWith('_G'));
    });

    test('isVariable returns true', () {
      final v = Variable('X');
      expect(v.isVariable, isTrue);
      expect(v.isAtom, isFalse);
      expect(v.isNumber, isFalse);
      expect(v.isCompound, isFalse);
    });
  });

  group('Atom', () {
    test('atoms are interned', () {
      final a1 = Atom('foo');
      final a2 = Atom('foo');
      expect(identical(a1, a2), isTrue);
    });

    test('equality', () {
      final a1 = Atom('foo');
      final a2 = Atom('foo');
      final a3 = Atom('bar');
      expect(a1, equals(a2));
      expect(a1, isNot(equals(a3)));
    });

    test('nil constant', () {
      final nil = Atom.nil;
      expect(nil.value, equals('[]'));
      expect(nil.isNil, isTrue);
      expect(nil.isList, isTrue);
    });

    test('isAtom returns true', () {
      final a = Atom('test');
      expect(a.isAtom, isTrue);
      expect(a.isVariable, isFalse);
      expect(a.isNumber, isFalse);
      expect(a.isCompound, isFalse);
      expect(a.isAtomic, isTrue);
      expect(a.isCallable, isTrue);
    });

    test('toString handles quoting', () {
      expect(Atom('foo').toString(), equals('foo'));
      expect(Atom('[]').toString(), equals('[]'));
      expect(Atom('hello world').toString(), equals("'hello world'"));
    });
  });

  group('Number', () {
    test('PrologInteger creation', () {
      final n = PrologInteger(42);
      expect(n.value, equals(42));
      expect(n.intValue, equals(42));
      expect(n.floatValue, equals(42.0));
    });

    test('PrologFloat creation', () {
      final n = PrologFloat(3.14);
      expect(n.value, equals(3.14));
      expect(n.floatValue, equals(3.14));
      expect(n.intValue, equals(3));
    });

    test('integer equality', () {
      expect(PrologInteger(42), equals(PrologInteger(42)));
      expect(PrologInteger(42), isNot(equals(PrologInteger(17))));
    });

    test('float equality', () {
      expect(PrologFloat(3.14), equals(PrologFloat(3.14)));
      expect(PrologFloat(3.14), isNot(equals(PrologFloat(2.71))));
    });

    test('type predicates', () {
      final int = PrologInteger(42);
      final float = PrologFloat(3.14);

      expect(int.isNumber, isTrue);
      expect(int.isInteger, isTrue);
      expect(int.isFloat, isFalse);
      expect(int.isAtomic, isTrue);

      expect(float.isNumber, isTrue);
      expect(float.isFloat, isTrue);
      expect(float.isInteger, isFalse);
      expect(float.isAtomic, isTrue);
    });
  });

  group('Compound', () {
    test('creates compound term', () {
      final c = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      expect(c.functor.value, equals('foo'));
      expect(c.arity, equals(2));
      expect(c.indicator, equals('foo/2'));
    });

    test('rejects zero-arity compound', () {
      expect(() => Compound(Atom('foo'), []), throwsArgumentError);
    });

    test('equality', () {
      final c1 = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final c2 = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      final c3 = Compound(Atom('bar'), [Atom('a'), Atom('b')]);
      final c4 = Compound(Atom('foo'), [Atom('a'), Atom('c')]);

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
      expect(c1, isNot(equals(c4)));
    });

    test('isCompound returns true', () {
      final c = Compound(Atom('foo'), [Atom('a')]);
      expect(c.isCompound, isTrue);
      expect(c.isVariable, isFalse);
      expect(c.isAtom, isFalse);
      expect(c.isNumber, isFalse);
      expect(c.isCallable, isTrue);
    });

    test('toString for regular compound', () {
      final c = Compound(Atom('foo'), [Atom('a'), Atom('b')]);
      expect(c.toString(), equals('foo(a, b)'));
    });
  });

  group('List', () {
    test('fromList creates proper list', () {
      final list = Compound.fromList([Atom('a'), Atom('b'), Atom('c')]);

      expect(list, isA<Compound>());
      expect(list.isList, isTrue);
    });

    test('fromList with empty list', () {
      final list = Compound.fromList([]);
      expect(list, equals(Atom.nil));
    });

    test('toList converts proper list', () {
      final list = Compound.fromList([Atom('a'), Atom('b'), Atom('c')]);
      final elements = Compound.toList(list);

      expect(elements, isNotNull);
      expect(elements!.length, equals(3));
      expect(elements[0], equals(Atom('a')));
      expect(elements[1], equals(Atom('b')));
      expect(elements[2], equals(Atom('c')));
    });

    test('toList on nil', () {
      final elements = Compound.toList(Atom.nil);
      expect(elements, isNotNull);
      expect(elements!.length, equals(0));
    });

    test('toList on improper list returns null', () {
      final improper = Compound(Atom.dot, [Atom('a'), Atom('b')]);
      expect(Compound.toList(improper), isNull);
    });

    test('list toString', () {
      final list = Compound.fromList([Atom('a'), Atom('b')]);
      expect(list.toString(), equals('[a, b]'));
    });

    test('improper list toString', () {
      final x = Variable('X');
      final improper = Compound(Atom.dot, [Atom('a'), x]);
      expect(improper.toString(), equals('[a | X]'));
    });

    test('isList predicate', () {
      final proper = Compound.fromList([Atom('a'), Atom('b')]);
      final improper = Compound(Atom.dot, [Atom('a'), Atom('b')]);

      expect(proper.isList, isTrue);
      expect(improper.isList, isFalse);
      expect(Atom.nil.isList, isTrue);
    });
  });
}
