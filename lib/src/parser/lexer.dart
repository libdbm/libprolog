import 'token.dart';

/// ISO-compliant Prolog lexer.
///
/// Implements tokenization according to ISO/IEC 13211-1:1995 section 6.4.
/// Supports:
/// - Atoms (quoted and unquoted)
/// - Variables (uppercase or underscore start)
/// - Numbers (integers, floats, with base notation)
/// - Strings (double-quoted)
/// - Comments (% line, /* block */)
/// - Escape sequences
class Lexer {
  final String source;
  final List<Token> tokens = [];

  int start = 0; // Start of current lexeme
  int current = 0; // Current character position
  int line = 1; // Current line (1-based)
  int column = 1; // Current column (1-based)

  Lexer(this.source);

  /// Tokenizes the source and returns all tokens.
  List<Token> scanTokens() {
    while (!isAtEnd) {
      start = current;
      scanToken();
    }

    // Add EOF token
    tokens.add(
      Token(type: TokenType.eof, lexeme: '', line: line, column: column),
    );

    return tokens;
  }

  /// Scans a single token.
  void scanToken() {
    final c = advance();

    // Layout characters (whitespace)
    if (isLayout(c)) {
      return; // Skip whitespace
    }

    // Comments
    if (c == '%') {
      skipLineComment();
      return;
    }
    if (c == '/' && match('*')) {
      skipBlockComment();
      return;
    }

    // Punctuation
    switch (c) {
      case '(':
        addToken(TokenType.leftParen);
        return;
      case ')':
        addToken(TokenType.rightParen);
        return;
      case '[':
        addToken(TokenType.leftBracket);
        return;
      case ']':
        addToken(TokenType.rightBracket);
        return;
      case '{':
        addToken(TokenType.leftBrace);
        return;
      case '}':
        addToken(TokenType.rightBrace);
        return;
      case '|':
        addToken(TokenType.pipe);
        return;
      case ',':
        addToken(TokenType.comma);
        return;
      case '.':
        // Dot can be end-of-clause or start of number
        if (peek().isEmpty || isLayout(peek()) || peek() == '%') {
          addToken(TokenType.dot);
        } else if (isDigit(peek())) {
          // .5 is a float
          scanNumber();
        } else {
          // Atom starting with dot (symbolic atom)
          scanSymbolicAtom();
        }
        return;
    }

    // Strings
    if (c == '"') {
      scanString();
      return;
    }

    // Quoted atoms
    if (c == "'") {
      scanQuotedAtom();
      return;
    }

    // Variables (uppercase or underscore)
    if (isUppercase(c) || c == '_') {
      scanVariable();
      return;
    }

    // Numbers
    if (isDigit(c)) {
      scanNumber();
      return;
    }

    // Atoms (lowercase start)
    if (isLowercase(c)) {
      scanAtom();
      return;
    }

    // Symbolic atoms (operators like +, -, *, etc.)
    if (isSymbol(c)) {
      scanSymbolicAtom();
      return;
    }

    // Solo characters (! and ;)
    if (c == '!' || c == ';') {
      scanSymbolicAtom();
      return;
    }

    throw LexerError('Unexpected character: $c', line, column - 1);
  }

  /// Scans an unquoted atom (starts with lowercase).
  void scanAtom() {
    while (isAlphaNumeric(peek()) || peek() == '_') {
      advance();
    }
    final text = source.substring(start, current);
    addToken(TokenType.atom, value: text);
  }

  /// Scans a symbolic atom (operators like +, -, =, etc.).
  void scanSymbolicAtom() {
    while (isSymbol(peek()) || peek() == '!') {
      advance();
    }
    final text = source.substring(start, current);
    addToken(TokenType.atom, value: text);
  }

  /// Scans a quoted atom ('text').
  void scanQuotedAtom() {
    final buffer = StringBuffer();

    while (!isAtEnd && peek() != "'") {
      if (peek() == '\\') {
        advance(); // consume \
        buffer.write(scanEscape());
      } else {
        buffer.write(peek());
        advance();
      }
    }

    if (isAtEnd) {
      throw LexerError('Unterminated quoted atom', line, column);
    }

    advance(); // consume closing '

    addToken(TokenType.atom, value: buffer.toString());
  }

  /// Scans a variable (starts with uppercase or _).
  void scanVariable() {
    while (isAlphaNumeric(peek()) || peek() == '_') {
      advance();
    }
    final text = source.substring(start, current);
    addToken(TokenType.variable, value: text);
  }

  /// Scans a number (integer or float).
  void scanNumber() {
    // Handle leading dot for floats like .5
    final startedWithDot = source[start] == '.';

    if (!startedWithDot) {
      // Check for base notation: 2'101, 0x1F, 0o77, 0b101
      if (peek() == 'x' || peek() == 'X') {
        advance(); // consume x
        scanHexNumber();
        return;
      }
      if (peek() == 'o' || peek() == 'O') {
        advance(); // consume o
        scanOctalNumber();
        return;
      }
      if (peek() == 'b' || peek() == 'B') {
        advance(); // consume b
        scanBinaryNumber();
        return;
      }

      // Check for character code: 0'c (must check before consuming more digits)
      if (current == start + 1 &&
          source[start] == '0' &&
          peek() == "'" &&
          peekNext().isNotEmpty) {
        advance(); // consume '
        final char = advance();
        final code = char.codeUnitAt(0);
        addToken(TokenType.integer, value: code);
        return;
      }

      // Consume digits (including underscores as digit separators)
      while (isDigit(peek()) || peek() == '_') {
        advance();
      }

      // Check for base notation: N'digits
      if (peek() == "'") {
        var text = source.substring(start, current);
        text = text.replaceAll('_', ''); // remove digit separators
        final base = int.parse(text);
        if (base < 2 || base > 36) {
          throw LexerError('Invalid base: $base (must be 2-36)', line, column);
        }
        advance(); // consume '
        scanBaseNumber(base);
        return;
      }
    }

    // Check for decimal point
    if (peek() == '.' && isDigit(peekNext())) {
      advance(); // consume .
      while (isDigit(peek())) {
        advance();
      }

      // Check for exponent
      if (peek() == 'e' || peek() == 'E') {
        scanExponent();
      }

      final text = source.substring(start, current);
      addToken(TokenType.float, value: double.parse(text));
      return;
    }

    // Check for exponent (makes it a float)
    if (peek() == 'e' || peek() == 'E') {
      scanExponent();
      final text = source.substring(start, current);
      addToken(TokenType.float, value: double.parse(text));
      return;
    }

    // Just an integer
    var text = source.substring(start, current);
    text = text.replaceAll('_', ''); // remove digit separators
    addToken(TokenType.integer, value: int.parse(text));
  }

  /// Scans hexadecimal number after 0x prefix.
  void scanHexNumber() {
    if (!isHexDigit(peek())) {
      throw LexerError('Expected hex digit after 0x', line, column);
    }
    while (isHexDigit(peek()) || peek() == '_') {
      advance();
    }
    var text = source.substring(start + 2, current); // skip 0x
    text = text.replaceAll('_', ''); // remove digit separators
    addToken(TokenType.integer, value: int.parse(text, radix: 16));
  }

  /// Scans octal number after 0o prefix.
  void scanOctalNumber() {
    if (!isOctalDigit(peek())) {
      throw LexerError('Expected octal digit after 0o', line, column);
    }
    while (isOctalDigit(peek()) || peek() == '_') {
      advance();
    }
    var text = source.substring(start + 2, current); // skip 0o
    text = text.replaceAll('_', ''); // remove digit separators
    addToken(TokenType.integer, value: int.parse(text, radix: 8));
  }

  /// Scans binary number after 0b prefix.
  void scanBinaryNumber() {
    if (!isBinaryDigit(peek())) {
      throw LexerError('Expected binary digit after 0b', line, column);
    }
    while (isBinaryDigit(peek()) || peek() == '_') {
      advance();
    }
    var text = source.substring(start + 2, current); // skip 0b
    text = text.replaceAll('_', ''); // remove digit separators
    addToken(TokenType.integer, value: int.parse(text, radix: 2));
  }

  /// Scans number with given base (N'digits notation).
  void scanBaseNumber(final int base) {
    while (isBaseDigit(peek(), base) || peek() == '_') {
      advance();
    }
    var text = source.substring(start, current);
    // Remove base prefix and underscores
    text = text.substring(text.indexOf("'") + 1).replaceAll('_', '');
    addToken(TokenType.integer, value: int.parse(text, radix: base));
  }

  /// Scans exponent part of float (e+10, E-5, etc.).
  void scanExponent() {
    advance(); // consume e/E
    if (peek() == '+' || peek() == '-') {
      advance();
    }
    if (!isDigit(peek())) {
      throw LexerError('Expected digit in exponent', line, column);
    }
    while (isDigit(peek())) {
      advance();
    }
  }

  /// Scans a double-quoted string.
  void scanString() {
    final buffer = StringBuffer();

    while (!isAtEnd && peek() != '"') {
      if (peek() == '\\') {
        advance(); // consume \
        buffer.write(scanEscape());
      } else {
        buffer.write(peek());
        advance();
      }
    }

    if (isAtEnd) {
      throw LexerError('Unterminated string', line, column);
    }

    advance(); // consume closing "

    addToken(TokenType.string, value: buffer.toString());
  }

  /// Scans an escape sequence and returns the character.
  String scanEscape() {
    if (isAtEnd) {
      throw LexerError('Incomplete escape sequence', line, column);
    }

    final c = advance();
    switch (c) {
      case 'n':
        return '\n';
      case 't':
        return '\t';
      case 'r':
        return '\r';
      case 'b':
        return '\b';
      case 'f':
        return '\f';
      case 'a':
        return '\x07'; // bell/alert
      case 'v':
        return '\x0B'; // vertical tab
      case 'e':
        return '\x1B'; // escape
      case '\\':
        return '\\';
      case "'":
        return "'";
      case '"':
        return '"';
      case 'x': // Hex escape: \xHH
        return scanHexEscape();
      case 'u': // Unicode escape: \uHHHH
        return scanUnicodeEscape(4);
      case 'U': // Unicode escape: \UHHHHHHHH
        return scanUnicodeEscape(8);
      default:
        // Octal escape: \DDD
        if (isOctalDigit(c)) {
          return scanOctalEscape(c);
        }
        throw LexerError('Invalid escape sequence: \\$c', line, column);
    }
  }

  /// Scans hex escape \xHH.
  String scanHexEscape() {
    final buffer = StringBuffer();
    for (var i = 0; i < 2; i++) {
      if (isHexDigit(peek())) {
        buffer.write(advance());
      } else {
        throw LexerError('Invalid hex escape sequence', line, column);
      }
    }
    final code = int.parse(buffer.toString(), radix: 16);
    return String.fromCharCode(code);
  }

  /// Scans unicode escape \uHHHH or \UHHHHHHHH.
  String scanUnicodeEscape(final int digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits; i++) {
      if (isHexDigit(peek())) {
        buffer.write(advance());
      } else {
        throw LexerError('Invalid unicode escape sequence', line, column);
      }
    }
    final code = int.parse(buffer.toString(), radix: 16);
    return String.fromCharCode(code);
  }

  /// Scans octal escape \DDD (up to 3 digits).
  String scanOctalEscape(final String first) {
    final buffer = StringBuffer(first);
    for (var i = 0; i < 2; i++) {
      if (isOctalDigit(peek())) {
        buffer.write(advance());
      } else {
        break;
      }
    }
    final code = int.parse(buffer.toString(), radix: 8);
    return String.fromCharCode(code);
  }

  /// Skips a line comment (% to end of line).
  void skipLineComment() {
    while (!isAtEnd && peek() != '\n') {
      advance();
    }
  }

  /// Skips a block comment (/* ... */).
  void skipBlockComment() {
    var depth = 1; // Support nested comments

    while (!isAtEnd && depth > 0) {
      if (peek() == '/' && peekNext() == '*') {
        advance();
        advance();
        depth++;
      } else if (peek() == '*' && peekNext() == '/') {
        advance();
        advance();
        depth--;
      } else {
        advance();
      }
    }

    if (depth > 0) {
      throw LexerError('Unterminated block comment', line, column);
    }
  }

  /// Adds a token to the list.
  void addToken(final TokenType type, {final Object? value}) {
    final text = source.substring(start, current);
    tokens.add(
      Token(
        type: type,
        lexeme: text,
        value: value,
        line: line,
        column: column - text.length,
      ),
    );
  }

  /// Advances to the next character.
  String advance() {
    if (isAtEnd) return '';
    final c = source[current];
    current++;
    if (c == '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }
    return c;
  }

  /// Returns current character without advancing.
  String peek() {
    if (isAtEnd) return '';
    return source[current];
  }

  /// Returns next character without advancing.
  String peekNext() {
    if (current + 1 >= source.length) return '';
    return source[current + 1];
  }

  /// Matches and consumes expected character.
  bool match(final String expected) {
    if (isAtEnd) return false;
    if (source[current] != expected) return false;
    advance();
    return true;
  }

  /// Returns true if at end of source.
  bool get isAtEnd => current >= source.length;

  // Character classification (ISO Prolog)

  /// Layout characters (whitespace).
  bool isLayout(final String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return code <= 32 || (code >= 127 && code <= 159);
  }

  /// Lowercase letter.
  bool isLowercase(final String c) {
    if (c.isEmpty) return false;
    return c.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
        c.codeUnitAt(0) <= 'z'.codeUnitAt(0);
  }

  /// Uppercase letter.
  bool isUppercase(final String c) {
    if (c.isEmpty) return false;
    return c.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
        c.codeUnitAt(0) <= 'Z'.codeUnitAt(0);
  }

  /// Digit 0-9.
  bool isDigit(final String c) {
    if (c.isEmpty) return false;
    return c.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        c.codeUnitAt(0) <= '9'.codeUnitAt(0);
  }

  /// Alphanumeric character.
  bool isAlphaNumeric(final String c) {
    return isLowercase(c) || isUppercase(c) || isDigit(c);
  }

  /// Symbol character (operators).
  bool isSymbol(final String c) {
    return c == '+' ||
        c == '-' ||
        c == '*' ||
        c == '/' ||
        c == '\\' ||
        c == '^' ||
        c == '<' ||
        c == '>' ||
        c == '=' ||
        c == '`' ||
        c == '~' ||
        c == ':' ||
        c == '.' ||
        c == '?' ||
        c == '@' ||
        c == '#' ||
        c == '\$' ||
        c == '&';
  }

  /// Hexadecimal digit.
  bool isHexDigit(final String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= '0'.codeUnitAt(0) && code <= '9'.codeUnitAt(0)) ||
        (code >= 'a'.codeUnitAt(0) && code <= 'f'.codeUnitAt(0)) ||
        (code >= 'A'.codeUnitAt(0) && code <= 'F'.codeUnitAt(0));
  }

  /// Octal digit.
  bool isOctalDigit(final String c) {
    if (c.isEmpty) return false;
    return c.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        c.codeUnitAt(0) <= '7'.codeUnitAt(0);
  }

  /// Binary digit.
  bool isBinaryDigit(final String c) {
    return c == '0' || c == '1';
  }

  /// Valid digit for given base.
  bool isBaseDigit(final String c, final int base) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);

    if (base <= 10) {
      return code >= '0'.codeUnitAt(0) && code < ('0'.codeUnitAt(0) + base);
    } else {
      // Base > 10, use letters a-z
      return (code >= '0'.codeUnitAt(0) && code <= '9'.codeUnitAt(0)) ||
          (code >= 'a'.codeUnitAt(0) &&
              code < ('a'.codeUnitAt(0) + (base - 10))) ||
          (code >= 'A'.codeUnitAt(0) &&
              code < ('A'.codeUnitAt(0) + (base - 10)));
    }
  }
}

/// Lexer error exception.
class LexerError implements Exception {
  final String message;
  final int line;
  final int column;

  LexerError(this.message, this.line, this.column);

  @override
  String toString() => 'Lexer error at line $line, column $column: $message';
}
