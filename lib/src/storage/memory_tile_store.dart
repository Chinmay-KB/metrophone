import '../models/pinned_tile.dart';
import 'tile_store.dart';

class MemoryTileStore implements TileStore {
  MemoryTileStore([List<PinnedTile> seed = const []]) : _tiles = [...seed];

  List<PinnedTile> _tiles;

  @override
  Future<List<PinnedTile>> load() async => List.unmodifiable(_tiles);

  @override
  Future<void> save(List<PinnedTile> tiles) async {
    _tiles = [...tiles];
  }
}
