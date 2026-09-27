import '../../../models/financial_item.dart';
import '../../../models/financial_record.dart';
import '../../../models/patient.dart';

/// 图表排行中的一位患者及其金额。
class PatientChargeRank {
  const PatientChargeRank({
    required this.patient,
    required this.amount,
  });

  final Patient patient;
  final double amount;
}

/// 按患者 ID 汇总已收金额。同名患者保持各自一行，才能打开对应财务详情。
List<PatientChargeRank> rankPatientsByReceived({
  required List<FinancialItem> items,
  required List<FinancialRecord> records,
  required List<Patient> patients,
  int limit = 20,
}) {
  final totals = <int, double>{};
  for (final item in items) {
    final patientId = _patientIdOf(records, item.financialRecordId);
    if (patientId == null) continue;
    totals[patientId] = (totals[patientId] ?? 0) + item.totalPrice;
  }
  return _toRanks(totals, patients, limit);
}

/// 按患者 ID 汇总欠费（应收减已收），只保留欠费大于 0 的患者。
List<PatientChargeRank> rankPatientsByDebt({
  required List<FinancialItem> items,
  required List<FinancialRecord> records,
  required List<Patient> patients,
  int limit = 30,
}) {
  final receivable = <int, double>{};
  final received = <int, double>{};
  for (final item in items) {
    final patientId = _patientIdOf(records, item.financialRecordId);
    if (patientId == null) continue;
    receivable[patientId] = (receivable[patientId] ?? 0) + item.itemPrice;
    received[patientId] = (received[patientId] ?? 0) + item.totalPrice;
  }

  final debts = <int, double>{};
  receivable.forEach((patientId, amount) {
    final debt = amount - (received[patientId] ?? 0);
    if (debt > 0) {
      debts[patientId] = debt;
    }
  });
  return _toRanks(debts, patients, limit);
}

int? _patientIdOf(List<FinancialRecord> records, int recordId) {
  for (final record in records) {
    if (record.id == recordId) {
      return record.patientId > 0 ? record.patientId : null;
    }
  }
  return null;
}

List<PatientChargeRank> _toRanks(
  Map<int, double> amounts,
  List<Patient> patients,
  int limit,
) {
  final entries = amounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final entry in entries.take(limit))
      PatientChargeRank(
        patient: _resolvePatient(patients, entry.key),
        amount: entry.value,
      ),
  ];
}

Patient _resolvePatient(List<Patient> patients, int patientId) {
  for (final patient in patients) {
    if (patient.id == patientId) return patient;
  }
  return Patient(
    id: patientId,
    name: '未知患者',
    age: 0,
    gender: '未知',
    phone: '',
    firstVisitDate: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
