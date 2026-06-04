import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import 'package:flutter/material.dart';

/// 财务计算辅助类
/// 
/// 提供财务记录相关的纯计算方法，不涉及状态管理
class FinancialCalculationHelper {
  /// 计算应收金额
  static double calculateTotalReceivable(FinancialRecord record, Map<int, List<FinancialItem>> recordItemsMap) {
    final items = recordItemsMap[record.id] ?? [];
    return items.fold(0.0, (sum, item) => sum + (item.itemPrice * (item.quantity ?? 1)));
  }

  /// 计算已收金额
  static double calculateTotalCollected(FinancialRecord record, Map<int, List<FinancialItem>> recordItemsMap) {
    final items = recordItemsMap[record.id] ?? [];
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// 计算欠费金额
  static double calculateOutstandingAmount(FinancialRecord record, Map<int, List<FinancialItem>> recordItemsMap) {
    return calculateTotalReceivable(record, recordItemsMap) - calculateTotalCollected(record, recordItemsMap);
  }

  /// 计算加工费总额
  static double calculateTotalProcessingFee(FinancialRecord record, Map<int, List<FinancialItem>> recordItemsMap) {
    final items = recordItemsMap[record.id] ?? [];
    return items.fold(0.0, (sum, item) => sum + item.processingFee);
  }

  /// 根据患者性别获取头像背景色
  static Color getAvatarBackgroundColor(Patient patient) {
    if (patient.gender == '女' || patient.gender.toLowerCase() == 'female') {
      return Colors.pink[400]!; // 女性为粉红色
    } else if (patient.gender == '男' || patient.gender.toLowerCase() == 'male') {
      return Colors.blue[300]!; // 男性为浅蓝色
    } else {
      return Colors.grey[400]!; // 其他情况为灰色
    }
  }
}
