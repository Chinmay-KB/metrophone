import 'package:flutter/services.dart';

import '../models/app_icon.dart';
import '../models/installed_app.dart';
import '../models/launcher_capabilities.dart';
import '../models/notification_snapshot.dart';
import 'launcher_platform.dart';

class MethodChannelLauncherPlatform implements LauncherPlatform {
  MethodChannelLauncherPlatform({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(_methodChannelName),
      _events = events ?? const EventChannel(_eventChannelName);

  static const _methodChannelName = 'metrophone/launcher';
  static const _eventChannelName = 'metrophone/notifications';

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<List<InstalledApp>> getInstalledApps() async {
    final raw = await _methods.invokeListMethod<Object?>('getInstalledApps');
    return [
      for (final item in raw ?? const <Object?>[])
        InstalledApp.fromMap((item! as Map<Object?, Object?>)),
    ];
  }

  @override
  Future<AppIcon> getAppIcon(
    String packageName, {
    bool monochrome = false,
    int size = 144,
  }) async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getAppIcon',
      <String, Object?>{
        'packageName': packageName,
        'monochrome': monochrome,
        'size': size,
      },
    );
    if (raw == null) {
      throw PlatformException(
        code: 'missing_icon',
        message: 'Android returned no icon for $packageName.',
      );
    }
    return AppIcon.fromMap(raw);
  }

  @override
  Future<bool> launchApp(InstalledApp app) async =>
      await _methods.invokeMethod<bool>('launchApp', <String, Object?>{
        'packageName': app.packageName,
        'activityName': app.activityName,
      }) ??
      false;

  @override
  Future<LauncherCapabilities> getCapabilities() async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getCapabilities',
    );
    return raw == null
        ? LauncherCapabilities.unsupported
        : LauncherCapabilities.fromMap(raw);
  }

  @override
  Future<bool> requestDefaultLauncher() async =>
      await _methods.invokeMethod<bool>('requestDefaultLauncher') ?? false;

  @override
  Future<bool> openNotificationAccessSettings() async =>
      await _methods.invokeMethod<bool>('openNotificationAccessSettings') ??
      false;

  @override
  Future<List<NotificationSnapshot>> getActiveNotifications() async {
    final raw = await _methods.invokeListMethod<Object?>(
      'getActiveNotifications',
    );
    return [
      for (final item in raw ?? const <Object?>[])
        NotificationSnapshot.fromMap(item! as Map<Object?, Object?>),
    ];
  }

  @override
  late final Stream<NotificationEvent> notificationEvents = _events
      .receiveBroadcastStream()
      .where((event) => event is Map<Object?, Object?>)
      .map(
        (event) => NotificationEvent.fromMap(event! as Map<Object?, Object?>),
      );
}
