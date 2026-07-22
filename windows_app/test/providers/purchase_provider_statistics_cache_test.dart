import 'package:dentist_app_windows/providers/purchase_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late PurchaseProvider provider;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    provider = PurchaseProvider(database: database);
    provider.setSqliteDataSource(database);
    await provider.ensurePurchaseItemsTableExists();
    await database.insert('purchase_items', {
      'purchase_record_id': 1,
      'material_name': '旧材料',
      'quantity': 1,
      'unit_price': 10,
      'total_price': 10,
      'created_at': '2026-07-22 10:00:00',
      'updated_at': '2026-07-22 10:00:00',
    });
  });

  tearDown(() async {
    provider.dispose();
    await database.close();
  });

  test('采购统计明细复用缓存，强制刷新时重新查询', () async {
    final initial = await provider.getPurchaseStatisticsItems([1]);
    expect(initial.single.materialName, '旧材料');

    await database.update(
      'purchase_items',
      {'material_name': '新材料'},
      where: 'purchase_record_id = ?',
      whereArgs: [1],
    );

    final cached = await provider.getPurchaseStatisticsItems([1]);
    final refreshed = await provider.getPurchaseStatisticsItems(
      [1],
      forceRefresh: true,
    );

    expect(cached.single.materialName, '旧材料');
    expect(refreshed.single.materialName, '新材料');
  });
}
