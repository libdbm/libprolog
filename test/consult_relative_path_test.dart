import 'dart:io';

import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('consult with relative paths', () {
    late PrologEngine engine;

    setUp(() {
      engine = PrologEngine();
    });

    test('consult with relative path from project root', () async {
      // Load example/family.pl using relative path from current directory
      final result = await engine.queryOnce("consult('example/family.pl')");
      expect(
        result.success,
        isTrue,
        reason: 'Should successfully load example/family.pl',
      );

      // Verify that a predicate from family.pl was loaded
      final query = await engine.queryOnce('parent(john, david)');
      expect(
        query.success,
        isTrue,
        reason: 'Should have loaded parent(john, david) fact',
      );
    });

    test('consult with simple filename when file exists', () async {
      // Create a test file in the current directory
      final testFile = File('test_consult.pl');
      testFile.writeAsStringSync('test_fact(hello).\n');

      try {
        // Load using simple filename
        final result = await engine.queryOnce("consult('test_consult.pl')");
        expect(
          result.success,
          isTrue,
          reason: 'Should successfully load test_consult.pl',
        );

        // Verify the fact was loaded
        final query = await engine.queryOnce('test_fact(hello)');
        expect(
          query.success,
          isTrue,
          reason: 'Should have loaded test_fact(hello)',
        );
      } finally {
        // Clean up
        if (testFile.existsSync()) {
          testFile.deleteSync();
        }
      }
    });

    test('consult with nested relative path', () async {
      // This should fail since the file doesn't exist, but shouldn't crash
      final result = await engine.queryOnce("consult('nonexistent/file.pl')");
      expect(
        result.success,
        isFalse,
        reason: 'Should fail for non-existent file',
      );
    });
  });
}
