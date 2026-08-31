import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Maps familiar Android roles to the corresponding Start-screen presentation.
/// Unrecognised apps retain their own Android application icon.
String? startRoleFor({required String packageName, required String label}) {
  final identity = '$packageName $label'.toLowerCase();
  if (packageName == 'phone' ||
      identity.contains('dialer') ||
      identity.contains(' phone')) {
    return 'phone';
  }
  if (packageName == 'messaging' ||
      identity.contains('messag') ||
      identity.contains('sms')) {
    return 'messaging';
  }
  if (packageName == 'browser' ||
      identity.contains('browser') ||
      identity.contains('chrome') ||
      identity.contains('internet explorer')) {
    return 'browser';
  }
  if (packageName == 'mail' ||
      identity.contains('mail') ||
      identity.contains('gmail') ||
      identity.contains('outlook')) {
    return 'mail';
  }
  if (packageName == 'store' ||
      identity.contains('play store') ||
      identity.contains(' app store')) {
    return 'store';
  }
  if (packageName == 'people' || identity.contains('contact')) return 'people';
  if (packageName == 'kids-corner') return 'kids-corner';
  if (identity.contains('alarm') || identity.contains('clock')) return 'alarms';
  if (identity.contains('battery')) return 'battery-saver';
  if (identity.contains('calculator')) return 'calculator';
  if (identity.contains('calendar')) return 'calendar';
  if (identity.contains('camera')) return 'camera';
  if (identity.contains('cortana')) return 'cortana';
  return null;
}

/// Original geometric fallback art for well-known launcher roles.
///
/// It is intentionally drawn in code rather than copied from Windows Phone
/// artwork. The launcher selects it for familiar system roles and retains the
/// Android-provided icon for every unrecognised application.
class StartRoleIcon extends StatelessWidget {
  const StartRoleIcon({super.key, required this.packageName});

  final String packageName;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey('start-role-icon-$packageName'),
    painter: _StartRoleIconPainter(packageName),
  );
}

/// The source-aligned app-list leading affordance, independent of the
/// Material icon font so it has the same silhouette in test and production.
class StartSearchIcon extends StatelessWidget {
  const StartSearchIcon({super.key, required this.close});

  final bool close;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StartSearchIconPainter(close),
  );
}

class _StartSearchIconPainter extends CustomPainter {
  const _StartSearchIconPainter(this.close);

  final bool close;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.square;
    final center = Offset(size.width / 2, size.height / 2);
    if (close) {
      canvas.drawLine(
        center.translate(-7, -7),
        center.translate(7, 7),
        paint,
      );
      canvas.drawLine(
        center.translate(7, -7), center.translate(-7, 7), paint);
      return;
    }
    canvas.drawCircle(center.translate(-3, -3), 7.5, paint);
    canvas.drawLine(center.translate(3, 3), center.translate(10, 10), paint);
  }

  @override
  bool shouldRepaint(covariant _StartSearchIconPainter oldDelegate) =>
      oldDelegate.close != close;
}

class _StartRoleIconPainter extends CustomPainter {
  const _StartRoleIconPainter(this.packageName);

  final String packageName;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 144;
    canvas.scale(scale);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = Colors.white;
    final cutout = Paint()..color = const Color(0xff3e65ff);
    switch (packageName) {
      case 'phone':
        canvas.save();
        canvas.translate(72, 72);
        canvas.rotate(-0.42);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-19, -48, 38, 96),
            const Radius.circular(18),
          ),
          paint,
        );
        canvas.drawRect(const Rect.fromLTWH(-27, -43, 54, 28), fill);
        canvas.drawRect(const Rect.fromLTWH(-27, 15, 54, 28), fill);
        canvas.restore();
      case 'messaging':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(25, 37, 94, 64),
            const Radius.circular(13),
          ),
          fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(48, 94)
            ..lineTo(40, 116)
            ..lineTo(66, 100)
            ..close(),
          fill,
        );
        for (final x in <double>[50, 72, 94]) {
          canvas.drawCircle(Offset(x, 68), 5, cutout);
        }
      case 'browser':
        canvas.drawCircle(const Offset(72, 72), 40, paint);
        canvas.drawArc(const Rect.fromLTWH(31, 31, 82, 82), -1, 2, false, paint);
        canvas.drawLine(const Offset(37, 84), const Offset(107, 84), paint);
        canvas.drawLine(const Offset(72, 32), const Offset(58, 111), paint);
      case 'mail':
        canvas.drawRect(const Rect.fromLTWH(23, 40, 98, 67), paint);
        canvas.drawPath(
          Path()
            ..moveTo(26, 45)
            ..lineTo(72, 82)
            ..lineTo(118, 45),
          paint,
        );
      case 'store':
        canvas.drawPath(
          Path()
            ..moveTo(30, 54)
            ..lineTo(42, 39)
            ..lineTo(102, 39)
            ..lineTo(114, 54)
            ..lineTo(107, 111)
            ..lineTo(37, 111)
            ..close(),
          fill,
        );
        canvas.drawArc(const Rect.fromLTWH(52, 20, 40, 45), 3.35, 2.95, false, paint);
        for (final y in <double>[68, 88]) {
          for (final x in <double>[52, 72, 92]) {
            canvas.drawRect(
              Rect.fromCenter(center: Offset(x, y), width: 10, height: 10),
              cutout,
            );
          }
        }
      case 'people':
        canvas.drawCircle(const Offset(51, 57), 18, fill);
        canvas.drawCircle(const Offset(94, 52), 14, fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27, 79, 51, 35),
            const Radius.circular(17),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(76, 76, 38, 31),
            const Radius.circular(15),
          ),
          fill,
        );
      case 'kids-corner':
        for (var index = 0; index < 5; index++) {
          canvas.save();
          canvas.translate(72, 65);
          canvas.rotate(index * math.pi * 2 / 5);
          canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..quadraticBezierTo(42, -9, 34, -39)
              ..quadraticBezierTo(8, -40, 0, 0)
              ..close(),
            fill,
          );
          canvas.restore();
        }
        canvas.drawCircle(const Offset(72, 65), 10, cutout);
        canvas.drawLine(const Offset(72, 71), const Offset(55, 119), paint);
      case 'alarms':
        canvas.drawCircle(const Offset(72, 76), 34, paint);
        canvas.drawLine(const Offset(72, 76), const Offset(72, 54), paint);
        canvas.drawLine(const Offset(72, 76), const Offset(91, 83), paint);
        canvas.drawArc(const Rect.fromLTWH(32, 19, 35, 35), 3.75, 2.3, false, paint);
        canvas.drawArc(const Rect.fromLTWH(77, 19, 35, 35), 1.1, 2.3, false, paint);
      case 'battery-saver':
        canvas.drawRect(const Rect.fromLTWH(24, 48, 86, 48), paint);
        canvas.drawRect(const Rect.fromLTWH(112, 62, 10, 20), fill);
        canvas.drawRect(const Rect.fromLTWH(33, 57, 34, 30), fill);
      case 'calculator':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(34, 24, 76, 96),
            const Radius.circular(5),
          ),
          fill,
        );
        canvas.drawRect(const Rect.fromLTWH(45, 36, 54, 18), cutout);
        for (final y in <double>[66, 84, 102]) {
          for (final x in <double>[50, 68, 86]) {
            canvas.drawCircle(Offset(x, y), 5, cutout);
          }
        }
      case 'calendar':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(26, 30, 92, 89),
            const Radius.circular(3),
          ),
          fill,
        );
        canvas.drawRect(const Rect.fromLTWH(26, 54, 92, 8), cutout);
        for (final x in <double>[44, 66, 88]) {
          for (final y in <double>[76, 95]) {
            canvas.drawRect(Rect.fromLTWH(x, y, 11, 11), cutout);
          }
        }
      case 'camera':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(20, 47, 104, 61),
            const Radius.circular(6),
          ),
          fill,
        );
        canvas.drawRect(const Rect.fromLTWH(43, 37, 33, 15), fill);
        canvas.drawCircle(const Offset(72, 77), 21, cutout);
        canvas.drawCircle(const Offset(72, 77), 12, fill);
      case 'cortana':
        canvas.drawCircle(const Offset(72, 72), 38, paint);
        canvas.drawCircle(const Offset(72, 72), 27, cutout);
      default:
        canvas.drawCircle(const Offset(72, 72), 33, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StartRoleIconPainter oldDelegate) =>
      oldDelegate.packageName != packageName;
}
