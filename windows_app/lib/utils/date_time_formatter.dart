import 'package:intl/intl.dart';

class DateTimeFormatter {
  // 统一的时间格式字符串
  static const String defaultFormat = 'yyyy-MM-dd HH:mm:ss';
  
  // 格式化DateTime为字符串
  static String format(DateTime dateTime) {
    return DateFormat(defaultFormat).format(dateTime);
  }
  
  // 从字符串解析为DateTime
  static DateTime parse(String dateString) {
    return DateFormat(defaultFormat).parse(dateString);
  }
  
  // 获取当前时间的格式化字符串
  static String now() {
    return format(DateTime.now());
  }
}