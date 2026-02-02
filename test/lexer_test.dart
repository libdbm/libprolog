import 'package:libprolog/src/parser/lexer.dart';
import 'package:libprolog/src/parser/token.dart';
import 'package:test/test.dart';

void main() {
  group('Lexer - Atoms', () {
    test('scans unquoted atom', () {
      final lexer = Lexer('hello');
      final tokens = lexer.scanTokens();

      expect(tokens.length, equals(2)); // atom + EOF
      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[0].value, equals('hello'));
    });

    test('scans atom with underscores', () {
      final lexer = Lexer('hello_world');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[0].value, equals('hello_world'));
    });

    test('scans quoted atom', () {
      final lexer = Lexer("'Hello World'");
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[0].value, equals('Hello World'));
    });

    test('scans quoted atom with escapes', () {
      final lexer = Lexer(r"'line1\nline2'");
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[0].value, equals('line1\nline2'));
    });

    test('scans symbolic atoms', () {
      final operators = ['+', '-', '*', '/', '=', '<', '>', ':-', '=..'];
      for (final op in operators) {
        final lexer = Lexer(op);
        final tokens = lexer.scanTokens();

        expect(tokens[0].type, equals(TokenType.atom));
        expect(tokens[0].value, equals(op));
      }
    });

    test('scans solo character atoms', () {
      final lexer = Lexer('! ;');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[0].value, equals('!'));
      expect(tokens[1].type, equals(TokenType.atom));
      expect(tokens[1].value, equals(';'));
    });
  });

  group('Lexer - Variables', () {
    test('scans variable starting with uppercase', () {
      final lexer = Lexer('X');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.variable));
      expect(tokens[0].value, equals('X'));
    });

    test('scans variable starting with underscore', () {
      final lexer = Lexer('_result');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.variable));
      expect(tokens[0].value, equals('_result'));
    });

    test('scans anonymous variable', () {
      final lexer = Lexer('_');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.variable));
      expect(tokens[0].value, equals('_'));
    });

    test('scans variable with mixed case', () {
      final lexer = Lexer('MyVariable');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.variable));
      expect(tokens[0].value, equals('MyVariable'));
    });
  });

  group('Lexer - Numbers', () {
    test('scans integer', () {
      final lexer = Lexer('42');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(42));
    });

    test('scans float with decimal', () {
      final lexer = Lexer('3.14');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.float));
      expect(tokens[0].value, equals(3.14));
    });

    test('scans float with exponent', () {
      final lexer = Lexer('1.5e10');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.float));
      expect(tokens[0].value, equals(1.5e10));
    });

    test('scans float with negative exponent', () {
      final lexer = Lexer('2.5e-3');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.float));
      expect(tokens[0].value, equals(2.5e-3));
    });

    test('scans hexadecimal number', () {
      final lexer = Lexer('0x1F');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(31));
    });

    test('scans octal number', () {
      final lexer = Lexer('0o77');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(63));
    });

    test('scans binary number', () {
      final lexer = Lexer('0b1010');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(10));
    });

    test('scans base notation number', () {
      final lexer = Lexer("2'101");
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(5));
    });

    test('scans character code', () {
      final lexer = Lexer("0'A");
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(65));
    });

    test('scans number with digit separators', () {
      final lexer = Lexer('1_000_000');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.integer));
      expect(tokens[0].value, equals(1000000));
    });
  });

  group('Lexer - Strings', () {
    test('scans simple string', () {
      final lexer = Lexer('"hello"');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.string));
      expect(tokens[0].value, equals('hello'));
    });

    test('scans string with escapes', () {
      final lexer = Lexer(r'"line1\nline2\ttab"');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.string));
      expect(tokens[0].value, equals('line1\nline2\ttab'));
    });

    test('scans string with hex escape', () {
      final lexer = Lexer(r'"\x41"');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.string));
      expect(tokens[0].value, equals('A'));
    });

    test('scans string with unicode escape', () {
      final lexer = Lexer(r'"\u0041"');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.string));
      expect(tokens[0].value, equals('A'));
    });
  });

  group('Lexer - Punctuation', () {
    test('scans parentheses', () {
      final lexer = Lexer('()');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.leftParen));
      expect(tokens[1].type, equals(TokenType.rightParen));
    });

    test('scans brackets', () {
      final lexer = Lexer('[]');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.leftBracket));
      expect(tokens[1].type, equals(TokenType.rightBracket));
    });

    test('scans braces', () {
      final lexer = Lexer('{}');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.leftBrace));
      expect(tokens[1].type, equals(TokenType.rightBrace));
    });

    test('scans pipe', () {
      final lexer = Lexer('|');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.pipe));
    });

    test('scans comma', () {
      final lexer = Lexer(',');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.comma));
    });

    test('scans dot as end-of-clause', () {
      final lexer = Lexer('fact.');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[1].type, equals(TokenType.dot));
    });
  });

  group('Lexer - Comments', () {
    test('skips line comment', () {
      final lexer = Lexer('atom % comment\nVar');
      final tokens = lexer.scanTokens();

      expect(tokens.length, equals(3)); // atom, Var, EOF
      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[1].type, equals(TokenType.variable));
    });

    test('skips block comment', () {
      final lexer = Lexer('atom /* comment */ Var');
      final tokens = lexer.scanTokens();

      expect(tokens.length, equals(3)); // atom, Var, EOF
      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[1].type, equals(TokenType.variable));
    });

    test('skips nested block comments', () {
      final lexer = Lexer('atom /* outer /* inner */ outer */ Var');
      final tokens = lexer.scanTokens();

      expect(tokens.length, equals(3)); // atom, Var, EOF
      expect(tokens[0].type, equals(TokenType.atom));
      expect(tokens[1].type, equals(TokenType.variable));
    });
  });

  group('Lexer - Complex Expressions', () {
    test('scans compound term', () {
      final lexer = Lexer('parent(john, mary)');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom)); // parent
      expect(tokens[1].type, equals(TokenType.leftParen));
      expect(tokens[2].type, equals(TokenType.atom)); // john
      expect(tokens[3].type, equals(TokenType.comma));
      expect(tokens[4].type, equals(TokenType.atom)); // mary
      expect(tokens[5].type, equals(TokenType.rightParen));
    });

    test('scans list', () {
      final lexer = Lexer('[1, 2, 3]');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.leftBracket));
      expect(tokens[1].type, equals(TokenType.integer));
      expect(tokens[2].type, equals(TokenType.comma));
      expect(tokens[3].type, equals(TokenType.integer));
      expect(tokens[4].type, equals(TokenType.comma));
      expect(tokens[5].type, equals(TokenType.integer));
      expect(tokens[6].type, equals(TokenType.rightBracket));
    });

    test('scans list with tail', () {
      final lexer = Lexer('[H|T]');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.leftBracket));
      expect(tokens[1].type, equals(TokenType.variable)); // H
      expect(tokens[2].type, equals(TokenType.pipe));
      expect(tokens[3].type, equals(TokenType.variable)); // T
      expect(tokens[4].type, equals(TokenType.rightBracket));
    });

    test('scans clause', () {
      final lexer = Lexer('mortal(X) :- human(X).');
      final tokens = lexer.scanTokens();

      expect(tokens[0].type, equals(TokenType.atom)); // mortal
      expect(tokens[1].type, equals(TokenType.leftParen));
      expect(tokens[2].type, equals(TokenType.variable)); // X
      expect(tokens[3].type, equals(TokenType.rightParen));
      expect(tokens[4].type, equals(TokenType.atom)); // :-
      expect(tokens[5].type, equals(TokenType.atom)); // human
      expect(tokens[6].type, equals(TokenType.leftParen));
      expect(tokens[7].type, equals(TokenType.variable)); // X
      expect(tokens[8].type, equals(TokenType.rightParen));
      expect(tokens[9].type, equals(TokenType.dot));
    });
  });

  group('Lexer - Whitespace', () {
    test('handles spaces', () {
      final lexer = Lexer('a   b');
      final tokens = lexer.scanTokens();

      expect(tokens.length, equals(3)); // a, b, EOF
    });

    test('handles tabs and newlines', () {
      final lexer = Lexer('a\t\nb');
      final tokens = lexer.scanTokens();

      expect(tokens.length, equals(3)); // a, b, EOF
    });

    test('tracks line numbers', () {
      final lexer = Lexer('a\nb\nc');
      final tokens = lexer.scanTokens();

      expect(tokens[0].line, equals(1));
      expect(tokens[1].line, equals(2));
      expect(tokens[2].line, equals(3));
    });
  });

  group('Lexer - Errors', () {
    test('throws on unterminated string', () {
      final lexer = Lexer('"hello');
      expect(() => lexer.scanTokens(), throwsA(isA<LexerError>()));
    });

    test('throws on unterminated quoted atom', () {
      final lexer = Lexer("'hello");
      expect(() => lexer.scanTokens(), throwsA(isA<LexerError>()));
    });

    test('throws on unterminated block comment', () {
      final lexer = Lexer('/* comment');
      expect(() => lexer.scanTokens(), throwsA(isA<LexerError>()));
    });

    test('throws on invalid base', () {
      final lexer = Lexer("40'123");
      expect(() => lexer.scanTokens(), throwsA(isA<LexerError>()));
    });

    test('throws on invalid escape', () {
      final lexer = Lexer(r'"\q"');
      expect(() => lexer.scanTokens(), throwsA(isA<LexerError>()));
    });
  });
}
