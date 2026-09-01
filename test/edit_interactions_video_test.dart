import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/app.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/models/launcher_capabilities.dart';
import 'package:metrophone/src/models/pinned_tile.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';
import 'package:wp_pivot_flutter/wp_components.dart';

import 'support/fake_launcher_platform.dart';
import 'support/wp_font_loader.dart';

void main() {
  const outputPath = String.fromEnvironment('OUTPUT');
  testWidgets('renders shipping launcher interaction demonstration', (
    tester,
  ) async {
    if (outputPath.isEmpty) return;
    final output = Directory(outputPath);
    if (output.existsSync()) throw StateError('OUTPUT must be fresh');
    output.createSync(recursive: true);
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadWpPivotFonts);
    final platform = FakeLauncherPlatform()
      ..installedApps = _apps
      ..launchSucceeds = false
      ..currentCapabilities = const LauncherCapabilities(
        sdkInt: 35,
        isDefaultLauncher: true,
        canRequestHomeRole: true,
        hasNotificationAccess: true,
        supportsNativeMonochromeIcons: true,
      );
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(_tiles),
    );
    addTearDown(controller.dispose);
    addTearDown(platform.close);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MetrophoneApp(controller: controller, disposeController: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    var frame = 0;
    List<int>? settledSelectionFrame;
    Future<void> capture(
      String scenario, {
      bool verifySettledSelectionContinuity = false,
    }) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = List<int>.from(bytes!.buffer.asUint8List());
        if (verifySettledSelectionContinuity) {
          if (settledSelectionFrame == null) {
            settledSelectionFrame = pngBytes;
          } else {
            expect(pngBytes, orderedEquals(settledSelectionFrame!));
          }
        }
        File('${output.path}/${frame.toString().padLeft(3, '0')}-$scenario.png')
            .writeAsBytesSync(pngBytes);
        image.dispose();
        frame++;
      });
    }

    final phone = find.byKey(const ValueKey('tile-phone'));
    await capture('start-rest');
    await tester.tap(phone);
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('launch-exit');
    }
    await tester.pump(const Duration(milliseconds: 360));

    await tester.longPress(phone, warnIfMissed: false);
    for (var index = 0; index < 7; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('edit-entry');
    }
    for (var index = 0; index < 24; index++) {
      await tester.pump(const Duration(milliseconds: 50));
      await capture('edit-wiggle');
    }

    final gesture = await tester.startGesture(tester.getCenter(phone));
    for (var index = 0; index < 7; index++) {
      await gesture.moveBy(const Offset(28, 34));
      await tester.pump(const Duration(milliseconds: 24));
      await capture('live-reorder');
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 260));

    final selected = find.byKey(const ValueKey('tile-phone'));
    // The selected tile has an active edit transform; Flutter's semantic bounds
    // lag that transform by one frame, while the gesture still reaches it.
    await tester.longPress(selected, warnIfMissed: false);
    await tester.pump();
    final resize = find.byKey(const ValueKey('wp-tile-edit-visual-resize'));
    if (resize.evaluate().isNotEmpty) await tester.tap(resize.first);
    for (var index = 0; index < 8; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('resize-reflow');
    }
    await tester.fling(
      find.byType(WpSplitSurfaceView),
      const Offset(-480, 0),
      1200,
    );
    for (var index = 0; index < 8; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture('app-list-rest');

    for (var index = 0; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 80));
      await capture('app-list-before-alphabet');
    }
    await tester.tap(
      find.byKey(const ValueKey('wp-app-list-header-frame')).first,
    );
    await tester.pump();
    for (var index = 0; index < 16; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('alphabet-open');
    }
    await tester.tap(find.byKey(const ValueKey('wp-alphabet-cell-c')));
    await tester.pump();
    for (var index = 0; index < 18; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('alphabet-select');
    }
    // Selection holds the catalog black until its new controller has completed
    // the post-dismiss correction. Flush its post-frame correction before
    // documenting the final state.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Alarms').hitTestable(), findsNothing);
    expect(find.text('Calculator').hitTestable(), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 80));
      await capture(
        'app-list-after-selection',
        verifySettledSelectionContinuity: true,
      );
    }
    File('${output.path}/frames.json').writeAsStringSync(
      jsonEncode({
        'viewport': [480, 800],
        'frame_interval_ms': 28,
        'frame_count': frame,
        'scenarios': [
          'start-rest',
          'launch-exit',
          'edit-entry',
          'edit-wiggle',
          'live-reorder',
          'resize-reflow',
          'app-list-rest',
          'app-list-before-alphabet',
          'alphabet-open',
          'alphabet-select',
          'app-list-after-selection',
        ],
        'scenario_frame_intervals_ms': {
          'start-rest': 0,
          'launch-exit': 28,
          'edit-entry': 28,
          'edit-wiggle': 50,
          'live-reorder': 24,
          'resize-reflow': 28,
          'app-list-rest': 0,
          'app-list-before-alphabet': 80,
          'alphabet-open': 28,
          'alphabet-select': 28,
          'app-list-after-selection': 80,
        },
      }),
    );
  }, skip: outputPath.isEmpty);
}

const _apps = [
  InstalledApp(
    packageName: 'phone',
    activityName: 'phone.Main',
    label: 'Fake GSM Network',
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
    label: 'Internet Explorer',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'mail',
    activityName: 'mail.Main',
    label: 'Mail',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'store',
    activityName: 'store.Main',
    label: 'Store',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'people',
    activityName: 'people.Main',
    label: 'People',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'kids-corner',
    activityName: 'kidsCorner.Main',
    label: "Kid's Corner",
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'alarms',
    activityName: 'alarms.Main',
    label: 'Alarms',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'battery-saver',
    activityName: 'battery.Main',
    label: 'Battery Saver',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'calculator',
    activityName: 'calculator.Main',
    label: 'Calculator',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'calendar',
    activityName: 'calendar.Main',
    label: 'Calendar',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'camera',
    activityName: 'camera.Main',
    label: 'Camera',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'cortana',
    activityName: 'cortana.Main',
    label: 'Cortana',
    isSystemApp: true,
  ),
];
const _tiles = [
  PinnedTile(packageName: 'phone', size: TileSize.medium, liveEnabled: true),
  PinnedTile(packageName: 'messaging', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'browser', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'mail', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'store', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'people', size: TileSize.medium, liveEnabled: true),
  PinnedTile(
    packageName: 'kids-corner',
    size: TileSize.wide,
    liveEnabled: true,
  ),
];
