import '../terms/term.dart';
import '../terms/compound.dart';

/// Utility functions for clause manipulation.
class ClauseUtils {
  /// Expands a clause body into a list of goals.
  ///
  /// Conjunctions (,/2) are flattened into a flat list of goals.
  /// Example: (a, (b, c)) => [a, b, c]
  static List<Term> expandBody(final Term body) {
    if (body is Compound && body.functor.value == ',' && body.arity == 2) {
      return [...expandBody(body.args[0]), ...expandBody(body.args[1])];
    }

    return [body];
  }
}
