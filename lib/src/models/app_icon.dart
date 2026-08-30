import 'dart:typed_data';

class AppIcon {
  const AppIcon({required this.bytes, required this.isNativeMonochrome});

  factory AppIcon.fromMap(Map<Object?, Object?> map) => AppIcon(
    bytes: map['bytes']! as Uint8List,
    isNativeMonochrome: map['isNativeMonochrome'] as bool? ?? false,
  );

  final Uint8List bytes;
  final bool isNativeMonochrome;
}
