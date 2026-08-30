import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/controller/launcher_controller.dart';
import 'src/platform/method_channel_launcher_platform.dart';
import 'src/storage/tile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xff000000),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xff000000),
    ),
  );
  runApp(
    MetrophoneApp(
      controller: LauncherController(
        platform: MethodChannelLauncherPlatform(),
        tileStore: SharedPreferencesTileStore(),
      ),
    ),
  );
}
