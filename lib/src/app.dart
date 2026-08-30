import 'package:flutter/material.dart';
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
    ),
    home: LauncherScreen(
      controller: controller,
      disposeController: disposeController,
    ),
  );
}
