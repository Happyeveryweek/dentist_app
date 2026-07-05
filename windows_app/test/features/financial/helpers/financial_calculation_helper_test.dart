import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/features/financial/helpers/financial_calculation_helper.dart';
import 'package:dentist_app_windows/models/financial_record.dart';
import 'package:dentist_app_windows/models/financial_item.dart';
import 'package:dentist_app_windows/models/patient.dart';

FinancialRecord _makeRecord({required int id, required int patientId}) {
  return FinancialRecord(
    id: id,
    patientId: patientId,
    totalQuantity: 0,
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

FinancialItem _makeItem({
  required int recordId,
  double itemPrice = 0.0,
  int quantity = 1,
  double totalPrice = 0.0,
  double processingFee = 0.0,
}) {
  return FinancialItem(
    id: 1,
    financialRecordId: recordId,
    itemName: '治疗费',
    itemPrice: itemPrice,
    processingFee: processingFee,
    quantity: quantity,
    totalPrice: totalPrice,
    chargeDate: DateTime(2026, 7, 5),
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  group('财务管理-收费计算', () {
    test('应收金额等于各项目单价乘以数量之和', () {
      final record = _makeRecord(id: 1, patientId: 1);
      final items = {
        1: [
          _makeItem(recordId: 1, itemPrice: 100.0, quantity: 2),
          _makeItem(recordId: 1, itemPrice: 50.0, quantity: 1),
        ],
      };
      expect(FinancialCalculationHelper.calculateTotalReceivable(record, items),
          250.0);
    });

    test('无收费明细时应收金额为0', () {
      final record = _makeRecord(id: 1, patientId: 1);
      expect(FinancialCalculationHelper.calculateTotalReceivable(record, {}),
          0.0);
    });

    test('已收金额等于各项目实收价格之和', () {
      final record = _makeRecord(id: 1, patientId: 1);
      final items = {
        1: [
          _makeItem(recordId: 1, totalPrice: 200.0),
          _makeItem(recordId: 1, totalPrice: 50.0),
        ],
      };
      expect(FinancialCalculationHelper.calculateTotalCollected(record, items),
          250.0);
    });

    test('欠费金额等于应收减去已收', () {
      final record = _makeRecord(id: 1, patientId: 1);
      final items = {
        1: [
          _makeItem(
            recordId: 1,
            itemPrice: 100.0,
            quantity: 3,
            totalPrice: 250.0,
          ),
        ],
      };
      expect(
        FinancialCalculationHelper.calculateOutstandingAmount(record, items),
        50.0,
      );
    });

    test('加工费总额累加各项目加工费', () {
      final record = _makeRecord(id: 1, patientId: 1);
      final items = {
        1: [
          _makeItem(recordId: 1, processingFee: 30.0),
          _makeItem(recordId: 1, processingFee: 20.0),
        ],
      };
      expect(
        FinancialCalculationHelper.calculateTotalProcessingFee(record, items),
        50.0,
      );
    });
  });

  group('财务管理-患者头像颜色', () {
    test('根据患者性别返回不同头像背景色', () {
      final male = Patient(
        name: '男患者',
        age: 30,
        gender: '男',
        phone: '13800000000',
        firstVisitDate: DateTime(2026, 1, 1),
      );
      final female = Patient(
        name: '女患者',
        age: 30,
        gender: '女',
        phone: '13800000001',
        firstVisitDate: DateTime(2026, 1, 1),
      );

      final maleColor =
          FinancialCalculationHelper.getAvatarBackgroundColor(male);
      final femaleColor =
          FinancialCalculationHelper.getAvatarBackgroundColor(female);

      expect(maleColor, isNotNull);
      expect(femaleColor, isNotNull);
      expect(maleColor, isNot(equals(femaleColor)));
    });
  });
}
