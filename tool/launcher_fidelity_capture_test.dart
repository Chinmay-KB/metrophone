import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/app.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/models/launcher_capabilities.dart';
import 'package:metrophone/src/models/pinned_tile.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';
import 'package:wp_pivot_flutter/wp_components.dart';
import 'package:wp_pivot_flutter/wp_pivot_flutter.dart';

import '../test/support/fake_launcher_platform.dart';

void main() {
  const outputPath = String.fromEnvironment('OUTPUT');

  testWidgets(
    'capture Metrophone component integration at the WP8.1 reference viewport',
    (tester) async {
      final output = Directory(outputPath);
      if (output.existsSync()) {
        throw StateError('Use a fresh OUTPUT directory: $outputPath');
      }
      output.createSync(recursive: true);

      final fontLoader = FontLoader(wpPivotFontFamily)
        ..addFont(
          rootBundle.load(
            'packages/wp_pivot_flutter/assets/fonts/selawksl.ttf',
          ),
        )
        ..addFont(
          rootBundle.load('packages/wp_pivot_flutter/assets/fonts/selawk.ttf'),
        );
      await fontLoader.load();

      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = FakeLauncherPlatform()
        ..installedApps = _apps
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
          child: MetrophoneApp(
            controller: controller,
            disposeController: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final frames = <String>[];
      await _capture(tester, boundary, output, 'start.png');
      frames.add('start.png');
      debugPrint('CAPTURED start.png');

      await tester.drag(find.byType(WpSplitSurfaceView), const Offset(-420, 0));
      await tester.pumpAndSettle();
      await _capture(tester, boundary, output, 'apps.png');
      frames.add('apps.png');
      debugPrint('CAPTURED apps.png');

      // Match the held-out WP8.1 alphabet sample's enabled-letter state without
      // changing the already-captured app-list fixture geometry.
      platform.installedApps = _alphabetApps;
      await controller.refreshCatalog();
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('wp-app-list-header-frame')).first,
      );
      await tester.pump();
      await _capture(tester, boundary, output, 'alphabet.png');
      frames.add('alphabet.png');
      debugPrint('CAPTURED alphabet.png');
      await tester.tapAt(const Offset(470, 795));
      await tester.pump();

      platform.installedApps = _apps;
      await controller.refreshCatalog();
      await tester.pump();

      await tester.drag(find.byType(WpSplitSurfaceView), const Offset(420, 0));
      await tester.pumpAndSettle();
      final calendar = find.byKey(const ValueKey('tile-calendar'));
      tester.widget<WpTile>(calendar).onTap!();
      await tester.pump();
      for (var index = 0; index < 19; index++) {
        final name = 'launch-exit-${index.toString().padLeft(3, '0')}.png';
        await _capture(tester, boundary, output, name);
        frames.add(name);
        await tester.pump(const Duration(microseconds: 16667));
      }
      debugPrint('CAPTURED launch exit sequence');

      final revision = Process.runSync('git', [
        'rev-parse',
        'HEAD',
      ]).stdout.toString().trim();
      File('${output.path}/manifest.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'schema_version': 1,
          'adapter_id': 'metrophone-wp81-component-integration-v1',
          'source': 'deterministic Flutter widget render',
          'resolution': [480, 800],
          'candidate_revision': revision,
          'component_package':
              'wp_pivot_flutter 2.3.0 at merge revision 72a8b6a',
          'frames': frames,
          'launch_exit_frame_interval_ms': 16.667,
          'claims': [
            'launcher integration preserves measured static component geometry',
            'launcher launch callback waits for the caller-owned scene exit',
            'captured poses are produced by the shipping launcher widgets',
          ],
          'limits': [
            'deterministic widget time is not Android physical latency',
            'native host capture timing does not qualify an exact WP curve',
            'fixture icons are generic fallbacks rather than Microsoft artwork',
          ],
        }),
      );
    },
    skip: outputPath.isEmpty,
  );
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Directory output,
  String name,
) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${output.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

const _apps = <InstalledApp>[
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
    packageName: 'music',
    activityName: 'music.Main',
    label: 'Music',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'games',
    activityName: 'games.Main',
    label: 'Games',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'office',
    activityName: 'office.Main',
    label: 'Office',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'notes',
    activityName: 'notes.Main',
    label: 'Notes',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'calendar',
    activityName: 'calendar.Main',
    label: 'Calendar',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'kids',
    activityName: 'kids.Main',
    label: "Kid's Corner",
    isSystemApp: true,
  ),
];

const _tiles = <PinnedTile>[
  PinnedTile(packageName: 'phone', size: TileSize.medium, liveEnabled: true),
  PinnedTile(packageName: 'messaging', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'browser', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'mail', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'store', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'people', size: TileSize.medium, liveEnabled: true),
  PinnedTile(packageName: 'music', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'games', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'office', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'notes', size: TileSize.small, liveEnabled: true),
  PinnedTile(packageName: 'calendar', size: TileSize.medium, liveEnabled: true),
  PinnedTile(packageName: 'kids', size: TileSize.medium, liveEnabled: true),
];

const _alphabetApps = <InstalledApp>[
  InstalledApp(
    packageName: 'fixture.a',
    activityName: 'fixture.a.Main',
    label: 'A',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.b',
    activityName: 'fixture.b.Main',
    label: 'B',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.c',
    activityName: 'fixture.c.Main',
    label: 'C',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.d',
    activityName: 'fixture.d.Main',
    label: 'D',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.f',
    activityName: 'fixture.f.Main',
    label: 'F',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.g',
    activityName: 'fixture.g.Main',
    label: 'G',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.h',
    activityName: 'fixture.h.Main',
    label: 'H',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.i',
    activityName: 'fixture.i.Main',
    label: 'I',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.m',
    activityName: 'fixture.m.Main',
    label: 'M',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.n',
    activityName: 'fixture.n.Main',
    label: 'N',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.o',
    activityName: 'fixture.o.Main',
    label: 'O',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.p',
    activityName: 'fixture.p.Main',
    label: 'P',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.s',
    activityName: 'fixture.s.Main',
    label: 'S',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.t',
    activityName: 'fixture.t.Main',
    label: 'T',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.v',
    activityName: 'fixture.v.Main',
    label: 'V',
    isSystemApp: true,
  ),
  InstalledApp(
    packageName: 'fixture.w',
    activityName: 'fixture.w.Main',
    label: 'W',
    isSystemApp: true,
  ),
];
