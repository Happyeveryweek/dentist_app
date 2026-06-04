import 'package:lpinyin/lpinyin.dart';

class PinyinUtil {
  // 将中文文本转换为拼音，支持简体和繁体中文
  static String toPinyin(String text) {
    if (text.isEmpty) return '';

    try {
      // 使用lpinyin转换中文为拼音，不带声调
      return PinyinHelper.getPinyin(text,
          separator: ' ', format: PinyinFormat.WITHOUT_TONE);
    } catch (e) {
      print('中文转拼音出错: $e');
      return text; // 转换失败则返回原文本
    }
  }

  // 将中文文本转换为拼音首字母缩写（如"樊睿焱" -> "fry"）
  static String getInitials(String text) {
    if (text.isEmpty) return '';

    try {
      String pinyin = PinyinHelper.getPinyin(text,
          separator: ' ', format: PinyinFormat.WITHOUT_TONE);

      // 分割拼音并获取每个词的首字母
      List<String> words = pinyin.split(' ');
      String initials = '';
      for (var word in words) {
        if (word.isNotEmpty) {
          initials += word[0]; // 获取每个拼音的首字母
        }
      }
      return initials.toLowerCase();
    } catch (e) {
      print('获取拼音首字母缩写出错: $e');
      return '';
    }
  }

  // 获取短拼音（老方法，保持兼容）
  static String getFirstLetters(String text) {
    if (text.isEmpty) return '';

    try {
      // 获取每个汉字的拼音首字母
      return PinyinHelper.getShortPinyin(text).toLowerCase();
    } catch (e) {
      print('中文转拼音首字母出错: $e');
      return text; // 转换失败则返回原文本
    }
  }
}
