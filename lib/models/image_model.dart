import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageModel {
  final String id;
  final String? path;
  final Uint8List? bytes;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  // 편집 상태 관련 속성
  double rotation;
  double scale;
  List<ImageFilter> appliedFilters;
  List<TextOverlay> textOverlays;
  CropData? cropData;

  ImageModel({
    required this.id,
    this.path,
    this.bytes,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
    this.rotation = 0.0,
    this.scale = 1.0,
    List<ImageFilter>? appliedFilters,
    List<TextOverlay>? textOverlays,
    this.cropData,
  })  : appliedFilters = appliedFilters ?? [],
        textOverlays = textOverlays ?? [];

  ImageModel copyWith({
    String? id,
    String? path,
    Uint8List? bytes,
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    double? rotation,
    double? scale,
    List<ImageFilter>? appliedFilters,
    List<TextOverlay>? textOverlays,
    CropData? cropData,
  }) {
    return ImageModel(
      id: id ?? this.id,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      appliedFilters: appliedFilters ?? this.appliedFilters,
      textOverlays: textOverlays ?? this.textOverlays,
      cropData: cropData ?? this.cropData,
    );
  }
}

class ImageFilter {
  final String name;
  final FilterType type;
  final double intensity;

  ImageFilter({
    required this.name,
    required this.type,
    this.intensity = 1.0,
  });
}

enum FilterType {
  brightness,
  contrast,
  saturation,
  sepia,
  grayscale,
  vintage,
}

class TextOverlay {
  final String text;
  final double x;
  final double y;
  final double fontSize;
  final String fontFamily;
  final int color;
  final double rotation;

  TextOverlay({
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 20.0,
    this.fontFamily = 'Roboto',
    this.color = 0xFFFFFFFF,
    this.rotation = 0.0,
  });
}

class CropData {
  final double x;
  final double y;
  final double width;
  final double height;

  CropData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
