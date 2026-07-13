import 'package:dentist_app_windows/providers/database_provider.dart';
import 'package:dentist_app_windows/services/module_mysql_connection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysql1/mysql1.dart';

class _FakeMySqlConnection implements MySqlConnection {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDatabaseProvider implements DatabaseProvider {
  MySqlConnection? connection;
  Future<void> Function()? onInitialize;
  int initializeCount = 0;
  bool throwWhenReadingConnection = false;

  @override
  MySqlConnection? get mysqlConnection {
    if (throwWhenReadingConnection) {
      throw Exception('无法读取最新连接');
    }
    return connection;
  }

  @override
  Future<void> initializeMySQL() async {
    initializeCount++;
    await onInitialize?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MySqlConnection? cachedConnection;
  late String dataSourceType;
  late _FakeDatabaseProvider? databaseProvider;
  late bool probeSucceeds;
  late List<MySqlConnection?> cacheUpdates;

  ModuleMysqlConnectionService createService() {
    return ModuleMysqlConnectionService(
      logTag: 'ModuleMysqlConnectionServiceTest',
      getDatabaseProvider: () => databaseProvider,
      getCachedConnection: () => cachedConnection,
      setCachedConnection: (connection) {
        cachedConnection = connection;
        cacheUpdates.add(connection);
      },
      getEffectiveDataSourceType: () => dataSourceType,
      probeConnection: (_, __, ___) async {
        if (!probeSucceeds) {
          throw Exception('连接不可用');
        }
      },
    );
  }

  setUp(() {
    cachedConnection = _FakeMySqlConnection();
    dataSourceType = 'mysql';
    databaseProvider = _FakeDatabaseProvider();
    probeSucceeds = true;
    cacheUpdates = [];
  });

  test('当前数据源不是 MySQL 时返回缓存连接', () async {
    dataSourceType = 'sqlite';
    final originalCache = cachedConnection;

    final result = await createService().getCurrentConnection();

    expect(result, same(originalCache));
    expect(cacheUpdates, isEmpty);
  });

  test('DatabaseProvider 不存在时返回缓存连接', () async {
    databaseProvider = null;
    final originalCache = cachedConnection;

    final result = await createService().getCurrentConnection();

    expect(result, same(originalCache));
    expect(cacheUpdates, isEmpty);
  });

  test('最新连接可用时更新缓存', () async {
    final latestConnection = _FakeMySqlConnection();
    databaseProvider?.connection = latestConnection;

    final result = await createService().getCurrentConnection();

    expect(result, same(latestConnection));
    expect(cachedConnection, same(latestConnection));
    expect(cacheUpdates, [same(latestConnection)]);
  });

  test('最新连接失效时重新初始化并更新缓存', () async {
    final newConnection = _FakeMySqlConnection();
    databaseProvider
      ?..connection = _FakeMySqlConnection()
      ..onInitialize = () async {
        databaseProvider?.connection = newConnection;
      };
    probeSucceeds = false;

    final result = await createService().getCurrentConnection();

    expect(databaseProvider?.initializeCount, 1);
    expect(result, same(newConnection));
    expect(cachedConnection, same(newConnection));
  });

  test('测试连接失败时清空缓存', () async {
    dataSourceType = 'sqlite';
    probeSucceeds = false;

    final result = await createService().testCurrentConnection();

    expect(result, isFalse);
    expect(cachedConnection, isNull);
    expect(cacheUpdates, [isNull]);
  });

  test('同步连接优先使用 DatabaseProvider 最新连接', () {
    final latestConnection = _FakeMySqlConnection();
    databaseProvider?.connection = latestConnection;

    final result = createService().getSyncConnection();

    expect(result, same(latestConnection));
    expect(cachedConnection, same(latestConnection));
  });

  test('同步连接读取最新连接失败时降级使用缓存', () {
    final originalCache = cachedConnection;
    databaseProvider?.throwWhenReadingConnection = true;

    final result = createService().getSyncConnection();

    expect(result, same(originalCache));
    expect(cachedConnection, same(originalCache));
  });
}
