import '../terms/atom.dart';
import '../terms/compound.dart';
import '../terms/number.dart';
import '../terms/variable.dart';
import '../unification/unify.dart';
import '../utils/term_comparison.dart';
import 'builtin.dart';

/// Registers list manipulation built-ins.
void registerListPredicates(final BuiltinRegistry registry) {
  registry.register('length', 2, _length);
  registry.register('append', 3, _append);
  registry.register('member', 2, _member);
  registry.register('reverse', 2, _reverse);
  registry.register('nth0', 3, _nth0);
  registry.register('nth1', 3, _nth1);
  registry.register('nth', 3, _nth1); // Alias for nth1
  registry.register('last', 2, _last);
  registry.register('select', 3, _select);
  registry.register('sumlist', 2, _sumlist);
  registry.register('sum_list', 2, _sumlist); // ISO alias
  registry.register('max_list', 2, _maxList);
  registry.register('min_list', 2, _minList);
  registry.register('msort', 2, _msort);
  registry.register('sort', 2, _sort);
}

/// Implements length/2: length(?List, ?Length).
///
/// True if Length is the number of elements in List.
BuiltinResult _length(final BuiltinContext context) {
  final list = context.arg(0);
  final length = context.arg(1);

  // Mode: +list, ?length (calculate length)
  if (list != Atom.nil && list is! Variable) {
    final elements = Compound.toList(list);
    if (elements == null) {
      return const BuiltinFailure();
    }

    final len = PrologInteger(elements.length);
    return context.unifyAndReturn(length, len);
  }

  // Mode: ?list, +length (generate list of variables)
  if (length is PrologInteger) {
    if (length.value < 0) {
      return const BuiltinFailure();
    }

    final vars = List.generate(length.value, (i) => Variable('_L$i'));
    final generatedList = Compound.fromList(vars);

    return context.unifyAndReturn(list, generatedList);
  }

  return const BuiltinFailure();
}

/// Implements append/3: append(?List1, ?List2, ?List3).
///
/// True if List3 is the concatenation of List1 and List2.
///
/// NOTE: This implementation supports common modes but is not fully non-deterministic.
/// Modes like append(?X, ?Y, [1,2,3]) that generate multiple solutions require
/// BuiltinStream support, which is not yet implemented.
BuiltinResult _append(final BuiltinContext context) {
  final list1 = context.arg(0);
  final list2 = context.arg(1);
  final list3 = context.arg(2);

  // Mode: +list1, +list2, ?list3 (concatenate)
  if ((list1 == Atom.nil ||
          (list1 is Compound && !list1.args.any((a) => a is Variable))) &&
      (list2 == Atom.nil ||
          (list2 is Compound && !list2.args.any((a) => a is Variable)))) {
    final elems1 = Compound.toList(list1) ?? [];
    final elems2 = Compound.toList(list2) ?? [];

    final result = Compound.fromList([...elems1, ...elems2]);
    return context.unifyAndReturn(list3, result);
  }

  // Mode: +list1, ?list2, +list3 (find suffix)
  if (list3 != Atom.nil && list3 is! Variable) {
    final elems1 = Compound.toList(list1);
    final elems3 = Compound.toList(list3);

    if (elems1 != null && elems3 != null) {
      if (elems1.length > elems3.length) {
        return const BuiltinFailure();
      }

      // Check if list1 is a prefix of list3 using proper unification
      final marker = context.trail.mark();
      var isPrefix = true;
      for (var i = 0; i < elems1.length; i++) {
        if (!Unify.unify(
          elems1[i],
          elems3[i],
          context.substitution,
          context.trail,
        )) {
          context.trail.undoToMarker(marker, context.substitution);
          isPrefix = false;
          break;
        }
      }

      if (!isPrefix) {
        return const BuiltinFailure();
      }

      // Prefix matched - commit the marker
      context.trail.commit();

      // Remainder is list2
      final remainder = elems3.sublist(elems1.length);
      final result = Compound.fromList(remainder);

      return Unify.unify(list2, result, context.substitution, context.trail)
          ? const BuiltinSuccess()
          : const BuiltinFailure();
    }
  }

  // Other modes would require non-deterministic search
  return const BuiltinFailure();
}

/// Implements member/2: member(?Element, ?List).
///
/// True if Element is a member of List.
///
/// NOTE: This is a simplified deterministic implementation that only finds
/// the first match. A full ISO-compliant implementation would be non-deterministic,
/// creating choice points for each matching element to support backtracking.
/// This requires BuiltinStream support, which is not yet implemented.
BuiltinResult _member(final BuiltinContext context) {
  final element = context.arg(0);
  final list = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  // Check if element unifies with any list member
  // TODO: Make non-deterministic by returning BuiltinStream with choice points
  for (final elem in elements) {
    final marker = context.trail.mark();
    if (Unify.unify(element, elem, context.substitution, context.trail)) {
      // Found a match - commit the marker since unification succeeded
      context.trail.commit();
      return const BuiltinSuccess();
    }
    // Undo the unification attempt for next iteration
    context.trail.undoToMarker(marker, context.substitution);
  }

  return const BuiltinFailure();
}

/// Implements reverse/2: reverse(?List1, ?List2).
///
/// True if List2 is the reverse of List1.
BuiltinResult _reverse(final BuiltinContext context) {
  final list1 = context.arg(0);
  final list2 = context.arg(1);

  // Mode: +list1, ?list2
  if (list1 != Atom.nil && list1 is! Variable) {
    final elements = Compound.toList(list1);
    if (elements == null) {
      return const BuiltinFailure();
    }

    final reversed = Compound.fromList(elements.reversed.toList());
    return context.unifyAndReturn(list2, reversed);
  }

  // Mode: ?list1, +list2
  if (list2 != Atom.nil && list2 is! Variable) {
    final elements = Compound.toList(list2);
    if (elements == null) {
      return const BuiltinFailure();
    }

    final reversed = Compound.fromList(elements.reversed.toList());
    return context.unifyAndReturn(list1, reversed);
  }

  return const BuiltinFailure();
}

/// Implements nth0/3: nth0(?N, ?List, ?Element).
///
/// True if Element is the Nth element of List (0-indexed).
BuiltinResult _nth0(final BuiltinContext context) {
  final n = context.arg(0);
  final list = context.arg(1);
  final element = context.arg(2);

  if (n is! PrologInteger) {
    return const BuiltinFailure();
  }

  if (n.value < 0) {
    return const BuiltinFailure();
  }

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  if (n.value >= elements.length) {
    return const BuiltinFailure();
  }

  return context.unifyAndReturn(element, elements[n.value]);
}

/// Implements nth1/3: nth1(?N, ?List, ?Element).
///
/// True if Element is the Nth element of List (1-indexed).
BuiltinResult _nth1(final BuiltinContext context) {
  final n = context.arg(0);
  final list = context.arg(1);
  final element = context.arg(2);

  if (n is! PrologInteger) {
    return const BuiltinFailure();
  }

  if (n.value < 1) {
    return const BuiltinFailure();
  }

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  final index = n.value - 1;
  if (index >= elements.length) {
    return const BuiltinFailure();
  }

  return context.unifyAndReturn(element, elements[index]);
}

/// Implements last/2: last(?List, ?Element).
///
/// True if Element is the last element of List.
BuiltinResult _last(final BuiltinContext context) {
  final list = context.arg(0);
  final element = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null || elements.isEmpty) {
    return const BuiltinFailure();
  }

  return context.unifyAndReturn(element, elements.last);
}

/// Implements select/3: select(?Element, ?List, ?Rest).
///
/// True if List contains Element and Rest is List with Element removed.
/// NOTE: Simplified deterministic version - finds first match only.
BuiltinResult _select(final BuiltinContext context) {
  final element = context.arg(0);
  final list = context.arg(1);
  final rest = context.arg(2);

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  // Find first element that unifies
  for (var i = 0; i < elements.length; i++) {
    final marker = context.trail.mark();
    if (Unify.unify(
      element,
      elements[i],
      context.substitution,
      context.trail,
    )) {
      // Create list without this element
      final remaining = [...elements.sublist(0, i), ...elements.sublist(i + 1)];
      final result = Compound.fromList(remaining);

      if (Unify.unify(rest, result, context.substitution, context.trail)) {
        context.trail.commit();
        return const BuiltinSuccess();
      }
    }
    context.trail.undoToMarker(marker, context.substitution);
  }

  return const BuiltinFailure();
}

/// Implements sumlist/2: sumlist(+List, ?Sum).
///
/// True if Sum is the sum of all numbers in List.
BuiltinResult _sumlist(final BuiltinContext context) {
  final list = context.arg(0);
  final sum = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  var total = 0.0;
  var hasFloat = false;

  for (final elem in elements) {
    if (elem is PrologInteger) {
      total += elem.value;
    } else if (elem is PrologFloat) {
      total += elem.value;
      hasFloat = true;
    } else {
      return const BuiltinFailure();
    }
  }

  final result = hasFloat ? PrologFloat(total) : PrologInteger(total.toInt());
  return context.unifyAndReturn(sum, result);
}

/// Implements max_list/2: max_list(+List, ?Max).
///
/// True if Max is the maximum element in List.
BuiltinResult _maxList(final BuiltinContext context) {
  final list = context.arg(0);
  final max = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null || elements.isEmpty) {
    return const BuiltinFailure();
  }

  PrologNumber? maxValue;

  for (final elem in elements) {
    if (elem is! PrologNumber) {
      return const BuiltinFailure();
    }

    if (maxValue == null) {
      maxValue = elem;
    } else {
      final comparison = _compareNumbers(elem, maxValue);
      if (comparison > 0) {
        maxValue = elem;
      }
    }
  }

  return context.unifyAndReturn(max, maxValue!);
}

/// Implements min_list/2: min_list(+List, ?Min).
///
/// True if Min is the minimum element in List.
BuiltinResult _minList(final BuiltinContext context) {
  final list = context.arg(0);
  final min = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null || elements.isEmpty) {
    return const BuiltinFailure();
  }

  PrologNumber? minValue;

  for (final elem in elements) {
    if (elem is! PrologNumber) {
      return const BuiltinFailure();
    }

    if (minValue == null) {
      minValue = elem;
    } else {
      final comparison = _compareNumbers(elem, minValue);
      if (comparison < 0) {
        minValue = elem;
      }
    }
  }

  return context.unifyAndReturn(min, minValue!);
}

/// Implements msort/2: msort(+List, ?Sorted).
///
/// Sorts List using merge sort, preserving duplicates.
/// Uses standard term ordering (ISO compliant).
BuiltinResult _msort(final BuiltinContext context) {
  final list = context.arg(0);
  final sorted = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  // Use ISO-compliant term comparison (uses variable.id not variable.name)
  final sortedElements = [...elements];
  sortedElements.sort(TermComparison.compare);

  final result = Compound.fromList(sortedElements);
  return context.unifyAndReturn(sorted, result);
}

/// Implements sort/2: sort(+List, ?Sorted).
///
/// Sorts List and removes duplicates using standard term ordering.
BuiltinResult _sort(final BuiltinContext context) {
  final list = context.arg(0);
  final sorted = context.arg(1);

  final elements = Compound.toList(list);
  if (elements == null) {
    return const BuiltinFailure();
  }

  // Use ISO-compliant term comparison and deduplication
  final sortedElements = TermComparison.sort(elements);
  final unique = TermComparison.removeDuplicates(sortedElements);

  final result = Compound.fromList(unique);
  return context.unifyAndReturn(sorted, result);
}

/// Compares two numbers for ordering.
int _compareNumbers(final PrologNumber a, final PrologNumber b) {
  final aVal = a is PrologInteger
      ? a.value.toDouble()
      : (a as PrologFloat).value;
  final bVal = b is PrologInteger
      ? b.value.toDouble()
      : (b as PrologFloat).value;

  return aVal.compareTo(bVal);
}
