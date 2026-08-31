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

import 'support/fake_launcher_platform.dart';

void main() {
  const outputPath = String.fromEnvironment('OUTPUT');
  testWidgets('renders shipping launcher interaction demonstration', (tester) async {
    if (outputPath.isEmpty) return;
    final output = Directory(outputPath);
    if (output.existsSync()) throw StateError('OUTPUT must be fresh');
    output.createSync(recursive: true);
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeLauncherPlatform()
      ..installedApps = _apps
      ..launchSucceeds = false
      ..currentCapabilities = const LauncherCapabilities(
        sdkInt: 35, isDefaultLauncher: true, canRequestHomeRole: true,
        hasNotificationAccess: true, supportsNativeMonochromeIcons: true,
      );
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(_tiles),
    );
    addTearDown(controller.dispose);
    addTearDown(platform.close);
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MetrophoneApp(controller: controller, disposeController: false),
    ));
    await tester.pumpAndSettle();
    var frame = 0;
    Future<void> capture(String scenario) async {
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/${frame.toString().padLeft(3, '0')}-$scenario.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        frame++;
      });
    }

    final phone = find.byKey(const ValueKey('tile-phone'));
    await capture('launch-exit');
    await tester.tap(phone);
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('launch-exit');
    }
    await tester.pumpAndSettle();

    await tester.longPress(phone);
    for (var index = 0; index < 7; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('edit-entry');
    }

    final gesture = await tester.startGesture(tester.getCenter(phone));
    for (var index = 0; index < 7; index++) {
      await gesture.moveBy(const Offset(28, 34));
      await tester.pump(const Duration(milliseconds: 24));
      await capture('live-reorder');
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final selected = find.byKey(const ValueKey('tile-phone'));
    await tester.longPress(selected);
    await tester.pump();
    final resize = find.byKey(const ValueKey('wp-tile-edit-visual-resize'));
    if (resize.evaluate().isNotEmpty) await tester.tap(resize.first);
    for (var index = 0; index < 8; index++) {
      await tester.pump(const Duration(milliseconds: 28));
      await capture('resize-reflow');
    }
    File('${output.path}/frames.json').writeAsStringSync(jsonEncode({
      'viewport': [480, 800],
      'frame_interval_ms': 28,
      'frame_count': frame,
      'scenarios': ['launch-exit', 'edit-entry', 'live-reorder', 'resize-reflow'],
    }));
  }, skip: outputPath.isEmpty);
}

const _apps = [
  InstalledApp(packageName: 'phone', activityName: 'phone.Main', label: 'Phone', isSystemApp: true),
  InstalledApp(packageName: 'messaging', activityName: 'messaging.Main', label: 'Messaging', isSystemApp: true),
  InstalledApp(packageName: 'browser', activityName: 'browser.Main', label: 'Browser', isSystemApp: true),
  InstalledApp(packageName: 'mail', activityName: 'mail.Main', label: 'Mail', isSystemApp: true),
  InstalledApp(packageName: 'people', activityName: 'people.Main', label: 'People', isSystemApp: true),
];
const _tiles = [
  PinnedTile(packageName: 'phone', size: TileSize.medium, liveEnabled: true),
  PinnedTile(packageName: 'messaging', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'browser', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'mail', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'people', size: TileSize.medium, liveEnabled: true),
];
