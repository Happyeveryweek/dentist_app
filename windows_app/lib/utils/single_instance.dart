import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
      
      print('🔒 尝试创建锁文件: $_lockFilePath');
      
      final lockFile = File(_lockFilePath!);
      
      // 尝试以独占模式打开文件
      try {
        _lockFile = await lockFile.open(mode: FileMode.write);
        
        // 尝试获取独占锁
        await _lockFile!.lock(FileLock.exclusive);
        
        // 写入当前进程ID
        await _lockFile!.writeString('${pid}\n${DateTime.now()}');
        await _lockFile!.flush();
        
        print('✅ 成功获取独占锁，当前是唯一实例');
        return true;
      } catch (e) {
        print('❌ 无法获取独占锁，应用已在运行: $e');
        // 无法获取锁，说明已有实例在运行
        await _lockFile?.close();
        _lockFile = null;
        return false;
      }
    } catch (e) {
      print('⚠️ 单实例检测失败: $e');
      return true; // 出错时允许运行
    }
  }

  /// 释放锁（应用退出时调用）
  static Future<void> release() async {
    try {
      if (_lockFile != null) {
        await _lockFile!.unlock();
        await _lockFile!.close();
        _lockFile = null;
        print('🔓 已释放锁文件');
      }
      
      // 删除锁文件
      if (_lockFilePath != null) {
        final lockFile = File(_lockFilePath!);
        if (await lockFile.exists()) {
          await lockFile.delete();
          print('🗑️ 已删除锁文件');
        }
      }
    } catch (e) {
      print('⚠️ 释放锁失败: $e');
    }
  }
}
