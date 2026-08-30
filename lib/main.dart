import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/controller/launcher_controller.dart';
import 'src/platform/method_channel_launcher_platform.dart';
import 'src/storage/tile_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MetrophoneApp(
      controller: LauncherController(
        platform: MethodChannelLauncherPlatform(),
        tileStore: SharedPreferencesTileStore(),
      ),
    ),
  );
}
