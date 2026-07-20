import 'table_schema.dart';

// ==================== Windows端 SQLite 表结构实现 ====================

class SQLitePatientsTableSchema implements TableSchema {
  @override
  String get tableName => 'patients';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'medical_record_number': 'INTEGER',
        'name': 'VARCHAR(100) NOT NULL',
        'name_pinyin': 'VARCHAR(200)',
        'name_initials': 'VARCHAR(200)',
        'age': 'INTEGER',
        'gender': 'VARCHAR(10) NOT NULL',
        'phone': 'VARCHAR(100)',
        'identification_number': 'VARCHAR(100)',
        'doctor': 'VARCHAR(100)',
        'address': 'VARCHAR(500)',
        'address_pinyin': 'VARCHAR(400)',
        'first_visit_date': 'TEXT NOT NULL',
        'dental_condition': 'TEXT',
        'treatment_items': 'TEXT',
        'total_cost': 'FLOAT',
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
        'medical_history': 'TEXT',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    final indexes = indexDefinitions.isNotEmpty
        ? ',\n  ${indexDefinitions.join(',\n  ')}'
        : '';

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns$indexes
)''';
  }
}

class SQLiteAppointmentsTableSchema implements TableSchema {
  @override
  String get tableName => 'appointments';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'patient_id': 'INTEGER NOT NULL',
        'appointment_date': 'TEXT NOT NULL',
        'status': 'VARCHAR(20) NOT NULL',
        'treatment_type': 'VARCHAR(100)',
        'notes': 'TEXT',
        'cost': 'FLOAT',
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
        'appointment_time': 'TEXT NOT NULL DEFAULT "00:00:00"',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [
        'FOREIGN KEY(patient_id) REFERENCES patients (id)',
      ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    final parts = <String>[columns];

    if (indexDefinitions.isNotEmpty) {
      parts.add(indexDefinitions.join(',\n  '));
    }

    if (foreignKeyConstraints.isNotEmpty) {
      parts.add(foreignKeyConstraints.join(',\n  '));
    }

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
${parts.join(',\n')}
)''';
  }
}

class SQLiteFinancialRecordsTableSchema implements TableSchema {
  @override
  String get tableName => 'financial_records';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'patient_id': 'INTEGER NOT NULL',
        'notes': 'TEXT',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'updated_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'total_quantity': 'INTEGER NOT NULL DEFAULT 0',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}

class SQLiteFinancialItemsTableSchema implements TableSchema {
  @override
  String get tableName => 'financial_items';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'financial_record_id': 'INTEGER NOT NULL',
        'item_name': 'TEXT NOT NULL',
        'item_price': 'REAL NOT NULL',
        'quantity': 'INTEGER NOT NULL DEFAULT 1',
        'total_price': 'REAL NOT NULL',
        'charge_date': 'TEXT NOT NULL',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'updated_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'processing_fee': 'REAL NOT NULL DEFAULT 0.0',
        'payment_method': 'TEXT',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [
        'FOREIGN KEY (financial_record_id) REFERENCES financial_records (id) ON DELETE CASCADE',
      ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    final parts = <String>[columns];

    if (indexDefinitions.isNotEmpty) {
      parts.add(indexDefinitions.join(',\n  '));
    }

    if (foreignKeyConstraints.isNotEmpty) {
      parts.add(foreignKeyConstraints.join(',\n  '));
    }

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
${parts.join(',\n')}
)''';
  }
}

class SQLiteMaterialsTableSchema implements TableSchema {
  @override
  String get tableName => 'materials';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'material_name': 'TEXT NOT NULL',
        'material_code': 'TEXT',
        'material_type': 'TEXT NOT NULL DEFAULT \'其他\'',
        'specification': 'TEXT',
        'unit': 'TEXT DEFAULT \'个\'',
        'default_price': 'REAL NOT NULL DEFAULT 0.0',
        'stock_quantity': 'INTEGER NOT NULL DEFAULT 0',
        'min_stock': 'INTEGER NOT NULL DEFAULT 0',
        'supplier': 'TEXT',
        'description': 'TEXT',
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}

class SQLiteMaterialImagesTableSchema implements TableSchema {
  @override
  String get tableName => 'material_images';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'material_id': 'INTEGER NOT NULL',
        'image_data': 'BLOB NOT NULL',
        'thumbnail_data': 'BLOB',
        'image_type': 'TEXT NOT NULL',
        'file_size': 'INTEGER NOT NULL',
        'thumbnail_size': 'INTEGER',
        'original_name': 'TEXT',
        'image_path': 'TEXT',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'has_thumbnail': 'INTEGER NOT NULL DEFAULT 0',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}

class SQLitePatientMaterialsTableSchema implements TableSchema {
  @override
  String get tableName => 'patient_materials';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'patient_id': 'INTEGER NOT NULL',
        'description': 'TEXT NOT NULL',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'updated_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}

class SQLitePurchaseRecordsTableSchema implements TableSchema {
  @override
  String get tableName => 'purchase_records';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'purchase_date': 'TEXT NOT NULL',
        'total_quantity': 'INTEGER NOT NULL',
        'total_amount': 'REAL NOT NULL',
        'supplier': 'TEXT',
        'doctor': 'TEXT',
        'notes': 'TEXT',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'updated_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}

class SQLitePurchaseItemsTableSchema implements TableSchema {
  @override
  String get tableName => 'purchase_items';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'purchase_record_id': 'INTEGER NOT NULL',
        'material_id': 'INTEGER',
        'material_name': 'TEXT NOT NULL',
        'quantity': 'INTEGER NOT NULL DEFAULT 1',
        'unit_price': 'REAL NOT NULL DEFAULT 0.0',
        'total_price': 'REAL NOT NULL DEFAULT 0.0',
        'unit': 'TEXT DEFAULT \'个\'',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
        'updated_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}

class SQLiteUsersTableSchema implements TableSchema {
  @override
  String get tableName => 'users';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'username': 'VARCHAR(20) NOT NULL UNIQUE',
        'email': 'VARCHAR(120) NOT NULL UNIQUE',
        'doctor': 'TEXT',
        'password': 'TEXT NOT NULL',
        'role': 'VARCHAR(20) NOT NULL',
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
        'avatar': 'TEXT DEFAULT \'avatar_1\'',
        'module_permissions': 'TEXT',
        'image_data': 'BLOB',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    final parts = <String>[columns];

    if (indexDefinitions.isNotEmpty) {
      parts.add(indexDefinitions.join(',\n  '));
    }

    if (foreignKeyConstraints.isNotEmpty) {
      parts.add(foreignKeyConstraints.join(',\n  '));
    }

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
${parts.join(',\n')}
)''';
  }
}

class SQLitePatientMedicalRecordsTableSchema implements TableSchema {
  @override
  String get tableName => 'patient_medical_records';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'patient_id': 'INTEGER NOT NULL',
        'record_number': 'VARCHAR(50) NOT NULL',
        'record_date': 'TEXT NOT NULL',
        'chief_complaint': 'TEXT',
        'present_illness': 'TEXT',
        'past_medical_history': 'TEXT',
        'past_dental_history': 'TEXT',
        'allergy_history': 'TEXT',
        'oral_examination': 'TEXT',
        'diagnosis': 'TEXT',
        'treatment_plan': 'TEXT',
        'notes': 'TEXT',
        'doctor_name': 'VARCHAR(100)',
        'created_by_doctor': 'VARCHAR(100)',
        'selected_dental_condition_date': 'TEXT',
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [
        'FOREIGN KEY (patient_id) REFERENCES patients(id)',
      ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    final parts = <String>[columns];

    if (indexDefinitions.isNotEmpty) {
      parts.add(indexDefinitions.join(',\n  '));
    }

    if (foreignKeyConstraints.isNotEmpty) {
      parts.add(foreignKeyConstraints.join(',\n  '));
    }

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
${parts.join(',\n')}
)''';
  }
}

class SQLiteMedicalRecordTemplatesTableSchema implements TableSchema {
  @override
  String get tableName => 'medical_record_templates';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'category': 'VARCHAR(50) NOT NULL',
        'name': 'VARCHAR(100) NOT NULL',
        'parent_name': 'VARCHAR(100)',
        'description': 'TEXT',
        'is_active': 'INTEGER NOT NULL DEFAULT 1',
        'sort_order': 'INTEGER NOT NULL DEFAULT 0',
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    final parts = <String>[columns];

    if (indexDefinitions.isNotEmpty) {
      parts.add(indexDefinitions.join(',\n  '));
    }

    if (foreignKeyConstraints.isNotEmpty) {
      parts.add(foreignKeyConstraints.join(',\n  '));
    }

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
${parts.join(',\n')}
)''';
  }
}

class SQLiteBackupLogsTableSchema implements TableSchema {
  @override
  String get tableName => 'database_structure_logs';

  @override
  Map<String, String> get columnDefinitions => {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'data_source_type': 'TEXT NOT NULL',
        'detection_time': 'TEXT NOT NULL',
        'status': 'TEXT NOT NULL',
        'required_tables': 'INTEGER NOT NULL',
        'missing_tables': 'INTEGER NOT NULL',
        'structure_changes': 'INTEGER NOT NULL',
        'errors': 'TEXT DEFAULT NULL',
        'details': 'TEXT DEFAULT NULL',
        'summary': 'TEXT NOT NULL',
        'created_at': 'TEXT NOT NULL DEFAULT (datetime(\'now\'))',
      };

  @override
  List<String> get indexDefinitions => [];

  @override
  List<String> get foreignKeyConstraints => [];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');

    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns
)''';
  }
}
