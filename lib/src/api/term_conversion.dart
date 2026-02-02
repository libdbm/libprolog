import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/compound.dart';
import '../terms/variable.dart';
import '../terms/number.dart';

/// Utilities for converting between Dart values and Prolog terms.
class TermConversion {
  /// Converts a Dart value to a Prolog term.
  ///
  /// Supports:
  /// - int → PrologInteger
  /// - double → PrologFloat
  /// - String → Atom
  /// - bool → Atom (true/false)
  /// - null → Atom (null)
  /// - List → Prolog list
  /// - Map → Prolog compound (key-value pairs)
  /// - Term → returns as-is
  static Term fromDart(final dynamic value) {
    if (value is Term) {
      return value;
    }

    if (value is int) {
      return PrologInteger(value);
    }

    if (value is double) {
      return PrologFloat(value);
    }

    if (value is String) {
      return Atom(value);
    }

    if (value is bool) {
      return Atom(value ? 'true' : 'false');
    }

    if (value == null) {
      return Atom('null');
    }

    if (value is List) {
      return _listFromDart(value);
    }

    if (value is Map) {
      return _mapFromDart(value);
    }

    throw ArgumentError(
      'Cannot convert $value (${value.runtimeType}) to Prolog term',
    );
  }

  /// Converts a Prolog term to a Dart value.
  ///
  /// - PrologInteger → int
  /// - PrologFloat → double
  /// - Atom → String (or bool for true/false, null for 'null')
  /// - Variable → String (variable name)
  /// - List → List
  /// - Compound → Map (for structured data) or stays as Compound
  static dynamic toDart(final Term term) {
    if (term is PrologInteger) {
      return term.value;
    }

    if (term is PrologFloat) {
      return term.value;
    }

    if (term is Atom) {
      // Special handling for booleans and null
      if (term.value == 'true') return true;
      if (term.value == 'false') return false;
      if (term.value == 'null') return null;
      return term.value;
    }

    if (term is Variable) {
      return '_${term.name}'; // Prefix with underscore to indicate unbound
    }

    if (term is Compound) {
      // Check if it's a list
      if (term.functor == Atom.dot && term.arity == 2) {
        return _listToDart(term);
      }

      // For other compounds, convert to a simple representation
      // Could be enhanced to convert specific functors to Maps
      return term; // Return as-is for now
    }

    return term;
  }

  /// Converts a Dart list to a Prolog list structure.
  ///
  /// Empty lists become the atom `[]`.
  /// Non-empty lists become nested `'.'(Head, Tail)` structures.
  ///
  /// Example: `[1, 2, 3]` → `'.'(1, '.'(2, '.'(3, [])))`
  static Term _listFromDart(final List list) {
    if (list.isEmpty) {
      return Atom.nil;
    }

    final elements = list.map(fromDart).toList();
    return Compound.fromList(elements);
  }

  /// Converts a Prolog list structure to a Dart list.
  ///
  /// Walks the `'.'(Head, Tail)` chain and collects elements.
  /// Handles improper lists by adding the tail as the final element.
  ///
  /// Example: `'.'(1, '.'(2, '.'(3, [])))` → `[1, 2, 3]`
  static List _listToDart(final Compound list) {
    final result = <dynamic>[];
    var current = list as Term;

    while (current is Compound &&
        current.functor == Atom.dot &&
        current.arity == 2) {
      result.add(toDart(current.args[0]));
      current = current.args[1];
    }

    // If tail is not nil, we have an improper list
    if (current != Atom.nil) {
      // Could handle improper lists differently
      result.add(toDart(current));
    }

    return result;
  }

  /// Converts a Dart Map to a Prolog compound structure.
  ///
  /// Creates `map([K1-V1, K2-V2, ...])` where each entry becomes
  /// a `-(Key, Value)` pair in a Prolog list.
  ///
  /// Example: `{a: 1, b: 2}` → `map([a-1, b-2])`
  static Term _mapFromDart(final Map map) {
    final pairs = <Term>[];

    for (final entry in map.entries) {
      final key = fromDart(entry.key);
      final value = fromDart(entry.value);
      pairs.add(Compound(Atom('-'), [key, value]));
    }

    return Compound(Atom('map'), [Compound.fromList(pairs)]);
  }

  /// Attempts to convert a term to a specific Dart type.
  ///
  /// Returns null if conversion is not possible.
  static T? tryConvert<T>(final Term term) {
    try {
      final value = toDart(term);
      if (value is T) {
        return value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
