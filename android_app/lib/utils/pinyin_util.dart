import 'package:lpinyin/lpinyin.dart';

/// 拼音转换工具类
class PinyinUtil {
  /// 将文本转换为拼音
  ///
  /// [text] 要转换的文本
  /// [separator] 拼音之间的分隔符，默认为空格
  /// 返回拼音字符串
  static String toPinyin(String text, {String separator = ' '}) {
    if (text.isEmpty) {
      return '';
    }

    try {
      // 使用lpinyin库转换为拼音，并使用分隔符连接
      return PinyinHelper.getPinyinE(
        text,
        separator: separator,
        format: PinyinFormat.WITHOUT_TONE,
      );
    } catch (e) {
      print('拼音转换错误: $e');
      return '';
    }
  }

  /// 获取文本的拼音首字母
  ///
  /// [text] 要获取首字母的文本
  /// 返回首字母字符串
  static String getInitials(String text) {
    if (text.isEmpty) {
      return '';
    }

    try {
      // 获取每个字的拼音首字母
      return PinyinHelper.getShortPinyin(text).toUpperCase();
    } catch (e) {
      print('获取拼音首字母错误: $e');
      return '';
    }
  }
}
