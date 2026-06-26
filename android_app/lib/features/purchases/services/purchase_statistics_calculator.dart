import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';

/// 采购统计计算服务
class PurchaseStatisticsCalculator {
  /// 计算月度数据
  static Map<String, Map<String, double>> calculateMonthlyData(
    List<PurchaseRecord> records,
    DateTime startDate,
    DateTime endDate,
  ) {
    final Map<String, Map<String, double>> monthlyData = {};

    // 生成时间范围内的所有月份
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);

    while (currentMonth.isBefore(endMonth) ||
        currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = {'amount': 0.0, 'quantity': 0.0, 'records': 0.0};
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    // 填充实际数据
    for (final record in records) {
      final monthKey = DateFormat('yyyy-MM').format(record.purchaseDate);
      final data = monthlyData[monthKey];
      if (data != null) {
        data['amount'] = (data['amount'] ?? 0) + record.totalAmount;
        data['quantity'] = (data['quantity'] ?? 0) + record.totalQuantity;
        data['records'] = (data['records'] ?? 0) + 1;
      }
    }

    return monthlyData;
  }

  /// 计算材料排行（按金额）
  static List<MapEntry<String, double>> calculateTopMaterialsByAmount(
    List<PurchaseItem> items,
  ) {
    final Map<String, double> materialTotals = {};

    for (final item in items) {
      materialTotals[item.materialName] =
          (materialTotals[item.materialName] ?? 0) + item.totalPrice;
    }

    final sortedMaterials =
        materialTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return sortedMaterials.take(20).toList();
  }

  /// 计算材料排行（按数量）
  static List<MapEntry<String, int>> calculateTopMaterialsByQuantity(
    List<PurchaseItem> items,
  ) {
    final Map<String, int> materialTotals = {};

    for (final item in items) {
      materialTotals[item.materialName] =
          (materialTotals[item.materialName] ?? 0) + item.quantity;
    }

    final sortedMaterials =
        materialTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return sortedMaterials.take(20).toList();
  }

  /// 计算供应商排行
  static List<MapEntry<String, double>> calculateTopSuppliers(
    List<PurchaseRecord> records,
  ) {
    final Map<String, double> supplierTotals = {};

    for (final record in records) {
      final supplier = record.supplier ?? '未知供应商';
      supplierTotals[supplier] =
          (supplierTotals[supplier] ?? 0) + record.totalAmount;
    }

    final sortedSuppliers =
        supplierTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return sortedSuppliers.take(10).toList();
  }

  /// 获取排名颜色
  static Color getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB74D); // 金色
      case 2:
        return const Color(0xFF757575); // 银色
      case 3:
        return const Color(0xFF8D6E63); // 铜色
      default:
        return const Color(0xFF1E88E5);
    }
  }
}
