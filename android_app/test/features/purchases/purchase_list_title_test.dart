import 'package:dentist_app/features/purchases/services/purchase_list_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('采购列表标题使用采购日期加采购单', () {
    expect(purchaseListTitle(DateTime(2026, 8, 8)), '20260808采购单');
    expect(purchaseListTitle(DateTime(2026, 1, 2)), '20260102采购单');
  });
}
