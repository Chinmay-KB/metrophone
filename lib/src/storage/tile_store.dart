import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pinned_tile.dart';

abstract interface class TileStore {
  Future<List<PinnedTile>> load();

  Future<void> save(List<PinnedTile> tiles);
}

class SharedPreferencesTileStore implements TileStore {
  SharedPreferencesTileStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'metrophone.pinned_tiles.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<List<PinnedTile>> load() async {
    final encoded = await _preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      final decoded = jsonDecode(encoded) as List<Object?>;
      return [
        for (final item in decoded)
          PinnedTile.fromJson((item! as Map).cast<String, Object?>()),
      ];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  @override
  Future<void> save(List<PinnedTile> tiles) async {
    final encoded = jsonEncode([for (final tile in tiles) tile.toJson()]);
    await _preferences.setString(_key, encoded);
  }
}
