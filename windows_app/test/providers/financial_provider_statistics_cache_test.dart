import 'package:dentist_app_windows/models/user.dart';
import 'package:dentist_app_windows/models/financial_item.dart';
import 'package:dentist_app_windows/providers/financial_provider.dart';
import 'package:dentist_app_windows/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late FinancialProvider provider;
  late UserProvider userProvider;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute(
      'CREATE TABLE patients (id INTEGER PRIMARY KEY, doctor TEXT)',
    );
    await database.execute('''
      CREATE TABLE financial_records (
        id INTEGER PRIMARY KEY,
        patient_id INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        total_quantity INTEGER
      )
    ''');
    await database.execute('''
      CREATE TABLE financial_items (
        id INTEGER PRIMARY KEY,
        financial_record_id INTEGER NOT NULL,
        item_name TEXT,
        item_price REAL,
        quantity INTEGER,
        total_price REAL,
        charge_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        processing_fee REAL,
        payment_method TEXT
      )
    ''');
    await database.insert('patients', {'id': 1, 'doctor': '医生甲'});
    await database.insert('financial_records', {
      'id': 1,
      'patient_id': 1,
      'notes': '记录',
      'created_at': '2026-07-22 10:00:00',
      'updated_at': '2026-07-22 10:00:00',
      'total_quantity': 1,
    });
    await database.insert('financial_items', {
      'id': 1,
      'financial_record_id': 1,
      'item_name': '旧项目',
      'item_price': 100.0,
      'quantity': 1,
      'total_price': 100.0,
      'charge_date': '2026-07-22 10:00:00',
      'created_at': '2026-07-22 10:00:00',
      'updated_at': '2026-07-22 10:00:00',
      'processing_fee': 0.0,
    });

    userProvider = UserProvider();
    userProvider.setCurrentUser(User(
      id: 1,
      username: 'admin',
      password: 'password',
      role: 'admin',
    ));
    provider = FinancialProvider(database: database);
    provider.setSqliteDataSource(database);
    provider.setUserProvider(userProvider);
  });

  tearDown(() async {
    provider.dispose();
    userProvider.dispose();
    await database.close();
  });

  test('财务统计复用筛选缓存，强制刷新时重新查询', () async {
    final initial = await provider.getAllFinancialItemsWithDetailsFiltered();
    expect((initial.single['item'] as FinancialItem).itemName, '旧项目');

    await database.update(
      'financial_items',
      {'item_name': '新项目'},
      where: 'id = ?',
      whereArgs: [1],
    );

    final cached = await provider.getAllFinancialItemsWithDetailsFiltered();
    final refreshed = await provider.getAllFinancialItemsWithDetailsFiltered(
      forceRefresh: true,
    );

    expect((cached.single['item'] as FinancialItem).itemName, '旧项目');
    expect((refreshed.single['item'] as FinancialItem).itemName, '新项目');
  });
}
