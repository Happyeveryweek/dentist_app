import 'package:dentist_app/features/purchases/services/purchase_amount_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('采购金额最多保留两位小数并去掉末尾零', () {
    expect(PurchaseAmountFormatter.format(10914.50), '10,914.5');
    expect(PurchaseAmountFormatter.format(10914.56), '10,914.56');
    expect(PurchaseAmountFormatter.format(418), '418');
    expect(PurchaseAmountFormatter.format(0), '0');
    expect(PurchaseAmountFormatter.format(null), '0');
  });
}
