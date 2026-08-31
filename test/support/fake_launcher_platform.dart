import 'dart:async';
import 'dart:typed_data';

import 'package:metrophone/src/models/app_icon.dart';
import 'package:metrophone/src/models/installed_app.dart';
import 'package:metrophone/src/models/launcher_capabilities.dart';
import 'package:metrophone/src/models/notification_snapshot.dart';
import 'package:metrophone/src/platform/launcher_platform.dart';

class FakeLauncherPlatform implements LauncherPlatform {
  final events = StreamController<NotificationEvent>.broadcast();

  List<InstalledApp> installedApps = const [];
  List<NotificationSnapshot> notifications = const [];
  Completer<List<NotificationSnapshot>>? notificationGate;
  LauncherCapabilities currentCapabilities = LauncherCapabilities.unsupported;
  InstalledApp? launchedApp;
  bool requestedHomeRole = false;
  bool openedNotificationSettings = false;
  bool launchSucceeds = true;

  @override
  Future<List<InstalledApp>> getInstalledApps() async => installedApps;

  @override
  Future<AppIcon> getAppIcon(
    String packageName, {
    bool monochrome = false,
    int size = 144,
  }) async => AppIcon(
    bytes: Uint8List.fromList(const [137, 80, 78, 71]),
    isNativeMonochrome: monochrome,
  );

  @override
  Future<bool> launchApp(InstalledApp app) async {
    launchedApp = app;
    return launchSucceeds;
  }

  @override
  Future<LauncherCapabilities> getCapabilities() async => currentCapabilities;

  @override
  Future<bool> requestDefaultLauncher() async {
    requestedHomeRole = true;
    return true;
  }

  @override
  Future<bool> openNotificationAccessSettings() async {
    openedNotificationSettings = true;
    return true;
  }

  @override
  Future<List<NotificationSnapshot>> getActiveNotifications() async =>
      notificationGate?.future ?? notifications;

  @override
  Stream<NotificationEvent> get notificationEvents => events.stream;

  Future<void> close() => events.close();
}
