import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controller/launcher_controller.dart';
import '../models/app_icon.dart';
import 'start_role_icon.dart';

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
  _DecodedIcon? _icon;
  Object? _error;
  var _generation = 0;

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
    final generation = ++_generation;
    final previous = _icon;
    _icon = null;
    _error = null;
    _disposeAfterFrame(previous);
    _decode(widget.controller.getIcon(
      widget.packageName,
      monochrome: widget.monochrome,
      size: (widget.size * 3).round(),
    )).then((decoded) {
      if (!mounted || generation != _generation) {
        decoded.dispose();
        return;
      }
      setState(() => _icon = decoded);
    }).catchError((Object error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    });
  }

  void _disposeAfterFrame(_DecodedIcon? icon) {
    if (icon == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => icon.dispose());
  }

  Future<_DecodedIcon> _decode(Future<AppIcon> source) async {
    final icon = await source;
    return decodeIconWithOwnership(
      ui.instantiateImageCodec(icon.bytes),
      getImage: (codec) async => (await codec.getNextFrame()).image,
      createValue: (image) async {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bounds = data == null
            ? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
            : visibleForegroundBounds(
                data.buffer.asUint8List(),
                image.width,
                image.height,
              );
        return _DecodedIcon(image, bounds);
      },
      disposeCodec: (codec) => codec.dispose(),
      disposeImage: (image) => image.dispose(),
    );
  }

  @override
  void dispose() {
    _generation++;
    _icon?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: _content(),
  );

  Widget _content() {
    final icon = _icon;
    if (icon != null) {
      return CustomPaint(
        key: ValueKey('launcher-icon-visible-${widget.packageName}'),
        painter: _VisibleIconPainter(icon),
      );
    }
    if (_error != null) return StartRoleIcon(packageName: widget.packageName);
    return const Padding(
      padding: EdgeInsets.all(12),
      child: CircularProgressIndicator(strokeWidth: 1.5),
    );
  }
}

/// Ensures the codec is always released and an image is released unless its
/// ownership is explicitly transferred to [createValue].  The generic shape
/// lets lifecycle tests exercise the error paths without mocking `dart:ui`.
@visibleForTesting
Future<T> decodeIconWithOwnership<TCodec extends Object, TImage extends Object, T>(
  Future<TCodec> codecFuture, {
  required Future<TImage> Function(TCodec codec) getImage,
  required Future<T> Function(TImage image) createValue,
  required void Function(TCodec codec) disposeCodec,
  required void Function(TImage image) disposeImage,
}) async {
  final codec = await codecFuture;
  TImage? image;
  var ownershipTransferred = false;
  var codecCleanupAttempted = false;
  try {
    image = await getImage(codec);
    final value = await createValue(image);
    // Do not hand the image to its value until the codec's cleanup succeeds.
    // If disposal itself throws, the finally block below still releases it.
    codecCleanupAttempted = true;
    disposeCodec(codec);
    ownershipTransferred = true;
    return value;
  } finally {
    try {
      if (!codecCleanupAttempted) {
        codecCleanupAttempted = true;
        disposeCodec(codec);
      }
    } finally {
      if (!ownershipTransferred && image != null) disposeImage(image);
    }
  }
}

/// Returns the alpha-bearing foreground rather than the decoded bitmap canvas.
/// A one-pixel pad protects thin antialiased icon edges from clipping.
Rect visibleForegroundBounds(Uint8List rgba, int width, int height) {
  var left = width;
  var top = height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] > 8) {
        left = left < x ? left : x;
        top = top < y ? top : y;
        right = right > x ? right : x;
        bottom = bottom > y ? bottom : y;
      }
    }
  }
  if (right < left || bottom < top) {
    return Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  }
  final safeLeft = (left - 1).clamp(0, width - 1);
  final safeTop = (top - 1).clamp(0, height - 1);
  final safeRight = (right + 2).clamp(1, width);
  final safeBottom = (bottom + 2).clamp(1, height);
  return Rect.fromLTRB(
    safeLeft.toDouble(),
    safeTop.toDouble(),
    safeRight.toDouble(),
    safeBottom.toDouble(),
  );
}

Rect visibleIconDestinationRect(Rect sourceBounds, Size destination) {
  final sourceAspect = sourceBounds.width / sourceBounds.height;
  final destinationAspect = destination.width / destination.height;
  final size = sourceAspect > destinationAspect
      ? Size(destination.width, destination.width / sourceAspect)
      : Size(destination.height * sourceAspect, destination.height);
  return Alignment.center.inscribe(size, Offset.zero & destination);
}

class _DecodedIcon {
  _DecodedIcon(this.image, this.bounds);

  final ui.Image image;
  final Rect bounds;
  var _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    image.dispose();
  }
}

class _VisibleIconPainter extends CustomPainter {
  const _VisibleIconPainter(this.icon);

  final _DecodedIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    if (icon._disposed) return;
    canvas.drawImageRect(
      icon.image,
      icon.bounds,
      visibleIconDestinationRect(icon.bounds, size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _VisibleIconPainter oldDelegate) =>
      oldDelegate.icon.image != icon.image || oldDelegate.icon.bounds != icon.bounds;
}
