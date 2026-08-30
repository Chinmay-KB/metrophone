import 'package:flutter/material.dart';

import '../controller/launcher_controller.dart';
import '../models/app_icon.dart';

class LauncherIcon extends StatefulWidget {
  const LauncherIcon({
    super.key,
    required this.controller,
    required this.packageName,
    this.monochrome = true,
    this.size = 44,
  });

  final LauncherController controller;
  final String packageName;
  final bool monochrome;
  final double size;

  @override
  State<LauncherIcon> createState() => _LauncherIconState();
}

class _LauncherIconState extends State<LauncherIcon> {
  late Future<AppIcon> _icon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LauncherIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName ||
        oldWidget.monochrome != widget.monochrome ||
        oldWidget.size != widget.size) {
      _load();
    }
  }

  void _load() {
    _icon = widget.controller.getIcon(
      widget.packageName,
      monochrome: widget.monochrome,
      size: (widget.size * 3).round(),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: FutureBuilder<AppIcon>(
      future: _icon,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.requireData.bytes,
            width: widget.size,
            height: widget.size,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const Icon(Icons.apps),
          );
        }
        if (snapshot.hasError) return const Icon(Icons.apps);
        return const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
      },
    ),
  );
}
