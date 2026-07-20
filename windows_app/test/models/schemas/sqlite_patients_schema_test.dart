import 'package:dentist_app_windows/models/schemas/mysql_schema.dart';
import 'package:dentist_app_windows/models/schemas/sqlite_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('SQLite 患者医生字段没有默认值或固定医生姓名', () async {
    sqfliteFfiInit();
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
    final schema = SQLitePatientsTableSchema();

    expect(schema.columnDefinitions['doctor'], isNot(contains('DEFAULT')));
    expect(schema.createTableSql, isNot(contains('申向歌')));

    await database.execute(schema.createTableSql);
    final columns = await database.rawQuery('PRAGMA table_info(patients)');
    final doctorColumn =
        columns.singleWhere((column) => column['name'] == 'doctor');
    expect(doctorColumn['dflt_value'], isNull);
  });

  test('MySQL 患者医生字段保持现有可空定义', () {
    expect(
      MySQLPatientsTableSchema().columnDefinitions['doctor'],
      'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    );
  });
}
