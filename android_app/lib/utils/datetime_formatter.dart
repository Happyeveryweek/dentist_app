import 'package:intl/intl.dart';
import './app_logger.dart';

/// 统一的时间格式处理工具类
/// 统一使用 YYYY-MM-DD HH:MM:SS 格式，兼容MySQL和SQLite
class DateTimeFormatter {
  // 统一的数据库时间格式：YYYY-MM-DD HH:MM:SS
  static final DateFormat _dbFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// 将DateTime转换为数据库标准格式字符串
  /// 返回格式：2025-10-23 18:02:32
  /// 确保使用本地时间而不是UTC时间
  static String toDbString(DateTime dateTime) {
    // 如果是UTC时间，转换为本地时间
    final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return _dbFormat.format(localDateTime);
  }

  /// 从数据库字符串解析为DateTime
  /// 只支持标准格式：2025-10-23 18:02:32
  /// 不再兼容ISO格式，完全统一格式
  /// 确保返回本地时间
  static DateTime fromDbString(String dateTimeString) {
    try {
      final parsedDateTime = _dbFormat.parse(dateTimeString);
      // 确保返回的是本地时间
      return parsedDateTime.isUtc ? parsedDateTime.toLocal() : parsedDateTime;
    } catch (e) {
      AppLogger.info('DateTimeFormatter: 无法解析时间字符串: $dateTimeString, 错误: $e');
      AppLogger.info('DateTimeFormatter: 期望格式为: YYYY-MM-DD HH:MM:SS');
      return DateTime.now(); // DateTime.now() 默认返回本地时间
    }
  }

  /// 获取当前时间的数据库格式字符串
  /// 确保使用本地时间
  static String nowDbString() {
    return toDbString(DateTime.now()); // DateTime.now() 默认返回本地时间
  }

  /// 获取当前本地时间
  /// 强制使用正确的本地时间，解决Android系统时间问题
  static DateTime nowLocal() {
    // 获取UTC时间和本地时区偏移
    final utcNow = DateTime.now().toUtc();
    final localOffset = DateTime.now().timeZoneOffset;

    // 强制计算本地时间，不依赖系统的isUtc判断
    final localTime = utcNow.add(localOffset);

    return localTime;
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
}
