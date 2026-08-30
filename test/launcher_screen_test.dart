import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/app.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/models/pinned_tile.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';
import 'package:wp_pivot_flutter/wp_components.dart';

import 'support/fake_launcher_platform.dart';

const _apps = [
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
];

void main() {
  late FakeLauncherPlatform platform;
  late LauncherController controller;

  setUp(() {
    platform = FakeLauncherPlatform()..installedApps = _apps;
    controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(const [
        PinnedTile(
          packageName: 'example.alpha',
          size: TileSize.medium,
          liveEnabled: true,
        ),
      ]),
    );
  });

  tearDown(() async {
    controller.dispose();
    await platform.close();
  });

  testWidgets('uses measured Start geometry and controlled tile editing', (
    tester,
  ) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WpSplitSurfaceView), findsOneWidget);
    expect(find.byKey(const ValueKey('launcher-ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('request-home-role')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('request-notification-access')),
      findsOneWidget,
    );

    final tile = find.byKey(const ValueKey('tile-example.alpha'));
    expect(tester.getTopLeft(tile), const Offset(24, 56));
    expect(tester.getSize(tile), const Size(210, 210));

    await tester.longPress(tile);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('wp-tile-edit-visual-unpin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wp-tile-edit-visual-resize')),
      findsOneWidget,
    );
  });

  testWidgets('swipes to app list, searches, and opens alphabet jump', (
    tester,
  ) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(WpSplitSurfaceView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-example.alpha')), findsOneWidget);
    expect(find.byType(WpAppListHeader), findsNWidgets(2));
    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('wp-app-list-header-frame')).first,
      ),
      const Offset(86, 57),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('wp-app-list-header-frame')).first,
      ),
      const Size.square(62),
    );
    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('wp-app-list-icon-frame')).first,
      ),
      const Offset(86, 131),
    );

    await tester.tap(find.byKey(const ValueKey('app-search-action')));
    await tester.pump();
    expect(find.byKey(const ValueKey('app-search-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('app-search-field')),
      'beta',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('app-example.alpha')), findsNothing);
    expect(find.byKey(const ValueKey('app-example.beta')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-search-action')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('wp-app-list-header-frame')).first,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('wp-alphabet-cell-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('wp-alphabet-cell-b')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('wp-alphabet-cell-a'))),
      const Offset(135, 19),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('wp-alphabet-cell-a'))),
      const Size.square(99),
    );
  });

  testWidgets('long press pins an app and tap launches after scene exit', (
    tester,
  ) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(WpSplitSurfaceView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    final beta = find.text('Beta');
    await tester.longPress(beta);
    await tester.pump();
    expect(controller.isPinned('example.beta'), isTrue);
    expect(find.text('pinned Beta to Start'), findsOneWidget);

    await tester.tap(beta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(platform.launchedApp, isNull);
    final sceneTransforms = tester.widgetList<Transform>(
      find.byKey(const ValueKey('wp-scene-transform')),
    );
    expect(
      sceneTransforms.any(
        (widget) =>
            widget.transform.storage[0] != 1 ||
            widget.transform.storage[12] != 0,
      ),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(platform.launchedApp?.packageName, 'example.beta');
  });

  testWidgets('Android Back dismisses overlays before returning to Start', (
    tester,
  ) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(WpSplitSurfaceView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-search-action')));
    await tester.pump();
    expect(find.byKey(const ValueKey('app-search-field')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('app-search-field')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('wp-app-list-header-frame')).first,
    );
    await tester.pump();
    expect(find.byType(WpAlphabetGrid), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(WpAlphabetGrid), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('launcher-ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-list')), findsNothing);
  });
}

Future<void> _setWvgaView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(480, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
