import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/models/launcher_capabilities.dart';
import 'package:metrophone/src/models/notification_snapshot.dart';
import 'package:metrophone/src/models/pinned_tile.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';

import 'support/fake_launcher_platform.dart';

const _clock = 1735689600000;

void main() {
  late FakeLauncherPlatform platform;

  setUp(() {
    platform = FakeLauncherPlatform()
      ..installedApps = const [
        InstalledApp(
          packageName: 'example.alpha',
          activityName: 'example.alpha.MainActivity',
          label: 'Alpha',
          isSystemApp: false,
        ),
        InstalledApp(
          packageName: 'example.beta',
          activityName: 'example.beta.MainActivity',
          label: 'Beta',
          isSystemApp: true,
        ),
      ]
      ..currentCapabilities = const LauncherCapabilities(
        sdkInt: 36,
        isDefaultLauncher: true,
        canRequestHomeRole: true,
        hasNotificationAccess: true,
        supportsNativeMonochromeIcons: true,
      );
  });

  tearDown(() => platform.close());

  test(
    'initializes catalog, capabilities, notifications, and valid tiles',
    () async {
      platform.notifications = [_notification('one', 'example.alpha', 'hello')];
      final controller = LauncherController(
        platform: platform,
        tileStore: MemoryTileStore(const [
          PinnedTile(
            packageName: 'example.alpha',
            size: TileSize.medium,
            liveEnabled: true,
          ),
          PinnedTile(
            packageName: 'not.installed',
            size: TileSize.small,
            liveEnabled: true,
          ),
        ]),
      );

      await controller.initialize();

      expect(controller.state, LauncherLoadState.ready);
      expect(controller.apps.map((app) => app.label), ['Alpha', 'Beta']);
      expect(controller.tiles.single.packageName, 'example.alpha');
      expect(controller.capabilities.isDefaultLauncher, isTrue);
      expect(controller.liveContentFor('example.alpha')?.text, 'hello');
      controller.dispose();
    },
  );

  test(
    'pins, resizes, toggles, reorders, and unpins persisted tiles',
    () async {
      final store = MemoryTileStore();
      final controller = LauncherController(
        platform: platform,
        tileStore: store,
      );
      await controller.initialize();

      await controller.pinApp('example.alpha');
      await controller.pinApp('example.beta');
      await controller.cycleTileSize('example.alpha');
      await controller.setLiveTileEnabled('example.alpha', enabled: false);
      await controller.reorderTile(1, 0);

      expect(controller.tiles.map((tile) => tile.packageName), [
        'example.beta',
        'example.alpha',
      ]);
      expect(controller.tiles.last.size, TileSize.wide);
      expect(controller.tiles.last.liveEnabled, isFalse);

      await controller.unpinApp('example.beta');
      expect((await store.load()).single.packageName, 'example.alpha');
      controller.dispose();
    },
  );

  test('aggregates notification events for live tile content', () async {
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(),
    );
    await controller.initialize();

    platform.events.add(
      NotificationEvent(
        type: NotificationEventType.posted,
        notification: _notification('one', 'example.alpha', 'first'),
      ),
    );
    platform.events.add(
      NotificationEvent(
        type: NotificationEventType.posted,
        notification: _notification(
          'two',
          'example.alpha',
          'latest',
          offset: 1,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final content = controller.liveContentFor('example.alpha');
    expect(content?.notificationCount, 2);
    expect(content?.text, 'latest');

    platform.events.add(
      const NotificationEvent(type: NotificationEventType.removed, key: 'two'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.liveContentFor('example.alpha')?.text, 'first');
    controller.dispose();
  });

  test('delegates user-consent flows and application launch', () async {
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(),
    );
    await controller.initialize();

    expect(await controller.requestDefaultLauncher(), isTrue);
    expect(await controller.openNotificationAccessSettings(), isTrue);
    expect(await controller.launchApp(platform.installedApps.first), isTrue);
    expect(platform.requestedHomeRole, isTrue);
    expect(platform.openedNotificationSettings, isTrue);
    expect(platform.launchedApp?.packageName, 'example.alpha');
    controller.dispose();
  });
}

NotificationSnapshot _notification(
  String key,
  String packageName,
  String text, {
  int offset = 0,
}) => NotificationSnapshot(
  key: key,
  packageName: packageName,
  postedAt: DateTime.fromMillisecondsSinceEpoch(_clock + offset),
  isOngoing: false,
  title: 'title',
  text: text,
);
