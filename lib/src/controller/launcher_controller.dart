import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_icon.dart';
import '../models/installed_app.dart';
import '../models/launcher_capabilities.dart';
import '../models/notification_snapshot.dart';
import '../models/pinned_tile.dart';
import '../platform/launcher_platform.dart';
import '../storage/tile_store.dart';

enum LauncherLoadState { idle, loading, ready, failed }

class LauncherController extends ChangeNotifier {
  factory LauncherController({
    required LauncherPlatform platform,
    required TileStore tileStore,
  }) => LauncherController._(platform, tileStore);

  LauncherController._(this._platform, this._tileStore);

  final LauncherPlatform _platform;
  final TileStore _tileStore;
  final Map<String, NotificationSnapshot> _notifications = {};
  StreamSubscription<NotificationEvent>? _notificationSubscription;
  bool _disposed = false;

  LauncherLoadState _state = LauncherLoadState.idle;
  LauncherLoadState get state => _state;

  String? _error;
  String? get error => _error;

  List<InstalledApp> _apps = const [];
  List<InstalledApp> get apps => _apps;

  List<PinnedTile> _tiles = const [];
  List<PinnedTile> get tiles => _tiles;

  LauncherCapabilities _capabilities = LauncherCapabilities.unsupported;
  LauncherCapabilities get capabilities => _capabilities;

  int get activeNotificationCount => _notifications.length;

  Future<void> initialize() async {
    if (_state == LauncherLoadState.loading) return;
    _state = LauncherLoadState.loading;
    _error = null;
    _notifyIfActive();

    await _notificationSubscription?.cancel();
    _notificationSubscription = _platform.notificationEvents.listen(
      _handleNotificationEvent,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Metrophone notification stream error: $error');
      },
    );

    try {
      final values = await Future.wait<Object>([
        _platform.getInstalledApps(),
        _platform.getCapabilities(),
        _platform.getActiveNotifications(),
        _tileStore.load(),
        _tileStore.hasStoredLayout(),
      ]);
      _apps = List.unmodifiable(values[0] as List<InstalledApp>);
      _capabilities = values[1] as LauncherCapabilities;
      _replaceNotifications(values[2] as List<NotificationSnapshot>);
      final installedPackages = {for (final app in _apps) app.packageName};
      final savedTiles = List<PinnedTile>.unmodifiable(
        (values[3] as List<PinnedTile>).where(
          (tile) => installedPackages.contains(tile.packageName),
        ),
      );
      final hasStoredLayout = values[4] as bool;
      if (!hasStoredLayout) {
        _tiles = List.unmodifiable(_defaultTiles(_apps));
        await _tileStore.save(_tiles);
      } else {
        _tiles = savedTiles;
      }
      _state = LauncherLoadState.ready;
      debugPrint(
        'METROPHONE_READY apps=${_apps.length} '
        'tiles=${_tiles.length} notifications=${_notifications.length} '
        'home=${_capabilities.isDefaultLauncher}',
      );
    } catch (error, stackTrace) {
      _state = LauncherLoadState.failed;
      _error = error.toString();
      debugPrint('Metrophone initialization failed: $error\n$stackTrace');
    }
    _notifyIfActive();
  }

  Future<void> refreshCatalog() async {
    _apps = List.unmodifiable(await _platform.getInstalledApps());
    _notifyIfActive();
  }

  Future<void> refreshCapabilities() async {
    _capabilities = await _platform.getCapabilities();
    _notifyIfActive();
  }

  Future<void> refreshNotifications() async {
    _replaceNotifications(await _platform.getActiveNotifications());
    _notifyIfActive();
  }

  InstalledApp? appForPackage(String packageName) {
    for (final app in _apps) {
      if (app.packageName == packageName) return app;
    }
    return null;
  }

  bool isPinned(String packageName) =>
      _tiles.any((tile) => tile.packageName == packageName);

  Future<void> pinApp(String packageName) async {
    if (isPinned(packageName) || appForPackage(packageName) == null) return;
    _tiles = List.unmodifiable([
      ..._tiles,
      PinnedTile(
        packageName: packageName,
        size: TileSize.medium,
        liveEnabled: true,
      ),
    ]);
    await _persistTiles();
  }

  Future<void> unpinApp(String packageName) async {
    _tiles = List.unmodifiable(
      _tiles.where((tile) => tile.packageName != packageName),
    );
    await _persistTiles();
  }

  Future<void> cycleTileSize(String packageName) async {
    _tiles = List.unmodifiable([
      for (final tile in _tiles)
        if (tile.packageName == packageName)
          tile.copyWith(
            size:
                TileSize.values[(tile.size.index + 1) % TileSize.values.length],
          )
        else
          tile,
    ]);
    await _persistTiles();
  }

  Future<void> setLiveTileEnabled(
    String packageName, {
    required bool enabled,
  }) async {
    _tiles = List.unmodifiable([
      for (final tile in _tiles)
        if (tile.packageName == packageName)
          tile.copyWith(liveEnabled: enabled)
        else
          tile,
    ]);
    await _persistTiles();
  }

  Future<void> reorderTile(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _tiles.length) return;
    final reordered = [..._tiles];
    final tile = reordered.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    reordered.insert(target.clamp(0, reordered.length), tile);
    _tiles = List.unmodifiable(reordered);
    await _persistTiles();
  }

  /// Moves a tile to an explicit final index.  Gesture-driven Start reflow
  /// uses this rather than the insertion-index semantics of [reorderTile].
  Future<void> reorderTileTo(int oldIndex, int targetIndex) async {
    if (oldIndex < 0 || oldIndex >= _tiles.length) return;
    final reordered = [..._tiles];
    final tile = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex.clamp(0, reordered.length), tile);
    _tiles = List.unmodifiable(reordered);
    await _persistTiles();
  }

  static List<PinnedTile> _defaultTiles(List<InstalledApp> apps) {
    final remaining = _sortedApps(apps);
    final selected = <InstalledApp>[];
    const roleKeywords = [
      ['phone', 'dialer'],
      ['messaging', 'messages', 'sms'],
      ['contacts', 'people'],
      ['browser', 'chrome'],
      ['camera'],
      ['calendar'],
      ['clock'],
    ];
    for (final keywords in roleKeywords) {
      final match = remaining.where((app) {
        final identity = '${app.label} ${app.packageName}'.toLowerCase();
        return keywords.any(identity.contains);
      }).firstOrNull;
      if (match != null) {
        selected.add(match);
        remaining.remove(match);
      }
      if (selected.length == 4) break;
    }
    selected.addAll(remaining.take(4 - selected.length));
    return [
      for (var index = 0; index < selected.length; index++)
        PinnedTile(
          packageName: selected[index].packageName,
          size: index == 0 ? TileSize.medium : TileSize.small,
          liveEnabled: true,
        ),
    ];
  }

  static List<InstalledApp> _sortedApps(Iterable<InstalledApp> apps) {
    final ordered = [...apps];
    ordered.sort((a, b) {
      final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      return byLabel != 0 ? byLabel : a.packageName.compareTo(b.packageName);
    });
    return ordered;
  }

  Future<AppIcon> getIcon(
    String packageName, {
    bool monochrome = true,
    int size = 144,
  }) => _platform.getAppIcon(packageName, monochrome: monochrome, size: size);

  Future<bool> launchApp(InstalledApp app) => _platform.launchApp(app);

  Future<bool> requestDefaultLauncher() => _platform.requestDefaultLauncher();

  Future<bool> openNotificationAccessSettings() =>
      _platform.openNotificationAccessSettings();

  LiveTileContent? liveContentFor(String packageName) {
    final matches =
        _notifications.values
            .where((notification) => notification.packageName == packageName)
            .toList()
          ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    if (matches.isEmpty) return null;
    final latest = matches.first;
    return LiveTileContent(
      notificationCount: matches.length,
      updatedAt: latest.postedAt,
      title: latest.title,
      text: latest.text,
    );
  }

  Future<void> _persistTiles() async {
    await _tileStore.save(_tiles);
    _notifyIfActive();
  }

  void _replaceNotifications(List<NotificationSnapshot> notifications) {
    _notifications
      ..clear()
      ..addEntries(<MapEntry<String, NotificationSnapshot>>[
        for (final notification in notifications)
          MapEntry(notification.key, notification),
      ]);
  }

  void _handleNotificationEvent(NotificationEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case NotificationEventType.posted:
        final notification = event.notification;
        if (notification != null) {
          _notifications[notification.key] = notification;
        }
      case NotificationEventType.removed:
        if (event.key != null) _notifications.remove(event.key);
      case NotificationEventType.reset:
        unawaited(refreshNotifications());
    }
    _notifyIfActive();
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
