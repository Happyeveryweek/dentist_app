import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dentist_app_windows/data_sources/sqlite_financial_data_source.dart';

void main() {
  late Database database;
  late SqliteFinancialDataSource dataSource;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dataSource = SqliteFinancialDataSource(database);

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
    await database.insert('patients', {'id': 2, 'doctor': '医生乙'});
    await database.insert('patients', {'id': 3, 'doctor': null});
    for (final patientId in [1, 2, 3]) {
      await database.insert('financial_records', {
        'id': patientId,
        'patient_id': patientId,
        'notes': '记录$patientId',
        'created_at': '2026-07-19 10:00:00',
        'updated_at': '2026-07-19 10:00:00',
        'total_quantity': 1,
      });
      await database.insert('financial_items', {
        'id': patientId,
        'financial_record_id': patientId,
        'item_name': '项目$patientId',
        'item_price': 100.0,
        'quantity': 1,
        'total_price': 100.0,
        'charge_date': '2026-07-19 10:00:00',
        'created_at': '2026-07-19 10:00:00',
        'updated_at': '2026-07-19 10:00:00',
        'processing_fee': 0.0,
      });
    }
  });

  tearDown(() => database.close());

  test('医生过滤同时限制患者聚合、收费项计数和分页明细', () async {
    final aggregates = await dataSource.getPatientAggregatesPage(
      doctorFilter: '医生甲',
    );
    final count = await dataSource.getFinancialItemsCount(
      doctorFilter: '医生甲',
    );
    final items = await dataSource.getFinancialItemsWithDetails(
      doctorFilter: '医生甲',
    );

    expect(aggregates['total'], 1);
    expect((aggregates['rows'] as List).single['patient_id'], 1);
    expect(count, 1);
    expect(items.single['patient_id'], 1);
  });

  test('无访问主体的过滤值返回空结果', () async {
    final aggregates = await dataSource.getPatientAggregatesPage(
      doctorFilter: '__NO_FINANCIAL_ACCESS__',
    );
    final count = await dataSource.getFinancialItemsCount(
      doctorFilter: '__NO_FINANCIAL_ACCESS__',
    );
    final items = await dataSource.getFinancialItemsWithDetails(
      doctorFilter: '__NO_FINANCIAL_ACCESS__',
    );

    expect(aggregates['total'], 0);
    expect(count, 0);
    expect(items, isEmpty);
  });

  test('管理员不传医生过滤时保留全量结果', () async {
    final aggregates = await dataSource.getPatientAggregatesPage();
    final count = await dataSource.getFinancialItemsCount();
    final items = await dataSource.getFinancialItemsWithDetails();

    expect(aggregates['total'], 3);
    expect(count, 3);
    expect(items, hasLength(3));
  });
}
