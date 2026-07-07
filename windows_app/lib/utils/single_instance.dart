import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'log_manager.dart';

/// 单实例管理器 - 确保应用只能运行一个实例
class SingleInstance {
  static RandomAccessFile? _lockFile;
  static String? _lockFilePath;

  /// 检查是否已有实例在运行
  /// 返回 true 表示当前是唯一实例，可以继续运行
  /// 返回 false 表示已有实例在运行
  static Future<bool> checkSingleInstance() async {
    if (!Platform.isWindows) {
      // 非 Windows 平台暂不限制
      return true;
    }

    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      _lockFilePath = path.join(tempDir.path, 'dentist_app.lock');

      final lockFilePath = _lockFilePath;
      if (lockFilePath == null) return true;
      final lockFile = File(lockFilePath);

      // 尝试以独占模式打开文件
      try {
        final file = await lockFile.open(mode: FileMode.write);
        _lockFile = file;

        // 尝试获取独占锁
        await file.lock(FileLock.exclusive);

        // 写入当前进程ID
        await file.writeString('${1}\n${DateTime.now()}');
        await file.flush();

        return true;
      } catch (e) {
        LogManager.w('SingleInstance', '无法获取独占锁，应用已在运行', error: e);
        // 无法获取锁，说明已有实例在运行
        await _lockFile?.close();
        _lockFile = null;
        return false;
      }
    } catch (e) {
      LogManager.e('SingleInstance', '单实例检测失败', error: e);
      return true; // 出错时允许运行
    }
  }

  /// 释放锁（应用退出时调用）
  static Future<void> release() async {
    try {
      final file = _lockFile;
      if (file != null) {
        await file.unlock();
        await file.close();
        _lockFile = null;
      }

      // 删除锁文件
      final lockFilePath = _lockFilePath;
      if (lockFilePath != null) {
        final lockFile = File(lockFilePath);
        if (await lockFile.exists()) {
          await lockFile.delete();
        }
      }
    } catch (e) {
      LogManager.e('SingleInstance', '释放锁失败', error: e);
    }
  }
}
