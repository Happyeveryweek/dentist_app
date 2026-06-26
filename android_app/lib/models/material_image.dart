import 'dart:convert';
import 'dart:typed_data';
import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';
import '../utils/map_parser.dart';

class MaterialImage {
  final int? id;
  final int? materialId;
  final List<int> imageData;
  final List<int>? thumbnailData;
  final String imageType;
  final int? fileSize;
  final int? thumbnailSize;
  final String? originalName;
  final DateTime createdAt;
  final int? hasThumbnail;
  final String? imagePath;

  MaterialImage({
    this.id,
    this.materialId,
    required this.imageData,
    this.thumbnailData,
    required this.imageType,
    this.fileSize,
    this.thumbnailSize,
    this.originalName,
    required this.createdAt,
    this.hasThumbnail,
    this.imagePath,
  });

  factory MaterialImage.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'MaterialImage');
    return MaterialImage(
      id: p.optional('id', (v) => v as int),
      materialId: p.optional('material_id', (v) => v as int),
      imageData: _parseImageData(map['image_data']) ?? <int>[],
      thumbnailData: _parseImageData(map['thumbnail_data']),
      imageType: p.string('image_type', defaultValue: 'jpg'),
      fileSize: p.optional('file_size', (v) => v as int),
      thumbnailSize: p.optional('thumbnail_size', (v) => v as int),
      originalName: _decodeOriginalName(
        map['original_name']?.toString() ?? map['originalName']?.toString(),
      ),
      createdAt: _parseCreatedAt(map['created_at']),
      hasThumbnail: p.optional('has_thumbnail', (v) => v as int),
      imagePath: p.stringOptional('image_path'),
    );
  }

  // 辅助方法：解析图片/缩略图二进制数据
  static List<int>? _parseImageData(dynamic value) {
    if (value == null) return null;
    if (value is List<int>) return value;
    if (value is Uint8List) return value.toList();
    if (value is String) {
      try {
        final bytes = <int>[];
        for (int i = 0; i < value.length; i++) {
          bytes.add(value.codeUnitAt(i));
        }
        return bytes.isNotEmpty ? bytes : <int>[];
      } catch (e) {
        AppLogger.info('MaterialImage: 二进制字符串处理失败: $e');
        return <int>[];
      }
    }
    AppLogger.info('MaterialImage: 未知的图片数据类型: ${value.runtimeType}');
    return <int>[];
  }

  static String? _decodeOriginalName(String? value) {
    if (value == null || value.isEmpty) {
      return value;
    }

    if (value.contains('%')) {
      try {
        final decoded = Uri.decodeComponent(value);
        if (decoded.isNotEmpty) {
          return decoded;
        }
      } catch (_) {
        // 保持原值，继续尝试其他兼容方式
      }
    }

    final looksLikeMojibake =
        value.contains('�') || RegExp(r'[ÃÂÄÅÆÇÐÑØÙÚÛÜÝÞßà-ÿ]').hasMatch(value);
    if (!looksLikeMojibake) {
      return value;
    }

    try {
      final decoded = utf8.decode(latin1.encode(value));
      return decoded.isEmpty ? value : decoded;
    } catch (_) {
      return value;
    }
  }

  // 时间解析辅助函数
  static DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      if (value.isEmpty) return DateTime.now();
      return DateTimeFormatter.fromDbString(value);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'image_data': imageData,
      'thumbnail_data': thumbnailData,
      'image_type': imageType,
      'file_size': fileSize,
      'thumbnail_size': thumbnailSize,
      'original_name': originalName,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'has_thumbnail': hasThumbnail,
      'image_path': imagePath,
    };
  }

  String get displayOriginalName => originalName ?? '图片详情';

  MaterialImage copyWith({
    int? id,
    int? materialId,
    List<int>? imageData,
    List<int>? thumbnailData,
    String? imageType,
    int? fileSize,
    int? thumbnailSize,
    String? originalName,
    DateTime? createdAt,
    int? hasThumbnail,
    String? imagePath,
  }) {
    return MaterialImage(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      imageData: imageData ?? this.imageData,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      imageType: imageType ?? this.imageType,
      fileSize: fileSize ?? this.fileSize,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      originalName: originalName ?? this.originalName,
      createdAt: createdAt ?? this.createdAt,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  String toString() {
    return 'MaterialImage(id: $id, materialId: $materialId, imageType: $imageType, originalName: $originalName, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialImage &&
        other.id == id &&
        other.materialId == materialId &&
        other.imageType == imageType &&
        other.originalName == originalName &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, materialId, imageType, originalName, createdAt);
  }
}
