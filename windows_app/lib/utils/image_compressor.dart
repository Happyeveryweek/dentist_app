import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'log_manager.dart';

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

  double get compressionRatio => ((1 - compressedSize / originalSize) * 100);
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
        LogManager.e('ImageCompressor', '图片解码失败');
        return null;
      }

      // 计算缩放比例
      int targetWidth = image.width;
      int targetHeight = image.height;

      if (image.width > maxSize || image.height > maxSize) {
        double scale =
            maxSize / (image.width > image.height ? image.width : image.height);
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

      // 编码为JPEG格式（比PNG更小）
      List<int> compressedBytes = img.encodeJpg(image, quality: quality);

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      LogManager.e('ImageCompressor', '图片压缩失败', error: e);
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
      final bytes = await file.readAsBytes();
      final originalSize = bytes.length;
      final extension = file.path.split('.').last.toLowerCase();
      final imageType = extension == 'png' ? 'png' : 'jpg';
      final compressedBytes = await Isolate.run(
        () => _encodeResizedJpeg(bytes, maxSize, quality, '无法解码图片文件'),
      );

      LogManager.w(
        'ImageCompressor',
        '原始图片: $originalSize 字节, 压缩后: ${compressedBytes.length} 字节',
      );

      return ImageCompressionResult(
        compressedBytes: compressedBytes,
        imageType: imageType,
        compressedSize: compressedBytes.length,
        originalSize: originalSize,
      );
    } catch (e) {
      LogManager.e('ImageCompressor', '压缩图片文件失败', error: e);
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
      return await Isolate.run(
        () => _encodeResizedJpeg(imageBytes, maxSize, quality, '无法解码图片'),
      );
    } catch (e) {
      LogManager.e('ImageCompressor', '生成缩略图失败', error: e);
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

Uint8List _encodeResizedJpeg(
  Uint8List bytes,
  int maxSize,
  int quality,
  String decodeError,
) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception(decodeError);
  }

  var output = image;
  if (image.width > maxSize || image.height > maxSize) {
    final scale =
        maxSize / (image.width > image.height ? image.width : image.height);
    output = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  return Uint8List.fromList(img.encodeJpg(output, quality: quality));
}
