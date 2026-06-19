import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../utils/image_compressor.dart';
import '../../../widgets/success_toast.dart';
import 'package:flutter/material.dart';

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
      print('开始选择图片...');
      
      // 使用file_picker选择图片
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // 确保获取字节数据
      );

      print('文件选择结果: ${result != null ? "有文件" : "无文件"}');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('选中文件: ${file.name}, 路径: ${file.path}');
        
        // 获取字节数据
        Uint8List? bytes;
        
        // 优先使用bytes属性
        if (file.bytes != null) {
          bytes = file.bytes!;
          print('从bytes属性获取数据: ${bytes.length} 字节');
        } 
        // 如果bytes为空，尝试从路径读取
        else if (file.path != null) {
          try {
            final imageFile = File(file.path!);
            bytes = await imageFile.readAsBytes();
            print('从文件路径读取数据: ${bytes.length} 字节');
          } catch (e) {
            print('从文件路径读取失败: $e');
          }
        }
        
        if (bytes == null) {
          print('无法获取图片数据');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '无法读取图片数据，请重试',
          );
          return;
        }
        
        print('开始验证图片格式...');
        // 验证图片格式
        if (!ImageCompressor.isValidImageFormat(bytes)) {
          print('图片格式验证失败');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '不支持的图片格式，请选择JPG、PNG等常见格式',
          );
          return;
        }
        
        print('图片格式验证通过');
        
        // 获取原始图片信息
        final dimensions = ImageCompressor.getImageDimensions(bytes);
        if (dimensions != null) {
          print('原始图片尺寸: ${dimensions['width']}x${dimensions['height']}');
        }
        
        print('开始压缩图片...');
        // 压缩图片
        final compressedBytes = await ImageCompressor.compressAvatar(bytes);
        
        if (compressedBytes == null) {
          print('图片压缩失败');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '图片处理失败，请重试',
          );
          return;
        }
        
        print('图片压缩成功: ${compressedBytes.length} 字节');
        
        // 检查压缩后的大小
        if (compressedBytes.length > 500 * 1024) { // 超过500KB
          print('压缩后图片仍然过大: ${compressedBytes.length} 字节');
          if (!context.mounted) return;
          AppToastManager.showError(
            context,
            message: '图片过大，请选择较小的图片',
          );
          return;
        }
        
        print('调用回调函数更新图片数据...');
        // 回调上传的图片数据和文件名
        final fileName = file.name;
        print('图片文件名: $fileName');
        onImageUploaded(compressedBytes, fileName);
        
        print('头像上传完成');
        if (!context.mounted) return;
        AppToastManager.showSuccess(
          context,
          message: '头像上传成功',
        );
      } else {
        print('用户取消了文件选择');
      }
    } catch (e, stackTrace) {
      print('选择图片失败: $e');
      print('堆栈跟踪: $stackTrace');
      if (!context.mounted) return;
      AppToastManager.showError(
        context,
        message: '选择图片失败: $e',
      );
    }
  }
}
