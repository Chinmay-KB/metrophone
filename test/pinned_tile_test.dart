import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/models/pinned_tile.dart';

void main() {
  test('pinned tile JSON round trip retains launcher state', () {
    const tile = PinnedTile(
      packageName: 'example.alpha',
      size: TileSize.wide,
      liveEnabled: false,
    );

    final decoded = PinnedTile.fromJson(tile.toJson());

    expect(decoded.packageName, tile.packageName);
    expect(decoded.size, TileSize.wide);
    expect(decoded.liveEnabled, isFalse);
  });
}
