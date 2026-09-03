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
  InstalledApp(
    packageName: 'example.charlie',
    activityName: 'example.charlie.MainActivity',
    label: 'Charlie',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.delta',
    activityName: 'example.delta.MainActivity',
    label: 'Delta',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.echo',
    activityName: 'example.echo.MainActivity',
    label: 'Echo',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.foxtrot',
    activityName: 'example.foxtrot.MainActivity',
    label: 'Foxtrot',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.golf',
    activityName: 'example.golf.MainActivity',
    label: 'Golf',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.hotel',
    activityName: 'example.hotel.MainActivity',
    label: 'Hotel',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.india',
    activityName: 'example.india.MainActivity',
    label: 'India',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.juliet',
    activityName: 'example.juliet.MainActivity',
    label: 'Juliet',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.kilo',
    activityName: 'example.kilo.MainActivity',
    label: 'Kilo',
    isSystemApp: false,
  ),
  InstalledApp(
    packageName: 'example.lima',
    activityName: 'example.lima.MainActivity',
    label: 'Lima',
    isSystemApp: false,
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
    // Setup presentation is DS-owned (WpSetupPanel/WpSetupAction); launcher
    // owns capability gating + consent entry points.
    expect(find.byType(WpSetupPanel), findsOneWidget);
    expect(find.text('set as home'), findsOneWidget);
    expect(find.text('enable live tiles'), findsOneWidget);

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

  testWidgets('scene entry swings each surface back as one page', (tester) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();

    // Native shell return (WP8.1 dialer -> Start capture) swings the whole
    // surface back rigidly: one opaque page transition per surface, no
    // per-tile stagger or fade while entering.
    WpStaggeredSceneTransition pageEntry(String key) {
      final transition = tester.widget<WpStaggeredSceneTransition>(
        find.byKey(ValueKey(key)),
      );
      expect(transition.direction, WpSceneTransitionDirection.enter);
      expect(transition.alignment, Alignment.centerRight);
      expect(transition.fade, isFalse);
      expect(transition.order, 0);
      expect(transition.maxOrder, 0);
      return transition;
    }

    pageEntry('start-scene-page-entry');
    expect(find.byType(WpStaggeredSceneTransition), findsOneWidget);

    await tester.fling(
      find.byType(WpSplitSurfaceView),
      const Offset(-480, 0),
      1200,
    );
    await tester.pumpAndSettle();
    pageEntry('apps-scene-page-entry');
    for (final element in tester.elementList(
      find.byType(WpStaggeredSceneTransition),
    )) {
      final transition = element.widget as WpStaggeredSceneTransition;
      expect(transition.direction, WpSceneTransitionDirection.enter);
      expect(transition.fade, isFalse);
    }
  });

  testWidgets('scene exit keeps the measured staggered pivots', (tester) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();

    // The DS default pivot is surface-neutral (center). Exit pins the
    // measured edges explicitly; a center pivot shears app icons away from
    // labels mid-flight.
    await tester.tap(find.byKey(const ValueKey('tile-example.alpha')));
    await tester.pump(const Duration(milliseconds: 100));
    final elements = tester.elementList(
      find.byType(WpStaggeredSceneTransition),
    );
    expect(elements, isNotEmpty);
    for (final element in elements) {
      final transition = element.widget as WpStaggeredSceneTransition;
      expect(transition.direction, WpSceneTransitionDirection.exit);
      expect(transition.alignment, Alignment.centerLeft);
    }
    await tester.pumpAndSettle();
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
    expect(find.byType(WpAppListHeader), findsAtLeastNWidgets(2));
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
    // Search presentation is DS-owned (WpSearchField); launcher owns
    // filtering/sorting/sections/Back. The inner field carries the DS key.
    expect(find.byKey(const ValueKey('wp-search-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('wp-search-field')),
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

  testWidgets('alphabet picker clears and returns to the selected section', (
    tester,
  ) async {
    await _setWvgaView(tester);
    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(WpSplitSurfaceView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('wp-app-list-header-frame')).first,
    );
    await tester.pump();
    expect(find.byType(WpAlphabetGrid), findsOneWidget);
    expect(find.byKey(const ValueKey('app-list')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byKey(const ValueKey('app-list')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 320));
    await tester.tap(find.byKey(const ValueKey('wp-alphabet-cell-c')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WpAlphabetGrid), findsOneWidget);

    // The picker clears to black while its post-dismiss correction settles.
    // The old A section must not be exposed at the reverse boundary, whether
    // C is already visible or still waiting for its correction frame.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WpAlphabetGrid), findsNothing);
    expect(find.text('Alpha').hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Alpha').hitTestable(), findsNothing);
    expect(find.text('Charlie').hitTestable(), findsOneWidget);
    expect(find.byType(WpAlphabetGrid), findsNothing);
    expect(find.byKey(const ValueKey('app-list')), findsOneWidget);
    final listScroller = find.descendant(
      of: find.byKey(const ValueKey('app-list')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(listScroller).position.pixels,
      closeTo(4 * 74, 1),
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
    expect(find.byKey(const ValueKey('wp-search-field')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('wp-search-field')), findsNothing);

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
