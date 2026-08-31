import '../models/pinned_tile.dart';
import 'tile_store.dart';

class MemoryTileStore implements TileStore {
  MemoryTileStore([List<PinnedTile> seed = const [], bool? savedLayout])
    : _tiles = [...seed],
      _hasStoredLayout = savedLayout ?? seed.isNotEmpty;

  List<PinnedTile> _tiles;
  bool _hasStoredLayout;

  @override
  Future<List<PinnedTile>> load() async => List.unmodifiable(_tiles);

  @override
  Future<bool> hasStoredLayout() async => _hasStoredLayout;

  @override
  Future<void> save(List<PinnedTile> tiles) async {
    _tiles = [...tiles];
    _hasStoredLayout = true;
  }
}
