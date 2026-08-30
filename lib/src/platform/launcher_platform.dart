import '../models/app_icon.dart';
import '../models/installed_app.dart';
import '../models/launcher_capabilities.dart';
import '../models/notification_snapshot.dart';

abstract interface class LauncherPlatform {
  Future<List<InstalledApp>> getInstalledApps();

  Future<AppIcon> getAppIcon(
    String packageName, {
    bool monochrome = false,
    int size = 144,
  });

  Future<bool> launchApp(InstalledApp app);

  Future<LauncherCapabilities> getCapabilities();

  Future<bool> requestDefaultLauncher();

  Future<bool> openNotificationAccessSettings();

  Future<List<NotificationSnapshot>> getActiveNotifications();

  Stream<NotificationEvent> get notificationEvents;
}
