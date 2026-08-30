class NotificationSnapshot {
  const NotificationSnapshot({
    required this.key,
    required this.packageName,
    required this.postedAt,
    required this.isOngoing,
    this.title,
    this.text,
    this.category,
  });

  factory NotificationSnapshot.fromMap(Map<Object?, Object?> map) =>
      NotificationSnapshot(
        key: map['key']! as String,
        packageName: map['packageName']! as String,
        postedAt: DateTime.fromMillisecondsSinceEpoch(map['postedAt']! as int),
        isOngoing: map['isOngoing'] as bool? ?? false,
        title: map['title'] as String?,
        text: map['text'] as String?,
        category: map['category'] as String?,
      );

  final String key;
  final String packageName;
  final DateTime postedAt;
  final bool isOngoing;
  final String? title;
  final String? text;
  final String? category;
}

enum NotificationEventType { posted, removed, reset }

class NotificationEvent {
  const NotificationEvent({required this.type, this.notification, this.key});

  factory NotificationEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = map['type'] as String?;
    final rawNotification = map['notification'];
    return NotificationEvent(
      type: switch (rawType) {
        'posted' => NotificationEventType.posted,
        'removed' => NotificationEventType.removed,
        _ => NotificationEventType.reset,
      },
      notification: rawNotification is Map<Object?, Object?>
          ? NotificationSnapshot.fromMap(rawNotification)
          : null,
      key: map['key'] as String?,
    );
  }

  final NotificationEventType type;
  final NotificationSnapshot? notification;
  final String? key;
}

class LiveTileContent {
  const LiveTileContent({
    required this.notificationCount,
    required this.updatedAt,
    this.title,
    this.text,
  });

  final int notificationCount;
  final DateTime updatedAt;
  final String? title;
  final String? text;
}
