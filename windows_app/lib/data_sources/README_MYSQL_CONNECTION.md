# MySQL连接管理统一方案

## 概述

为了解决MySQL连接长时间空闲后失效（bad socket错误）的问题，我们实现了统一的连接管理方案。

## 核心组件

### 1. MySqlConnectionManager（连接管理器）
位置：`lib/utils/mysql_connection_manager.dart`

**功能：**
- 自动验证连接有效性
- 连接失效时自动重连
- 智能缓存机制（30秒内不重复验证）
- 统一的错误处理

**使用方式：**
```dart
final manager = MySqlConnectionManager(
  connectionProvider: () async => databaseProvider.mysqlConnection,
  reconnectCallback: () async => await databaseProvider.initializeMySQL(),
);

// 获取有效连接
final connection = await manager.getConnection();
```

### 2. BaseMySqlDataSource（MySQL数据源基类）
位置：`lib/data_sources/base_mysql_data_source.dart`

**功能：**
- 封装连接管理逻辑
- 提供自动重试机制
- 统一的数据类型转换
- 辅助方法（convertRowToMap、safeGetInt等）

**使用方式：**
```dart
class MyDataSource extends BaseMySqlDataSource implements DataSourceInterface {
  MyDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );
  
  @override
  Future<List<MyModel>> getAllRecords() async {
    // 使用 executeQuery 替代直接的 connection.query
    final result = await executeQuery('SELECT * FROM my_table');
    
    return result.map((row) {
      // 使用 convertRowToMap 处理数据类型转换
      final map = convertRowToMap(row);
      return MyModel.fromMap(map);
    }).toList();
  }
}
```

## 工作流程

```
用户操作
    ↓
Provider调用数据源方法
    ↓
executeQuery()
    ↓
获取连接（通过ConnectionManager）
    ↓
检查缓存 → 是否最近验证过？
    ↓ 否
验证连接（SELECT 1）
    ↓
连接有效？
    ↙     ↘
  是       否
  ↓        ↓
使用连接  调用reconnectCallback
          ↓
      重新获取连接
          ↓
      再次验证
          ↓
      执行查询
```

## 已集成的模块

### ✅ 财务管理（FinancialProvider）
- 数据源：`MySqlFinancialDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

### ✅ 采购管理（PurchaseProvider）
- 数据源：`MySqlPurchaseDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

### ✅ 患者管理（PatientProvider）
- 数据源：`MySqlPatientDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

### ✅ 用户管理（UserProvider）
- 数据源：`MySqlUserDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

### ✅ 材料管理（MaterialProvider）
- 数据源：`MySqlMaterialDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

### ✅ 预约管理（AppointmentProvider）
- 数据源：`MySqlAppointmentDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

### ✅ 病历管理（MedicalRecordProvider）
- 数据源：`MySqlMedicalRecordDataSource`
- 自动连接验证和重连
- 所有查询操作都经过连接管理器

## 如何为新模块集成

### 步骤1：创建数据源类
```dart
import 'base_mysql_data_source.dart';

class MySqlMyModuleDataSource extends BaseMySqlDataSource implements MyModuleDataSource {
  MySqlMyModuleDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );
  
  // 实现接口方法...
}
```

### 步骤2：在Provider中初始化
```dart
void setMySqlDataSource(MySqlConnection connection) {
  _mysqlConnection = connection;
  _mysqlDataSource = MySqlMyModuleDataSource.withConnectionGetter(
    () async {
      final conn = await _currentMysqlConnection;
      return conn;
    },
    reconnectCallback: () async {
      if (_databaseProvider != null) {
        try {
          await _databaseProvider.initializeMySQL();
          print('✅ MyModuleProvider: MySQL重连成功');
        } catch (e) {
          print('❌ MyModuleProvider: MySQL重连失败: $e');
        }
      }
    },
  );
}
```

### 步骤3：使用executeQuery执行查询
```dart
@override
Future<List<MyModel>> getRecords() async {
  // 不要直接使用 connection.query
  // 使用 executeQuery，它会自动处理连接验证和重试
  final result = await executeQuery('SELECT * FROM my_table');
  
  return result.map((row) {
    final map = convertRowToMap(row);
    return MyModel.fromMap(map);
  }).toList();
}
```

## 关键特性

### 1. 自动重试
如果查询失败且是连接错误，会自动清除缓存并重试一次：
```dart
try {
  return await conn.query(sql, values);
} on MySqlException catch (e) {
  if (_isConnectionError(e)) {
    _connectionManager.clearCache();
    // 重试
    final conn = await connection;
    return await conn.query(sql, values);
  }
  rethrow;
}
```

### 2. 智能缓存
30秒内不会重复验证同一个连接，减少不必要的网络开销：
```dart
bool _isRecentlyValidated() {
  if (_lastValidationTime == null) return false;
  final elapsed = DateTime.now().difference(_lastValidationTime!);
  return elapsed < Duration(seconds: 30);
}
```

### 3. 连接错误检测
自动识别常见的连接错误：
```dart
bool _isConnectionError(MySqlException e) {
  final errorMessage = e.message.toLowerCase();
  return errorMessage.contains('socket') ||
         errorMessage.contains('connection') ||
         errorMessage.contains('closed') ||
         errorMessage.contains('timeout') ||
         errorMessage.contains('broken pipe');
}
```

## 调试和监控

### 获取连接状态
```dart
final status = dataSource.getConnectionStatus();
print('连接状态: $status');
// 输出: {hasConnection: true, lastValidation: 2024-01-01T12:00:00, isRecentlyValidated: true}
```

### 强制验证连接
```dart
final isValid = await dataSource.validateConnection();
if (!isValid) {
  print('连接无效，需要重连');
}
```

### 清除连接缓存
```dart
dataSource.clearConnectionCache();
// 下次查询时会重新获取和验证连接
```

## 性能优化建议

1. **调整验证间隔**：根据实际情况修改 `_validationInterval`（默认30秒）
2. **调整验证超时**：根据网络情况修改 `_validationTimeout`（默认3秒）
3. **MySQL服务器配置**：增加 `wait_timeout` 和 `interactive_timeout`

```sql
-- 在MySQL配置文件中设置
SET GLOBAL wait_timeout = 28800;
SET GLOBAL interactive_timeout = 28800;
```

## 常见问题

### Q: 为什么还是出现连接错误？
A: 检查以下几点：
1. DatabaseProvider的initializeMySQL方法是否正确实现
2. reconnectCallback是否正确配置
3. MySQL服务器是否正常运行
4. 网络连接是否稳定

### Q: 如何禁用自动重连？
A: 不传递reconnectCallback参数：
```dart
MySqlMyDataSource.withConnectionGetter(
  () async => connection,
  // 不传递 reconnectCallback
);
```

### Q: 如何调整验证频率？
A: 修改 `MySqlConnectionManager` 中的 `_validationInterval` 常量。

## 迁移指南

### 从旧代码迁移到新方案

**旧代码：**
```dart
class MySqlDataSource implements DataSource {
  final MySqlConnection Function() _getConnection;
  
  Future<List<Model>> getAll() async {
    final conn = _getConnection();
    final result = await conn.query('SELECT * FROM table');
    return result.map((row) => Model.fromMap(row.fields)).toList();
  }
}
```

**新代码：**
```dart
class MySqlDataSource extends BaseMySqlDataSource implements DataSource {
  MySqlDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );
  
  Future<List<Model>> getAll() async {
    final result = await executeQuery('SELECT * FROM table');
    return result.map((row) {
      final map = convertRowToMap(row);
      return Model.fromMap(map);
    }).toList();
  }
}
```

## 总结

这个统一方案解决了以下问题：
- ✅ 长时间空闲后的连接失效
- ✅ 重复的连接验证代码
- ✅ 不一致的错误处理
- ✅ 数据类型转换的重复代码
- ✅ 缺乏自动重连机制

所有使用MySQL的模块都应该采用这个方案，确保系统的稳定性和可维护性。
