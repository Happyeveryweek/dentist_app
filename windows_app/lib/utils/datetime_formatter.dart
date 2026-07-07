import 'package:intl/intl.dart';
import '../utils/log_manager.dart';

/// 统一的时间格式处理工具类
/// 统一使用 YYYY-MM-DD HH:MM:SS 格式，兼容MySQL和SQLite
class DateTimeFormatter {
  // 统一的数据库时间格式：YYYY-MM-DD HH:MM:SS
  static final DateFormat _dbFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// 将DateTime转换为数据库标准格式字符串
  /// 返回格式：2025-10-23 18:02:32
  static String toDbString(DateTime dateTime) {
    return _dbFormat.format(dateTime);
  }

  /// 从数据库字符串解析为DateTime
  /// 只支持标准格式：2025-10-23 18:02:32
  /// 不再兼容ISO格式，完全统一格式
  static DateTime fromDbString(String dateTimeString) {
    try {
      return _dbFormat.parse(dateTimeString);
    } catch (e) {
      LogManager.e('DatetimeFormatter',
          'DateTimeFormatter: 无法解析时间字符串: $dateTimeString, 错误',
          error: e);

      return DateTime.now();
    }
  }

  /// 获取当前时间的数据库格式字符串
  static String nowDbString() {
    return toDbString(DateTime.now());
  }

  /// 验证时间字符串格式是否正确
  static bool isValidDbFormat(String dateTimeString) {
    try {
      _dbFormat.parse(dateTimeString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 简化的格式转换方法（仅用于一次性数据迁移）
  /// 迁移完成后可以删除此方法
  static String convertToStandardFormat(String oldTimeString) {
    try {
      DateTime dateTime;
      if (oldTimeString.contains('T')) {
        // ISO格式转换
        dateTime = DateTime.parse(oldTimeString);
      } else {
        // 已经是标准格式
        dateTime = _dbFormat.parse(oldTimeString);
      }
      return toDbString(dateTime);
    } catch (e) {
      LogManager.e(
          'DatetimeFormatter', 'DateTimeFormatter: 格式转换失败: $oldTimeString, 错误',
          error: e);
      return nowDbString();
    }
  }
}
