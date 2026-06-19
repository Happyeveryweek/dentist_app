import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/datetime_formatter.dart';

// 材料图片模型
class MaterialImage {
  final int? id;
  final int materialId;
  final Uint8List imageData; // 压缩后的图片二进制数据
  final Uint8List? thumbnailData; // 缩略图数据
  final String imageType; // 图片类型 (jpg, png, gif等)
  final int fileSize; // 文件大小（字节）
  final int? thumbnailSize; // 缩略图大小（字节）
  final String? originalName; // 原始文件名
  final String? imagePath; // 图片路径
  final DateTime createdAt;
  final bool hasThumbnail; // 是否有缩略图

  MaterialImage({
    this.id,
    required this.materialId,
    required this.imageData,
    this.thumbnailData,
    required this.imageType,
    required this.fileSize,
    this.thumbnailSize,
    this.originalName,
    this.imagePath, // 图片路径
    DateTime? createdAt,
    this.hasThumbnail = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // 从Map构造MaterialImage对象
  factory MaterialImage.fromMap(Map<String, dynamic> map) {
    // 仅记录解析行为及关键元信息，避免打印整张图片的二进制数据
    try {
      final previewId = map['id'];
      final previewName = map['original_name'] ?? map['originalName'] ?? '';
      print('MaterialImage.fromMap - 开始解析: ID=$previewId, 名称=$previewName');
    } catch (_) {
      print('MaterialImage.fromMap - 开始解析一条记录（详情省略）');
    }
    
    DateTime createdAt = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          createdAt = map['created_at'];
        } else {
          createdAt = DateTimeFormatter.fromDbString(map['created_at'].toString());
        }
      } catch (e) {
        print('解析created_at错误: ${map['created_at']}, 使用当前时间');
      }
    }

    // 处理图片数据
    Uint8List imageData = Uint8List(0);
    if (map['image_data'] != null) {
      // 仅记录类型信息，避免打印二进制内容
      try {
        print('处理图片数据: 类型=${map['image_data'].runtimeType}');
      } catch (_) {}
      
      if (map['image_data'] is Uint8List) {
        imageData = map['image_data'];
      } else if (map['image_data'] is List<int>) {
        imageData = Uint8List.fromList(map['image_data']);
      } else if (map['image_data'] is String) {
        // 如果是String类型，可能是二进制数据的错误表示或Base64字符串
          try {
            // 首先尝试Base64解码
            imageData = Uint8List.fromList(base64Decode(map['image_data']));
          } catch (e) {
            // 如果失败，尝试将字符串按字符编码转换为字节（作为最后手段），并记录错误但不打印数据
            try {
              final stringData = map['image_data'] as String;
              final bytes = <int>[];
              for (int i = 0; i < stringData.length; i++) {
                bytes.add(stringData.codeUnitAt(i));
              }
              if (bytes.isNotEmpty) {
                imageData = Uint8List.fromList(bytes);
              } else {
                imageData = Uint8List(0);
              }
            } catch (e2) {
              print('二进制字符串处理也失败（忽略数据）: $e2');
              imageData = Uint8List(0);
            }
          }
      } else {
        print('未知的图片数据类型: ${map['image_data'].runtimeType}');
      }
    } else {
      print('图片数据为空');
    }

    // 处理缩略图数据
    Uint8List? thumbnailData;
    if (map['thumbnail_data'] != null) {
      // 仅记录类型信息，避免打印二进制内容
      try {
        print('处理缩略图数据: 类型=${map['thumbnail_data'].runtimeType}');
      } catch (_) {}
      
      if (map['thumbnail_data'] is Uint8List) {
        thumbnailData = map['thumbnail_data'];
      } else if (map['thumbnail_data'] is List<int>) {
        thumbnailData = Uint8List.fromList(map['thumbnail_data']);
      } else if (map['thumbnail_data'] is String) {
        // 如果是String类型，可能是二进制数据的错误表示或Base64字符串
          try {
            thumbnailData = Uint8List.fromList(base64Decode(map['thumbnail_data']));
          } catch (e) {
            try {
              final stringData = map['thumbnail_data'] as String;
              final bytes = <int>[];
              for (int i = 0; i < stringData.length; i++) {
                bytes.add(stringData.codeUnitAt(i));
              }
              if (bytes.isNotEmpty) {
                thumbnailData = Uint8List.fromList(bytes);
              } else {
                thumbnailData = Uint8List(0);
              }
            } catch (e2) {
              print('二进制字符串处理缩略图也失败（忽略数据）: $e2');
              thumbnailData = Uint8List(0);
            }
          }
      } else {
        print('未知的缩略图数据类型: ${map['thumbnail_data'].runtimeType}');
      }
    } else {
      print('缩略图数据为空');
    }

    final result = MaterialImage(
      id: map['id'],
      materialId: map['material_id'],
      imageData: imageData,
      thumbnailData: thumbnailData,
      imageType: map['image_type'] ?? 'jpg',
      fileSize: map['file_size'] ?? 0,
      thumbnailSize: map['thumbnail_size'],
      originalName: map['original_name'],
      imagePath: map['image_path'], // 图片路径
      createdAt: createdAt,
      hasThumbnail: _parseBoolValue(map['has_thumbnail']), // 正确解析布尔值
    );
    
  print('MaterialImage.fromMap - 创建结果: ID=${result.id}, 类型=${result.imageType}, 大小=${result.fileSize}');
    return result;
  }

  // 辅助方法：解析布尔值，支持多种数据类型
  static bool _parseBoolValue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      return lowerValue == 'true' || lowerValue == '1' || lowerValue == 'yes';
    }
    return false;
  }

  // 将MaterialImage对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'image_data': imageData, // 直接存储字节数组
      'thumbnail_data': thumbnailData, // 缩略图数据
      'image_type': imageType,
      'file_size': fileSize,
      'thumbnail_size': thumbnailSize, // 缩略图大小
      'original_name': originalName,
      'image_path': imagePath, // 图片路径
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'has_thumbnail': hasThumbnail ? 1 : 0, // 将布尔值转换为整数以兼容SQLite
    };
  }

  // 复制MaterialImage对象，但可以修改部分属性
  MaterialImage copyWith({
    int? id,
    int? materialId,
    Uint8List? imageData,
    Uint8List? thumbnailData,
    String? imageType,
    int? fileSize,
    int? thumbnailSize,
    String? originalName,
    String? imagePath, // 图片路径
    DateTime? createdAt,
    bool? hasThumbnail,
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
      imagePath: imagePath ?? this.imagePath, // 图片路径
      createdAt: createdAt ?? this.createdAt,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
    );
  }

  // 获取文件大小的可读格式
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  // 获取缩略图大小的可读格式
  String get thumbnailSizeFormatted {
    if (thumbnailSize == null) return '无';
    if (thumbnailSize! < 1024) {
      return '${thumbnailSize}B';
    } else if (thumbnailSize! < 1024 * 1024) {
      return '${(thumbnailSize! / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(thumbnailSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  // 检查是否为支持的图片格式
  bool get isSupportedFormat {
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(
      imageType.toLowerCase(),
    );
  }

  // 获取缩略图数据，如果没有则返回原图数据
  Uint8List get displayImageData {
    return thumbnailData ?? imageData;
  }

  // 检查是否有可用的缩略图
  bool get hasValidThumbnail {
    // 不仅要检查数据是否存在和长度，还要检查数据是否看起来像有效的图片数据
    if (thumbnailData == null || thumbnailData!.isEmpty) {
      return false;
    }
    
    // 检查数据长度是否合理（至少几百字节）
    if (thumbnailData!.length < 100) {
      return false;
    }
    
    // 检查文件头是否看起来像图片（简单的启发式检查）
    if (thumbnailData!.length >= 2) {
      final firstBytes = thumbnailData!.take(2).toList();
      // JPEG文件头通常是 0xFF 0xD8
      // PNG文件头通常是 0x89 0x50
      // GIF文件头通常是 0x47 0x49
      if (firstBytes[0] == 0xFF && firstBytes[1] == 0xD8) {
        return true; // JPEG
      } else if (firstBytes[0] == 0x89 && firstBytes[1] == 0x50) {
        return true; // PNG
      } else if (firstBytes[0] == 0x47 && firstBytes[1] == 0x49) {
        return true; // GIF
      } else if (firstBytes[0] == 0x42 && firstBytes[1] == 0x4D) {
        return true; // BMP
      } else if (firstBytes[0] == 0x52 && firstBytes[1] == 0x49) {
        return true; // WebP
      }
    }
    
    // 如果无法识别文件头，但数据长度合理，仍然认为可能有效
    // 这样可以处理一些特殊的图片格式
    return true;
  }

  @override
  String toString() {
    return 'MaterialImage(id: $id, materialId: $materialId, imageType: $imageType, fileSize: $fileSizeFormatted, thumbnailSize: $thumbnailSizeFormatted, hasThumbnail: $hasThumbnail, originalName: $originalName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialImage &&
        other.id == id &&
        other.materialId == materialId &&
        other.imageType == imageType &&
        other.fileSize == fileSize &&
        other.hasThumbnail == hasThumbnail;
  }

  @override
  int get hashCode {
    return id.hashCode ^ materialId.hashCode ^ imageType.hashCode ^ fileSize.hashCode ^ hasThumbnail.hashCode;
  }
}
