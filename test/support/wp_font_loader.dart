import 'package:flutter/services.dart';
import 'package:wp_pivot_flutter/wp_pivot_flutter.dart';

Future<void> loadWpPivotFonts() async {
  final loader = FontLoader(wpPivotFontFamily)
    ..addFont(
      rootBundle.load('packages/wp_pivot_flutter/assets/fonts/selawksl.ttf'),
    )
    ..addFont(rootBundle.load('packages/wp_pivot_flutter/assets/fonts/selawk.ttf'))
    ..addFont(
      rootBundle.load('packages/wp_pivot_flutter/assets/fonts/selawksb.ttf'),
    );
  await loader.load();
}
