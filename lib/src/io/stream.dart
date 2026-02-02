/// Stream abstraction for ISO-compliant I/O.
///
/// Provides character and byte streams with properties.
library;

import 'dart:io' as io;
import 'dart:convert';

/// Direction of a stream.
enum StreamDirection { input, output }

/// Type of stream content.
enum StreamType { text, binary }

/// End-of-stream status.
enum EndOfStream {
  not, // Not at end of stream
  at, // At end of stream
  past, // Past end of stream
}

/// Properties of a Prolog stream.
class StreamProperties {
  final String alias;
  final StreamDirection direction;
  final StreamType type;
  final bool reposition;
  final EndOfStream eofAction;

  const StreamProperties({
    required this.alias,
    required this.direction,
    required this.type,
    this.reposition = false,
    this.eofAction = EndOfStream.not,
  });
}

/// Abstract base class for Prolog streams.
abstract class PrologStream {
  /// Unique identifier for this stream.
  final String id;

  /// Properties of this stream.
  final StreamProperties properties;

  /// Whether this stream is open.
  bool _isOpen = true;

  PrologStream(this.id, this.properties);

  /// Returns true if the stream is open.
  bool get isOpen => _isOpen;

  /// Returns true if this is an input stream.
  bool get isInput => properties.direction == StreamDirection.input;

  /// Returns true if this is an output stream.
  bool get isOutput => properties.direction == StreamDirection.output;

  /// Returns true if this is a text stream.
  bool get isText => properties.type == StreamType.text;

  /// Returns true if this is a binary stream.
  bool get isBinary => properties.type == StreamType.binary;

  /// Closes the stream.
  void close() {
    _isOpen = false;
  }

  /// Flushes any buffered output.
  void flush();
}

/// Character input stream.
abstract class CharacterInputStream extends PrologStream {
  CharacterInputStream(super.id, super.properties);

  /// Reads the next character (returns null at EOF).
  String? readChar();

  /// Peeks at the next character without consuming it.
  String? peekChar();

  /// Reads the next character code (returns -1 at EOF).
  int readCode();

  /// Peeks at the next character code without consuming it.
  int peekCode();
}

/// Character output stream.
abstract class CharacterOutputStream extends PrologStream {
  CharacterOutputStream(super.id, super.properties);

  /// Writes a character.
  void writeChar(final String char);

  /// Writes a character code.
  void writeCode(final int code);

  /// Writes a newline.
  void writeNewline();
}

/// Byte input stream.
abstract class ByteInputStream extends PrologStream {
  ByteInputStream(super.id, super.properties);

  /// Reads the next byte (returns -1 at EOF).
  int readByte();

  /// Peeks at the next byte without consuming it.
  int peekByte();
}

/// Byte output stream.
abstract class ByteOutputStream extends PrologStream {
  ByteOutputStream(super.id, super.properties);

  /// Writes a byte.
  void writeByte(final int byte);
}

/// Standard input stream (stdin).
class StdinStream extends CharacterInputStream {
  final io.Stdin _stdin;
  String? _peeked;

  StdinStream(this._stdin)
    : super(
        'user_input',
        const StreamProperties(
          alias: 'user_input',
          direction: StreamDirection.input,
          type: StreamType.text,
        ),
      );

  @override
  String? readChar() {
    if (_peeked != null) {
      final char = _peeked;
      _peeked = null;
      return char;
    }

    final code = _stdin.readByteSync();
    if (code == -1) return null;
    return String.fromCharCode(code);
  }

  @override
  String? peekChar() {
    _peeked ??= readChar();
    return _peeked;
  }

  @override
  int readCode() {
    final char = readChar();
    if (char == null) return -1;
    return char.codeUnitAt(0);
  }

  @override
  int peekCode() {
    final char = peekChar();
    if (char == null) return -1;
    return char.codeUnitAt(0);
  }

  @override
  void flush() {
    // No-op for input stream
  }
}

/// Standard output stream (stdout).
class StdoutStream extends CharacterOutputStream {
  final io.Stdout _stdout;

  StdoutStream(this._stdout)
    : super(
        'user_output',
        const StreamProperties(
          alias: 'user_output',
          direction: StreamDirection.output,
          type: StreamType.text,
        ),
      );

  @override
  void writeChar(final String char) {
    _stdout.write(char);
  }

  @override
  void writeCode(final int code) {
    _stdout.writeCharCode(code);
  }

  @override
  void writeNewline() {
    _stdout.writeln();
  }

  @override
  void flush() {
    // Dart stdout auto-flushes in most cases
  }
}

/// Standard error stream (stderr).
class StderrStream extends CharacterOutputStream {
  final io.IOSink _stderr;

  StderrStream(this._stderr)
    : super(
        'user_error',
        const StreamProperties(
          alias: 'user_error',
          direction: StreamDirection.output,
          type: StreamType.text,
        ),
      );

  @override
  void writeChar(final String char) {
    _stderr.write(char);
  }

  @override
  void writeCode(final int code) {
    _stderr.writeCharCode(code);
  }

  @override
  void writeNewline() {
    _stderr.writeln();
  }

  @override
  void flush() {
    // Dart stderr auto-flushes
  }
}

/// File-based character input stream.
class FileInputStream extends CharacterInputStream {
  final io.RandomAccessFile _file;
  String? _peeked;
  bool _eof = false;

  FileInputStream(this._file, final String alias)
    : super(
        alias,
        StreamProperties(
          alias: alias,
          direction: StreamDirection.input,
          type: StreamType.text,
          reposition: true,
        ),
      );

  @override
  String? readChar() {
    if (_peeked != null) {
      final char = _peeked;
      _peeked = null;
      return char;
    }

    if (_eof) return null;

    try {
      final byte = _file.readByteSync();
      if (byte == -1) {
        _eof = true;
        return null;
      }
      return String.fromCharCode(byte);
    } catch (e) {
      _eof = true;
      return null;
    }
  }

  @override
  String? peekChar() {
    _peeked ??= readChar();
    return _peeked;
  }

  @override
  int readCode() {
    final char = readChar();
    if (char == null) return -1;
    return char.codeUnitAt(0);
  }

  @override
  int peekCode() {
    final char = peekChar();
    if (char == null) return -1;
    return char.codeUnitAt(0);
  }

  @override
  void close() {
    super.close();
    _file.closeSync();
  }

  @override
  void flush() {
    // No-op for input stream
  }
}

/// File-based character output stream.
class FileOutputStream extends CharacterOutputStream {
  final io.RandomAccessFile _file;

  FileOutputStream(this._file, final String alias)
    : super(
        alias,
        StreamProperties(
          alias: alias,
          direction: StreamDirection.output,
          type: StreamType.text,
          reposition: true,
        ),
      );

  @override
  void writeChar(final String char) {
    final bytes = utf8.encode(char);
    _file.writeFromSync(bytes);
  }

  @override
  void writeCode(final int code) {
    _file.writeByteSync(code);
  }

  @override
  void writeNewline() {
    _file.writeByteSync(10); // '\n'
  }

  @override
  void close() {
    super.close();
    _file.closeSync();
  }

  @override
  void flush() {
    _file.flushSync();
  }
}
