import 'dart:convert';
import '../../../utils/app_logger.dart';

/// 电话号码格式化辅助类
class PhoneFormatter {
  /// 从JSON格式中获取显示电话号码
  static String getDisplayPhone(String phone) {
    if (phone.startsWith('[') && phone.endsWith(']')) {
      try {
        List<dynamic> phones = jsonDecode(phone);
        if (phones.isNotEmpty) {
          return phones[0].toString();
        }
      } catch (e) {
        AppLogger.info('解析电话号码JSON失败: $e');
      }
    }
    return phone;
  }
}
