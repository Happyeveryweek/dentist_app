import 'dart:io';

import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/models/sync_config.dart';
import 'package:dentist_app/utils/atomic_file_writer.dart';
import 'package:dentist_app/utils/config_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'dentist_config_test_',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('配置原子保存保留最近一次可读取备份', () async {
    final first = DatabaseConfig(dbType: 'sqlite');
    final second = DatabaseConfig(
      dbType: 'mysql',
      mysql: MySqlConfig(host: '192.0.2.10'),
    );

    await ConfigUtils.saveConfig(first, configDirectory: temporaryDirectory);
    await ConfigUtils.saveConfig(second, configDirectory: temporaryDirectory);

    final configFile = File(
      path.join(temporaryDirectory.path, ConfigUtils.configFileName),
    );
    final backupFile = File(
      '${configFile.path}${AtomicFileWriter.backupSuffix}',
    );
    expect(await backupFile.exists(), isTrue);

    await configFile.writeAsString('corrupted');
    final loaded = await ConfigUtils.loadConfig(
      configDirectory: temporaryDirectory,
    );

    expect(loaded.dbType, 'sqlite');
    expect(await configFile.readAsString(), 'corrupted');
  });

  test('配置及备份均损坏时明确失败且保留原文件', () async {
    final configFile = File(
      path.join(temporaryDirectory.path, ConfigUtils.configFileName),
    );
    final backupFile = File(
      '${configFile.path}${AtomicFileWriter.backupSuffix}',
    );
    await configFile.writeAsString('corrupted-primary');
    await backupFile.writeAsString('corrupted-backup');

    await expectLater(
      ConfigUtils.loadConfig(configDirectory: temporaryDirectory),
      throwsA(isA<ConfigReadException>()),
    );
    expect(await configFile.readAsString(), 'corrupted-primary');
    expect(await backupFile.readAsString(), 'corrupted-backup');
  });

  test('同步配置损坏时读取备份且不删除损坏文件', () async {
    final configPath = path.join(temporaryDirectory.path, 'sync_config.json');
    final first = SyncConfig(syncTables: ['patients']);
    final second = SyncConfig(syncTables: ['appointments']);
    await SyncConfig.saveSyncConfig(first, filePath: configPath);
    await SyncConfig.saveSyncConfig(second, filePath: configPath);

    final configFile = File(configPath);
    await configFile.writeAsString('{broken-json');

    final loaded = await SyncConfig.loadSyncConfig(filePath: configPath);
    expect(loaded.syncTables, ['patients']);
    expect(await configFile.readAsString(), '{broken-json');
  });
}
