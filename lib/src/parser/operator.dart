/// Operator associativity and position.
///
/// ISO Prolog defines 7 operator types based on associativity and position.
enum OperatorType {
  /// Prefix, non-associative (e.g., \+ P)
  fx,

  /// Prefix, right-associative (e.g., - - X)
  fy,

  /// Infix, non-associative (e.g., X =:= Y)
  xfx,

  /// Infix, right-associative (e.g., X = Y = Z parses as X = (Y = Z))
  xfy,

  /// Infix, left-associative (e.g., X + Y + Z parses as (X + Y) + Z)
  yfx,

  /// Postfix, non-associative
  xf,

  /// Postfix, left-associative
  yf,
}

/// An operator definition.
///
/// Precedence ranges from 1 (tightest) to 1200 (loosest).
/// Terms have precedence 0, functors 0.
class Operator {
  final String name;
  final int precedence;
  final OperatorType type;

  const Operator(this.name, this.precedence, this.type);

  /// Returns true if this is a prefix operator.
  bool get isPrefix => type == OperatorType.fx || type == OperatorType.fy;

  /// Returns true if this is an infix operator.
  bool get isInfix =>
      type == OperatorType.xfx ||
      type == OperatorType.xfy ||
      type == OperatorType.yfx;

  /// Returns true if this is a postfix operator.
  bool get isPostfix => type == OperatorType.xf || type == OperatorType.yf;

  @override
  String toString() => 'op($precedence, $type, $name)';
}

/// Operator table for parser.
///
/// Maintains operator definitions for precedence parsing.
/// Supports dynamic operators (op/3 directive).
class OperatorTable {
  /// Map from operator name to list of operator definitions.
  /// An operator can have multiple definitions (e.g., + as prefix and infix).
  final Map<String, List<Operator>> _operators = {};

  /// Creates an operator table with standard ISO Prolog operators.
  OperatorTable() {
    _initializeStandardOperators();
  }

  /// Adds or updates an operator definition.
  void define(
    final String name,
    final int precedence,
    final OperatorType type,
  ) {
    if (precedence < 1 || precedence > 1200) {
      throw ArgumentError('Precedence must be between 1 and 1200');
    }

    final operators = _operators.putIfAbsent(name, () => []);

    // Remove existing operator of same type
    operators.removeWhere((op) => op.type == type);

    // Add new definition
    operators.add(Operator(name, precedence, type));
  }

  /// Removes an operator definition.
  void remove(final String name, final OperatorType type) {
    final operators = _operators[name];
    if (operators != null) {
      operators.removeWhere((op) => op.type == type);
      if (operators.isEmpty) {
        _operators.remove(name);
      }
    }
  }

  /// Returns all definitions for an operator name.
  List<Operator> lookup(final String name) {
    return _operators[name] ?? [];
  }

  /// Returns prefix operator definition if it exists.
  Operator? lookupPrefix(final String name) {
    return lookup(name).where((op) => op.isPrefix).firstOrNull;
  }

  /// Returns infix operator definition if it exists.
  Operator? lookupInfix(final String name) {
    return lookup(name).where((op) => op.isInfix).firstOrNull;
  }

  /// Returns postfix operator definition if it exists.
  Operator? lookupPostfix(final String name) {
    return lookup(name).where((op) => op.isPostfix).firstOrNull;
  }

  /// Initializes standard ISO Prolog operators.
  void _initializeStandardOperators() {
    // Arithmetic operators
    define('+', 500, OperatorType.yfx);
    define('-', 500, OperatorType.yfx);
    define('*', 400, OperatorType.yfx);
    define('/', 400, OperatorType.yfx);
    define('//', 400, OperatorType.yfx);
    define('mod', 400, OperatorType.yfx);
    define('rem', 400, OperatorType.yfx);
    define('**', 200, OperatorType.xfx);
    define('^', 200, OperatorType.xfy);

    // Unary arithmetic
    define('+', 200, OperatorType.fy);
    define('-', 200, OperatorType.fy);

    // Bitwise
    define('/\\', 500, OperatorType.yfx);
    define('\\/', 500, OperatorType.yfx);
    define('><', 500, OperatorType.yfx);
    define('>>', 400, OperatorType.yfx);
    define('<<', 400, OperatorType.yfx);
    define('\\', 200, OperatorType.fy);

    // Comparison
    define('=:=', 700, OperatorType.xfx);
    define('=\\=', 700, OperatorType.xfx);
    define('<', 700, OperatorType.xfx);
    define('>', 700, OperatorType.xfx);
    define('=<', 700, OperatorType.xfx);
    define('>=', 700, OperatorType.xfx);

    // Term comparison
    define('==', 700, OperatorType.xfx);
    define('\\==', 700, OperatorType.xfx);
    define('@<', 700, OperatorType.xfx);
    define('@>', 700, OperatorType.xfx);
    define('@=<', 700, OperatorType.xfx);
    define('@>=', 700, OperatorType.xfx);

    // Unification
    define('=', 700, OperatorType.xfx);
    define('\\=', 700, OperatorType.xfx);
    define('=..', 700, OperatorType.xfx);

    // Control
    define(',', 1000, OperatorType.xfy); // Conjunction
    define(';', 1100, OperatorType.xfy); // Disjunction/if-then-else
    define('|', 1100, OperatorType.xfy); // Disjunction (alternative syntax)
    define('->', 1050, OperatorType.xfy); // If-then
    define('*->', 1050, OperatorType.xfy); // Soft cut

    // Clauses
    define(':-', 1200, OperatorType.xfx); // Rule/directive
    define(':-', 1200, OperatorType.fx); // Directive
    define('?-', 1200, OperatorType.fx); // Query

    // DCG
    define('-->', 1200, OperatorType.xfx); // Grammar rule

    // Negation
    define('\\+', 900, OperatorType.fy); // Negation as failure

    // Type testing (used in some implementations)
    define('is', 700, OperatorType.xfx);

    // Module system (ISO extension)
    define(':', 600, OperatorType.xfy);
  }
}

/// Extension to add firstOrNull to Iterable.
extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
