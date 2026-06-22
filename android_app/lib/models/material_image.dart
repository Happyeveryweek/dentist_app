import 'dart:convert';
import 'dart:typed_data';
import '../utils/datetime_formatter.dart';

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
    // 处理图片数据
    List<int> imageData = <int>[];
    if (map['image_data'] != null) {
      if (map['image_data'] is List<int>) {
        imageData = map['image_data'];
      } else if (map['image_data'] is Uint8List) {
        imageData = map['image_data'].toList();
      } else if (map['image_data'] is String) {
        // 如果是String类型，可能是二进制数据的错误表示
        try {
          // 尝试直接处理字符串中的字节数据
          final stringData = map['image_data'] as String;
          final bytes = <int>[];
          
          // 处理可能包含特殊字符的二进制字符串
          // 对于JPEG等二进制数据，直接使用字符代码
          for (int i = 0; i < stringData.length; i++) {
            final charCode = stringData.codeUnitAt(i);
            // 对于二进制数据，直接添加字符代码，不过滤
            bytes.add(charCode);
          }
          
          if (bytes.isNotEmpty) {
            imageData = bytes;
          } else {
            imageData = <int>[];
          }
        } catch (e) {
          print('MaterialImage: 二进制字符串处理失败: $e');
          imageData = <int>[];
        }
      } else {
        print('MaterialImage: 未知的图片数据类型: ${map['image_data'].runtimeType}');
        imageData = <int>[];
      }
    }

    // 处理缩略图数据
    List<int>? thumbnailData;
    if (map['thumbnail_data'] != null) {
      if (map['thumbnail_data'] is List<int>) {
        thumbnailData = map['thumbnail_data'];
      } else if (map['thumbnail_data'] is Uint8List) {
        thumbnailData = map['thumbnail_data'].toList();
      } else if (map['thumbnail_data'] is String) {
        // 如果是String类型，可能是二进制数据的错误表示
        try {
          // 尝试直接处理字符串中的字节数据
          final stringData = map['thumbnail_data'] as String;
          final bytes = <int>[];
          
          // 处理可能包含特殊字符的二进制字符串
          // 对于JPEG等二进制数据，直接使用字符代码
          for (int i = 0; i < stringData.length; i++) {
            final charCode = stringData.codeUnitAt(i);
            // 对于二进制数据，直接添加字符代码，不过滤
            bytes.add(charCode);
          }
          
          if (bytes.isNotEmpty) {
            thumbnailData = bytes;
          } else {
            thumbnailData = <int>[];
          }
        } catch (e) {
          print('MaterialImage: 二进制字符串处理缩略图失败: $e');
          thumbnailData = <int>[];
        }
      } else {
        print('MaterialImage: 未知的缩略图数据类型: ${map['thumbnail_data'].runtimeType}');
        thumbnailData = <int>[];
      }
    }

    return MaterialImage(
      id: map['id'] as int?,
      materialId: map['material_id'] as int?,
      imageData: imageData,
      thumbnailData: thumbnailData,
      imageType: map['image_type'] as String? ?? 'jpg',
      fileSize: map['file_size'] as int?,
      thumbnailSize: map['thumbnail_size'] as int?,
      originalName: _decodeOriginalName(
        map['original_name']?.toString() ?? map['originalName']?.toString(),
      ),
      createdAt: _parseCreatedAt(map['created_at']),
      hasThumbnail: map['has_thumbnail'] as int?,
      imagePath: map['image_path'] as String?,
    );
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

    final looksLikeMojibake = value.contains('�') ||
        RegExp(r'[ÃÂÄÅÆÇÐÑØÙÚÛÜÝÞßà-ÿ]').hasMatch(value);
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
