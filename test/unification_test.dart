import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Substitution', () {
    test('empty substitution', () {
      final subst = Substitution();
      expect(subst.isEmpty, isTrue);
      expect(subst.size, equals(0));
    });

    test('bind and lookup', () {
      final subst = Substitution();
      final x = Variable('X');
      final a = Atom('hello');

      subst.bind(x, a);

      expect(subst.isBound(x), isTrue);
      expect(subst.lookup(x), equals(a));
      expect(subst.size, equals(1));
    });

    test('unbind', () {
      final subst = Substitution();
      final x = Variable('X');
      final a = Atom('hello');

      subst.bind(x, a);
      expect(subst.isBound(x), isTrue);

      subst.unbind(x);
      expect(subst.isBound(x), isFalse);
      expect(subst.isEmpty, isTrue);
    });

    test('deref follows variable chain', () {
      final subst = Substitution();
      final x = Variable('X');
      final y = Variable('Y');
      final z = Variable('Z');
      final a = Atom('hello');

      subst.bind(x, y);
      subst.bind(y, z);
      subst.bind(z, a);

      expect(subst.deref(x), equals(a));
      expect(subst.deref(y), equals(a));
      expect(subst.deref(z), equals(a));
      expect(subst.deref(a), equals(a));
    });

    test('deref on unbound variable', () {
      final subst = Substitution();
      final x = Variable('X');

      expect(subst.deref(x), equals(x));
    });

    test('apply substitution to compound', () {
      final subst = Substitution();
      final x = Variable('X');
      final y = Variable('Y');
      final a = Atom('a');
      final b = Atom('b');

      subst.bind(x, a);
      subst.bind(y, b);

      final compound = Compound(Atom('foo'), [x, y]);
      final result = subst.apply(compound);

      expect(result, isA<Compound>());
      final resultCompound = result as Compound;
      expect(resultCompound.args[0], equals(a));
      expect(resultCompound.args[1], equals(b));
    });

    test('copy creates independent copy', () {
      final subst1 = Substitution();
      final x = Variable('X');
      final a = Atom('hello');

      subst1.bind(x, a);
      final subst2 = subst1.copy();

      expect(subst2.isBound(x), isTrue);
      expect(subst2.lookup(x), equals(a));

      subst1.unbind(x);
      expect(subst1.isBound(x), isFalse);
      expect(subst2.isBound(x), isTrue);
    });
  });

  group('Trail', () {
    test('empty trail', () {
      final trail = Trail();
      expect(trail.isEmpty, isTrue);
      expect(trail.size, equals(0));
      expect(trail.markerCount, equals(0));
    });

    test('record variable', () {
      final trail = Trail();
      final x = Variable('X');

      trail.record(x);

      expect(trail.isEmpty, isFalse);
      expect(trail.size, equals(1));
    });

    test('mark and undo', () {
      final subst = Substitution();
      final trail = Trail();
      final x = Variable('X');
      final a = Atom('hello');

      trail.mark();
      subst.bind(x, a);
      trail.record(x);

      expect(subst.isBound(x), isTrue);

      trail.undo(subst);

      expect(subst.isBound(x), isFalse);
      expect(trail.size, equals(0));
    });

    test('multiple markers', () {
      final subst = Substitution();
      final trail = Trail();
      final x = Variable('X');
      final y = Variable('Y');
      final z = Variable('Z');
      final a = Atom('a');
      final b = Atom('b');
      final c = Atom('c');

      // First choice point
      trail.mark();
      subst.bind(x, a);
      trail.record(x);

      // Second choice point
      trail.mark();
      subst.bind(y, b);
      trail.record(y);

      // Third choice point
      trail.mark();
      subst.bind(z, c);
      trail.record(z);

      expect(trail.markerCount, equals(3));
      expect(subst.size, equals(3));

      // Undo last choice point
      trail.undo(subst);
      expect(subst.isBound(z), isFalse);
      expect(subst.isBound(y), isTrue);
      expect(subst.isBound(x), isTrue);

      // Undo second choice point
      trail.undo(subst);
      expect(subst.isBound(y), isFalse);
      expect(subst.isBound(x), isTrue);
    });

    test('commit removes marker without undoing', () {
      final subst = Substitution();
      final trail = Trail();
      final x = Variable('X');
      final a = Atom('hello');

      trail.mark();
      subst.bind(x, a);
      trail.record(x);

      expect(trail.markerCount, equals(1));

      trail.commit();

      expect(trail.markerCount, equals(0));
      expect(subst.isBound(x), isTrue); // Binding still there
    });

    test('reset clears everything', () {
      final trail = Trail();
      final x = Variable('X');
      final y = Variable('Y');

      trail.mark();
      trail.record(x);
      trail.mark();
      trail.record(y);

      trail.reset();

      expect(trail.isEmpty, isTrue);
      expect(trail.markerCount, equals(0));
    });
  });

  group('Unify', () {
    late Substitution subst;
    late Trail trail;

    setUp(() {
      subst = Substitution();
      trail = Trail();
    });

    test('unify identical terms', () {
      final a = Atom('foo');
      expect(Unify.unify(a, a, subst, trail), isTrue);
    });

    test('unify variable with atom', () {
      final x = Variable('X');
      final a = Atom('foo');

      expect(Unify.unify(x, a, subst, trail), isTrue);
      expect(subst.deref(x), equals(a));
    });

    test('unify two variables', () {
      final x = Variable('X');
      final y = Variable('Y');

      expect(Unify.unify(x, y, subst, trail), isTrue);
      expect(subst.isBound(x), isTrue);
    });

    test('unify atoms - success', () {
      final a1 = Atom('foo');
      final a2 = Atom('foo');

      expect(Unify.unify(a1, a2, subst, trail), isTrue);
    });

    test('unify atoms - failure', () {
      final a1 = Atom('foo');
      final a2 = Atom('bar');

      expect(Unify.unify(a1, a2, subst, trail), isFalse);
    });

    test('unify numbers - success', () {
      final n1 = PrologInteger(42);
      final n2 = PrologInteger(42);

      expect(Unify.unify(n1, n2, subst, trail), isTrue);
    });

    test('unify numbers - failure', () {
      final n1 = PrologInteger(42);
      final n2 = PrologInteger(17);

      expect(Unify.unify(n1, n2, subst, trail), isFalse);
    });

    test('unify compound terms - success', () {
      final x = Variable('X');
      final c1 = Compound(Atom('foo'), [Atom('a'), x]);
      final c2 = Compound(Atom('foo'), [Atom('a'), Atom('b')]);

      expect(Unify.unify(c1, c2, subst, trail), isTrue);
      expect(subst.deref(x), equals(Atom('b')));
    });

    test('unify compound terms - different functor', () {
      final c1 = Compound(Atom('foo'), [Atom('a')]);
      final c2 = Compound(Atom('bar'), [Atom('a')]);

      expect(Unify.unify(c1, c2, subst, trail), isFalse);
    });

    test('unify compound terms - different arity', () {
      final c1 = Compound(Atom('foo'), [Atom('a')]);
      final c2 = Compound(Atom('foo'), [Atom('a'), Atom('b')]);

      expect(Unify.unify(c1, c2, subst, trail), isFalse);
    });

    test('occur check prevents infinite structure', () {
      final x = Variable('X');
      final c = Compound(Atom('f'), [x]);

      // X = f(X) should fail with occur check
      expect(Unify.unify(x, c, subst, trail), isFalse);
    });

    test('occur check in nested structure', () {
      final x = Variable('X');
      final y = Variable('Y');

      subst.bind(y, Compound(Atom('f'), [x]));
      trail.record(y);

      // X = Y where Y = f(X), so X = f(X) should fail
      expect(Unify.unify(x, y, subst, trail), isFalse);
    });

    test('unify lists', () {
      final x = Variable('X');
      final y = Variable('Y');

      final list1 = Compound.fromList([Atom('a'), x, Atom('c')]);
      final list2 = Compound.fromList([y, Atom('b'), Atom('c')]);

      expect(Unify.unify(list1, list2, subst, trail), isTrue);
      expect(subst.deref(x), equals(Atom('b')));
      expect(subst.deref(y), equals(Atom('a')));
    });

    test('unify with variable chain', () {
      final x = Variable('X');
      final y = Variable('Y');
      final z = Variable('Z');

      // First unify X = Y
      expect(Unify.unify(x, y, subst, trail), isTrue);

      // Then unify Y = Z
      expect(Unify.unify(y, z, subst, trail), isTrue);

      // Finally unify Z = hello
      expect(Unify.unify(z, Atom('hello'), subst, trail), isTrue);

      // All should deref to hello
      expect(subst.deref(x), equals(Atom('hello')));
      expect(subst.deref(y), equals(Atom('hello')));
      expect(subst.deref(z), equals(Atom('hello')));
    });

    test('backtracking with trail', () {
      final x = Variable('X');
      final y = Variable('Y');

      // First attempt
      trail.mark();
      Unify.unify(x, Atom('a'), subst, trail);
      Unify.unify(y, Atom('b'), subst, trail);

      expect(subst.size, equals(2));

      // Backtrack
      trail.undo(subst);

      expect(subst.size, equals(0));
      expect(subst.isBound(x), isFalse);
      expect(subst.isBound(y), isFalse);
    });
  });
}
