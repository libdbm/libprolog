/// Central export for all built-in predicates.
library;

export 'builtin.dart';
export 'arithmetic.dart';
export 'term_manipulation.dart';
export 'term_comparison.dart';
export 'atom_processing.dart';
export 'list_predicates.dart';
export 'database_builtins.dart';
export 'control.dart';
export 'meta.dart';
export 'io.dart';
export 'dcg.dart';

import 'builtin.dart';
import 'arithmetic.dart';
import 'term_manipulation.dart';
import 'term_comparison.dart';
import 'atom_processing.dart';
import 'list_predicates.dart';
import 'database_builtins.dart';
import 'control.dart';
import 'meta.dart';
import 'io.dart';
import 'dcg.dart';
import '../io/stream_manager.dart';
import '../database/database.dart';

/// Creates a registry with all standard ISO built-ins registered.
BuiltinRegistry createStandardRegistry({
  StreamManager? streamManager,
  Database? database,
}) {
  final registry = BuiltinRegistry.standard();
  registerArithmeticBuiltins(registry);
  registerTermManipulationBuiltins(registry);
  registerTermComparisonBuiltins(registry);
  registerAtomProcessingBuiltins(registry);
  registerListPredicates(registry);
  registerControlBuiltins(registry);
  registerMetaPredicates(registry);
  registerDCGBuiltins(registry);

  // Register I/O built-ins if stream manager is provided
  if (streamManager != null) {
    registerIOBuiltins(registry, streamManager);
  }

  // Register database built-ins if database is provided
  if (database != null) {
    registerDatabaseBuiltins(registry, database);
  }

  return registry;
}
