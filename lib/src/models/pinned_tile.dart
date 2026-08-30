enum TileSize { small, medium, wide }

class PinnedTile {
  const PinnedTile({
    required this.packageName,
    required this.size,
    required this.liveEnabled,
  });

  factory PinnedTile.fromJson(Map<String, Object?> json) => PinnedTile(
    packageName: json['packageName']! as String,
    size: TileSize.values.byName(json['size']! as String),
    liveEnabled: json['liveEnabled'] as bool? ?? true,
  );

  final String packageName;
  final TileSize size;
  final bool liveEnabled;

  Map<String, Object?> toJson() => {
    'packageName': packageName,
    'size': size.name,
    'liveEnabled': liveEnabled,
  };

  PinnedTile copyWith({TileSize? size, bool? liveEnabled}) => PinnedTile(
    packageName: packageName,
    size: size ?? this.size,
    liveEnabled: liveEnabled ?? this.liveEnabled,
  );
}
