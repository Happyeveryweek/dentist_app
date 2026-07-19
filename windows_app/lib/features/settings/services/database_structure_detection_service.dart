import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:dentist_app_windows/models/database_structure_log.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';
import 'package:dentist_app_windows/features/settings/helpers/table_definitions_adapter.dart';
import 'package:dentist_app_windows/features/settings/helpers/database_type_converter_helper.dart';
import 'package:dentist_app_windows/utils/log_manager.dart';
import 'package:dentist_app_windows/features/users/services/password_service.dart';

/// 数据库结构检测服务
/// 负责检测和更新SQLite和MySQL数据库结构
class DatabaseStructureDetectionService {
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _sqliteDbPath = '';

  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;

  Database get _requireDatabase {
    final db = _database;
    if (db == null) {
      throw StateError('SQLite 数据库未初始化');
    }
    return db;
  }

  MySqlConnection get _requireMysqlConnection {
    final conn = _mysqlConnection;
    if (conn == null) {
      throw StateError('MySQL 连接未初始化');
    }
    return conn;
  }

  /// 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
  }

  /// 设置SQLite数据库路径
  void setSqliteDbPath(String path) {
    _sqliteDbPath = path;
  }

  /// 初始化MySQL连接
  Future<void> initializeMySQLConnection(
      Map<String, dynamic> mysqlSettings) async {
    LogManager.i('DatabaseStructureDetectionService', '开始初始化MySQL连接用于结构检测');
    try {
      // 测试现有连接
      if (_mysqlConnection != null) {
        try {
          await _requireMysqlConnection.query('SELECT 1');

          return;
        } catch (e) {
          try {
            await _requireMysqlConnection.close();
          } catch (_) {}
          _mysqlConnection = null;
        }
      }

      _mysqlConnection = await MySqlConnection.connect(
        ConnectionSettings(
          host: mysqlSettings['host'],
          port: mysqlSettings['port'],
          db: mysqlSettings['database'],
          user: mysqlSettings['username'],
          password: mysqlSettings['password'],
        ),
      );

      // 设置字符集
      await _requireMysqlConnection.query("SET NAMES 'utf8mb4'");
      await _requireMysqlConnection.query("SET character_set_connection = 'utf8mb4'");
      await _requireMysqlConnection.query("SET character_set_results = 'utf8mb4'");

      LogManager.i('DatabaseStructureDetectionService', 'MySQL连接初始化成功');
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '初始化MySQL连接失败',
          error: e);
      rethrow;
    }
  }

  /// 检测并更新数据库结构
  Future<Map<String, dynamic>> detectAndUpdateDatabaseStructure({
    String? targetDataSource,
  }) async {
    final dataSource = targetDataSource ?? 'sqlite';

    // 使用TableDefinitionsAdapter获取所有系统表
    final systemTables = TableDefinitionsAdapter.getAllSystemTableNames();

    final result = {
      'status': '开始检测数据库结构',
      'dataSourceType': dataSource,
      'detectionTime': DateTimeFormatter.nowDbString(),
      'requiredTables': systemTables.length,
      'missingTables': 0,
      'structureChanges': 0,
      'errors': <String>[],
      'details': <String, dynamic>{
        'systemTables': systemTables,
        'tablesCreated': <String>[],
        'tablesUpdated': <String>[],
        'columnsAdded': <Map<String, dynamic>>[],
        'columnsModified': <Map<String, dynamic>>[],
        'extraColumns': <Map<String, dynamic>>[],
        'typeMismatchColumns': <Map<String, dynamic>>[],
        'constraintDifferences': <Map<String, dynamic>>[],
        'structureChanges': <String>[],
        'detectedTables': <String>[],
        'missingTableNames': <String>[],
        'ignoredTables': <String>[],
      },
    };

    try {
      LogManager.i('DatabaseStructureDetectionService',
          '开始检测数据库结构，数据源: $dataSource，必需表数: ${systemTables.length}');

      if (dataSource == 'sqlite') {
        await _detectAndUpdateSQLiteStructure(result, systemTables);
      } else if (dataSource == 'mysql') {
        await _detectAndUpdateMySQLStructure(result, systemTables);
      } else {
        throw Exception('不支持的数据源类型: $dataSource');
      }

      result['status'] = '数据库结构检测完成';
      LogManager.i('DatabaseStructureDetectionService',
          '数据库结构检测完成，变化数: ${result['structureChanges']}');
    } catch (e) {
      result['status'] = '数据库结构检测失败';
      (result['errors'] as List<String>).add('检测过程中发生错误: $e');
      LogManager.e('DatabaseStructureDetectionService', '数据库结构检测失败', error: e);
    }

    return result;
  }

  /// 检测并更新SQLite结构
  Future<void> _detectAndUpdateSQLiteStructure(
      Map<String, dynamic> result, List<String> systemTables) async {
    if (_database == null) {
      throw Exception('SQLite数据库连接未初始化');
    }

    // 使用统一的表结构检测和更新逻辑
    await _detectAndUpdateTableStructure(result, false, systemTables);
  }

  /// 检测并更新MySQL结构
  Future<void> _detectAndUpdateMySQLStructure(
      Map<String, dynamic> result, List<String> systemTables) async {
    if (_mysqlConnection == null) {
      throw Exception('MySQL数据库连接未初始化');
    }

    // 使用统一的表结构检测和更新逻辑
    await _detectAndUpdateTableStructure(result, true, systemTables);
  }

  /// 检测并更新表结构
  Future<void> _detectAndUpdateTableStructure(Map<String, dynamic> result,
      bool isMySQL, List<String> systemTables) async {
    // 根据数据库类型获取相应的表结构定义
    final allTableDefinitions = isMySQL
        ? TableDefinitionsAdapter.getMySQLTableDefinitions()
        : TableDefinitionsAdapter.getSQLiteTableDefinitions();

    // 只获取系统表的定义
    final tableDefinitions = <String, Map<String, String>>{};
    for (final tableName in systemTables) {
      final tableDef = allTableDefinitions[tableName];
      if (tableDef != null) {
        tableDefinitions[tableName] = tableDef;
      }
    }

    // 获取数据库中所有现有表
    final allExistingTables =
        isMySQL ? await _getMySQLTableNames() : await _getSQLiteTableNames();

    // 只关注系统表
    final systemExistingTables = allExistingTables
        .where((table) => systemTables.contains(table))
        .toList();
    final ignoredTables = allExistingTables
        .where((table) => !systemTables.contains(table))
        .toList();

    result['details']['detectedTables'] = systemExistingTables;
    result['details']['ignoredTables'] = ignoredTables;

    if (ignoredTables.isNotEmpty) {
      (result['details']['structureChanges'] as List<String>)
          .add('忽略 ${ignoredTables.length} 个非系统表: ${ignoredTables.join(', ')}');
    }

    // 1. 检查缺失的系统表并创建
    await _createMissingTables(
        systemExistingTables, result, isMySQL, tableDefinitions, systemTables);

    // 2. 检查现有系统表结构并更新
    await _updateExistingTableStructures(
        systemExistingTables, result, isMySQL, tableDefinitions);

    // 3. 如果是MySQL，只有在真正需要时才执行特殊修复
    if (isMySQL) {
      final hasRealChanges =
          (result['details']['columnsAdded'] as List<dynamic>?)?.isNotEmpty ==
                  true ||
              (result['details']['tablesUpdated'] as List<dynamic>?)
                      ?.isNotEmpty ==
                  true;

      if (hasRealChanges) {
        await _fixMySQLTableStructures(systemExistingTables, result);
      } else {}
    }
  }

  /// 创建缺失的表
  Future<void> _createMissingTables(
      List<String> existingTables,
      Map<String, dynamic> result,
      bool isMySQL,
      Map<String, Map<String, String>> tableDefinitions,
      List<String> systemTables) async {
    // 检查缺失的系统表
    final missingTables = <String>[];
    for (final tableName in systemTables) {
      if (tableDefinitions.containsKey(tableName) &&
          !existingTables.contains(tableName)) {
        missingTables.add(tableName);
      }
    }

    result['missingTables'] = missingTables.length;
    result['details']['missingTableNames'] = missingTables;

    if (missingTables.isNotEmpty) {
      (result['details']['structureChanges'] as List<String>).add(
          '发现 ${missingTables.length} 个缺失的系统表: ${missingTables.join(', ')}');
    } else {
      (result['details']['structureChanges'] as List<String>)
          .add('所有系统表都已存在，无需创建新表');
    }

    // 创建缺失的表
    final tablesCreated = <String>[];
    for (final tableName in missingTables) {
      final tableDef = tableDefinitions[tableName];
      if (tableDef == null) continue;

      try {
        if (isMySQL) {
          final createSQL = TableDefinitionsAdapter.generateMySQLCreateTable(
              tableName, tableDef);
          await _requireMysqlConnection.query(createSQL);

          if (tableName == 'users') {
            await _createDefaultMySQLUser();
          }
        } else {
          final createSQL = TableDefinitionsAdapter.generateSQLiteCreateTable(
              tableName, tableDef);
          await _requireDatabase.execute(createSQL);

          if (tableName == 'users') {
            await _createDefaultSQLiteUser();
          }
        }
        tablesCreated.add(tableName);

        (result['details']['structureChanges'] as List<String>)
            .add('创建系统表: $tableName');
      } catch (e) {
        final errorMsg = '创建系统表 $tableName 失败: $e';
        (result['errors'] as List<String>).add(errorMsg);
      }
    }

    result['details']['tablesCreated'] = tablesCreated;
    result['structureChanges'] =
        ((result['structureChanges'] as int?) ?? 0) + tablesCreated.length;
  }

  /// 创建默认MySQL用户
  Future<void> _createDefaultMySQLUser() async {
    try {
      final existingUsers = await _requireMysqlConnection.query(
          'SELECT COUNT(*) as count FROM users WHERE username = ?', ['admin']);

      if (existingUsers.first['count'] == 0) {
        final hashedPassword = PasswordService().hashPassword('123456');
        await _requireMysqlConnection.query('''
          INSERT INTO users (username, email, password, role, doctor, avatar, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
        ''', [
          'admin',
          'admin@example.com',
          hashedPassword,
          'admin',
          '系统管理员',
          'avatar_5'
        ]);
      } else {}
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '创建MySQL默认用户失败',
          error: e);
    }
  }

  /// 创建默认SQLite用户
  Future<void> _createDefaultSQLiteUser() async {
    try {
      final existingUsers = await _requireDatabase
          .query('users', where: 'username = ?', whereArgs: ['admin']);

      if (existingUsers.isEmpty) {
        final hashedPassword = PasswordService().hashPassword('123456');
        final now = DateTimeFormatter.nowDbString();
        await _requireDatabase.insert('users', {
          'username': 'admin',
          'email': 'admin@example.com',
          'password': hashedPassword,
          'role': 'admin',
          'doctor': '系统管理员',
          'avatar': 'avatar_5',
          'created_at': now,
          'updated_at': now,
        });
      } else {}
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '创建SQLite默认用户失败',
          error: e);
    }
  }

  /// 更新现有表结构
  Future<void> _updateExistingTableStructures(
      List<String> existingTables,
      Map<String, dynamic> result,
      bool isMySQL,
      Map<String, Map<String, String>> tableDefinitions) async {
    final columnsAdded = <Map<String, dynamic>>[];
    final columnsModified = <Map<String, dynamic>>[];
    final tablesUpdated = <String>[];

    try {
      (result['details']['structureChanges'] as List<String>)
          .add('开始检查现有系统表结构');

      for (final tableName in existingTables) {
        final requiredColumns = tableDefinitions[tableName];
        if (requiredColumns != null) {
          if (isMySQL) {
            await _checkAndUpdateMySQLTableStructure(tableName, requiredColumns,
                columnsAdded, columnsModified, tablesUpdated, result);
          } else {
            await _checkAndUpdateSQLiteTableStructure(
                tableName,
                requiredColumns,
                columnsAdded,
                columnsModified,
                tablesUpdated,
                result);
          }
        }
      }

      result['details']['columnsAdded'] = columnsAdded;
      result['details']['columnsModified'] = columnsModified;
      result['details']['tablesUpdated'] = tablesUpdated;
      result['structureChanges'] = ((result['structureChanges'] as int?) ?? 0) +
          columnsAdded.length +
          columnsModified.length;

      final summary =
          '表结构检查完成: 添加字段 ${columnsAdded.length} 个, 修改字段 ${columnsModified.length} 个, 更新表 ${tablesUpdated.length} 个';

      (result['details']['structureChanges'] as List<String>).add(summary);
    } catch (e) {
      final errorMsg = '表结构检查失败: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 检查并更新SQLite表结构
  Future<void> _checkAndUpdateSQLiteTableStructure(
      String tableName,
      Map<String, String> requiredColumns,
      List<Map<String, dynamic>> columnsAdded,
      List<Map<String, dynamic>> columnsModified,
      List<String> tablesUpdated,
      Map<String, dynamic> result) async {
    if (_database == null) return;

    try {
      final existingColumns = await _getSQLiteTableColumnDetails(tableName);
      final existingColumnNames = existingColumns.keys.toList();

      bool tableUpdated = false;
      final structureDifferences = <String>[];

      final extraColumns = <String>[];
      for (final existingColumn in existingColumnNames) {
        if (!requiredColumns.containsKey(existingColumn)) {
          extraColumns.add(existingColumn);
        }
      }

      final missingColumns = <String>[];

      for (final columnName in requiredColumns.keys) {
        final normalizedColumnName = columnName.toLowerCase().trim();
        final normalizedExistingColumns = existingColumnNames
            .map((name) => name.toLowerCase().trim())
            .toList();
        if (!normalizedExistingColumns.contains(normalizedColumnName)) {
          missingColumns.add(columnName);
        }
      }

      final columnsToModify = <String>[];
      for (final columnName in requiredColumns.keys) {
        final existingColumn = existingColumns[columnName];
        final requiredType = requiredColumns[columnName];
        if (existingColumn != null && requiredType != null) {
          final existingType = existingColumn['type'] as String;
          if (_shouldUpdateSQLiteColumnType(existingType, requiredType)) {
            columnsToModify.add(columnName);
          }
        }
      }

      if (missingColumns.isNotEmpty) {
        structureDifferences.add(
            '缺失字段 ${missingColumns.length} 个: ${missingColumns.join(', ')}');

        for (final columnName in missingColumns) {
          try {
            final reCheckColumns = await _getSQLiteTableColumns(tableName);
            final normalizedReCheckColumns = reCheckColumns
                .map((name) => name.toLowerCase().trim())
                .toList();
            final normalizedColumnName = columnName.toLowerCase().trim();

            if (normalizedReCheckColumns.contains(normalizedColumnName)) {
              structureDifferences.add('字段 $columnName 已存在，跳过添加');
              continue;
            }

            final requiredType = requiredColumns[columnName];
            if (requiredType == null) continue;
            final columnDef = DatabaseTypeConverterHelper.convertToSQLiteType(
                requiredType);
            String safeColumnDef = columnDef
                .replaceAll('PRIMARY KEY', '')
                .replaceAll('AUTOINCREMENT', '')
                .trim();

            if (safeColumnDef.contains('NOT NULL')) {
              safeColumnDef = safeColumnDef.replaceAll('NOT NULL', '').trim();
            }

            await _requireDatabase.execute(
                'ALTER TABLE $tableName ADD COLUMN $columnName $safeColumnDef');
            await _setSQLiteDefaultValue(tableName, columnName);

            columnsAdded.add({
              'table': tableName,
              'column': columnName,
              'type': safeColumnDef,
              'database': 'SQLite',
              'action': 'added'
            });

            (result['details']['structureChanges'] as List<String>)
                .add('为SQLite表 $tableName 添加字段: $columnName');
            structureDifferences.add('已添加字段: $columnName ($safeColumnDef)');
            tableUpdated = true;
          } catch (e) {
            if (e.toString().contains('duplicate column name')) {
              LogManager.e('DatabaseStructureDetectionService',
                  '字段 $columnName 已存在，跳过添加 (捕获到重复字段错误)');
              structureDifferences.add('字段 $columnName 已存在，跳过添加');
              continue;
            }

            final errorMsg = '为SQLite表 $tableName 添加字段 $columnName 失败: $e';

            (result['errors'] as List<String>).add(errorMsg);
            structureDifferences.add('添加字段失败: $columnName - $e');
          }
        }
      } else {
        (result['details']['structureChanges'] as List<String>)
            .add('SQLite表 $tableName 结构完整');
      }

      if (extraColumns.isNotEmpty) {
        (result['details']['extraColumns'] as List<Map<String, dynamic>>).add({
          'table': tableName,
          'columns': extraColumns,
          'database': 'SQLite',
        });
        structureDifferences.add(
            '多余字段 ${extraColumns.length} 个: ${extraColumns.join(', ')} (已保留)');
      }

      if (columnsToModify.isNotEmpty) {
        final typeDifferences = <String>[];
        for (final columnName in columnsToModify) {
          final existingColumn = existingColumns[columnName];
          final requiredType = requiredColumns[columnName];
          if (existingColumn == null || requiredType == null) continue;
          final existingType = existingColumn['type'] as String;
          typeDifferences.add('$columnName: $existingType → $requiredType');
        }
        (result['details']['typeMismatchColumns'] as List<Map<String, dynamic>>)
            .add({
          'table': tableName,
          'columns': columnsToModify,
          'database': 'SQLite',
        });
        structureDifferences.add(
            '类型不匹配字段 ${columnsToModify.length} 个: ${typeDifferences.join(', ')} (SQLite兼容，已保留)');
      }

      final constraintDifferences = <String>[];
      for (final columnName in existingColumns.keys) {
        final existingColumn = existingColumns[columnName];
        final requiredDef = requiredColumns[columnName];
        if (existingColumn != null && requiredDef != null) {
          final existingNotNull = existingColumn['notnull'] as int == 1;
          final requiredNotNull =
              requiredDef.toUpperCase().contains('NOT NULL');
          if (existingNotNull != requiredNotNull) {
            constraintDifferences.add(
                '$columnName: NOT NULL约束不匹配 (现有: $existingNotNull, 需要: $requiredNotNull)');
          }

          final existingDefault = existingColumn['dflt_value'];
          final hasRequiredDefault =
              requiredDef.toUpperCase().contains('DEFAULT');
          if ((existingDefault == null) != (!hasRequiredDefault)) {
            constraintDifferences.add(
                '$columnName: 默认值不匹配 (现有: $existingDefault, 需要: ${hasRequiredDefault ? '有默认值' : '无默认值'})');
          }
        }
      }

      if (constraintDifferences.isNotEmpty) {
        (result['details']['constraintDifferences']
                as List<Map<String, dynamic>>)
            .add({
          'table': tableName,
          'details': constraintDifferences,
          'database': 'SQLite',
        });
        structureDifferences.add(
            '约束差异 ${constraintDifferences.length} 个: ${constraintDifferences.join(', ')} (已保留)');
      }

      if (structureDifferences.isEmpty) {
        (result['details']['structureChanges'] as List<String>)
            .add('SQLite表 $tableName 结构完全匹配');
      } else {
        (result['details']['structureChanges'] as List<String>).add(
            'SQLite表 $tableName 结构差异: ${structureDifferences.join(' | ')}');
      }

      if (tableUpdated) {
        tablesUpdated.add(tableName);
      }
    } catch (e) {
      final errorMsg = '检查SQLite表 $tableName 结构时出错: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 设置SQLite默认值
  Future<void> _setSQLiteDefaultValue(
      String tableName, String columnName) async {
    try {
      if (columnName == 'created_at' || columnName == 'updated_at') {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = datetime('now') 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName == 'avatar') {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = 'avatar_1' 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName.contains('price') ||
          columnName.contains('amount') ||
          columnName.contains('cost')) {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = 0.0 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName.contains('quantity') ||
          columnName.contains('stock')) {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = 0 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName == 'role') {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = 'user' 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName == 'status') {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = 'active' 
          WHERE $columnName IS NULL
        ''');
      } else {
        await _requireDatabase.execute('''
          UPDATE $tableName 
          SET $columnName = '' 
          WHERE $columnName IS NULL
        ''');
      }
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService',
          '为SQLite表 $tableName 字段 $columnName 设置默认值失败',
          error: e);
    }
  }

  /// 获取SQLite表字段详细信息
  Future<Map<String, Map<String, dynamic>>> _getSQLiteTableColumnDetails(
      String tableName) async {
    if (_database == null) return {};

    try {
      final result = await _requireDatabase.rawQuery('PRAGMA table_info($tableName)');
      final columns = <String, Map<String, dynamic>>{};

      for (final row in result) {
        final columnName = row['name'] as String;
        columns[columnName] = {
          'type': row['type'] as String,
          'notnull': row['notnull'] as int,
          'dflt_value': row['dflt_value'],
          'pk': row['pk'] as int,
        };
      }

      return columns;
    } catch (e) {
      LogManager.e(
          'DatabaseStructureDetectionService', '获取SQLite表 $tableName 的字段详细信息失败',
          error: e);
      return {};
    }
  }

  /// 获取SQLite表字段名列表
  Future<List<String>> _getSQLiteTableColumns(String tableName) async {
    final columns = await _getSQLiteTableColumnDetails(tableName);
    return columns.keys.toList();
  }

  /// 获取SQLite表名
  Future<List<String>> _getSQLiteTableNames() async {
    if (_database == null) return [];

    try {
      final result = await _requireDatabase.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      return result.map((table) => table['name'] as String).toList();
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '获取SQLite表名失败',
          error: e);
      return [];
    }
  }

  /// 检查并更新MySQL表结构
  Future<void> _checkAndUpdateMySQLTableStructure(
      String tableName,
      Map<String, String> requiredColumns,
      List<Map<String, dynamic>> columnsAdded,
      List<Map<String, dynamic>> columnsModified,
      List<String> tablesUpdated,
      Map<String, dynamic> result) async {
    if (_mysqlConnection == null) return;

    try {
      final existingColumns = await _getMySQLTableColumnDetails(tableName);

      bool tableUpdated = false;
      final structureDifferences = <String>[];

      final extraColumns = <String>[];
      for (final existingColumn in existingColumns.keys) {
        if (!requiredColumns.containsKey(existingColumn)) {
          extraColumns.add(existingColumn);
        }
      }

      final missingColumns = <String>[];
      final typeMismatchColumns = <String>[];
      final constraintDifferences = <String>[];

      for (final columnName in requiredColumns.keys) {
        final existingColumn = existingColumns[columnName];
        final requiredType = requiredColumns[columnName];
        if (existingColumn == null || requiredType == null) {
          missingColumns.add(columnName);
        } else {
          final existingType = existingColumn['type'] as String;
          final existingNull = (existingColumn['nullable'] as bool?) ?? false;
          final existingKey = (existingColumn['key'] as String?) ?? '';
          final existingDefault = existingColumn['default'];
          final normalizedRequiredType =
              _normalizeMySQLColumnDefinition(requiredType);

          if (_shouldUpdateMySQLColumnType(existingType, requiredType)) {
            typeMismatchColumns
                .add('$columnName: $existingType → $normalizedRequiredType');
          }

          final requiredAllowsNull =
              !requiredType.toUpperCase().contains('NOT NULL');
          if (existingNull != requiredAllowsNull) {
            constraintDifferences.add(
                '$columnName: NULL约束不匹配 (现有: ${existingNull ? 'NULL' : 'NOT NULL'}, 需要: ${requiredAllowsNull ? 'NULL' : 'NOT NULL'})');
          }

          final existingIsPrimaryKey = existingKey.toUpperCase() == 'PRI';
          final requiredIsPrimaryKey =
              requiredType.toUpperCase().contains('PRIMARY KEY');
          if (existingIsPrimaryKey != requiredIsPrimaryKey) {
            constraintDifferences.add(
                '$columnName: 主键约束不匹配 (现有: ${existingIsPrimaryKey ? 'PRIMARY KEY' : '非主键'}, 需要: ${requiredIsPrimaryKey ? 'PRIMARY KEY' : '非主键'})');
          }

          final existingAutoIncrement =
              ((existingColumn['extra'] as String?) ?? '')
                  .toUpperCase()
                  .contains('AUTO_INCREMENT');
          final requiredAutoIncrement =
              requiredType.toUpperCase().contains('AUTO_INCREMENT');
          if (existingAutoIncrement != requiredAutoIncrement) {
            constraintDifferences.add(
                '$columnName: AUTO_INCREMENT不匹配 (现有: ${existingAutoIncrement ? 'AUTO_INCREMENT' : '非自增'}, 需要: ${requiredAutoIncrement ? 'AUTO_INCREMENT' : '非自增'})');
          }

          final hasRequiredDefault =
              requiredType.toUpperCase().contains('DEFAULT');
          if ((existingDefault == null) != (!hasRequiredDefault)) {
            constraintDifferences.add(
                '$columnName: 默认值不匹配 (现有: ${existingDefault ?? 'NULL'}, 需要: ${hasRequiredDefault ? '有默认值' : '无默认值'})');
          }
        }
      }

      if (extraColumns.isNotEmpty) {
        (result['details']['extraColumns'] as List<Map<String, dynamic>>).add({
          'table': tableName,
          'columns': extraColumns,
          'database': 'MySQL',
        });
        structureDifferences.add(
            '多余字段 ${extraColumns.length} 个: ${extraColumns.join(', ')} (已保留)');
      }

      if (missingColumns.isNotEmpty) {
        structureDifferences.add(
            '缺失字段 ${missingColumns.length} 个: ${missingColumns.join(', ')}');

        for (final columnName in missingColumns) {
          final requiredType = requiredColumns[columnName];
          if (requiredType == null) continue;

          try {
            final columnDef = DatabaseTypeConverterHelper.convertToMySQLType(
                requiredType);
            String mysqlColumnDef =
                columnDef.replaceAll('PRIMARY KEY', '').trim();

            if (columnName == 'avatar' &&
                mysqlColumnDef.contains('TEXT DEFAULT')) {
              mysqlColumnDef = 'VARCHAR(50) DEFAULT \'avatar_1\'';
            }

            if (mysqlColumnDef.contains('AUTO_INCREMENT')) {
              mysqlColumnDef =
                  mysqlColumnDef.replaceAll('AUTO_INCREMENT', '').trim();
            }

            await _requireMysqlConnection.query(
                'ALTER TABLE $tableName ADD COLUMN $columnName $mysqlColumnDef');

            columnsAdded.add({
              'table': tableName,
              'column': columnName,
              'type': mysqlColumnDef,
              'database': 'MySQL',
              'action': 'added'
            });

            (result['details']['structureChanges'] as List<String>)
                .add('为MySQL表 $tableName 添加字段: $columnName');
            structureDifferences.add('已添加字段: $columnName ($mysqlColumnDef)');
            tableUpdated = true;
          } catch (e) {
            final errorMsg = '为MySQL表 $tableName 添加字段 $columnName 失败: $e';

            (result['errors'] as List<String>).add(errorMsg);
            structureDifferences.add('添加字段失败: $columnName - $e');
          }
        }
      } else {
        (result['details']['structureChanges'] as List<String>)
            .add('MySQL表 $tableName 结构完整');
      }

      if (typeMismatchColumns.isNotEmpty) {
        (result['details']['typeMismatchColumns'] as List<Map<String, dynamic>>)
            .add({
          'table': tableName,
          'columns': typeMismatchColumns,
          'database': 'MySQL',
        });
        structureDifferences.add(
            '类型不匹配字段 ${typeMismatchColumns.length} 个: ${typeMismatchColumns.join(', ')} (已保留，避免数据丢失)');
      }

      if (constraintDifferences.isNotEmpty) {
        (result['details']['constraintDifferences']
                as List<Map<String, dynamic>>)
            .add({
          'table': tableName,
          'details': constraintDifferences,
          'database': 'MySQL',
        });
        structureDifferences.add(
            '约束差异 ${constraintDifferences.length} 个: ${constraintDifferences.join(', ')} (已保留)');
      }

      if (structureDifferences.isEmpty) {
        (result['details']['structureChanges'] as List<String>)
            .add('MySQL表 $tableName 结构完全匹配');
      } else {
        (result['details']['structureChanges'] as List<String>)
            .add('MySQL表 $tableName 结构差异: ${structureDifferences.join(' | ')}');
      }

      if (tableUpdated) {
        tablesUpdated.add(tableName);
      }
    } catch (e) {
      final errorMsg = '检查MySQL表 $tableName 结构时出错: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 判断MySQL字段类型是否需要更新
  bool _shouldUpdateMySQLColumnType(String existingType, String requiredType) {
    final existingNormalized = _normalizeMySQLColumnDefinition(existingType);
    final requiredNormalized = _normalizeMySQLColumnDefinition(requiredType);
    return existingNormalized != requiredNormalized;
  }

  /// 判断SQLite字段类型是否需要更新
  bool _shouldUpdateSQLiteColumnType(String existingType, String requiredType) {
    final existingNormalized = _normalizeSQLiteColumnDefinition(existingType);
    final requiredNormalized = _normalizeSQLiteColumnDefinition(requiredType);
    return existingNormalized != requiredNormalized;
  }

  /// 规范化MySQL字段定义，剥离约束与空格后用于比较
  String _normalizeMySQLColumnDefinition(String columnDef) {
    var normalized = columnDef.toUpperCase();
    normalized = normalized.replaceAll(RegExp(r'PRIMARY KEY'), '');
    normalized = normalized.replaceAll(RegExp(r'AUTO_INCREMENT'), '');
    normalized = normalized.replaceAll(RegExp(r'NOT NULL'), '');
    normalized = normalized.replaceAll(RegExp(r'DEFAULT\s+[^,\s]+'), '');
    normalized = normalized.replaceAll(RegExp(r'UNIQUE'), '');
    normalized = normalized.replaceAll(RegExp(r"COMMENT\s+'[^']*'"), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    normalized = normalized.replaceAll(RegExp(r'VARCHAR\(\d+\)'), 'VARCHAR');
    normalized = normalized.replaceAll(RegExp(r'CHAR\(\d+\)'), 'CHAR');
    normalized =
        normalized.replaceAll(RegExp(r'DECIMAL\(\d+,\d+\)'), 'DECIMAL');
    normalized =
        normalized.replaceAll(RegExp(r'NUMERIC\(\d+,\d+\)'), 'NUMERIC');
    normalized = normalized.replaceAll(RegExp(r'INT\(\d+\)'), 'INT');
    normalized = normalized.replaceAll(RegExp(r'TINYINT\(\d+\)'), 'TINYINT');
    normalized = normalized.replaceAll(RegExp(r'BIGINT\(\d+\)'), 'BIGINT');
    normalized = normalized.replaceAll(RegExp(r'SMALLINT\(\d+\)'), 'SMALLINT');
    normalized =
        normalized.replaceAll(RegExp(r'MEDIUMINT\(\d+\)'), 'MEDIUMINT');
    normalized = normalized.replaceAll(RegExp(r'DOUBLE\(\d+,\d+\)'), 'DOUBLE');
    normalized = normalized.replaceAll(RegExp(r'FLOAT\(\d+,\d+\)'), 'FLOAT');

    return normalized;
  }

  /// 规范化SQLite字段定义，剥离约束与空格后用于比较
  String _normalizeSQLiteColumnDefinition(String columnDef) {
    var normalized = columnDef.toUpperCase();
    normalized = normalized.replaceAll(RegExp(r'PRIMARY KEY'), '');
    normalized = normalized.replaceAll(RegExp(r'AUTOINCREMENT'), '');
    normalized = normalized.replaceAll(RegExp(r'NOT NULL'), '');
    normalized = normalized.replaceAll(RegExp(r'DEFAULT\s+[^,\s]+'), '');
    normalized = normalized.replaceAll(RegExp(r'UNIQUE'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    normalized = normalized.replaceAll(RegExp(r'VARCHAR\(\d+\)'), 'TEXT');
    normalized = normalized.replaceAll(RegExp(r'CHAR\(\d+\)'), 'TEXT');
    normalized = normalized.replaceAll(RegExp(r'DECIMAL\(\d+,\d+\)'), 'REAL');
    normalized = normalized.replaceAll(RegExp(r'NUMERIC\(\d+,\d+\)'), 'REAL');
    normalized = normalized.replaceAll(RegExp(r'INT\(\d+\)'), 'INTEGER');
    normalized = normalized.replaceAll(RegExp(r'TINYINT\(\d+\)'), 'INTEGER');
    normalized = normalized.replaceAll(RegExp(r'BIGINT\(\d+\)'), 'INTEGER');
    normalized = normalized.replaceAll(RegExp(r'DATETIME'), 'TEXT');
    normalized = normalized.replaceAll(RegExp(r'DATE'), 'TEXT');
    return normalized;
  }

  /// 获取MySQL表字段详细信息
  Future<Map<String, Map<String, dynamic>>> _getMySQLTableColumnDetails(
      String tableName) async {
    if (_mysqlConnection == null) return {};

    try {
      final result = await _requireMysqlConnection.query('DESCRIBE $tableName');
      final columns = <String, Map<String, dynamic>>{};

      for (final row in result) {
        final columnName =
            DatabaseTypeConverterHelper.safeStringParse(row['Field']);
        final columnType =
            DatabaseTypeConverterHelper.safeStringParse(row['Type']);
        final nullable =
            DatabaseTypeConverterHelper.safeStringParse(row['Null']) == 'YES';
        final key = DatabaseTypeConverterHelper.safeStringParse(row['Key']);
        final defaultValue = row['Default'];

        columns[columnName] = {
          'type': columnType,
          'nullable': nullable,
          'key': key,
          'default': defaultValue,
        };
      }

      return columns;
    } catch (e) {
      LogManager.e(
          'DatabaseStructureDetectionService', '获取MySQL表 $tableName 的字段详细信息失败',
          error: e);
      return {};
    }
  }

  /// 获取MySQL表名
  Future<List<String>> _getMySQLTableNames() async {
    if (_mysqlConnection == null) return [];

    try {
      final result = await _requireMysqlConnection.query('SHOW TABLES');
      return result
          .map((table) => DatabaseTypeConverterHelper.safeStringParse(
                table.fields.isNotEmpty ? table.fields.values.first : table[0],
              ))
          .toList();
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '获取MySQL表名失败',
          error: e);
      return [];
    }
  }

  /// 修复MySQL表结构
  Future<void> _fixMySQLTableStructures(
      List<String> existingTables, Map<String, dynamic> result) async {
    if (_mysqlConnection == null) return;

    try {
      if (existingTables.contains('purchase_items')) {
        await _fixPurchaseItemsTable(result);
      }

      if (existingTables.contains('material_images')) {
        await _fixMaterialImagesTable(result);
      }

      if (existingTables.contains('appointments')) {
        await _fixAppointmentsTable(result);
      }
    } catch (e) {
      final errorMsg = '修复MySQL表结构时出错: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 修复purchase_items表
  Future<void> _fixPurchaseItemsTable(Map<String, dynamic> result) async {
    try {
      final columns = await _getMySQLTableColumnDetails('purchase_items');

      if (!columns.containsKey('material_id')) {
        await _requireMysqlConnection
            .query('ALTER TABLE purchase_items ADD COLUMN material_id INTEGER');

        (result['details']['structureChanges'] as List<String>)
            .add('为purchase_items表添加material_id字段');
      }

      if (!columns.containsKey('quantity')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE purchase_items ADD COLUMN quantity INTEGER DEFAULT 1');

        (result['details']['structureChanges'] as List<String>)
            .add('为purchase_items表添加quantity字段');
      }

      if (!columns.containsKey('unit_price')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE purchase_items ADD COLUMN unit_price DECIMAL(10,2) DEFAULT 0.00');

        (result['details']['structureChanges'] as List<String>)
            .add('为purchase_items表添加unit_price字段');
      }

      if (!columns.containsKey('total_price')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE purchase_items ADD COLUMN total_price DECIMAL(10,2) DEFAULT 0.00');

        (result['details']['structureChanges'] as List<String>)
            .add('为purchase_items表添加total_price字段');
      }
    } catch (e) {
      final errorMsg = '修复purchase_items表失败: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 修复material_images表
  Future<void> _fixMaterialImagesTable(Map<String, dynamic> result) async {
    try {
      final columns = await _getMySQLTableColumnDetails('material_images');

      if (!columns.containsKey('image_url')) {
        await _requireMysqlConnection
            .query('ALTER TABLE material_images ADD COLUMN image_url TEXT');

        (result['details']['structureChanges'] as List<String>)
            .add('为material_images表添加image_url字段');
      }

      if (!columns.containsKey('image_path')) {
        await _requireMysqlConnection
            .query('ALTER TABLE material_images ADD COLUMN image_path TEXT');

        (result['details']['structureChanges'] as List<String>)
            .add('为material_images表添加image_path字段');
      }

      if (!columns.containsKey('thumbnail_url')) {
        await _requireMysqlConnection
            .query('ALTER TABLE material_images ADD COLUMN thumbnail_url TEXT');

        (result['details']['structureChanges'] as List<String>)
            .add('为material_images表添加thumbnail_url字段');
      }

      if (!columns.containsKey('thumbnail_path')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE material_images ADD COLUMN thumbnail_path TEXT');

        (result['details']['structureChanges'] as List<String>)
            .add('为material_images表添加thumbnail_path字段');
      }

      if (!columns.containsKey('is_primary')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE material_images ADD COLUMN is_primary BOOLEAN DEFAULT FALSE');

        (result['details']['structureChanges'] as List<String>)
            .add('为material_images表添加is_primary字段');
      }

      if (!columns.containsKey('display_order')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE material_images ADD COLUMN display_order INTEGER DEFAULT 0');

        (result['details']['structureChanges'] as List<String>)
            .add('为material_images表添加display_order字段');
      }
    } catch (e) {
      final errorMsg = '修复material_images表失败: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 修复appointments表
  Future<void> _fixAppointmentsTable(Map<String, dynamic> result) async {
    try {
      final columns = await _getMySQLTableColumnDetails('appointments');

      if (!columns.containsKey('status')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE appointments ADD COLUMN status VARCHAR(20) DEFAULT "scheduled"');

        (result['details']['structureChanges'] as List<String>)
            .add('为appointments表添加status字段');
      }

      if (!columns.containsKey('notes')) {
        await _requireMysqlConnection
            .query('ALTER TABLE appointments ADD COLUMN notes TEXT');

        (result['details']['structureChanges'] as List<String>)
            .add('为appointments表添加notes字段');
      }

      if (!columns.containsKey('reminder_sent')) {
        await _requireMysqlConnection.query(
            'ALTER TABLE appointments ADD COLUMN reminder_sent BOOLEAN DEFAULT FALSE');

        (result['details']['structureChanges'] as List<String>)
            .add('为appointments表添加reminder_sent字段');
      }

      if (!columns.containsKey('created_by')) {
        await _requireMysqlConnection
            .query('ALTER TABLE appointments ADD COLUMN created_by INTEGER');

        (result['details']['structureChanges'] as List<String>)
            .add('为appointments表添加created_by字段');
      }

      if (!columns.containsKey('updated_by')) {
        await _requireMysqlConnection
            .query('ALTER TABLE appointments ADD COLUMN updated_by INTEGER');

        (result['details']['structureChanges'] as List<String>)
            .add('为appointments表添加updated_by字段');
      }
    } catch (e) {
      final errorMsg = '修复appointments表失败: $e';

      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 获取数据库结构检测日志
  Future<List<DatabaseStructureLog>> getDatabaseStructureLogs(
      {int limit = 50}) async {
    try {
      Database? logDatabase = _database;

      if (_sqliteDbPath.isNotEmpty) {
        try {
          logDatabase = await openDatabase(_sqliteDbPath);
        } catch (e) {
          LogManager.e(
              'DatabaseStructureDetectionService', '无法打开本地SQLite数据库读取日志，使用当前连接',
              error: e);
          logDatabase = _database;
        }
      }

      if (logDatabase == null) {
        return [];
      }

      final results = await logDatabase.query(
        'database_structure_logs',
        orderBy: 'detection_time DESC',
        limit: limit,
      );

      final logs = results.map((row) {
        return DatabaseStructureLog.fromMap({
          'id': row['id'],
          'data_source_type': row['data_source_type'],
          'detection_time': row['detection_time'],
          'status': row['status'],
          'required_tables': row['required_tables'],
          'missing_tables': row['missing_tables'],
          'structure_changes': row['structure_changes'],
          'errors': DatabaseTypeConverterHelper.decodeJsonSafely(
              row['errors'] ?? '[]'),
          'details': DatabaseTypeConverterHelper.decodeJsonSafely(
              row['details'] ?? '{}'),
          'summary': row['summary'],
          'created_at': row['created_at'],
        });
      }).toList();

      if (logDatabase != _database) {
        await logDatabase.close();
      }

      return logs;
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '获取数据库结构检测日志失败',
          error: e);
      return [];
    }
  }

  /// 删除数据库结构检测日志
  Future<bool> deleteDatabaseStructureLog(int logId) async {
    try {
      Database? logDatabase = _database;

      if (_sqliteDbPath.isNotEmpty) {
        try {
          logDatabase = await openDatabase(_sqliteDbPath);
        } catch (e) {
          LogManager.e(
              'DatabaseStructureDetectionService', '无法打开本地SQLite数据库删除日志，使用当前连接',
              error: e);
          logDatabase = _database;
        }
      }

      if (logDatabase == null) {
        return false;
      }

      final count = await logDatabase.delete(
        'database_structure_logs',
        where: 'id = ?',
        whereArgs: [logId],
      );

      if (logDatabase != _database) {
        await logDatabase.close();
      }

      return count > 0;
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '删除数据库结构检测日志失败',
          error: e);
      return false;
    }
  }

  /// 清空所有数据库结构检测日志
  Future<bool> clearAllDatabaseStructureLogs() async {
    try {
      Database? logDatabase = _database;

      if (_sqliteDbPath.isNotEmpty) {
        try {
          logDatabase = await openDatabase(_sqliteDbPath);
        } catch (e) {
          LogManager.e(
              'DatabaseStructureDetectionService', '无法打开本地SQLite数据库清空日志，使用当前连接',
              error: e);
          logDatabase = _database;
        }
      }

      if (logDatabase == null) {
        return false;
      }

      await logDatabase.delete('database_structure_logs');

      if (logDatabase != _database) {
        await logDatabase.close();
      }

      return true;
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '清空数据库结构检测日志失败',
          error: e);
      return false;
    }
  }

  /// 保存数据库结构检测日志
  Future<void> saveDatabaseStructureLog(DatabaseStructureLog log) async {
    try {
      Database? logDatabase = _database;

      if (_sqliteDbPath.isNotEmpty) {
        try {
          logDatabase = await openDatabase(_sqliteDbPath);

          await logDatabase.execute('''
            CREATE TABLE IF NOT EXISTS database_structure_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data_source_type TEXT NOT NULL,
              detection_time TEXT NOT NULL,
              status TEXT NOT NULL,
              required_tables INTEGER NOT NULL DEFAULT 0,
              missing_tables INTEGER NOT NULL DEFAULT 0,
              structure_changes INTEGER NOT NULL DEFAULT 0,
              errors TEXT,
              details TEXT,
              summary TEXT,
              created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        } catch (e) {
          LogManager.e(
              'DatabaseStructureDetectionService', '无法打开本地SQLite数据库存储日志，使用当前连接',
              error: e);
          logDatabase = _database;
        }
      }

      if (logDatabase == null) {
        return;
      }

      try {
        final columns = await logDatabase
            .rawQuery('PRAGMA table_info(database_structure_logs)');
        final hasCreatedAt = columns.any((col) => col['name'] == 'created_at');
        if (!hasCreatedAt) {
          await logDatabase.execute(
              'ALTER TABLE database_structure_logs ADD COLUMN created_at TEXT NOT NULL DEFAULT (datetime(\'now\'))');
        }
      } catch (e) {
        LogManager.e('DatabaseStructureDetectionService', '检查/添加created_at列失败',
            error: e);
      }

      await logDatabase.insert('database_structure_logs', {
        'data_source_type': log.dataSourceType,
        'detection_time': DateTimeFormatter.toDbString(log.detectionTime),
        'status': log.status,
        'required_tables': log.requiredTables,
        'missing_tables': log.missingTables,
        'structure_changes': log.structureChanges,
        'errors': log.errors.isEmpty ? '[]' : jsonEncode(log.errors),
        'details': log.details.isEmpty ? '{}' : jsonEncode(log.details),
        'summary': log.summary,
        'created_at': DateTimeFormatter.toDbString(log.createdAt),
      });

      if (logDatabase != _database) {
        await logDatabase.close();
      }
    } catch (e) {
      LogManager.e('DatabaseStructureDetectionService', '保存数据库结构检测日志失败',
          error: e);
    }
  }
}
