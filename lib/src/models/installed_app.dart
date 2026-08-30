class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.activityName,
    required this.label,
    required this.isSystemApp,
    this.versionName,
  });

  factory InstalledApp.fromMap(Map<Object?, Object?> map) => InstalledApp(
    packageName: map['packageName']! as String,
    activityName: map['activityName']! as String,
    label: map['label']! as String,
    isSystemApp: map['isSystemApp'] as bool? ?? false,
    versionName: map['versionName'] as String?,
  );

  final String packageName;
  final String activityName;
  final String label;
  final bool isSystemApp;
  final String? versionName;
}
