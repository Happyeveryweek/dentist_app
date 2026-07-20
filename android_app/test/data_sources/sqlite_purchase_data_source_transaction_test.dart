import 'package:dentist_app/data_sources/sqlite_purchase_data_source.dart';
import 'package:dentist_app/models/purchase_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test('采购明细写入与主记录汇总在同一事务提交', () async {
    final database = _FakeDatabase(parentExists: true);
    final dataSource = SqlitePurchaseDataSource(database);

    final id = await dataSource.createPurchaseItemWithTotals(
      PurchaseItem(
        purchaseRecordId: 7,
        materialName: '树脂',
        quantity: 2,
        unitPrice: 12.5,
        totalPrice: 25,
      ),
    );

    expect(id, 1);
    expect(database.items, hasLength(1));
    expect(database.totalQuantity, 2);
    expect(database.totalAmount, 25);
  });

  test('采购汇总更新失败时回滚已写入明细', () async {
    final database = _FakeDatabase(parentExists: false);
    final dataSource = SqlitePurchaseDataSource(database);

    await expectLater(
      dataSource.createPurchaseItemWithTotals(
        PurchaseItem(
          purchaseRecordId: 404,
          materialName: '不存在主记录的材料',
          quantity: 1,
          unitPrice: 10,
          totalPrice: 10,
        ),
      ),
      throwsStateError,
    );

    expect(database.items, isEmpty);
    expect(database.totalQuantity, 0);
    expect(database.totalAmount, 0);
  });
}

class _FakeDatabase implements Database {
  _FakeDatabase({required this.parentExists});

  final bool parentExists;
  List<Map<String, Object?>> items = [];
  int totalQuantity = 0;
  double totalAmount = 0;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final originalItems = items.map(Map<String, Object?>.from).toList();
    final originalQuantity = totalQuantity;
    final originalAmount = totalAmount;
    try {
      return await action(_FakeTransaction(this));
    } catch (_) {
      items = originalItems;
      totalQuantity = originalQuantity;
      totalAmount = originalAmount;
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransaction implements Transaction {
  _FakeTransaction(this.fakeDatabase);

  final _FakeDatabase fakeDatabase;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    fakeDatabase.items.add({...values, 'id': fakeDatabase.items.length + 1});
    return fakeDatabase.items.length;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return [
      {
        'total_quantity': fakeDatabase.items.fold<int>(
          0,
          (sum, item) => sum + (item['quantity'] as int),
        ),
        'total_amount': fakeDatabase.items.fold<double>(
          0,
          (sum, item) => sum + (item['total_price'] as num).toDouble(),
        ),
      },
    ];
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!fakeDatabase.parentExists) return 0;
    fakeDatabase.totalQuantity = values['total_quantity'] as int;
    fakeDatabase.totalAmount = values['total_amount'] as double;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
