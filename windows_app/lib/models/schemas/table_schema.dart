import 'mysql_schema.dart';
import 'sqlite_schema.dart';

// Windows端抽象表结构接口
abstract class TableSchema {
  /// 获取创建表的SQL语句
  String get createTableSql;
  
  /// 获取表名
  String get tableName;
  
  /// 获取表的字段定义映射
  Map<String, String> get columnDefinitions;
  
  /// 获取表的索引定义
  List<String> get indexDefinitions;
  
  /// 获取表的外键约束
  List<String> get foreignKeyConstraints;
}

// 表结构类型枚举
enum DatabaseType {
  mysql,
  sqlite,
}

// 表结构工厂
class TableSchemaFactory {
  static TableSchema getSchema(String tableName, DatabaseType databaseType) {
    switch (tableName) {
      case 'patients':
        return databaseType == DatabaseType.mysql 
            ? MySQLPatientsTableSchema() 
            : SQLitePatientsTableSchema();
      case 'appointments':
        return databaseType == DatabaseType.mysql 
            ? MySQLAppointmentsTableSchema() 
            : SQLiteAppointmentsTableSchema();
      case 'financial_records':
        return databaseType == DatabaseType.mysql 
            ? MySQLFinancialRecordsTableSchema() 
            : SQLiteFinancialRecordsTableSchema();
      case 'financial_items':
        return databaseType == DatabaseType.mysql 
            ? MySQLFinancialItemsTableSchema() 
            : SQLiteFinancialItemsTableSchema();
      case 'materials':
        return databaseType == DatabaseType.mysql 
            ? MySQLMaterialsTableSchema() 
            : SQLiteMaterialsTableSchema();
      case 'material_images':
        return databaseType == DatabaseType.mysql 
            ? MySQLMaterialImagesTableSchema() 
            : SQLiteMaterialImagesTableSchema();
      case 'patient_materials':
        return databaseType == DatabaseType.mysql 
            ? MySQLPatientMaterialsTableSchema() 
            : SQLitePatientMaterialsTableSchema();
      case 'purchase_records':
        return databaseType == DatabaseType.mysql 
            ? MySQLPurchaseRecordsTableSchema() 
            : SQLitePurchaseRecordsTableSchema();
      case 'purchase_items':
        return databaseType == DatabaseType.mysql 
            ? MySQLPurchaseItemsTableSchema() 
            : SQLitePurchaseItemsTableSchema();
      case 'users':
        return databaseType == DatabaseType.mysql 
            ? MySQLUsersTableSchema() 
            : SQLiteUsersTableSchema();

      case 'patient_medical_records':
        return databaseType == DatabaseType.mysql 
            ? MySQLPatientMedicalRecordsTableSchema() 
            : SQLitePatientMedicalRecordsTableSchema();

      case 'medical_record_templates':
        return databaseType == DatabaseType.mysql 
            ? MySQLMedicalRecordTemplatesTableSchema() 
            : SQLiteMedicalRecordTemplatesTableSchema();
      case 'database_structure_logs':
        return databaseType == DatabaseType.mysql 
            ? MySQLBackupLogsTableSchema() 
            : SQLiteBackupLogsTableSchema();
      default:
        throw Exception('未知的表名: $tableName');
    }
  }
}
