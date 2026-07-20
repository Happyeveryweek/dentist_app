import 'package:dentist_app/models/sync_config.dart';
import 'package:dentist_app/utils/sync_table_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('同步配置拒绝未知表名和重复表名', () {
    expect(
      () => SyncConfig.fromJson({
        'sync_tables': ['patients', 'unknown_table'],
      }),
      throwsFormatException,
    );
    expect(
      () => SyncTableConfig.validate(['patients', 'patients']),
      throwsFormatException,
    );
  });

  test('部分同步只生成已选表且删除顺序与插入顺序相反', () {
    final insertionOrder = SyncTableConfig.insertionOrder([
      'purchase_items',
      'purchase_records',
      'appointments',
    ]);

    expect(insertionOrder, [
      'appointments',
      'purchase_records',
      'purchase_items',
    ]);
    expect(
      SyncTableConfig.deletionOrder(insertionOrder),
      insertionOrder.reversed.toList(),
    );
    expect(insertionOrder, isNot(contains('users')));
    expect(insertionOrder, isNot(contains('materials')));
  });
}
