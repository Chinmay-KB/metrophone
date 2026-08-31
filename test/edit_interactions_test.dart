import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/app.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/models/pinned_tile.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';
import 'package:metrophone/src/ui/launcher_icon.dart';
import 'package:metrophone/src/ui/start_role_icon.dart';
import 'package:wp_pivot_flutter/wp_components.dart';

import 'support/fake_launcher_platform.dart';

void main() {
  test('known launcher roles use source-aligned glyphs and preserve unknown apps', () {
    expect(startRoleFor(packageName: 'phone', label: 'Fake GSM Network'), 'phone');
    expect(
      startRoleFor(packageName: 'com.android.chrome', label: 'Chrome'),
      'browser',
    );
    expect(
      startRoleFor(packageName: 'com.android.calculator2', label: 'Calculator'),
      'calculator',
    );
    expect(
      startRoleFor(packageName: 'org.example.field-notes', label: 'Field Notes'),
      isNull,
    );
  });

  test(
    'first run persists a small deterministic installed default set',
    () async {
      final platform = FakeLauncherPlatform()..installedApps = _apps;
      final store = MemoryTileStore();
      final controller = LauncherController(
        platform: platform,
        tileStore: store,
      );
      await controller.initialize();

      expect(controller.tiles.map((tile) => tile.packageName), [
        'alpha',
        'beta',
        'zeta',
      ]);
      expect(controller.tiles.first.size, TileSize.medium);
      expect(await store.hasStoredLayout(), isTrue);
      controller.dispose();
      await platform.close();
    },
  );

  test('an intentionally saved empty layout stays empty', () async {
    final platform = FakeLauncherPlatform()..installedApps = _apps;
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(const [], true),
    );
    await controller.initialize();

    expect(controller.tiles, isEmpty);
    controller.dispose();
    await platform.close();
  });

  test(
    'first-run defaults prefer familiar launcher roles before fallback',
    () async {
      final platform = FakeLauncherPlatform()
        ..installedApps = const [
          InstalledApp(
            packageName: 'org.example.z',
            activityName: 'z.Main',
            label: 'Zebra',
            isSystemApp: false,
          ),
          InstalledApp(
            packageName: 'com.android.chrome',
            activityName: 'Chrome.Main',
            label: 'Chrome',
            isSystemApp: false,
          ),
          InstalledApp(
            packageName: 'com.android.camera',
            activityName: 'Camera.Main',
            label: 'Camera',
            isSystemApp: false,
          ),
          InstalledApp(
            packageName: 'com.android.dialer',
            activityName: 'Dialer.Main',
            label: 'Dialer',
            isSystemApp: true,
          ),
          InstalledApp(
            packageName: 'com.android.messaging',
            activityName: 'Messages.Main',
            label: 'Messages',
            isSystemApp: true,
          ),
          InstalledApp(
            packageName: 'com.android.contacts',
            activityName: 'People.Main',
            label: 'People',
            isSystemApp: true,
          ),
        ];
      final controller = LauncherController(
        platform: platform,
        tileStore: MemoryTileStore(),
      );
      await controller.initialize();
      expect(controller.tiles.map((tile) => tile.packageName), [
        'com.android.dialer',
        'com.android.messaging',
        'com.android.contacts',
        'com.android.chrome',
      ]);
      controller.dispose();
      await platform.close();
    },
  );

  test('visible icon geometry trims transparent canvas padding', () {
    final pixels = Uint8List(10 * 12 * 4);
    for (var y = 2; y <= 7; y++) {
      for (var x = 3; x <= 5; x++) {
        pixels[(y * 10 + x) * 4 + 3] = 255;
      }
    }
    expect(
      visibleForegroundBounds(pixels, 10, 12),
      const Rect.fromLTRB(2, 1, 7, 9),
    );
    expect(
      visibleIconDestinationRect(
        const Rect.fromLTWH(0, 0, 5, 8),
        const Size(100, 100),
      ),
      const Rect.fromLTWH(18.75, 0, 62.5, 100),
    );
  });

  test(
    'icon decode ownership releases resources on every failure path',
    () async {
      final frameFailureCodec = _FakeCodec();
      await expectLater(
        decodeIconWithOwnership<_FakeCodec, _FakeImage, String>(
          Future.value(frameFailureCodec),
          getImage: (_) async => throw StateError('getNextFrame failed'),
          createValue: (_) async => 'unreachable',
          disposeCodec: (codec) => codec.dispose(),
          disposeImage: (image) => image.dispose(),
        ),
        throwsStateError,
      );
      expect(frameFailureCodec.disposeCount, 1);

      final imageFailureCodec = _FakeCodec();
      final untransferredImage = _FakeImage();
      await expectLater(
        decodeIconWithOwnership<_FakeCodec, _FakeImage, String>(
          Future.value(imageFailureCodec),
          getImage: (_) async => untransferredImage,
          createValue: (_) async => throw StateError('toByteData failed'),
          disposeCodec: (codec) => codec.dispose(),
          disposeImage: (image) => image.dispose(),
        ),
        throwsStateError,
      );
      expect(imageFailureCodec.disposeCount, 1);
      expect(untransferredImage.disposeCount, 1);

      final successCodec = _FakeCodec();
      final transferredImage = _FakeImage();
      expect(
        await decodeIconWithOwnership<_FakeCodec, _FakeImage, String>(
          Future.value(successCodec),
          getImage: (_) async => transferredImage,
          createValue: (_) async => 'owner received image',
          disposeCodec: (codec) => codec.dispose(),
          disposeImage: (image) => image.dispose(),
        ),
        'owner received image',
      );
      expect(successCodec.disposeCount, 1);
      expect(transferredImage.disposeCount, 0);

      final cleanupFailureCodec = _FakeCodec(throwOnDispose: true);
      final cleanupFailureImage = _FakeImage();
      await expectLater(
        decodeIconWithOwnership<_FakeCodec, _FakeImage, String>(
          Future.value(cleanupFailureCodec),
          getImage: (_) async => cleanupFailureImage,
          createValue: (_) async => 'not transferred after failed cleanup',
          disposeCodec: (codec) => codec.dispose(),
          disposeImage: (image) => image.dispose(),
        ),
        throwsStateError,
      );
      expect(cleanupFailureCodec.disposeCount, 1);
      expect(cleanupFailureImage.disposeCount, 1);
    },
  );

  testWidgets(
    'left-edge exit, edit scale, live preview, and resize all animate',
    (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final platform = FakeLauncherPlatform()
        ..installedApps = _interactionApps
        ..launchSucceeds = false;
      final controller = LauncherController(
        platform: platform,
        tileStore: MemoryTileStore(_interactionTiles),
      );
      addTearDown(controller.dispose);
      addTearDown(platform.close);
      await tester.pumpWidget(
        MetrophoneApp(controller: controller, disposeController: false),
      );
      await tester.pumpAndSettle();
      final phone = find.byKey(const ValueKey('tile-phone'));
      await tester.tap(phone);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(
        tester
            .widgetList<Transform>(
              find.byKey(const ValueKey('wp-scene-transform')),
            )
            .any((transform) => transform.alignment == Alignment.centerLeft),
        isTrue,
      );
      final browserTransition = tester.widget<WpStaggeredSceneTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('tile-browser')),
              matching: find.byType(WpStaggeredSceneTransition),
            )
            .first,
      );
      final phoneTransition = tester.widget<WpStaggeredSceneTransition>(
        find
            .ancestor(
              of: phone,
              matching: find.byType(WpStaggeredSceneTransition),
            )
            .first,
      );
      expect(browserTransition.order, lessThan(phoneTransition.order));
      expect(
        tester
            .widgetList<Transform>(
              find.byKey(const ValueKey('wp-scene-transform')),
            )
            .any(
              (transform) =>
                  transform.transform.storage[0] != 1 ||
                  transform.transform.storage[12] != 0,
            ),
        isTrue,
      );
      await tester.pumpAndSettle();
      await tester.longPress(phone);
      await tester.pump(const Duration(milliseconds: 100));
      for (final transform in tester.widgetList<Transform>(
        find.byKey(const ValueKey('wp-tilt-transform')),
      )) {
        expect(
          transform.transform.storage,
          orderedEquals(Matrix4.identity().storage),
        );
      }
      for (final transform in tester.widgetList<Transform>(
        find.byKey(const ValueKey('wp-scene-transform')),
      )) {
        expect(
          transform.transform.storage,
          orderedEquals(Matrix4.identity().storage),
        );
      }
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const ValueKey('tile-edit-scale-phone')),
            )
            .scale,
        1.06,
      );
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const ValueKey('tile-edit-scale-messaging')),
            )
            .scale,
        0.92,
      );
      final wiggle = find.byKey(
        const ValueKey('tile-edit-wiggle-offset-messaging'),
      );
      final firstWiggle = tester.widget<Transform>(wiggle).transform.storage;
      final firstWiggleOffset = Offset(firstWiggle[12], firstWiggle[13]);
      await tester.pump(const Duration(milliseconds: 260));
      final nextWiggle = tester.widget<Transform>(wiggle).transform.storage;
      final nextWiggleOffset = Offset(nextWiggle[12], nextWiggle[13]);
      expect((nextWiggleOffset - firstWiggleOffset).distance, greaterThan(0.1));

      final before = tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('tile-position-messaging')),
          )
          .left;
      final gesture = await tester.startGesture(tester.getCenter(phone));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey('tile-position-messaging')),
            )
            .left,
        before,
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 40));
      final partial = tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('tile-position-messaging')),
          )
          .left;
      expect(partial, lessThan(before!));
      expect(partial, greaterThan(24));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 260));
      expect(controller.tiles.first.packageName, 'phone');
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey('tile-position-messaging')),
            )
            .left,
        before,
      );

      final commitGesture = await tester.startGesture(tester.getCenter(phone));
      await commitGesture.moveBy(const Offset(190, 190));
      await tester.pump(const Duration(milliseconds: 80));
      final during = tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('tile-position-messaging')),
          )
          .left;
      expect(during, isNot(before));
      final stack = tester.widget<Stack>(
        find.byKey(const ValueKey('start-tile-stack')),
      );
      expect(stack.children.last.key, const ValueKey('tile-position-phone'));
      await commitGesture.up();
      await tester.pump(const Duration(milliseconds: 260));

      await tester.longPress(find.byKey(const ValueKey('tile-phone')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('wp-tile-edit-visual-resize')).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        controller.tiles.firstWhere((tile) => tile.packageName == 'phone').size,
        TileSize.wide,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('tile-phone'))).width,
        greaterThan(210),
      );
    },
  );

  testWidgets('reduced motion removes edit-scale duration', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final platform = FakeLauncherPlatform()..installedApps = _interactionApps;
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(_interactionTiles),
    );
    addTearDown(controller.dispose);
    addTearDown(platform.close);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('tile-phone')));
    await tester.pump();
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('tile-edit-scale-phone')),
          )
          .duration,
      Duration.zero,
    );
    expect(
      find.byKey(const ValueKey('tile-edit-wiggle-offset-messaging')),
      findsNothing,
    );
  });
}

const _apps = [
  InstalledApp(
    packageName: 'zeta',
    activityName: 'zeta.Main',
    label: 'Zeta',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'beta',
    activityName: 'beta.Main',
    label: 'Beta',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'alpha',
    activityName: 'alpha.Main',
    label: 'Alpha',
    isSystemApp: false,
  ),
];

const _interactionApps = [
  InstalledApp(
    packageName: 'phone',
    activityName: 'phone.Main',
    label: 'Phone',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'messaging',
    activityName: 'messaging.Main',
    label: 'Messaging',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'browser',
    activityName: 'browser.Main',
    label: 'Browser',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'people',
    activityName: 'people.Main',
    label: 'People',
    isSystemApp: true,
  ),
];

const _interactionTiles = [
  PinnedTile(packageName: 'phone', size: TileSize.medium, liveEnabled: true),
  PinnedTile(packageName: 'messaging', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'browser', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'people', size: TileSize.medium, liveEnabled: true),
];

class _FakeCodec {
  _FakeCodec({this.throwOnDispose = false});

  final bool throwOnDispose;
  var disposeCount = 0;

  void dispose() {
    disposeCount++;
    if (throwOnDispose) throw StateError('codec dispose failed');
  }
}

class _FakeImage {
  var disposeCount = 0;

  void dispose() => disposeCount++;
}
