class LauncherCapabilities {
  const LauncherCapabilities({
    required this.sdkInt,
    required this.isDefaultLauncher,
    required this.canRequestHomeRole,
    required this.hasNotificationAccess,
    required this.supportsNativeMonochromeIcons,
  });

  factory LauncherCapabilities.fromMap(Map<Object?, Object?> map) =>
      LauncherCapabilities(
        sdkInt: map['sdkInt']! as int,
        isDefaultLauncher: map['isDefaultLauncher']! as bool,
        canRequestHomeRole: map['canRequestHomeRole']! as bool,
        hasNotificationAccess: map['hasNotificationAccess']! as bool,
        supportsNativeMonochromeIcons:
            map['supportsNativeMonochromeIcons']! as bool,
      );

  static const unsupported = LauncherCapabilities(
    sdkInt: 0,
    isDefaultLauncher: false,
    canRequestHomeRole: false,
    hasNotificationAccess: false,
    supportsNativeMonochromeIcons: false,
  );

  final int sdkInt;
  final bool isDefaultLauncher;
  final bool canRequestHomeRole;
  final bool hasNotificationAccess;
  final bool supportsNativeMonochromeIcons;
}
