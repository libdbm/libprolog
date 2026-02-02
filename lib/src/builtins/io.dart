/// I/O built-in predicates.
library;

import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../terms/variable.dart';
import '../terms/number.dart';
import '../io/stream_manager.dart';
import '../io/stream.dart';
import '../parser/parser.dart';
import 'builtin.dart';

/// Registers I/O built-in predicates.
void registerIOBuiltins(
  final BuiltinRegistry registry,
  final StreamManager streamManager,
) {
  // Character I/O
  registry.register('get_char', 1, (ctx) => _getChar(ctx, streamManager));
  registry.register('put_char', 1, (ctx) => _putChar(ctx, streamManager));
  registry.register('peek_char', 1, (ctx) => _peekChar(ctx, streamManager));
  registry.register('get_code', 1, (ctx) => _getCode(ctx, streamManager));
  registry.register('put_code', 1, (ctx) => _putCode(ctx, streamManager));
  registry.register('peek_code', 1, (ctx) => _peekCode(ctx, streamManager));
  registry.register('nl', 0, (ctx) => _nl(ctx, streamManager));

  // Byte I/O
  registry.register('get_byte', 1, (ctx) => _getByte(ctx, streamManager));
  registry.register('put_byte', 1, (ctx) => _putByte(ctx, streamManager));
  registry.register('peek_byte', 1, (ctx) => _peekByte(ctx, streamManager));

  // Term I/O
  registry.register('read', 1, (ctx) => _read(ctx, streamManager));
  registry.register('write', 1, (ctx) => _write(ctx, streamManager));
  registry.register('writeq', 1, (ctx) => _writeq(ctx, streamManager));
  registry.register('writeln', 1, (ctx) => _writeln(ctx, streamManager));
  registry.register(
    'write_canonical',
    1,
    (ctx) => _writeCanonical(ctx, streamManager),
  );

  // Stream management
  registry.register(
    'at_end_of_stream',
    0,
    (ctx) => _atEndOfStream0(ctx, streamManager),
  );
  registry.register(
    'at_end_of_stream',
    1,
    (ctx) => _atEndOfStream1(ctx, streamManager),
  );

  // Stream management (continued)
  registry.register('open', 3, (ctx) => _open(ctx, streamManager));
  registry.register('close', 1, (ctx) => _close(ctx, streamManager));
  registry.register(
    'current_input',
    1,
    (ctx) => _currentInput(ctx, streamManager),
  );
  registry.register(
    'current_output',
    1,
    (ctx) => _currentOutput(ctx, streamManager),
  );
  registry.register('set_input', 1, (ctx) => _setInput(ctx, streamManager));
  registry.register('set_output', 1, (ctx) => _setOutput(ctx, streamManager));
  registry.register(
    'flush_output',
    0,
    (ctx) => _flushOutput(ctx, streamManager),
  );
}

/// Implements get_char/1: get_char(Char).
///
/// Reads a character from current input.
BuiltinResult _getChar(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final char = streamManager.currentInput.readChar();

  if (char == null) {
    // EOF - unify with end_of_file atom
    return context.unifyAndReturn(context.arg(0), Atom('end_of_file'));
  }

  return context.unifyAndReturn(context.arg(0), Atom(char));
}

/// Implements put_char/1: put_char(Char).
///
/// Writes a character to current output.
BuiltinResult _putChar(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);

  if (term is! Atom) {
    return const BuiltinFailure();
  }

  final char = term.value;
  if (char.length != 1) {
    return const BuiltinFailure();
  }

  streamManager.currentOutput.writeChar(char);
  return const BuiltinSuccess();
}

/// Implements peek_char/1: peek_char(Char).
///
/// Peeks at next character from current input without consuming it.
BuiltinResult _peekChar(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final char = streamManager.currentInput.peekChar();

  if (char == null) {
    return context.unifyAndReturn(context.arg(0), Atom('end_of_file'));
  }

  return context.unifyAndReturn(context.arg(0), Atom(char));
}

/// Implements nl/0: nl.
///
/// Writes a newline to current output.
BuiltinResult _nl(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  streamManager.currentOutput.writeNewline();
  return const BuiltinSuccess();
}

/// Implements read/1: read(Term).
///
/// Reads a Prolog term from current input.
BuiltinResult _read(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  // Read characters until we have a complete term (ending with '.')
  final buffer = StringBuffer();
  String? char;

  while ((char = streamManager.currentInput.readChar()) != null) {
    buffer.write(char);
    if (char == '.') {
      // Check if followed by whitespace or EOF
      final next = streamManager.currentInput.peekChar();
      if (next == null || next == ' ' || next == '\n' || next == '\t') {
        break;
      }
    }
  }

  if (buffer.isEmpty) {
    // EOF - unify with end_of_file
    return context.unifyAndReturn(context.arg(0), Atom('end_of_file'));
  }

  // Parse the term
  try {
    final term = Parser.parseTerm(buffer.toString());

    return context.unifyAndReturn(context.arg(0), term);
  } catch (e) {
    // Parse error
    return const BuiltinFailure();
  }
}

/// Implements write/1: write(Term).
///
/// Writes a term to current output.
BuiltinResult _write(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);
  streamManager.currentOutput.writeChar(term.toString());
  return const BuiltinSuccess();
}

/// Implements writeq/1: writeq(Term).
///
/// Writes a term to current output with atoms quoted if necessary.
BuiltinResult _writeq(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);
  // For now, just use toString (proper implementation would quote atoms)
  streamManager.currentOutput.writeChar(term.toString());
  return const BuiltinSuccess();
}

/// Implements open/3: open(File, Mode, Stream).
///
/// Opens a file and unifies Stream with the stream alias.
BuiltinResult _open(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final file = context.arg(0);
  final mode = context.arg(1);
  final streamVar = context.arg(2);

  if (file is! Atom) {
    return const BuiltinFailure();
  }

  if (mode is! Atom) {
    return const BuiltinFailure();
  }

  final path = file.value;
  final modeStr = mode.value;

  try {
    final stream = switch (modeStr) {
      'read' => streamManager.openInput(path),
      'write' => streamManager.openOutput(path),
      'append' => streamManager.openAppend(path),
      _ => null,
    };

    if (stream == null) {
      return const BuiltinFailure();
    }

    // Unify with stream alias atom
    return context.unifyAndReturn(streamVar, Atom(stream.properties.alias));
  } catch (e) {
    return const BuiltinFailure();
  }
}

/// Implements close/1: close(Stream).
///
/// Closes a stream.
BuiltinResult _close(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final streamTerm = context.arg(0);

  if (streamTerm is! Atom) {
    return const BuiltinFailure();
  }

  final alias = streamTerm.value;
  final stream = streamManager.getStreamByAlias(alias);

  if (stream == null) {
    return const BuiltinFailure();
  }

  streamManager.closeStream(stream);
  return const BuiltinSuccess();
}

/// Implements current_input/1: current_input(Stream).
///
/// Unifies Stream with the current input stream alias.
BuiltinResult _currentInput(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final currentStream = streamManager.currentInput;

  return context.unifyAndReturn(
    context.arg(0),
    Atom(currentStream.properties.alias),
  );
}

/// Implements current_output/1: current_output(Stream).
///
/// Unifies Stream with the current output stream alias.
BuiltinResult _currentOutput(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final currentStream = streamManager.currentOutput;

  return context.unifyAndReturn(
    context.arg(0),
    Atom(currentStream.properties.alias),
  );
}

/// Implements get_code/1: get_code(Code).
///
/// Reads a character code from current input.
BuiltinResult _getCode(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final code = streamManager.currentInput.readCode();

  return context.unifyAndReturn(context.arg(0), PrologInteger(code));
}

/// Implements put_code/1: put_code(Code).
///
/// Writes a character code to current output.
BuiltinResult _putCode(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);

  if (term is! PrologInteger) {
    return const BuiltinFailure();
  }

  streamManager.currentOutput.writeCode(term.value);
  return const BuiltinSuccess();
}

/// Implements peek_code/1: peek_code(Code).
///
/// Peeks at next character code without consuming it.
BuiltinResult _peekCode(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final code = streamManager.currentInput.peekCode();

  return context.unifyAndReturn(context.arg(0), PrologInteger(code));
}

/// Implements get_byte/1: get_byte(Byte).
///
/// Reads a byte from current input (for binary streams).
BuiltinResult _getByte(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  // For now, read as character code (simplified implementation)
  final code = streamManager.currentInput.readCode();

  return context.unifyAndReturn(context.arg(0), PrologInteger(code));
}

/// Implements put_byte/1: put_byte(Byte).
///
/// Writes a byte to current output (for binary streams).
BuiltinResult _putByte(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);

  if (term is! PrologInteger) {
    return const BuiltinFailure();
  }

  streamManager.currentOutput.writeCode(term.value);
  return const BuiltinSuccess();
}

/// Implements peek_byte/1: peek_byte(Byte).
///
/// Peeks at next byte without consuming it.
BuiltinResult _peekByte(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final code = streamManager.currentInput.peekCode();

  return context.unifyAndReturn(context.arg(0), PrologInteger(code));
}

/// Implements writeln/1: writeln(Term).
///
/// Writes a term followed by a newline.
BuiltinResult _writeln(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);
  streamManager.currentOutput.writeChar(term.toString());
  streamManager.currentOutput.writeNewline();
  return const BuiltinSuccess();
}

/// Implements set_input/1: set_input(Stream).
///
/// Sets the current input stream.
BuiltinResult _setInput(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final streamTerm = context.arg(0);

  if (streamTerm is! Atom) {
    return const BuiltinFailure();
  }

  final alias = streamTerm.value;
  final stream = streamManager.getStreamByAlias(alias);

  if (stream == null) {
    return const BuiltinFailure();
  }

  if (stream is! CharacterInputStream) {
    return const BuiltinFailure();
  }

  streamManager.setCurrentInput(stream);
  return const BuiltinSuccess();
}

/// Implements set_output/1: set_output(Stream).
///
/// Sets the current output stream.
BuiltinResult _setOutput(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final streamTerm = context.arg(0);

  if (streamTerm is! Atom) {
    return const BuiltinFailure();
  }

  final alias = streamTerm.value;
  final stream = streamManager.getStreamByAlias(alias);

  if (stream == null) {
    return const BuiltinFailure();
  }

  if (stream is! CharacterOutputStream) {
    return const BuiltinFailure();
  }

  streamManager.setCurrentOutput(stream);
  return const BuiltinSuccess();
}

/// Implements flush_output/0: flush_output.
///
/// Flushes the current output stream.
BuiltinResult _flushOutput(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  streamManager.currentOutput.flush();
  return const BuiltinSuccess();
}

/// Implements write_canonical/1: write_canonical(Term).
///
/// Writes Term in canonical form (without operators, fully parenthesized).
BuiltinResult _writeCanonical(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final term = context.arg(0);

  // Write canonical representation (fully functional form)
  final canonical = _toCanonical(term);
  for (final char in canonical.split('')) {
    streamManager.currentOutput.writeChar(char);
  }

  return const BuiltinSuccess();
}

/// Converts a term to canonical (functional) representation.
String _toCanonical(final Term term) {
  if (term is Atom) {
    // Quote atoms if needed
    if (_needsQuoting(term.value)) {
      return "'${term.value}'";
    }
    return term.value;
  } else if (term is PrologInteger) {
    return term.value.toString();
  } else if (term is PrologFloat) {
    return term.value.toString();
  } else if (term is Variable) {
    return term.name;
  } else if (term is Compound) {
    // Always write in functional form, never as operators
    final args = term.args.map(_toCanonical).join(', ');
    return '${_toCanonical(term.functor)}($args)';
  }
  return term.toString();
}

/// Checks if an atom needs quoting in canonical form.
bool _needsQuoting(final String atom) {
  if (atom.isEmpty) return true;
  if (atom[0].toLowerCase() != atom[0]) return false; // Starts with uppercase
  // Check for special characters
  return atom.contains(RegExp(r'[^a-z0-9_]'));
}

/// Implements at_end_of_stream/0: at_end_of_stream.
///
/// Succeeds if current input stream is at end-of-file.
BuiltinResult _atEndOfStream0(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final stream = streamManager.currentInput;
  // Check EOF by peeking
  final char = stream.peekChar();
  return char == null ? const BuiltinSuccess() : const BuiltinFailure();
}

/// Implements at_end_of_stream/1: at_end_of_stream(Stream).
///
/// Succeeds if the specified stream is at end-of-file.
BuiltinResult _atEndOfStream1(
  final BuiltinContext context,
  final StreamManager streamManager,
) {
  final streamTerm = context.arg(0);

  if (streamTerm is! Atom) {
    return const BuiltinFailure();
  }

  final alias = streamTerm.value;
  final stream = streamManager.getStreamByAlias(alias);

  if (stream == null) {
    return const BuiltinFailure();
  }

  if (stream is! CharacterInputStream) {
    return const BuiltinFailure();
  }

  // Check EOF by peeking
  final char = stream.peekChar();
  return char == null ? const BuiltinSuccess() : const BuiltinFailure();
}
