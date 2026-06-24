import 'package:intl/intl.dart';

import '../../../utils/datetime_formatter.dart';

/// 采购统计时间范围管理服务
class PurchaseDateRangeService {
  /// 预设时间范围配置
  static const List<Map<String, dynamic>> presets = [
    {'label': '本月', 'key': 'this_month'},
    {'label': '上月', 'key': 'last_month'},
    {'label': '近90天', 'key': '90d'},
    {'label': '今年', 'key': 'this_year'},
    {'label': '全部', 'key': 'all'},
  ];

  /// 获取默认时间范围（最近6个月）
  static Map<String, DateTime> getDefaultDateRange() {
    final now = DateTimeFormatter.nowLocal();
    return {
      'start': DateTime(now.year, now.month - 5, 1),
      'end': DateTime(now.year, now.month, now.day),
    };
  }

  /// 获取最早的采购记录日期
  static DateTime getEarliestPurchaseDate(List<DateTime> purchaseDates) {
    if (purchaseDates.isEmpty) {
      final now = DateTimeFormatter.nowLocal();
      return DateTime(now.year, now.month - 11, 1);
    }
    DateTime earliest = DateTime(9999);
    for (final date in purchaseDates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (normalizedDate.isBefore(earliest)) earliest = normalizedDate;
    }
    return earliest;
  }

  /// 应用预设时间范围
  static Map<String, DateTime> applyPreset(
    String preset,
    DateTime earliestDate,
  ) {
    final now = DateTimeFormatter.nowLocal();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        start = DateTime(lastMonth.year, lastMonth.month, 1);
        end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case '90d':
        start = now.subtract(const Duration(days: 89));
        break;
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'all':
        start = earliestDate;
        end = DateTimeFormatter.nowLocal();
        break;
      default:
        start = DateTime(now.year, now.month - 2, 1);
    }

    return {'start': start, 'end': end};
  }

  /// 检查预设是否激活
  static bool isPresetActive(
    String preset,
    DateTime startDate,
    DateTime endDate,
    DateTime earliestDate,
  ) {
    final now = DateTimeFormatter.nowLocal();
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);

    switch (preset) {
      case 'this_month':
        final ps = DateTime(now.year, now.month, 1);
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        final ps = DateTime(lastMonth.year, lastMonth.month, 1);
        final pe = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      case '90d':
        final ps = now.subtract(const Duration(days: 89));
        final psNormalized = DateTime(ps.year, ps.month, ps.day);
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(psNormalized) && e.isAtSameMomentAs(pe);
      case 'this_year':
        final ps = DateTime(now.year, 1, 1);
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      case 'all':
        final ps = earliestDate;
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      default:
        return false;
    }
  }

  /// 格式化日期范围显示
  static String formatDateRangeDisplay(DateTime startDate, DateTime endDate) {
    return '${DateFormat('yyyy-MM-dd').format(startDate)} 至 ${DateFormat('yyyy-MM-dd').format(endDate)}';
  }

  /// 判断记录是否在时间范围内
  static bool isWithinRange(
    DateTime date,
    DateTime startDate,
    DateTime endDate,
  ) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
        (d.isAtSameMomentAs(e) || d.isBefore(e));
  }
}
