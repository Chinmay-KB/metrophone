import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metrophone/src/controller/launcher_controller.dart';
import 'package:metrophone/src/platform/method_channel_launcher_platform.dart';
import 'package:metrophone/src/storage/memory_tile_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android launcher bridge serves real catalog and icons', (
    tester,
  ) async {
    final platform = MethodChannelLauncherPlatform();
    final apps = await platform.getInstalledApps();
    final capabilities = await platform.getCapabilities();

    expect(apps, isNotEmpty);
    expect(capabilities.sdkInt, greaterThanOrEqualTo(24));

    final colored = await platform.getAppIcon(apps.first.packageName, size: 96);
    final monochrome = await platform.getAppIcon(
      apps.first.packageName,
      monochrome: true,
      size: 96,
    );
    expect(colored.bytes, _isPng);
    expect(monochrome.bytes, _isPng);

    final controller = LauncherController(
      platform: platform,
      tileStore: MemoryTileStore(),
    );
    await controller.initialize();
    expect(controller.state, LauncherLoadState.ready);
    expect(controller.apps.length, apps.length);
    controller.dispose();
  });
}

final Matcher _isPng = predicate<Uint8List>(
  (bytes) =>
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47,
  'is a non-empty PNG image',
);
