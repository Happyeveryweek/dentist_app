import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dentist_app_windows/services/database_backup_service.dart';

void main() {
  late Directory testDirectory;
  Database? sourceDatabase;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'database_backup_service_test_',
    );
  });

  tearDown(() async {
    await sourceDatabase?.close();
    sourceDatabase = null;
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  Future<Database> createDatabase(String filePath, String value) async {
    final database = await databaseFactoryFfi.openDatabase(
      filePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await database.execute(
      'CREATE TABLE records (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
    );
    await database.insert('records', {'id': 1, 'value': value});
    return database;
  }

  test('SQLite 备份生成可通过完整性检查的一致快照', () async {
    final sourcePath =
        '${testDirectory.path}${Platform.pathSeparator}source.db';
    final backupDirectory = Directory(
      '${testDirectory.path}${Platform.pathSeparator}backups',
    );
    sourceDatabase = await createDatabase(sourcePath, 'snapshot-value');
    final service = DatabaseBackupService(
      sqliteDatabase: sourceDatabase,
      dataSourceType: 'sqlite',
    );

    final backupPath = await service.backupSQLiteDatabase(
      backupPath: backupDirectory.path,
    );

    final backupDatabase = await databaseFactoryFfi.openDatabase(
      backupPath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(backupDatabase.close);
    final integrity = await backupDatabase.rawQuery('PRAGMA integrity_check');
    final records = await backupDatabase.query('records');

    expect(integrity.single.values.single, 'ok');
    expect(records.single['value'], 'snapshot-value');
  });

  test('SQLite 恢复覆盖真实目标路径并保留恢复前备份', () async {
    final sourcePath =
        '${testDirectory.path}${Platform.pathSeparator}source.db';
    final targetPath =
        '${testDirectory.path}${Platform.pathSeparator}custom.db';
    final backupDirectory = Directory(
      '${testDirectory.path}${Platform.pathSeparator}backups',
    );
    sourceDatabase = await createDatabase(sourcePath, 'restored-value');
    final backupService = DatabaseBackupService(
      sqliteDatabase: sourceDatabase,
      dataSourceType: 'sqlite',
    );
    final backupPath = await backupService.backupSQLiteDatabase(
      backupPath: backupDirectory.path,
    );
    await sourceDatabase?.close();
    sourceDatabase = null;

    final targetDatabase = await createDatabase(targetPath, 'original-value');
    await targetDatabase.close();

    final restoreService = DatabaseBackupService(dataSourceType: 'sqlite');
    await restoreService.restoreSQLiteDatabase(
      backupPath,
      targetDatabasePath: targetPath,
    );

    final restoredDatabase = await databaseFactoryFfi.openDatabase(
      targetPath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(restoredDatabase.close);
    final restoredRecords = await restoredDatabase.query('records');
    expect(restoredRecords.single['value'], 'restored-value');

    final preRestoreFiles = testDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('custom_pre_restore_'))
        .toList();
    expect(preRestoreFiles, hasLength(1));

    final preRestoreDatabase = await databaseFactoryFfi.openDatabase(
      preRestoreFiles.single.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(preRestoreDatabase.close);
    final originalRecords = await preRestoreDatabase.query('records');
    expect(originalRecords.single['value'], 'original-value');
  });
}
