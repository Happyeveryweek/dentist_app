import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import './patient_calculation_helper.dart';

/// 财务数据聚合辅助类
/// 
/// 提供患者模式的数据聚合逻辑
class FinancialDataAggregator {
  /// 获取财务数据（按患者去重，基于患者的"最新收费日期/最近更新"排序）
  static List<Map<String, dynamic>> getFinancialData({
    required List<FinancialRecord> financialRecords,
    required Map<int, List<FinancialItem>> recordItemsMap,
    required Map<int, DateTime> patientLatestChargeDateMap,
    required Map<int, DateTime> patientLastUpdatedMap,
    required String sortBy,
    required bool sortAscending,
    required Patient? Function(int) getPatientById,
  }) {
    // 聚合：key 为 patientId
    final Map<int, Map<String, dynamic>> agg = {};

    for (final record in financialRecords) {
      final pid = record.patientId;
      final patient = getPatientById(pid);
      if (patient == null) continue;

      // Route B：若后端已提供聚合日期，则直接使用；否则退回到记录/明细推算
      DateTime? patientLatestChargeFromAgg = patientLatestChargeDateMap[pid];
      DateTime? patientLastUpdatedFromAgg = patientLastUpdatedMap[pid];

      // 该记录自身的最新收费日期（若无明细则用记录创建时间）
      final items = recordItemsMap[record.id] ?? [];
      final recordLatestCharge = items.isNotEmpty
          ? items.map((i) => i.chargeDate).reduce((a, b) => a.isAfter(b) ? a : b)
          : record.createdAt;

      if (!agg.containsKey(pid)) {
        agg[pid] = {
          'patient': patient,
          // 代表记录：先用当前记录，后续遇到"更新更晚"的记录替换
          'record': record,
          'patientLatestChargeDate': patientLatestChargeFromAgg ?? recordLatestCharge, // 优先用后端聚合
          'patientLastUpdated': patientLastUpdatedFromAgg ?? record.updatedAt,        // 优先用后端聚合
        };
      } else {
        final m = agg[pid]!;
        // 维护患者维度的最新收费日期（所有收费明细的最大 charge_date）
        final prevCharge = m['patientLatestChargeDate'] as DateTime;
        final candidateCharge = patientLatestChargeFromAgg ?? recordLatestCharge;
        if (candidateCharge.isAfter(prevCharge)) {
          m['patientLatestChargeDate'] = candidateCharge;
        }
        // 维护患者维度的最近更新时间（所有记录 updated_at 的最大值）
        final prevUpdated = m['patientLastUpdated'] as DateTime;
        final candidateUpdated = patientLastUpdatedFromAgg ?? record.updatedAt;
        if (candidateUpdated.isAfter(prevUpdated)) {
          m['patientLastUpdated'] = candidateUpdated;
          // 同时更新代表性记录为最近更新的这条
          m['record'] = record;
        }
      }
    }

    // 聚合后转列表并排序
    final List<Map<String, dynamic>> list = agg.values.toList();
    list.sort((a, b) {
      int compareDate(DateTime da, DateTime db) => sortAscending ? da.compareTo(db) : db.compareTo(da);
      if (sortBy == 'charge_date') {
        final da = a['patientLatestChargeDate'] as DateTime;
        final db = b['patientLatestChargeDate'] as DateTime;
        return compareDate(da, db);
      }
      final da = a['patientLastUpdated'] as DateTime;
      final db = b['patientLastUpdated'] as DateTime;
      return compareDate(da, db);
    });

    // 输出格式与调用方预期保持一致
    return list.map((m) {
      final patient = m['patient'] as Patient;
      final record = m['record'] as FinancialRecord;
      return {
        'patient': patient,
        'record': record,
        'totalCost': PatientCalculationHelper.getPatientTotalReceivable(
          record.patientId,
          financialRecords,
          recordItemsMap,
        ),
        'lastFinancialUpdateDate': PatientCalculationHelper.getPatientLastFinancialUpdateDate(
          record.patientId,
          financialRecords,
        ),
        // 暴露患者级最新日期，供后续排序使用
        'patientLatestChargeDate': m['patientLatestChargeDate'] as DateTime,
        'patientLastUpdated': m['patientLastUpdated'] as DateTime,
      };
    }).toList();
  }
}
