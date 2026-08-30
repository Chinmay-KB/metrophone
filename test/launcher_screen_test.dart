import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrophone/src/app.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';
import 'package:wp_pivot_flutter/wp_pivot_flutter.dart';

import 'support/fake_launcher_platform.dart';

void main() {
  testWidgets('basic shell exposes setup, diagnostics, and pinnable tiles', (
    tester,
  ) async {
    final platform = FakeLauncherPlatform()
      ..installedApps = const [
        InstalledApp(
          packageName: 'example.alpha',
          activityName: 'example.alpha.MainActivity',
          label: 'Alpha',
          isSystemApp: false,
        ),
      ];
    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(),
    );

    await tester.pumpWidget(
      MetrophoneApp(controller: controller, disposeController: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WpPivotView), findsOneWidget);
    expect(find.byKey(const ValueKey('launcher-ready')), findsOneWidget);
    expect(find.text('1 apps • 0 live notifications'), findsOneWidget);
    expect(find.byKey(const ValueKey('request-home-role')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('request-notification-access')),
      findsOneWidget,
    );

    await controller.pinApp('example.alpha');
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-example.alpha')), findsOneWidget);

    controller.dispose();
    await platform.close();
  });
}
