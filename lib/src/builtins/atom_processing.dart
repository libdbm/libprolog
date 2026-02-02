import '../terms/term.dart';
import '../terms/atom.dart';
import '../terms/number.dart';
import '../terms/compound.dart';
import '../terms/variable.dart';
import 'builtin.dart';

/// Creates an ISO instantiation_error.
BuiltinError _instantiationError(final String context) {
  return BuiltinError(
    Compound(Atom('error'), [Atom('instantiation_error'), Atom(context)]),
  );
}

/// Creates an ISO type_error.
BuiltinError _typeError(
  final String expected,
  final Term culprit,
  final String context,
) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('type_error'), [Atom(expected), culprit]),
      Atom(context),
    ]),
  );
}

/// Creates an ISO domain_error.
BuiltinError _domainError(
  final String domain,
  final Term culprit,
  final String context,
) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('domain_error'), [Atom(domain), culprit]),
      Atom(context),
    ]),
  );
}

/// Creates an ISO representation_error.
BuiltinError _representationError(final String flag, final String context) {
  return BuiltinError(
    Compound(Atom('error'), [
      Compound(Atom('representation_error'), [Atom(flag)]),
      Atom(context),
    ]),
  );
}

/// Registers ISO Prolog atom and string processing built-in predicates.
///
/// Provides conversion and manipulation of atoms, characters, and numbers.
/// All predicates follow ISO/IEC 13211-1:1995 standard.
///
/// **Predicates registered:**
/// - `atom_length/2` - Get length of atom
/// - `atom_concat/3` - Concatenate/split atoms
/// - `atom_chars/2` - Convert between atom and char list
/// - `atom_codes/2` - Convert between atom and code list
/// - `char_code/2` - Convert single char to/from code
/// - `number_chars/2` - Convert number to/from char list
/// - `number_codes/2` - Convert number to/from code list
/// - `sub_atom/5` - Extract substring with position info
///
/// **Examples:**
/// ```prolog
/// ?- atom_chars(hello, L).     % L=[h,e,l,l,o]
/// ?- atom_concat(foo, bar, X). % X=foobar
/// ?- char_code(a, C).          % C=97
/// ```
void registerAtomProcessingBuiltins(final BuiltinRegistry registry) {
  registry.register('atom_length', 2, _atomLength);
  registry.register('atom_concat', 3, _atomConcat);
  registry.register('atom_chars', 2, _atomChars);
  registry.register('atom_codes', 2, _atomCodes);
  registry.register('char_code', 2, _charCode);
  registry.register('number_chars', 2, _numberChars);
  registry.register('number_codes', 2, _numberCodes);
  registry.register('sub_atom', 5, _subAtom);
}

/// Implements atom_length/2: atom_length(+Atom, ?Length).
///
/// Unifies Length with the number of characters in Atom.
/// ISO errors:
/// - instantiation_error if Atom is a variable
/// - type_error(atom, Atom) if Atom is not an atom
/// - type_error(integer, Length) if Length is not an integer or variable
/// - domain_error(not_less_than_zero, Length) if Length is negative
BuiltinResult _atomLength(final BuiltinContext context) {
  final atom = context.arg(0);
  final length = context.arg(1);

  // ISO: Atom must be instantiated
  if (atom is Variable) {
    return _instantiationError('atom_length/2');
  }

  // ISO: Atom must be an atom
  if (atom is! Atom) {
    return _typeError('atom', atom, 'atom_length/2');
  }

  // ISO: If Length is bound, must be integer
  if (length is! Variable) {
    if (length is! PrologInteger) {
      return _typeError('integer', length, 'atom_length/2');
    }
    // ISO: Length must be non-negative
    if (length.value < 0) {
      return _domainError('not_less_than_zero', length, 'atom_length/2');
    }
  }

  final len = PrologInteger(atom.value.length);
  return context.unifyAndReturn(length, len);
}

/// Implements atom_concat/3: atom_concat(?Atom1, ?Atom2, ?Atom3).
///
/// True if Atom3 is the concatenation of Atom1 and Atom2.
/// Can work in multiple modes.
/// ISO errors:
/// - instantiation_error if insufficient arguments are instantiated
/// - type_error(atom, X) if any bound argument is not an atom
BuiltinResult _atomConcat(final BuiltinContext context) {
  final atom1 = context.arg(0);
  final atom2 = context.arg(1);
  final atom3 = context.arg(2);

  // Check for type errors on bound arguments
  if (atom1 is! Variable && atom1 is! Atom) {
    return _typeError('atom', atom1, 'atom_concat/3');
  }
  if (atom2 is! Variable && atom2 is! Atom) {
    return _typeError('atom', atom2, 'atom_concat/3');
  }
  if (atom3 is! Variable && atom3 is! Atom) {
    return _typeError('atom', atom3, 'atom_concat/3');
  }

  // Mode: +atom1, +atom2, ?atom3 (concatenate)
  if (atom1 is Atom && atom2 is Atom) {
    final result = Atom(atom1.value + atom2.value);
    return context.unifyAndReturn(atom3, result);
  }

  // Mode: +atom1, ?atom2, +atom3 (split with known prefix)
  if (atom1 is Atom && atom3 is Atom) {
    if (atom3.value.startsWith(atom1.value)) {
      final suffix = atom3.value.substring(atom1.value.length);
      return context.unifyAndReturn(atom2, Atom(suffix));
    }
    return const BuiltinFailure();
  }

  // Mode: ?atom1, +atom2, +atom3 (split with known suffix)
  if (atom2 is Atom && atom3 is Atom) {
    if (atom3.value.endsWith(atom2.value)) {
      final prefix = atom3.value.substring(
        0,
        atom3.value.length - atom2.value.length,
      );
      return context.unifyAndReturn(atom1, Atom(prefix));
    }
    return const BuiltinFailure();
  }

  // ISO: At least one of (Atom1, Atom2) or Atom3 must be instantiated
  // If Atom3 is variable and either Atom1 or Atom2 is variable, instantiation_error
  if (atom3 is Variable) {
    return _instantiationError('atom_concat/3');
  }

  // Mode: ?atom1, ?atom2, +atom3 (generate all splits) - non-deterministic
  // For now, fail on this mode (would need BuiltinStream)
  return const BuiltinFailure();
}

/// Implements atom_chars/2: atom_chars(?Atom, ?Chars).
///
/// Converts between atom and list of single-character atoms.
/// ISO errors:
/// - instantiation_error if both Atom and Chars are variables
/// - type_error(atom, Atom) if Atom is bound but not an atom
/// - type_error(list, Chars) if Chars is bound but not a list
/// - type_error(character, Elem) if Chars contains non-character element
BuiltinResult _atomChars(final BuiltinContext context) {
  final atom = context.arg(0);
  final chars = context.arg(1);

  // ISO: Type check on Atom if bound
  if (atom is! Variable && atom is! Atom) {
    return _typeError('atom', atom, 'atom_chars/2');
  }

  // Mode: +atom, ?chars (atom to list)
  if (atom is Atom) {
    final charList = atom.value.split('').map((c) => Atom(c)).toList();
    final prologList = Compound.fromList(charList);
    return context.unifyAndReturn(chars, prologList);
  }

  // ISO: If Atom is variable, Chars must be instantiated
  if (chars is Variable) {
    return _instantiationError('atom_chars/2');
  }

  // Mode: ?atom, +chars (list to atom)
  if (chars is Compound || chars is Atom) {
    final elements = Compound.toList(chars);
    if (elements == null) {
      return _typeError('list', chars, 'atom_chars/2');
    }

    final buffer = StringBuffer();
    for (final elem in elements) {
      // Each element must be a single-character atom
      if (elem is Variable) {
        return _instantiationError('atom_chars/2');
      }
      if (elem is! Atom || elem.value.length != 1) {
        return _typeError('character', elem, 'atom_chars/2');
      }
      buffer.write(elem.value);
    }

    return context.unifyAndReturn(atom, Atom(buffer.toString()));
  }

  return _typeError('list', chars, 'atom_chars/2');
}

/// Implements atom_codes/2: atom_codes(?Atom, ?Codes).
///
/// Converts between atom and list of character codes.
/// ISO errors:
/// - instantiation_error if both Atom and Codes are variables
/// - type_error(atom, Atom) if Atom is bound but not an atom
/// - type_error(list, Codes) if Codes is bound but not a list
/// - type_error(integer, Elem) if Codes contains non-integer element
/// - representation_error(character_code) if code is out of valid range
BuiltinResult _atomCodes(final BuiltinContext context) {
  final atom = context.arg(0);
  final codes = context.arg(1);

  // ISO: Type check on Atom if bound
  if (atom is! Variable && atom is! Atom) {
    return _typeError('atom', atom, 'atom_codes/2');
  }

  // Mode: +atom, ?codes (atom to code list)
  if (atom is Atom) {
    final codeList = atom.value.codeUnits.map((c) => PrologInteger(c)).toList();
    final prologList = Compound.fromList(codeList);
    return context.unifyAndReturn(codes, prologList);
  }

  // ISO: If Atom is variable, Codes must be instantiated
  if (codes is Variable) {
    return _instantiationError('atom_codes/2');
  }

  // Mode: ?atom, +codes (code list to atom)
  if (codes is Compound || codes is Atom) {
    final elements = Compound.toList(codes);
    if (elements == null) {
      return _typeError('list', codes, 'atom_codes/2');
    }

    final codeUnits = <int>[];
    for (final elem in elements) {
      // Each element must be an integer
      if (elem is Variable) {
        return _instantiationError('atom_codes/2');
      }
      if (elem is! PrologInteger) {
        return _typeError('integer', elem, 'atom_codes/2');
      }
      // Check for valid character code range
      if (elem.value < 0 || elem.value > 0x10FFFF) {
        return _representationError('character_code', 'atom_codes/2');
      }
      codeUnits.add(elem.value);
    }

    final result = String.fromCharCodes(codeUnits);
    return context.unifyAndReturn(atom, Atom(result));
  }

  return _typeError('list', codes, 'atom_codes/2');
}

/// Implements char_code/2: char_code(?Char, ?Code).
///
/// Converts between single-character atom and its code.
/// ISO errors:
/// - instantiation_error if both Char and Code are variables
/// - type_error(character, Char) if Char is bound but not a single character
/// - type_error(integer, Code) if Code is bound but not an integer
/// - representation_error(character_code) if Code is out of valid range
BuiltinResult _charCode(final BuiltinContext context) {
  final char = context.arg(0);
  final code = context.arg(1);

  // Mode: +char, ?code (char to code)
  if (char is Atom) {
    // ISO: Char must be a single character
    if (char.value.length != 1) {
      return _typeError('character', char, 'char_code/2');
    }
    final charCode = PrologInteger(char.value.codeUnitAt(0));
    return context.unifyAndReturn(code, charCode);
  }

  // ISO: If Char is not an atom but bound, type error
  if (char is! Variable) {
    return _typeError('character', char, 'char_code/2');
  }

  // Mode: ?char, +code (code to char)
  if (code is PrologInteger) {
    // ISO: Code must be in valid character code range
    if (code.value < 0 || code.value > 0x10FFFF) {
      return _representationError('character_code', 'char_code/2');
    }
    final character = Atom(String.fromCharCode(code.value));
    return context.unifyAndReturn(char, character);
  }

  // ISO: If Code is bound but not integer, type error
  if (code is! Variable) {
    return _typeError('integer', code, 'char_code/2');
  }

  // ISO: Both arguments are variables
  return _instantiationError('char_code/2');
}

/// Implements number_chars/2: number_chars(?Number, ?Chars).
///
/// Converts between number and list of character atoms.
BuiltinResult _numberChars(final BuiltinContext context) {
  final number = context.arg(0);
  final chars = context.arg(1);

  // Mode: +number, ?chars (number to char list)
  if (number is PrologNumber) {
    final str = number is PrologInteger
        ? number.value.toString()
        : (number as PrologFloat).value.toString();
    final charList = str.split('').map((c) => Atom(c)).toList();
    final prologList = Compound.fromList(charList);
    return context.unifyAndReturn(chars, prologList);
  }

  // Mode: ?number, +chars (char list to number)
  if (chars is Compound || chars is Atom) {
    final elements = Compound.toList(chars);
    if (elements == null) return const BuiltinFailure();

    final buffer = StringBuffer();
    for (final elem in elements) {
      if (elem is! Atom || elem.value.length != 1) {
        return const BuiltinFailure();
      }
      buffer.write(elem.value);
    }

    final str = buffer.toString();

    // Try parsing as integer first
    final intVal = int.tryParse(str);
    if (intVal != null) {
      return context.unifyAndReturn(number, PrologInteger(intVal));
    }

    // Try parsing as float
    final floatVal = double.tryParse(str);
    if (floatVal != null) {
      return context.unifyAndReturn(number, PrologFloat(floatVal));
    }

    return const BuiltinFailure();
  }

  return const BuiltinFailure();
}

/// Implements number_codes/2: number_codes(?Number, ?Codes).
///
/// Converts between number and list of character codes.
BuiltinResult _numberCodes(final BuiltinContext context) {
  final number = context.arg(0);
  final codes = context.arg(1);

  // Mode: +number, ?codes (number to code list)
  if (number is PrologNumber) {
    final str = number is PrologInteger
        ? number.value.toString()
        : (number as PrologFloat).value.toString();
    final codeList = str.codeUnits.map((c) => PrologInteger(c)).toList();
    final prologList = Compound.fromList(codeList);
    return context.unifyAndReturn(codes, prologList);
  }

  // Mode: ?number, +codes (code list to number)
  if (codes is Compound || codes is Atom) {
    final elements = Compound.toList(codes);
    if (elements == null) return const BuiltinFailure();

    final codeUnits = <int>[];
    for (final elem in elements) {
      if (elem is! PrologInteger) {
        return const BuiltinFailure();
      }
      codeUnits.add(elem.value);
    }

    final str = String.fromCharCodes(codeUnits);

    // Try parsing as integer first
    final intVal = int.tryParse(str);
    if (intVal != null) {
      return context.unifyAndReturn(number, PrologInteger(intVal));
    }

    // Try parsing as float
    final floatVal = double.tryParse(str);
    if (floatVal != null) {
      return context.unifyAndReturn(number, PrologFloat(floatVal));
    }

    return const BuiltinFailure();
  }

  return const BuiltinFailure();
}

/// Implements sub_atom/5: sub_atom(+Atom, ?Before, ?Length, ?After, ?SubAtom).
///
/// True if SubAtom is a substring of Atom with Before characters before it,
/// Length characters in it, and After characters after it.
/// ISO errors:
/// - instantiation_error if Atom is a variable
/// - type_error(atom, Atom) if Atom is not an atom
/// - type_error(atom, SubAtom) if SubAtom is bound but not an atom
/// - type_error(integer, Before/Length/After) if bound but not integer
/// - domain_error(not_less_than_zero, X) if Before/Length/After is negative
BuiltinResult _subAtom(final BuiltinContext context) {
  final atom = context.arg(0);
  final before = context.arg(1);
  final length = context.arg(2);
  final after = context.arg(3);
  final subAtom = context.arg(4);

  // ISO: Atom must be instantiated
  if (atom is Variable) {
    return _instantiationError('sub_atom/5');
  }

  // ISO: Atom must be an atom
  if (atom is! Atom) {
    return _typeError('atom', atom, 'sub_atom/5');
  }

  // ISO: Type check on SubAtom if bound
  if (subAtom is! Variable && subAtom is! Atom) {
    return _typeError('atom', subAtom, 'sub_atom/5');
  }

  // ISO: Type and domain checks on Before, Length, After
  for (final term in [before, length, after]) {
    if (term is! Variable) {
      if (term is! PrologInteger) {
        return _typeError('integer', term, 'sub_atom/5');
      }
      if (term.value < 0) {
        return _domainError('not_less_than_zero', term, 'sub_atom/5');
      }
    }
  }

  final atomStr = atom.value;
  final atomLen = atomStr.length;

  // If all are ground, just check
  if (before is PrologInteger &&
      length is PrologInteger &&
      after is PrologInteger &&
      subAtom is Atom) {
    if (before.value + length.value + after.value != atomLen) {
      return const BuiltinFailure();
    }

    final sub = atomStr.substring(before.value, before.value + length.value);
    return sub == subAtom.value
        ? const BuiltinSuccess()
        : const BuiltinFailure();
  }

  // Most common mode: +atom, +before, +length, +after, ?subatom
  if (before is PrologInteger &&
      length is PrologInteger &&
      after is PrologInteger) {
    if (before.value + length.value + after.value != atomLen) {
      return const BuiltinFailure();
    }

    final sub = atomStr.substring(before.value, before.value + length.value);
    return context.unifyAndReturn(subAtom, Atom(sub));
  }

  // Other modes would require non-deterministic results (BuiltinStream)
  // For now, fail on those modes
  return const BuiltinFailure();
}
