import 'package:dentist_app/features/purchases/services/purchase_statistics_service.dart';
import 'package:dentist_app/models/purchase_item.dart';
import 'package:dentist_app/models/purchase_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('按采购明细条数计算每条记录的项目数', () async {
    final records = [
      PurchaseRecord(
        id: 32,
        purchaseDate: DateTime(2026, 6, 27),
        totalQuantity: 82,
        totalAmount: 0,
      ),
    ];

    final statistics = await PurchaseStatisticsService.calculateStatistics(
      records,
      (recordId) async => [
        PurchaseItem(
          id: 1,
          purchaseRecordId: recordId,
          materialName: '材料 A',
          quantity: 80,
          unitPrice: 1,
          totalPrice: 80,
        ),
        PurchaseItem(
          id: 2,
          purchaseRecordId: recordId,
          materialName: '材料 B',
          quantity: 2,
          unitPrice: 1,
          totalPrice: 2,
        ),
      ],
    );

    expect(statistics.totalQuantity, 82);
    expect(statistics.projectCountsByRecordId, {32: 2});
  });
}
