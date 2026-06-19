import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/reusable_date_range_picker.dart';

/// 财务日期范围选择器
/// 
/// 提供日期范围选择和预设时间范围功能
class FinancialDateRangeSelector {
  /// 显示自定义日期范围选择器
  static Future<void> showCustomDateRangePicker({
    required BuildContext context,
    DateTime? startDate,
    DateTime? endDate,
    required Function(DateTime?, DateTime?) onDateRangeSelected,
  }) async {
    final now = DateTime.now();
    final DateTime initialStart = startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = endDate ?? now;
    final picked = await ReusableDateRangePicker.show(
      context,
      start: initialStart,
      end: initialEnd,
      title: '选择日期范围',
    );
    if (picked != null) {
      onDateRangeSelected(picked.start, picked.end);
    }
  }

  /// 应用预设时间范围
  static DateRangeResult applyPreset(String preset) {
    if (preset == 'all') {
      return DateRangeResult(start: null, end: null);
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);

    if (preset == 'this_month') {
      start = DateTime(now.year, now.month, 1);
    } else if (preset == 'last_month') {
      final lastMonth = DateTime(now.year, now.month - 1);
      start = DateTime(lastMonth.year, lastMonth.month, 1);
      end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    } else if (preset == '6m') {
      start = DateTime(now.year, now.month - 5, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == '1q') {
      start = DateTime(now.year, now.month - 2, 1);
    } else if (preset == '30d') {
      start = now.subtract(const Duration(days: 29));
    } else if (preset == '90d') {
      start = now.subtract(const Duration(days: 89));
    } else if (preset == '12m') {
      start = DateTime(now.year, now.month - 11, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'this_year') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'last_year') {
      start = DateTime(now.year - 1, 1, 1);
      end = DateTime(now.year - 1, 12, 31);
    } else {
      return DateRangeResult(start: null, end: null);
    }

    return DateRangeResult(start: start, end: end);
  }

  /// 检查日期是否在范围内
  static bool isWithinRange(DateTime? date, DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return true;
    }

    if (date == null) {
      return false;
    }

    final d = DateTime(date.year, date.month, date.day);

    // 检查开始日期
    if (startDate != null) {
      final s = DateTime(startDate.year, startDate.month, startDate.day);
      if (d.isBefore(s)) {
        return false;
      }
    }

    // 检查结束日期
    if (endDate != null) {
      final e = DateTime(endDate.year, endDate.month, endDate.day);
      if (d.isAfter(e)) {
        return false;
      }
    }

    return true;
  }
}

/// 日期范围结果
class DateRangeResult {
  final DateTime? start;
  final DateTime? end;

  DateRangeResult({this.start, this.end});
}
