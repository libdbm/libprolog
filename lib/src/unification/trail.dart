import '../terms/variable.dart';
import 'substitution.dart';

/// A trail for recording variable bindings during unification.
///
/// The trail enables backtracking by recording which variables were bound
/// at each choice point, allowing us to undo bindings when backtracking.
///
/// Trail entries are organized in a stack structure, with markers indicating
/// choice points that can be undone.
class Trail {
  /// Stack of bound variables in chronological order.
  final List<Variable> _trail;

  /// Stack of trail markers (indices) for choice points.
  final List<int> _markers;

  /// Creates an empty trail.
  Trail() : _trail = [], _markers = [];

  /// Returns the current size of the trail.
  int get size => _trail.length;

  /// Returns true if the trail is empty.
  bool get isEmpty => _trail.isEmpty;

  /// Records a variable binding on the trail.
  ///
  /// Should be called whenever a variable is bound during unification.
  void record(final Variable variable) {
    _trail.add(variable);
  }

  /// Creates a choice point marker at the current trail position.
  ///
  /// Returns the marker index that can be used to undo to this point.
  int mark() {
    final marker = _trail.length;
    _markers.add(marker);
    return marker;
  }

  /// Removes the most recent choice point marker without undoing bindings.
  ///
  /// Used when a choice point succeeds and no longer needs to be backtracked.
  void commit() {
    if (_markers.isNotEmpty) {
      _markers.removeLast();
    }
  }

  /// Undoes all variable bindings back to the most recent choice point.
  ///
  /// Removes bindings from the substitution for all variables recorded
  /// since the last marker.
  void undo(final Substitution substitution) {
    if (_markers.isEmpty) {
      // No choice point - clear everything
      _undoTo(0, substitution);
      return;
    }

    final marker = _markers.removeLast();
    _undoTo(marker, substitution);
  }

  /// Undoes bindings back to a specific marker position.
  ///
  /// This is used when backtracking to a choice point that saved a specific marker.
  void undoToMarker(final int marker, final Substitution substitution) {
    // Remove any markers that are at or after this position
    while (_markers.isNotEmpty && _markers.last >= marker) {
      _markers.removeLast();
    }

    // Undo bindings back to the marker position
    _undoTo(marker, substitution);
  }

  /// Undoes bindings back to a specific trail position.
  void _undoTo(final int position, final Substitution substitution) {
    while (_trail.length > position) {
      final variable = _trail.removeLast();
      substitution.unbind(variable);
    }
  }

  /// Resets the trail to empty state.
  void reset() {
    _trail.clear();
    _markers.clear();
  }

  /// Returns the number of choice points.
  int get markerCount => _markers.length;

  @override
  String toString() {
    return 'Trail(size: $size, markers: $_markers)';
  }
}
