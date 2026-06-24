import 'dart:typed_data';
import 'package:image/image.dart' as img;
import './app_logger.dart';

/// 图片压缩工具类
/// 用于压缩用户上传的头像图片，减小数据库存储空间
class ImageCompressor {
  // 头像最大尺寸（像素）
  static const int maxAvatarSize = 200;

  // 压缩质量（0-100）
  static const int compressionQuality = 85;

  /// 压缩头像图片（使用默认头像尺寸）
  static Future<Uint8List?> compressAvatar(Uint8List imageBytes) async {
    return compressImage(imageBytes, maxSize: maxAvatarSize);
  }

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
        AppLogger.info('图片解码失败');
        return null;
      }

      AppLogger.info(
        '原始图片尺寸: ${image.width}x${image.height}, 大小: ${imageBytes.length} 字节',
      );

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

        AppLogger.info('图片已缩放至: ${targetWidth}x$targetHeight');
      }

      // 编码为JPEG格式（比PNG更小）
      List<int> compressedBytes = img.encodeJpg(image, quality: quality);

      AppLogger.info('压缩后图片大小: ${compressedBytes.length} 字节');
      AppLogger.info(
        '压缩率: ${((1 - compressedBytes.length / imageBytes.length) * 100).toStringAsFixed(1)}%',
      );

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      AppLogger.info('图片压缩失败: $e');
      return null;
    }
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

      return {'width': image.width, 'height': image.height};
    } catch (e) {
      return null;
    }
  }
}
