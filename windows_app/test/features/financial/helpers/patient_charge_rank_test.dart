import 'package:dentist_app_windows/features/financial/helpers/patient_charge_rank.dart';
import 'package:dentist_app_windows/models/financial_item.dart';
import 'package:dentist_app_windows/models/financial_record.dart';
import 'package:dentist_app_windows/models/patient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 27);
  final patients = [
    Patient(
      id: 1,
      name: '张三',
      age: 30,
      gender: '男',
      phone: '1',
      firstVisitDate: now,
    ),
    Patient(
      id: 2,
      name: '张三',
      age: 40,
      gender: '女',
      phone: '2',
      firstVisitDate: now,
    ),
  ];
  final records = [
    FinancialRecord(
      id: 11,
      patientId: 1,
      totalQuantity: 1,
      createdAt: now,
      updatedAt: now,
    ),
    FinancialRecord(
      id: 22,
      patientId: 2,
      totalQuantity: 1,
      createdAt: now,
      updatedAt: now,
    ),
    FinancialRecord(
      id: 33,
      patientId: 0,
      totalQuantity: 1,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  FinancialItem item({
    required int id,
    required int recordId,
    required double itemPrice,
    required double totalPrice,
  }) {
    return FinancialItem(
      id: id,
      financialRecordId: recordId,
      itemName: '项目$id',
      itemPrice: itemPrice,
      processingFee: 0,
      quantity: 1,
      totalPrice: totalPrice,
      chargeDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('同名患者按 ID 分开排行', () {
    final ranks = rankPatientsByReceived(
      items: [
        item(id: 1, recordId: 11, itemPrice: 100, totalPrice: 80),
        item(id: 2, recordId: 22, itemPrice: 50, totalPrice: 50),
        item(id: 3, recordId: 33, itemPrice: 999, totalPrice: 999),
        item(id: 4, recordId: 99, itemPrice: 10, totalPrice: 10),
      ],
      records: records,
      patients: patients,
    );

    expect(ranks.map((rank) => rank.patient.id).toList(), [1, 2]);
    expect(ranks.map((rank) => rank.amount).toList(), [80, 50]);
  });

  test('欠费排行只保留应收大于已收的患者', () {
    final ranks = rankPatientsByDebt(
      items: [
        item(id: 1, recordId: 11, itemPrice: 100, totalPrice: 100),
        item(id: 2, recordId: 22, itemPrice: 80, totalPrice: 30),
      ],
      records: records,
      patients: patients,
    );

    expect(ranks, hasLength(1));
    expect(ranks.single.patient.id, 2);
    expect(ranks.single.amount, 50);
  });
}
