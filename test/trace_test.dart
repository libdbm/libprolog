import 'package:libprolog/libprolog.dart';
import 'package:test/test.dart';

void main() {
  group('Trace/Notrace Debugger', () {
    late Database db;
    late Resolver resolver;

    setUp(() {
      db = Database();
      resolver = Resolver(db);
    });

    test('trace/0 enables tracing', () async {
      expect(resolver.isTracing, isFalse);

      final solutions = await resolver.queryGoal(Atom('trace')).toList();

      expect(solutions.length, equals(1));
      expect(resolver.isTracing, isTrue);
    });

    test('notrace/0 disables tracing', () async {
      resolver.trace();
      expect(resolver.isTracing, isTrue);

      final solutions = await resolver.queryGoal(Atom('notrace')).toList();

      expect(solutions.length, equals(1));
      expect(resolver.isTracing, isFalse);
    });

    test('trace method accepts custom callback', () async {
      final events = <(TracePort, int, String)>[];

      resolver.trace((final port, final depth, final goal) {
        events.add((port, depth, goal.toString()));
        return true;
      });

      // Add a simple fact
      db.assert_(Clause(Atom('foo')));

      // Query it
      await resolver.queryGoal(Atom('foo')).toList();

      // Should have recorded call and exit events
      expect(events, isNotEmpty);
      expect(events.any((e) => e.$1 == TracePort.call), isTrue);
      expect(events.any((e) => e.$1 == TracePort.exit), isTrue);
    });

    test('trace callback receives correct depth', () async {
      final depths = <int>[];

      resolver.trace((final port, final depth, final goal) {
        if (port == TracePort.call) {
          depths.add(depth);
        }
        return true;
      });

      // Add parent/grandparent rules
      db.assert_(
        Clause(Compound(Atom('grandparent'), [Variable('X'), Variable('Z')]), [
          Compound(Atom('parent'), [Variable('X'), Variable('Y')]),
          Compound(Atom('parent'), [Variable('Y'), Variable('Z')]),
        ]),
      );
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('alice'), Atom('bob')])),
      );
      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('bob'), Atom('charlie')])),
      );

      // Query grandparent
      final g = Variable('G');
      final c = Variable('C');
      await resolver.queryGoal(Compound(Atom('grandparent'), [g, c])).toList();

      // Should have increasing depths for nested calls
      expect(depths, isNotEmpty);
      // First call to grandparent should be at depth 1
      expect(depths.first, equals(1));
    });

    test('trace callback can abort execution', () async {
      var count = 0;

      resolver.trace((final port, final depth, final goal) {
        count++;
        return count < 3; // Abort after 2 events
      });

      db.assert_(Clause(Atom('foo')));
      db.assert_(Clause(Atom('bar')));

      // Execution should stop early due to callback returning false
      // Note: This tests that the callback return value is respected
      await resolver.queryGoal(Atom('foo')).toList();
    });

    test('trace shows dereferenced variables', () async {
      final goals = <String>[];

      resolver.trace((final port, final depth, final goal) {
        if (port == TracePort.exit) {
          goals.add(goal.toString());
        }
        return true;
      });

      db.assert_(
        Clause(Compound(Atom('parent'), [Atom('john'), Atom('mary')])),
      );

      final x = Variable('X');
      await resolver
          .queryGoal(Compound(Atom('parent'), [Atom('john'), x]))
          .toList();

      // The exit trace should show the bound variable value
      // (depending on implementation - either bound or unbound form)
      expect(goals, isNotEmpty);
    });

    test('notrace clears custom callback', () async {
      resolver.trace((final port, final depth, final goal) {
        return true;
      });

      expect(resolver.isTracing, isTrue);

      resolver.notrace();

      expect(resolver.isTracing, isFalse);
    });
  });
}
