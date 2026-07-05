import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../utils/image_compressor.dart';
import '../../../widgets/success_toast.dart';
import 'package:flutter/material.dart';
import '../../../utils/log_manager.dart';

/// 用户头像服务
/// 负责头像选择、验证、压缩、上传等业务逻辑
class UserAvatarService {
  /// 选择并上传图片
  ///
  /// [context] BuildContext 用于显示提示
  /// [onImageUploaded] 图片上传成功回调，参数为压缩后的图片数据和文件名
  static Future<void> pickAndUploadImage(
    BuildContext context,
    Function(List<int>, String) onImageUploaded,
  ) async {
    try {
      // 使用file_picker选择图片
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // 确保获取字节数据
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        // 获取字节数据
        Uint8List? bytes;

        // 优先使用bytes属性
        final fileBytes = file.bytes;
        if (fileBytes != null) {
          bytes = fileBytes;
        }
        // 如果bytes为空，尝试从路径读取
        else {
          final filePath = file.path;
          if (filePath != null) {
            try {
              final imageFile = File(filePath);
              bytes = await imageFile.readAsBytes();
            } catch (e) {
              LogManager.e('UserAvatarService', '从文件路径读取失败', error: e);
            }
          }
        }

        if (bytes == null) {
          LogManager.e('UserAvatarService', '无法获取图片数据');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '无法读取图片数据，请重试',
          );
          return;
        }

        // 验证图片格式
        if (!ImageCompressor.isValidImageFormat(bytes)) {
          LogManager.e('UserAvatarService', '图片格式验证失败');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '不支持的图片格式，请选择JPG、PNG等常见格式',
          );
          return;
        }

        // 获取原始图片信息
        final dimensions = ImageCompressor.getImageDimensions(bytes);
        if (dimensions != null) {}

        // 压缩图片
        final compressedBytes = await ImageCompressor.compressAvatar(bytes);

        if (compressedBytes == null) {
          LogManager.e('UserAvatarService', '图片压缩失败');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '图片处理失败，请重试',
          );
          return;
        }

        // 检查压缩后的大小
        if (compressedBytes.length > 500 * 1024) {
          // 超过500KB

          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '图片过大，请选择较小的图片',
          );
          return;
        }

        // 回调上传的图片数据和文件名
        final fileName = file.name;

        onImageUploaded(compressedBytes, fileName);

        if (!context.mounted) return;
        AppToastManager.showSuccess(
          context,
          message: '头像上传成功',
        );
      } else {}
    } catch (e) {
      LogManager.e('UserAvatarService', '选择图片失败', error: e);

      if (!context.mounted) return;
      AppToastManager.showError(
        context,
        message: '选择图片失败: $e',
      );
    }
  }
}
