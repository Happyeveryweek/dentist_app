# Windows端数据库分离式架构

## 概述

Windows端采用分离式架构来管理MySQL和SQLite两种数据源的表结构定义，确保两种数据库类型的表结构互不干扰，同时保持代码的可维护性和一致性。

## 架构设计

### 核心组件

1. **抽象接口** (`table_schema.dart`)
   - 定义表结构的抽象接口 `TableSchema`
   - 提供数据库类型枚举 `DatabaseType`
   - 实现表结构工厂 `TableSchemaFactory`

2. **MySQL实现** (`mysql_schema.dart`)
   - 实现所有表的MySQL版本表结构
   - 包含字段定义、索引、外键约束等

3. **SQLite实现** (`sqlite_schema.dart`)
   - 实现所有表的SQLite版本表结构
   - 适配SQLite的语法和特性

4. **验证工具** (`schema_validator.dart`)
   - 验证MySQL和SQLite表结构的一致性
   - 生成表结构对比报告

5. **初始化工具** (`database_initializer.dart`)
   - 根据数据源类型生成相应的初始化SQL
   - 验证表结构的完整性

6. **使用示例** (`example_usage.dart`)
   - 展示如何使用分离式架构的各种功能

## 支持的表

| 表名 | 描述 | MySQL支持 | SQLite支持 |
|------|------|-----------|------------|
| `patients` | 患者信息 | ✅ | ✅ |
| `appointments` | 预约信息 | ✅ | ✅ |
| `financial_records` | 财务记录 | ✅ | ✅ |
| `financial_items` | 财务项目 | ✅ | ✅ |
| `materials` | 材料信息 | ✅ | ✅ |
| `material_images` | 材料图片 | ✅ | ✅ |
| `patient_materials` | 患者材料 | ✅ | ✅ |
| `purchase_records` | 采购记录 | ✅ | ✅ |
| `purchase_items` | 采购项目 | ✅ | ✅ |
| `users` | 用户信息 | ✅ | ✅ |
| `dental_treatments` | 牙科治疗 | ✅ | ✅ |
| `dental_charts` | 牙科图表 | ✅ | ✅ |
| `database_structure_logs` | 数据库结构日志 | ✅ | ✅ |

## 使用方法

### 基本用法

```dart
import 'package:windows_app/models/schemas/table_schema.dart';

// 获取MySQL患者表结构
final mysqlSchema = TableSchemaFactory.getSchema('patients', DatabaseType.mysql);
print(mysqlSchema.createTableSql);

// 获取SQLite患者表结构
final sqliteSchema = TableSchemaFactory.getSchema('patients', DatabaseType.sqlite);
print(sqliteSchema.createTableSql);
```

### 表结构验证

```dart
import 'package:windows_app/models/schemas/schema_validator.dart';

// 验证所有表结构的一致性
final results = SchemaValidator.validateSchemas();
print(SchemaValidator.generateSchemaReport());
```

### 数据库初始化

```dart
import 'package:windows_app/models/schemas/database_initializer.dart';

// 获取MySQL初始化SQL
final mysqlSQL = DatabaseInitializer.getMySQLInitializationSQL();

// 获取SQLite初始化SQL
final sqliteSQL = DatabaseInitializer.getSQLiteInitializationSQL();
```

## 架构优势

### 1. 解耦合
- MySQL和SQLite的表结构定义完全分离
- 修改一种数据库类型不会影响另一种

### 2. 可维护性
- 每种数据库类型的表结构都有独立的实现
- 便于单独维护和更新

### 3. 一致性
- 通过工厂模式确保表结构的一致性
- 统一的接口定义便于使用

### 4. 扩展性
- 易于添加新的数据库类型支持
- 便于添加新的表结构

## 字段命名规范

### 数据库字段
- 使用 `snake_case` 命名规范
- 例如：`medical_record_number`, `first_visit_date`

### Dart代码
- 使用 `camelCase` 命名规范
- 例如：`medicalRecordNumber`, `firstVisitDate`

## 类型映射

| MySQL类型 | SQLite类型 | Dart类型 | 说明 |
|-----------|------------|----------|------|
| `int(11)` | `INTEGER` | `int` | 整数类型 |
| `varchar(n)` | `VARCHAR(n)` | `String` | 可变长度字符串 |
| `text` | `TEXT` | `String` | 长文本 |
| `datetime` | `DATETIME` | `DateTime` | 日期时间 |
| `float` | `REAL` | `double` | 浮点数 |
| `decimal(m,n)` | `REAL` | `double` | 精确小数 |
| `longblob` | `BLOB` | `Uint8List` | 二进制数据 |

## 注意事项

1. **字段顺序**：确保MySQL和SQLite版本的字段顺序一致
2. **默认值**：注意两种数据库类型的默认值语法差异
3. **索引语法**：MySQL和SQLite的索引创建语法有所不同
4. **外键约束**：SQLite的外键约束语法与MySQL略有不同

## 测试

运行示例代码来测试分离式架构：

```dart
import 'package:windows_app/models/schemas/example_usage.dart';

void main() {
  ExampleUsage.runAllExamples();
}
```

## 维护指南

### 添加新表
1. 在 `table_schema.dart` 中添加新表的工厂方法
2. 在 `mysql_schema.dart` 中实现MySQL版本
3. 在 `sqlite_schema.dart` 中实现SQLite版本
4. 更新验证器和初始化工具中的表名列表

### 修改现有表
1. 分别修改MySQL和SQLite版本的实现
2. 运行验证器确保一致性
3. 更新相关文档

### 添加新数据库类型
1. 在 `DatabaseType` 枚举中添加新类型
2. 实现新数据库类型的表结构类
3. 更新工厂方法
4. 更新验证器和初始化工具

## 版本历史

- **v1.0.0**: 初始版本，支持MySQL和SQLite
- 包含13个核心表的完整实现
- 提供完整的验证和初始化工具
- 支持表结构一致性检查
