import 'package:flutter/material.dart';

import '../../constants.dart';

/// A `SpatialHashGrid` is a utility class that provides a spatial hashing system.
/// It organizes and queries rectangular objects (`Rect`) within a 2D grid,
/// allowing for efficient spatial lookups.
///
/// The grid divides the 2D space into cells of fixed size (`cellSize`). Each
/// cell maintains references to objects (referred to as "nodes") that overlap
/// with that cell.
class SpatialHashGrid {
  /// The fixed size of each grid cell.
  final double cellSize;

  /// The main grid structure that maps grid cell indices to a set of nodes.
  /// Each node is represented as a record containing an identifier (`String`)
  /// and its bounding rectangle (`Rect`).
  final Map<({int x, int y}), Set<({String id, Rect rect})>> grid = {};

  /// Maps each node's identifier to the set of grid cells it occupies.
  final Map<String, Set<({int x, int y})>> nodeToCells = {};

  /// Constructs a `SpatialHashGrid` using a predefined cell size defined in `constants.dart`.
  SpatialHashGrid() : cellSize = kSpatialHashingCellSize;

  /// Calculates the grid cell index for a given point in 2D space.
  ({int x, int y}) _getGridIndex(Offset point) {
    return (
      x: (point.dx / cellSize).floor(),
      y: (point.dy / cellSize).floor(),
    );
  }

  /// Determines all grid cells that a given rectangle (`Rect`) overlaps.
  ///
  /// Returns a set of cell indices `({int x, int y})`.
  Set<({int x, int y})> _getCoveredCells(Rect rect) {
    final ({int x, int y}) topLeft = _getGridIndex(rect.topLeft);
    final ({int x, int y}) bottomRight = _getGridIndex(rect.bottomRight);

    final Set<({int x, int y})> cells = {};

    for (int x = topLeft.x; x <= bottomRight.x; x++) {
      for (int y = topLeft.y; y <= bottomRight.y; y++) {
        cells.add((x: x, y: y));
      }
    }

    return cells;
  }

  /// Inserts a new node into the spatial hash grid.
  ///
  /// A node is represented by a record `(String id, Rect rect)`, where:
  /// - `node.id` is the unique identifier of the node.
  /// - `node.rect` is the bounding rectangle of the node.
  void insert(({String id, Rect rect}) node) {
    final Set<({int x, int y})> cells = _getCoveredCells(node.rect);

    for (final ({int x, int y}) cell in cells) {
      if (!grid.containsKey(cell)) {
        grid[cell] = {};
      }

      grid[cell]!.add(node);
    }

    nodeToCells[node.id] = cells;
  }

  /// Removes a node from the spatial hash grid by its identifier (`nodeId`).
  void remove(String nodeId) {
    if (nodeToCells.containsKey(nodeId)) {
      for (final ({int x, int y}) cell in nodeToCells[nodeId]!) {
        if (grid.containsKey(cell)) {
          grid[cell]!.removeWhere((node) => node.id == nodeId);
        }
      }

      nodeToCells.remove(nodeId);
    }
  }

  /// Clears all data from the spatial hash grid.
  void clear() {
    grid.clear();
    nodeToCells.clear();
  }

  /// Queries the spatial hash grid for all node identifiers (`String`)
  /// whose rectangles overlap with a given bounding rectangle (`bounds`).
  ///
  /// Returns a set of node identifiers that are within or overlap the bounds.
  Set<String> queryNodeIdsInArea(Rect bounds) {
    final Set<String> nodeIds = {};

    final Set<({int x, int y})> cells = _getCoveredCells(bounds);

    for (final ({int x, int y}) cell in cells) {
      if (grid.containsKey(cell)) {
        for (final ({String id, Rect rect}) node in grid[cell]!) {
          if (bounds.overlaps(node.rect)) {
            nodeIds.add(node.id);
          }
        }
      }
    }

    return nodeIds;
  }

  /// Computes the total number of node references stored in the grid.
  ///
  /// Useful for debugging or performance analysis.
  int get numRefs => grid.values.fold(0, (acc, nodes) => acc + nodes.length);
}
