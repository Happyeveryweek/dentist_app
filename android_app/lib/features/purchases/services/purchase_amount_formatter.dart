import 'package:intl/intl.dart';

/// 采购金额展示格式化工具。
///
/// 金额最多显示两位小数，去掉无意义的末尾零；整数和零分别显示为整数和 0。
abstract final class PurchaseAmountFormatter {
  static final NumberFormat _format = NumberFormat('#,##0.##');
  static final NumberFormat _inputFormat = NumberFormat('0.##');

  static String format(num? amount) {
    final value = amount;
    if (value == null || !value.isFinite) {
      return '0';
    }
    return _format.format(value);
  }

  static String formatCurrency(num? amount) => '¥${format(amount)}';

  /// 编辑框使用不带千位分隔符的格式，避免文本回填后无法直接解析。
  static String formatInput(num? amount) {
    final value = amount;
    if (value == null || !value.isFinite) {
      return '0';
    }
    return _inputFormat.format(value);
  }
}
