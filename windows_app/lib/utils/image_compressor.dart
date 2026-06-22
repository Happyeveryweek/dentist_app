import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// 图片压缩结果类
class ImageCompressionResult {
  final Uint8List compressedBytes;
  final String imageType;
  final int compressedSize;
  final int originalSize;

  ImageCompressionResult({
    required this.compressedBytes,
    required this.imageType,
    required this.compressedSize,
    required this.originalSize,
  });

  double get compressionRatio => 
      ((1 - compressedSize / originalSize) * 100);
}

/// 图片压缩工具类
/// 用于压缩用户上传的头像图片和材料图片，减小数据库存储空间
class ImageCompressor {
  // 头像最大尺寸（像素）
  static const int maxAvatarSize = 200;
  
  // 材料图片最大尺寸（像素）
  static const int maxMaterialImageSize = 1024;
  
  // 缩略图最大尺寸（像素）
  static const int maxThumbnailSize = 200;
  
  // 压缩质量（0-100）
  static const int compressionQuality = 85;
  
  // 缩略图压缩质量
  static const int thumbnailQuality = 80;
  
  /// 压缩图片数据
  /// 
  /// [imageBytes] 原始图片字节数据
  /// [maxSize] 最大尺寸（宽度和高度的最大值）
  /// [quality] 压缩质量（0-100）
  /// 
  /// 返回压缩后的图片字节数据
  static Future<Uint8List?> compressImage(
    Uint8List imageBytes, {
    int maxSize = maxAvatarSize,
    int quality = compressionQuality,
  }) async {
    try {
      // 解码图片
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('图片解码失败');
        return null;
      }
      
      print('原始图片尺寸: ${image.width}x${image.height}, 大小: ${imageBytes.length} 字节');
      
      // 计算缩放比例
      int targetWidth = image.width;
      int targetHeight = image.height;
      
      if (image.width > maxSize || image.height > maxSize) {
        double scale = maxSize / (image.width > image.height ? image.width : image.height);
        targetWidth = (image.width * scale).round();
        targetHeight = (image.height * scale).round();
        
        // 调整图片大小
        image = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );
        
        print('图片已缩放至: ${targetWidth}x${targetHeight}');
      }
      
      // 编码为JPEG格式（比PNG更小）
      List<int> compressedBytes = img.encodeJpg(image, quality: quality);
      
      print('压缩后图片大小: ${compressedBytes.length} 字节');
      print('压缩率: ${((1 - compressedBytes.length / imageBytes.length) * 100).toStringAsFixed(1)}%');
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('图片压缩失败: $e');
      return null;
    }
  }
  
  /// 压缩图片文件（用于材料管理）
  /// 
  /// [file] 图片文件
  /// [maxSize] 最大尺寸
  /// [quality] 压缩质量
  /// 
  /// 返回压缩结果对象
  static Future<ImageCompressionResult> compressImageFile(
    File file, {
    int maxSize = maxMaterialImageSize,
    int quality = compressionQuality,
  }) async {
    try {
      // 读取文件
      final bytes = await file.readAsBytes();
      final originalSize = bytes.length;
      
      // 解码图片
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('无法解码图片文件');
      }
      
      // 确定图片类型
      String imageType = 'jpg';
      final extension = file.path.split('.').last.toLowerCase();
      if (extension == 'png') {
        imageType = 'png';
      }
      
      print('原始图片: ${image.width}x${image.height}, ${originalSize} 字节');
      
      // 计算缩放比例
      int targetWidth = image.width;
      int targetHeight = image.height;
      
      if (image.width > maxSize || image.height > maxSize) {
        double scale = maxSize / (image.width > image.height ? image.width : image.height);
        targetWidth = (image.width * scale).round();
        targetHeight = (image.height * scale).round();
        
        // 调整图片大小
        image = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );
        
        print('图片已缩放至: ${targetWidth}x${targetHeight}');
      }
      
      // 编码为JPEG格式
      List<int> compressedBytes = img.encodeJpg(image, quality: quality);
      
      print('压缩后图片: ${compressedBytes.length} 字节');
      print('压缩率: ${((1 - compressedBytes.length / originalSize) * 100).toStringAsFixed(1)}%');
      
      return ImageCompressionResult(
        compressedBytes: Uint8List.fromList(compressedBytes),
        imageType: imageType,
        compressedSize: compressedBytes.length,
        originalSize: originalSize,
      );
    } catch (e) {
      print('压缩图片文件失败: $e');
      rethrow;
    }
  }
  
  /// 生成缩略图
  /// 
  /// [imageBytes] 原始图片字节数据
  /// [maxSize] 缩略图最大尺寸
  /// [quality] 压缩质量
  /// 
  /// 返回缩略图字节数据
  static Future<Uint8List> generateThumbnail(
    Uint8List imageBytes, {
    int maxSize = maxThumbnailSize,
    int quality = thumbnailQuality,
  }) async {
    try {
      // 解码图片
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('无法解码图片');
      }
      
      // 计算缩放比例
      int targetWidth = image.width;
      int targetHeight = image.height;
      
      if (image.width > maxSize || image.height > maxSize) {
        double scale = maxSize / (image.width > image.height ? image.width : image.height);
        targetWidth = (image.width * scale).round();
        targetHeight = (image.height * scale).round();
        
        // 调整图片大小
        image = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );
      }
      
      // 编码为JPEG格式
      List<int> thumbnailBytes = img.encodeJpg(image, quality: quality);
      
      print('缩略图生成: ${targetWidth}x${targetHeight}, ${thumbnailBytes.length} 字节');
      
      return Uint8List.fromList(thumbnailBytes);
    } catch (e) {
      print('生成缩略图失败: $e');
      rethrow;
    }
  }
  
  /// 压缩头像图片（使用默认头像尺寸）
  static Future<Uint8List?> compressAvatar(Uint8List imageBytes) async {
    return compressImage(imageBytes, maxSize: maxAvatarSize);
  }
  
  /// 验证图片格式
  static bool isValidImageFormat(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取图片尺寸信息
  static Map<String, int>? getImageDimensions(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;
      
      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      return null;
    }
  }
}
