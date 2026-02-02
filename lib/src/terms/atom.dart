import 'term.dart';

/// A Prolog atom - an atomic constant.
///
/// Atoms are symbolic constants like: foo, 'hello world', [], etc.
/// Atoms are interned for efficiency - identical atoms share the same instance.
///
/// Examples: foo, bar, 'Hello World', [], true, fail
class Atom extends Term {
  /// The atom's name/value.
  final String value;

  /// Cache of interned atoms for efficiency.
  static final Map<String, Atom> _cache = {};

  /// Private constructor - use factory constructor instead.
  const Atom._(this.value);

  /// Creates or retrieves an interned atom with the given value.
  factory Atom(final String value) {
    return _cache.putIfAbsent(value, () => Atom._(value));
  }

  /// Common atom constants.
  static final nil = Atom('[]');
  static final true_ = Atom('true');
  static final false_ = Atom('false');
  static final fail = Atom('fail');
  static final cut = Atom('!');
  static final dot = Atom('.');
  static final cons = dot; // List constructor

  @override
  bool get isAtom => true;

  @override
  bool get isNil => this == nil;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Atom && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    // Simple heuristic: quote if contains spaces or special chars
    if (value.isEmpty) return "''";
    if (value == '[]') return '[]';

    final needsQuotes =
        value.contains(' ') ||
        value.contains("'") ||
        (!_isLowerStart(value) && value != '[]' && value != '!');

    if (needsQuotes) {
      // Escape single quotes
      final escaped = value.replaceAll("'", "\\'");
      return "'$escaped'";
    }

    return value;
  }

  /// Checks if a string starts with a lowercase letter.
  static bool _isLowerStart(final String s) {
    if (s.isEmpty) return false;
    final first = s.codeUnitAt(0);
    return first >= 97 && first <= 122; // 'a' to 'z'
  }

  /// Clears the atom cache (primarily for testing).
  static void clearCache() {
    _cache.clear();
  }
}
