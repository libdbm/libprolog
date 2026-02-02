import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('Highlighter', () {
    test('highlights atoms in cyan', () {
      final result = Highlighter.highlight('foo');
      expect(result, contains(AnsiColors.cyan));
      expect(result, contains('foo'));
      expect(result, contains(AnsiColors.reset));
    });

    test('highlights variables in yellow', () {
      final result = Highlighter.highlight('X');
      expect(result, contains(AnsiColors.yellow));
      expect(result, contains('X'));
      expect(result, contains(AnsiColors.reset));
    });

    test('highlights integers in magenta', () {
      final result = Highlighter.highlight('42');
      expect(result, contains(AnsiColors.magenta));
      expect(result, contains('42'));
      expect(result, contains(AnsiColors.reset));
    });

    test('highlights floats in magenta', () {
      final result = Highlighter.highlight('3.14');
      expect(result, contains(AnsiColors.magenta));
      expect(result, contains('3.14'));
      expect(result, contains(AnsiColors.reset));
    });

    test('highlights strings in green', () {
      final result = Highlighter.highlight('"hello"');
      expect(result, contains(AnsiColors.green));
      expect(result, contains('"hello"'));
      expect(result, contains(AnsiColors.reset));
    });

    test('highlights compound term', () {
      final result = Highlighter.highlight('parent(tom, mary)');
      // Should have cyan for atoms
      expect(result, contains(AnsiColors.cyan));
      expect(result, contains('parent'));
      expect(result, contains('tom'));
      expect(result, contains('mary'));
    });

    test('highlights term with variable', () {
      final result = Highlighter.highlight('parent(X, mary)');
      expect(result, contains(AnsiColors.yellow)); // Variable
      expect(result, contains(AnsiColors.cyan)); // Atoms
      expect(result, contains('X'));
      expect(result, contains('mary'));
    });

    test('highlights line comments in gray', () {
      final result = Highlighter.highlight('foo % this is a comment');
      expect(result, contains(AnsiColors.gray));
      expect(result, contains('% this is a comment'));
    });

    test('returns empty string unchanged', () {
      expect(Highlighter.highlight(''), equals(''));
    });

    test('handles partial/incomplete input gracefully', () {
      // Incomplete string
      final result = Highlighter.highlight('"unclosed');
      expect(result, contains('"unclosed'));
    });

    test('strip removes ANSI codes', () {
      final colored = Highlighter.highlight('foo');
      final stripped = Highlighter.strip(colored);
      expect(stripped, equals('foo'));
    });

    test('displayLength returns correct length', () {
      final colored = Highlighter.highlight('foo');
      expect(Highlighter.displayLength(colored), equals(3));
    });

    test('error helper colors red', () {
      final result = Highlighter.error('test error');
      expect(result, contains(AnsiColors.red));
      expect(result, contains('test error'));
      expect(result, contains(AnsiColors.reset));
    });

    test('success helper colors green', () {
      final result = Highlighter.success('true');
      expect(result, contains(AnsiColors.green));
      expect(result, contains('true'));
      expect(result, contains(AnsiColors.reset));
    });

    test('variable helper colors yellow', () {
      final result = Highlighter.variable('X');
      expect(result, contains(AnsiColors.yellow));
      expect(result, contains('X'));
      expect(result, contains(AnsiColors.reset));
    });

    test('atom helper colors cyan', () {
      final result = Highlighter.atom('foo');
      expect(result, contains(AnsiColors.cyan));
      expect(result, contains('foo'));
      expect(result, contains(AnsiColors.reset));
    });

    test('number helper colors magenta', () {
      final result = Highlighter.number('42');
      expect(result, contains(AnsiColors.magenta));
      expect(result, contains('42'));
      expect(result, contains(AnsiColors.reset));
    });

    test('highlights rule with body', () {
      final result = Highlighter.highlight(
        'grandparent(X, Z) :- parent(X, Y), parent(Y, Z)',
      );
      expect(result, contains(AnsiColors.yellow)); // Variables
      expect(result, contains(AnsiColors.cyan)); // Atoms
      expect(result, contains('grandparent'));
      expect(result, contains('parent'));
    });

    test('highlights list', () {
      final result = Highlighter.highlight('[1, 2, 3]');
      expect(result, contains(AnsiColors.magenta)); // Numbers
      expect(result, contains('1'));
      expect(result, contains('2'));
      expect(result, contains('3'));
    });

    test('highlights arithmetic expression', () {
      final result = Highlighter.highlight('X is 2 + 3');
      expect(result, contains(AnsiColors.yellow)); // X
      expect(result, contains(AnsiColors.magenta)); // 2, 3
      expect(result, contains(AnsiColors.cyan)); // is
    });
  });

  group('AnsiColors', () {
    test('reset code is correct', () {
      expect(AnsiColors.reset, equals('\x1b[0m'));
    });

    test('cyan code is correct', () {
      expect(AnsiColors.cyan, equals('\x1b[36m'));
    });

    test('yellow code is correct', () {
      expect(AnsiColors.yellow, equals('\x1b[33m'));
    });

    test('magenta code is correct', () {
      expect(AnsiColors.magenta, equals('\x1b[35m'));
    });

    test('green code is correct', () {
      expect(AnsiColors.green, equals('\x1b[32m'));
    });

    test('red code is correct', () {
      expect(AnsiColors.red, equals('\x1b[31m'));
    });

    test('gray code is correct', () {
      expect(AnsiColors.gray, equals('\x1b[90m'));
    });
  });
}
