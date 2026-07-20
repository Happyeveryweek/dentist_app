import 'package:dentist_app/models/schemas/table_schema.dart';
import 'package:dentist_app/models/schemas/sqlite_schema.dart';

/// 同步表配置管理
class SyncTableConfig {
  /// 所有需要同步的表名列表
  static const List<String> syncTableNames = [
    'users',
    'patients',
    'appointments',
    'purchase_records',
    'purchase_items',
    'financial_records',
    'financial_items',
    'materials',
    'patient_materials',
    'material_images',
    'patient_medical_records',
    'medical_record_templates',
  ];

  static void validate(List<String> tableNames) {
    if (tableNames.isEmpty) {
      throw const FormatException('至少选择一个同步表');
    }
    final unsupported = tableNames.toSet().difference(syncTableNames.toSet());
    if (unsupported.isNotEmpty) {
      throw FormatException('包含不支持的同步表: ${unsupported.join(', ')}');
    }
    if (tableNames.length != tableNames.toSet().length) {
      throw const FormatException('同步表不能重复');
    }
  }

  static List<String> insertionOrder(List<String> tableNames) {
    validate(tableNames);
    final selected = tableNames.toSet();
    return syncTableNames.where(selected.contains).toList();
  }

  static List<String> deletionOrder(List<String> tableNames) {
    return insertionOrder(tableNames).reversed.toList();
  }

  /// 获取所有需要同步的表及其SQLite结构
  static Map<String, TableSchema> getSyncTables() {
    return {
      'users': SQLiteUsersTableSchema(),
      'patients': SQLitePatientsTableSchema(),
      'appointments': SQLiteAppointmentsTableSchema(),
      'financial_records': SQLiteFinancialRecordsTableSchema(),
      'financial_items': SQLiteFinancialItemsTableSchema(),
      'materials': SQLiteMaterialsTableSchema(),
      'material_images': SQLiteMaterialImagesTableSchema(),
      'patient_materials': SQLitePatientMaterialsTableSchema(),
      'purchase_records': SQLitePurchaseRecordsTableSchema(),
      'purchase_items': SQLitePurchaseItemsTableSchema(),
      'patient_medical_records': SQLitePatientMedicalRecordsTableSchema(),
      'medical_record_templates': SQLiteMedicalRecordTemplatesTableSchema(),
    };
  }
}
