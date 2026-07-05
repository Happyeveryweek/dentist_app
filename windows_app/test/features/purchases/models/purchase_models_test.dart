import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/models/purchase_record.dart';
import 'package:dentist_app_windows/models/purchase_item.dart';

void main() {
  group('采购管理-采购明细计算', () {
    test('采购明细总价等于单价乘以数量', () {
      final item = PurchaseItem(
        purchaseRecordId: 1,
        materialName: '树脂',
        quantity: 5,
        unitPrice: 12.5,
        totalPrice: 62.5,
      );
      expect(item.calculateTotalPrice(), 62.5);
    });

    test('未提供单位时显示默认单位“个”', () {
      final item = PurchaseItem(
        purchaseRecordId: 1,
        materialName: '树脂',
        quantity: 1,
        unitPrice: 10.0,
        totalPrice: 10.0,
      );
      expect(item.formattedUnit, '个');
    });

    test('提供单位时显示对应单位', () {
      final item = PurchaseItem(
        purchaseRecordId: 1,
        materialName: '树脂',
        quantity: 1,
        unitPrice: 10.0,
        totalPrice: 10.0,
        unit: '盒',
      );
      expect(item.formattedUnit, '盒');
    });

    test('金额格式化保留两位小数并带货币符号', () {
      final item = PurchaseItem(
        purchaseRecordId: 1,
        materialName: '树脂',
        quantity: 3,
        unitPrice: 10.0,
        totalPrice: 30.0,
      );
      expect(item.formattedUnitPrice, '¥10.00');
      expect(item.formattedTotalPrice, '¥30.00');
    });

    test('copyWith仅更新指定字段', () {
      final item = PurchaseItem(
        purchaseRecordId: 1,
        materialName: '树脂',
        quantity: 1,
        unitPrice: 10.0,
        totalPrice: 10.0,
      );
      final updated = item.copyWith(quantity: 5, totalPrice: 50.0);
      expect(updated.quantity, 5);
      expect(updated.totalPrice, 50.0);
      expect(updated.materialName, '树脂');
    });
  });

  group('采购管理-采购记录', () {
    test('采购记录总金额格式化为人民币', () {
      final record = PurchaseRecord(
        purchaseDate: DateTime(2026, 7, 5),
        totalQuantity: 10,
        totalAmount: 1234.5,
      );
      expect(record.formattedTotalAmount, '¥1234.50');
    });

    test('采购日期格式化为yyyy-MM-dd', () {
      final record = PurchaseRecord(
        purchaseDate: DateTime(2026, 7, 5),
        totalQuantity: 1,
        totalAmount: 100.0,
      );
      expect(record.formattedPurchaseDate, '2026-07-05');
    });

    test('采购记录copyWith仅更新指定字段', () {
      final record = PurchaseRecord(
        purchaseDate: DateTime(2026, 7, 5),
        totalQuantity: 10,
        totalAmount: 1000.0,
        supplier: 'A公司',
      );
      final updated = record.copyWith(totalAmount: 2000.0, supplier: 'B公司');
      expect(updated.totalAmount, 2000.0);
      expect(updated.supplier, 'B公司');
      expect(updated.totalQuantity, 10);
    });

    test('采购记录按ID判等', () {
      final a = PurchaseRecord(
        id: 1,
        purchaseDate: DateTime(2026, 7, 5),
        totalQuantity: 1,
        totalAmount: 100.0,
      );
      final b = PurchaseRecord(
        id: 1,
        purchaseDate: DateTime(2026, 7, 6),
        totalQuantity: 2,
        totalAmount: 200.0,
      );
      final c = PurchaseRecord(
        id: 2,
        purchaseDate: DateTime(2026, 7, 5),
        totalQuantity: 1,
        totalAmount: 100.0,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
