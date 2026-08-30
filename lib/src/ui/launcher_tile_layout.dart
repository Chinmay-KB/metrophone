import '../models/pinned_tile.dart';

class LauncherTileSlot {
  const LauncherTileSlot({
    required this.tile,
    required this.index,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
  });

  final PinnedTile tile;
  final int index;
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
}

/// Packs persisted tiles into the first available cells of the Windows Phone
/// four-column grid while preserving the user's tile order.
List<LauncherTileSlot> packLauncherTiles(
  List<PinnedTile> tiles, {
  int columns = 4,
}) {
  assert(columns > 0);
  final occupied = <(int, int)>{};
  final slots = <LauncherTileSlot>[];

  for (var index = 0; index < tiles.length; index++) {
    final tile = tiles[index];
    final (rowSpan, columnSpan) = switch (tile.size) {
      TileSize.small => (1, 1),
      TileSize.medium => (2, 2),
      TileSize.wide => (2, columns),
    };
    var row = 0;
    var placed = false;
    while (!placed) {
      for (var column = 0; column <= columns - columnSpan; column++) {
        if (_fits(
          occupied,
          row: row,
          column: column,
          rowSpan: rowSpan,
          columnSpan: columnSpan,
        )) {
          for (var y = row; y < row + rowSpan; y++) {
            for (var x = column; x < column + columnSpan; x++) {
              occupied.add((y, x));
            }
          }
          slots.add(
            LauncherTileSlot(
              tile: tile,
              index: index,
              row: row,
              column: column,
              rowSpan: rowSpan,
              columnSpan: columnSpan,
            ),
          );
          placed = true;
          break;
        }
      }
      if (!placed) row++;
    }
  }

  return List.unmodifiable(slots);
}

bool _fits(
  Set<(int, int)> occupied, {
  required int row,
  required int column,
  required int rowSpan,
  required int columnSpan,
}) {
  for (var y = row; y < row + rowSpan; y++) {
    for (var x = column; x < column + columnSpan; x++) {
      if (occupied.contains((y, x))) return false;
    }
  }
  return true;
}
