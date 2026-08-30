import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wp_pivot_flutter/wp_components.dart';
import 'package:wp_pivot_flutter/wp_pivot_flutter.dart';

import 'controller/launcher_controller.dart';
import 'ui/launcher_screen.dart';

class MetrophoneApp extends StatelessWidget {
  const MetrophoneApp({
    super.key,
    required this.controller,
    this.disposeController = true,
  });

  final LauncherController controller;
  final bool disposeController;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Metrophone',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xff3e65ff),
        surface: Color(0xff111111),
      ),
      fontFamily: wpPivotFontFamily,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xff3e65ff),
        selectionColor: Color(0x993e65ff),
        selectionHandleColor: Color(0xff3e65ff),
      ),
    ),
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.black,
      ),
      child: ColoredBox(color: Colors.black, child: child!),
    ),
    home: WpPhoneTheme(
      data: const WpPhoneThemeData.dark(),
      child: LauncherScreen(
        controller: controller,
        disposeController: disposeController,
      ),
    ),
  );
}
