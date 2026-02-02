/// Manages Prolog streams and current I/O context.
library;

import 'dart:io' as io;
import 'stream.dart';

/// Global stream manager for Prolog I/O.
class StreamManager {
  /// Registry of all open streams by alias.
  final Map<String, PrologStream> _streams = {};

  /// Registry of all open streams by ID.
  final Map<String, PrologStream> _streamsById = {};

  /// Current input stream.
  CharacterInputStream _currentInput;

  /// Current output stream.
  CharacterOutputStream _currentOutput;

  /// Standard input stream.
  final CharacterInputStream userInput;

  /// Standard output stream.
  final CharacterOutputStream userOutput;

  /// Standard error stream.
  final CharacterOutputStream userError;

  /// Counter for generating unique stream IDs.
  int _streamIdCounter = 0;

  /// Creates a stream manager with standard streams.
  StreamManager()
    : userInput = StdinStream(io.stdin),
      userOutput = StdoutStream(io.stdout),
      userError = StderrStream(io.stderr),
      _currentInput = StdinStream(io.stdin),
      _currentOutput = StdoutStream(io.stdout) {
    // Register standard streams
    _registerStream(userInput);
    _registerStream(userOutput);
    _registerStream(userError);
  }

  /// Returns the current input stream.
  CharacterInputStream get currentInput => _currentInput;

  /// Returns the current output stream.
  CharacterOutputStream get currentOutput => _currentOutput;

  /// Sets the current input stream.
  void setCurrentInput(final CharacterInputStream stream) {
    _currentInput = stream;
  }

  /// Sets the current output stream.
  void setCurrentOutput(final CharacterOutputStream stream) {
    _currentOutput = stream;
  }

  /// Opens a file for reading.
  CharacterInputStream openInput(final String path, {String? alias}) {
    final file = io.File(path).openSync(mode: io.FileMode.read);
    final streamAlias = alias ?? _generateStreamId();
    final stream = FileInputStream(file, streamAlias);
    _registerStream(stream);
    return stream;
  }

  /// Opens a file for writing.
  CharacterOutputStream openOutput(final String path, {String? alias}) {
    final file = io.File(path).openSync(mode: io.FileMode.write);
    final streamAlias = alias ?? _generateStreamId();
    final stream = FileOutputStream(file, streamAlias);
    _registerStream(stream);
    return stream;
  }

  /// Opens a file for appending.
  CharacterOutputStream openAppend(final String path, {String? alias}) {
    final file = io.File(path).openSync(mode: io.FileMode.append);
    final streamAlias = alias ?? _generateStreamId();
    final stream = FileOutputStream(file, streamAlias);
    _registerStream(stream);
    return stream;
  }

  /// Closes a stream.
  void closeStream(final PrologStream stream) {
    stream.close();
    _streams.remove(stream.properties.alias);
    _streamsById.remove(stream.id);
  }

  /// Gets a stream by alias.
  PrologStream? getStreamByAlias(final String alias) {
    return _streams[alias];
  }

  /// Gets a stream by ID.
  PrologStream? getStreamById(final String id) {
    return _streamsById[id];
  }

  /// Returns all open streams.
  Iterable<PrologStream> get allStreams => _streams.values;

  /// Registers a stream.
  void _registerStream(final PrologStream stream) {
    _streams[stream.properties.alias] = stream;
    _streamsById[stream.id] = stream;
  }

  /// Generates a unique stream ID.
  String _generateStreamId() {
    return 'stream_${_streamIdCounter++}';
  }

  /// Closes all non-standard streams.
  void closeAll() {
    final streamsToClose = _streams.values
        .where(
          (s) =>
              s != userInput && s != userOutput && s != userError && s.isOpen,
        )
        .toList();

    for (final stream in streamsToClose) {
      closeStream(stream);
    }
  }
}
