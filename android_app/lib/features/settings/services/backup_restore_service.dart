import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../../../utils/app_logger.dart';

/// 备份恢复服务
/// 负责数据库备份、恢复、导入导出
class BackupRestoreService {
  /// 备份数据库
  ///
  /// [backupPath] - 备份文件路径
  /// [currentDbPath] - 当前数据库路径
  /// [dbType] - 数据库类型
  ///
  /// 返回 true 表示备份成功，false 表示备份失败
  static Future<bool> backupDatabase(
    String backupPath,
    String currentDbPath,
    String dbType,
  ) async {
    try {
      AppLogger.info('开始备份SQLite数据库到: $backupPath');

      // 确认当前是SQLite数据库类型
      if (dbType != 'sqlite') {
        AppLogger.info('错误：只能备份SQLite数据库');
        return false;
      }

      // 获取SQLite数据库文件路径
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : '';
      if (dbPath.isEmpty) {
        AppLogger.info('错误：无法获取SQLite数据库路径');
        return false;
      }

      // 复制数据库文件
      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        AppLogger.info('错误：源数据库文件不存在');
        return false;
      }

      await sourceFile.copy(backupPath);
      AppLogger.info('数据库文件已备份到: $backupPath');

      // 创建目标目录（如果不存在）
      final dir = File(backupPath).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      return true;
    } catch (e) {
      AppLogger.info('备份数据库错误: $e');
      return false;
    }
  }

  /// 从备份恢复数据库
  ///
  /// [backupPath] - 备份文件路径
  /// [currentDbPath] - 当前数据库路径
  /// [dbType] - 数据库类型
  ///
  /// 返回 true 表示恢复成功，false 表示恢复失败
  static Future<bool> restoreDatabaseFromBackup(
    String backupPath,
    String currentDbPath,
    String dbType,
  ) async {
    try {
      AppLogger.info('开始从备份恢复SQLite数据库: $backupPath');

      // 确认当前是SQLite数据库类型
      if (dbType != 'sqlite') {
        AppLogger.info('错误：只能恢复到SQLite数据库');
        return false;
      }

      // 检查备份文件是否存在
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        AppLogger.info('错误：备份文件不存在');
        return false;
      }

      // 获取SQLite数据库文件路径
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : '';
      if (dbPath.isEmpty) {
        AppLogger.info('错误：无法获取SQLite数据库路径');
        return false;
      }

      // 复制备份文件到数据库位置
      await backupFile.copy(dbPath);
      AppLogger.info('备份文件已恢复到数据库');

      return true;
    } catch (e) {
      AppLogger.info('恢复数据库错误: $e');
      return false;
    }
  }

  /// 选择备份文件
  ///
  /// 返回选择的文件路径，如果用户取消则返回 null
  static Future<String?> selectBackupFile() async {
    try {
      const XTypeGroup sqliteGroup = XTypeGroup(
        label: '数据库备份文件',
        extensions: ['db', 'sqlite', 'sqlite3'],
        mimeTypes: [
          'application/octet-stream',
          'application/x-sqlite3',
          'application/vnd.sqlite3',
        ],
        uniformTypeIdentifiers: ['public.database', 'public.data'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [sqliteGroup]);

      if (file != null) {
        return file.path;
      }

      return null;
    } catch (e) {
      AppLogger.info('选择备份文件错误: $e');
      return null;
    }
  }

  /// 生成默认备份文件名
  ///
  /// 格式：dentist_backup_年月日_时分秒.db
  static String generateBackupFilename() {
    final now = DateTime.now();
    return 'dentist_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.db';
  }

  /// 生成默认 Excel 文件名
  ///
  /// 格式：患者信息_年月日_时分秒.xlsx
  static String generateExcelFilename() {
    final now = DateTime.now();
    return '患者信息_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.xlsx';
  }
}
