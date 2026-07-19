import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dentist_app_windows/data_sources/sqlite_patient_data_source.dart';

void main() {
  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        name_pinyin TEXT,
        name_initials TEXT,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        phone TEXT,
        medical_record_number INTEGER,
        address TEXT,
        address_pinyin TEXT,
        identification_number TEXT,
        doctor TEXT,
        dental_condition TEXT,
        treatment_items TEXT,
        first_visit_date TEXT,
        total_cost REAL,
        medical_history TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await database.insert('patients', {
      'id': 1,
      'name': '患者甲',
      'age': 30,
      'gender': '男',
      'doctor': '医生甲',
      'first_visit_date': '2026-07-19 10:00:00',
      'total_cost': 0.0,
      'created_at': '2026-07-19 10:00:00',
      'updated_at': '2026-07-19 10:00:00',
    });
    await database.insert('patients', {
      'id': 2,
      'name': '患者乙',
      'age': 30,
      'gender': '女',
      'doctor': '医生乙',
      'first_visit_date': '2026-07-19 10:00:00',
      'total_cost': 0.0,
      'created_at': '2026-07-19 10:00:00',
      'updated_at': '2026-07-19 10:00:00',
    });
  });

  tearDown(() => database.close());

  test('管理员可读取全部患者', () async {
    final dataSource = SqlitePatientDataSource(database, isAdmin: true);

    expect(await dataSource.getAllPatients(), hasLength(2));
    expect(
        (await dataSource.getPatientsPage(page: 1, pageSize: 10))['totalCount'],
        2);
  });

  test('医生只可读取本人患者的全量、分页、搜索和按 ID 查询', () async {
    final dataSource = SqlitePatientDataSource(database, doctorName: '医生甲');

    expect((await dataSource.getAllPatients()).single.id, 1);
    expect(
        (await dataSource.getPatientsPage(page: 1, pageSize: 10))['totalCount'],
        1);
    expect(await dataSource.searchPatientIds('患者'), [1]);
    expect((await dataSource.getPatientById(1))?.id, 1);
    expect(await dataSource.getPatientById(2), isNull);
  });

  test('无用户或无医生身份失败关闭', () async {
    final noUser = SqlitePatientDataSource(database);
    final noDoctor = SqlitePatientDataSource(database, doctorName: '');

    expect(await noUser.getAllPatients(), isEmpty);
    expect(
        (await noUser.getPatientsPage(page: 1, pageSize: 10))['totalCount'], 0);
    expect(await noUser.searchPatientIds('患者'), isEmpty);
    expect(await noUser.getPatientById(1), isNull);
    expect(await noDoctor.getAllPatients(), isEmpty);
  });
}
