import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../utils/app_logger.dart';

/// 权限管理服务
/// 负责处理应用权限请求，包括存储权限、照片权限等
class PermissionService {
  /// 请求存储权限
  ///
  /// 返回 true 表示权限已授予，false 表示权限被拒绝
  static Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // 判断Android版本
        if (await Permission.manageExternalStorage.isGranted) {
          return true; // 已有权限
        }

        // 请求管理外部存储权限（Android 11+）
        PermissionStatus manageStatus =
            await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          return true;
        }

        // 尝试请求普通存储权限
        Map<Permission, PermissionStatus> statuses =
            await [Permission.storage].request();

        if (statuses[Permission.storage]!.isGranted) {
          return true;
        } else {
          return false;
        }
      } else if (Platform.isIOS) {
        // iOS请求权限
        PermissionStatus status = await Permission.photos.request();
        return status.isGranted;
      } else {
        // 其他平台默认允许
        return true;
      }
    } catch (e) {
      AppLogger.info('请求权限出错: $e');
      return false;
    }
  }

  /// 显示权限设置对话框
  ///
  /// [context] - BuildContext 用于显示对话框
  /// [onOpenSettings] - 打开设置的回调
  static void showPermissionSettingsDialog(
    BuildContext context,
    VoidCallback onOpenSettings,
  ) {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('需要存储权限'),
            content: const Text('请前往设置中授予应用存储权限，以便选择和读取数据库文件。'),
            actions: [
              TextButton(
                child: const Text('取消'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('去设置'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenSettings();
                },
              ),
            ],
          ),
    );
  }
}
