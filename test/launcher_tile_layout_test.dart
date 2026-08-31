import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/models/pinned_tile.dart';
import 'package:metrophone/src/ui/launcher_tile_layout.dart';

void main() {
  test('packs small, medium, and wide tiles without changing order', () {
    final slots = packLauncherTiles(const [
      PinnedTile(
        packageName: 'medium',
        size: TileSize.medium,
        liveEnabled: true,
      ),
      PinnedTile(
        packageName: 'small-one',
        size: TileSize.small,
        liveEnabled: true,
      ),
      PinnedTile(
        packageName: 'small-two',
        size: TileSize.small,
        liveEnabled: true,
      ),
      PinnedTile(packageName: 'wide', size: TileSize.wide, liveEnabled: true),
    ]);

    expect(
      slots
          .map(
            (slot) => (
              slot.tile.packageName,
              slot.row,
              slot.column,
              slot.rowSpan,
              slot.columnSpan,
            ),
          )
          .toList(),
      [
        ('medium', 0, 0, 2, 2),
        ('small-one', 0, 2, 1, 1),
        ('small-two', 0, 3, 1, 1),
        ('wide', 2, 0, 2, 4),
      ],
    );
  });

  test('fills holes before adding another row', () {
    final slots = packLauncherTiles(const [
      PinnedTile(
        packageName: 'small-one',
        size: TileSize.small,
        liveEnabled: true,
      ),
      PinnedTile(
        packageName: 'medium',
        size: TileSize.medium,
        liveEnabled: true,
      ),
      PinnedTile(
        packageName: 'small-two',
        size: TileSize.small,
        liveEnabled: true,
      ),
    ]);

    expect((slots[0].row, slots[0].column), (0, 0));
    expect((slots[1].row, slots[1].column), (0, 1));
    expect((slots[2].row, slots[2].column), (0, 3));
  });
}
