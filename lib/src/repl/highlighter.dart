/// Syntax highlighter for Prolog code using ANSI color codes.
library;

import '../parser/lexer.dart';
import '../parser/token.dart';

/// ANSI color codes for syntax highlighting.
class AnsiColors {
  static const reset = '\x1b[0m';
  static const cyan = '\x1b[36m';
  static const yellow = '\x1b[33m';
  static const magenta = '\x1b[35m';
  static const green = '\x1b[32m';
  static const red = '\x1b[31m';
  static const gray = '\x1b[90m';
  static const white = '\x1b[37m';
  static const bold = '\x1b[1m';
}

/// Syntax highlighter for Prolog code.
///
/// Uses the lexer to tokenize input and wraps tokens with ANSI color codes.
/// Handles partial/incomplete input gracefully for use during editing.
class Highlighter {
  /// Returns the color code for a token type.
  static String colorFor(final TokenType type) {
    return switch (type) {
      TokenType.atom => AnsiColors.cyan,
      TokenType.variable => AnsiColors.yellow,
      TokenType.integer => AnsiColors.magenta,
      TokenType.float => AnsiColors.magenta,
      TokenType.string => AnsiColors.green,
      TokenType.leftParen => AnsiColors.white,
      TokenType.rightParen => AnsiColors.white,
      TokenType.leftBracket => AnsiColors.white,
      TokenType.rightBracket => AnsiColors.white,
      TokenType.leftBrace => AnsiColors.white,
      TokenType.rightBrace => AnsiColors.white,
      TokenType.pipe => AnsiColors.white,
      TokenType.comma => AnsiColors.white,
      TokenType.dot => AnsiColors.white,
      TokenType.eof => '',
    };
  }

  /// Highlights a Prolog input string with ANSI colors.
  ///
  /// Returns the input with ANSI color codes inserted around tokens.
  /// Handles incomplete/partial input gracefully by catching lexer errors.
  static String highlight(final String input) {
    if (input.isEmpty) return input;

    try {
      final lexer = Lexer(input);
      final tokens = lexer.scanTokens();

      if (tokens.isEmpty ||
          (tokens.length == 1 && tokens[0].type == TokenType.eof)) {
        return input;
      }

      final result = StringBuffer();
      var pos = 0;

      for (final token in tokens) {
        if (token.type == TokenType.eof) break;

        // Calculate token start position from column
        final start = _findTokenStart(input, pos, token.lexeme);
        if (start < 0) continue;

        // Add any text before this token (whitespace, comments)
        if (start > pos) {
          final gap = input.substring(pos, start);
          // Check if this gap contains a comment
          result.write(_highlightComments(gap));
        }

        // Add the colored token
        final color = colorFor(token.type);
        if (color.isNotEmpty) {
          result.write(color);
          result.write(token.lexeme);
          result.write(AnsiColors.reset);
        } else {
          result.write(token.lexeme);
        }

        pos = start + token.lexeme.length;
      }

      // Add any remaining text
      if (pos < input.length) {
        result.write(_highlightComments(input.substring(pos)));
      }

      return result.toString();
    } catch (e) {
      // If lexer fails on partial input, return original
      return input;
    }
  }

  /// Finds the start position of a token lexeme in the input.
  static int _findTokenStart(
    final String input,
    final int from,
    final String lexeme,
  ) {
    return input.indexOf(lexeme, from);
  }

  /// Highlights comments in a string gap (between tokens).
  static String _highlightComments(final String text) {
    if (!text.contains('%') && !text.contains('/*')) {
      return text;
    }

    final result = StringBuffer();
    var i = 0;

    while (i < text.length) {
      if (text[i] == '%') {
        // Line comment - find end
        result.write(AnsiColors.gray);
        final end = text.indexOf('\n', i);
        if (end < 0) {
          result.write(text.substring(i));
          result.write(AnsiColors.reset);
          break;
        } else {
          result.write(text.substring(i, end));
          result.write(AnsiColors.reset);
          result.write('\n');
          i = end + 1;
        }
      } else if (i + 1 < text.length && text[i] == '/' && text[i + 1] == '*') {
        // Block comment - find end
        result.write(AnsiColors.gray);
        final end = text.indexOf('*/', i + 2);
        if (end < 0) {
          result.write(text.substring(i));
          result.write(AnsiColors.reset);
          break;
        } else {
          result.write(text.substring(i, end + 2));
          result.write(AnsiColors.reset);
          i = end + 2;
        }
      } else {
        result.write(text[i]);
        i++;
      }
    }

    return result.toString();
  }

  /// Highlights an error message in red.
  static String error(final String message) {
    return '${AnsiColors.red}$message${AnsiColors.reset}';
  }

  /// Highlights a success message (like "true" or variable bindings).
  static String success(final String message) {
    return '${AnsiColors.green}$message${AnsiColors.reset}';
  }

  /// Highlights a variable name.
  static String variable(final String name) {
    return '${AnsiColors.yellow}$name${AnsiColors.reset}';
  }

  /// Highlights an atom.
  static String atom(final String name) {
    return '${AnsiColors.cyan}$name${AnsiColors.reset}';
  }

  /// Highlights a number.
  static String number(final String value) {
    return '${AnsiColors.magenta}$value${AnsiColors.reset}';
  }

  /// Strips all ANSI escape codes from a string.
  ///
  /// Useful for calculating display length or for non-ANSI terminals.
  static String strip(final String text) {
    return text.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
  }

  /// Returns the display length of a string (excluding ANSI codes).
  static int displayLength(final String text) {
    return strip(text).length;
  }
}
