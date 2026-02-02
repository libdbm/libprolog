/// Token types for Prolog lexer.
///
/// Based on ISO/IEC 13211-1:1995 section 6.4 (Tokens).
enum TokenType {
  // Names
  atom, // Unquoted or quoted atom
  variable, // Variable starting with uppercase or _
  // Numbers
  integer, // Integer literal
  float, // Float literal
  // Strings
  string, // Double-quoted string
  // Punctuation
  leftParen, // (
  rightParen, // )
  leftBracket, // [
  rightBracket, // ]
  leftBrace, // {
  rightBrace, // }
  pipe, // |
  comma, // ,
  dot, // . (end of clause)
  // Special
  eof, // End of file
}

/// A token from the lexer.
///
/// Represents a single lexical unit with its type, value, and position.
class Token {
  /// The type of this token.
  final TokenType type;

  /// The lexeme (original text) of this token.
  final String lexeme;

  /// The parsed value (for numbers and atoms).
  final Object? value;

  /// Line number (1-based).
  final int line;

  /// Column number (1-based).
  final int column;

  const Token({
    required this.type,
    required this.lexeme,
    this.value,
    required this.line,
    required this.column,
  });

  @override
  String toString() {
    if (value != null && value != lexeme) {
      return 'Token($type, "$lexeme", value: $value, line: $line, col: $column)';
    }
    return 'Token($type, "$lexeme", line: $line, col: $column)';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is Token &&
          other.type == type &&
          other.lexeme == lexeme &&
          other.value == value);

  @override
  int get hashCode => Object.hash(type, lexeme, value);
}
