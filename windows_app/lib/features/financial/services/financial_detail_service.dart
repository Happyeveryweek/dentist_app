import 'package:flutter/material.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../providers/financial_provider.dart';

/// 财务详情页业务逻辑 Service
/// 用于处理财务详情页的业务逻辑，包括数据加载、增删改查等
class FinancialDetailService {
  final FinancialProvider financialProvider;

  FinancialDetailService({required this.financialProvider});

  /// 加载患者财务记录
  Future<List<Map<String, dynamic>>> loadPatientRecords(
    int patientId,
    int? initialRecordId,
  ) async {
    try {
      final allRecords = await financialProvider.getAllFinancialRecords();

      // 获取该患者的所有财务记录
      final patientRecords =
          allRecords.where((record) => record.patientId == patientId).toList();

      // 按日期排序，最新的在前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // 为每个财务记录加载其明细项
      final List<Map<String, dynamic>> detailedRecords = [];

      for (final record in patientRecords) {
        // 获取该财务记录的所有明细项
        final items =
            await financialProvider.getFinancialItemsByRecordId(record.id!);

        if (items.isNotEmpty) {
          // 如果有明细项，为每个明细项创建一个显示记录
          for (final item in items) {
            detailedRecords.add({
              'record': record,
              'item': item,
              'isDetail': true,
              'isHighlighted':
                  initialRecordId != null && record.id == initialRecordId,
            });
          }
        } else {
          // 如果没有明细项，显示主记录
          detailedRecords.add({
            'record': record,
            'item': null,
            'isDetail': false,
            'isHighlighted':
                initialRecordId != null && record.id == initialRecordId,
          });
        }
      }

      return detailedRecords;
    } catch (e) {
      throw Exception('获取财务记录失败: $e');
    }
  }

  /// 获取或创建财务记录
  Future<FinancialRecord?> getOrCreateFinancialRecord(int patientId) async {
    try {
      // 首先检查该患者是否已有财务记录
      final existingRecords =
          await financialProvider.getFinancialRecordsByPatientId(patientId);

      if (existingRecords.isNotEmpty) {
        // 如果已有记录，返回第一个记录（通常按创建时间排序）
        return existingRecords.first;
      } else {
        // 如果没有记录，创建新的财务记录
        final newRecord = FinancialRecord(
          id: null,
          patientId: patientId,
          totalQuantity: 0, // 初始数量为0，添加收费项时会更新
          notes: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final recordId = await financialProvider.addFinancialRecord(newRecord);

        if (recordId > 0) {
          // 返回创建的记录
          return newRecord.copyWith(id: recordId);
        } else {
          return null;
        }
      }
    } catch (e) {
      throw Exception('获取或创建财务记录失败: $e');
    }
  }

  /// 删除财务记录明细项
  Future<bool> deleteFinancialItem(int itemId) async {
    try {
      return await financialProvider.deleteFinancialItem(itemId);
    } catch (e) {
      throw Exception('删除收费明细项失败: $e');
    }
  }

  Future<bool> deleteFinancialItemAndCleanupRecord({
    required int itemId,
    required int recordId,
  }) async {
    try {
      return await financialProvider.deleteFinancialItemAndCleanupRecord(
        itemId: itemId,
        recordId: recordId,
      );
    } catch (e) {
      throw Exception('删除收费明细项失败: $e');
    }
  }

  /// 更新财务记录的收费项数量和更新时间
  Future<void> updateFinancialRecordAfterItemChange(
      FinancialRecord record) async {
    try {
      // 获取该财务记录的所有收费项，重新计算总数量
      final items =
          await financialProvider.getFinancialItemsByRecordId(record.id!);
      final totalQuantity =
          items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 1));

      // 更新财务记录
      final updatedRecord = record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );

      await financialProvider.updateFinancialRecord(updatedRecord);
    } catch (e) {
      throw Exception('更新财务记录失败: $e');
    }
  }

  /// 更新患者的财务统计
  Future<void> updatePatientFinancialSummary(int patientId) async {
    try {
      // 调用新的方法更新患者的总体财务统计信息
      await financialProvider.updatePatientFinancialSummary(patientId);
    } catch (e) {
      throw Exception('更新患者财务统计失败: $e');
    }
  }

  /// 添加财务明细项
  Future<int?> addFinancialItem(FinancialItem item) async {
    try {
      return await financialProvider.addFinancialItem(item);
    } catch (e) {
      throw Exception('添加收费明细项失败: $e');
    }
  }

  /// 更新财务明细项
  Future<bool> updateFinancialItem(FinancialItem item) async {
    try {
      return await financialProvider.updateFinancialItem(item);
    } catch (e) {
      throw Exception('更新收费明细项失败: $e');
    }
  }
}
