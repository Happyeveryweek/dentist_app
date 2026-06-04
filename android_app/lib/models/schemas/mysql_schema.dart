import 'table_schema.dart';

// ==================== 安卓端 MySQL 表结构实现 ====================

class MySQLPatientsTableSchema implements TableSchema {
  @override
  String get tableName => 'patients';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'medical_record_number': 'int(11) DEFAULT NULL',
    'name': 'varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL',
    'name_pinyin': 'varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'name_initials': 'varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'age': 'int(11) DEFAULT NULL',
    'gender': 'varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL',
    'phone': 'varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'identification_number': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'doctor': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'address': 'varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'address_pinyin': 'varchar(400) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'first_visit_date': 'datetime NOT NULL',
    'dental_condition': 'text COLLATE utf8mb4_unicode_ci',
    'treatment_items': 'mediumtext COLLATE utf8mb4_unicode_ci',
    'total_cost': 'float DEFAULT NULL',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    'medical_history': 'text COLLATE utf8mb4_unicode_ci',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_patients_medical_record ON $tableName (medical_record_number)',
    'CREATE INDEX idx_patients_name ON $tableName (name)',
    'CREATE INDEX idx_patients_name_pinyin ON $tableName (name_pinyin)',
  ];

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC''';
  }
}

class MySQLAppointmentsTableSchema implements TableSchema {
  @override
  String get tableName => 'appointments';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'patient_id': 'int(11) NOT NULL',
    'appointment_date': 'datetime NOT NULL',
    'appointment_time': 'time NOT NULL',
    'status': 'varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT \'scheduled\'',
    'treatment_type': 'text COLLATE utf8mb4_unicode_ci',
    'notes': 'text COLLATE utf8mb4_unicode_ci',
    'cost': 'float DEFAULT NULL',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_patient_id ON $tableName (patient_id)',
    'CREATE INDEX idx_appointment_date ON $tableName (appointment_date)',
    'CREATE INDEX idx_appointment_status ON $tableName (status)',
  ];

  @override
  List<String> get foreignKeyConstraints => [
    'CONSTRAINT appointments_ibfk_1 FOREIGN KEY (patient_id) REFERENCES patients (id)',
  ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');
    
    final constraints = foreignKeyConstraints.join(',\n  ');
    
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns,
  $constraints
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC''';
  }
}

class MySQLFinancialRecordsTableSchema implements TableSchema {
  @override
  String get tableName => 'financial_records';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'patient_id': 'int(11) NOT NULL',
    'notes': 'text',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    'total_quantity': 'int(11) NOT NULL DEFAULT 0',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_patient_id ON $tableName (patient_id)',
  ];

  @override
  List<String> get foreignKeyConstraints => [
    'CONSTRAINT financial_records_ibfk_1 FOREIGN KEY (patient_id) REFERENCES patients (id)',
  ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');
    
    final constraints = foreignKeyConstraints.join(',\n  ');
    
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns,
  $constraints
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4''';
  }
}

class MySQLFinancialItemsTableSchema implements TableSchema {
  @override
  String get tableName => 'financial_items';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'financial_record_id': 'int(11) NOT NULL',
    'item_name': 'varchar(255) NOT NULL',
    'payment_method': 'varchar(20) DEFAULT NULL',
    'item_price': 'decimal(10,2) NOT NULL',
    'quantity': 'int(11) DEFAULT 1',
    'total_price': 'decimal(10,2) NOT NULL',
    'charge_date': 'date NOT NULL',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    'processing_fee': 'decimal(10,2) NOT NULL DEFAULT 0.00',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_financial_record_id ON $tableName (financial_record_id)',
  ];

  @override
  List<String> get foreignKeyConstraints => [
    'CONSTRAINT financial_items_ibfk_1 FOREIGN KEY (financial_record_id) REFERENCES financial_records (id)',
  ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');
    
    final constraints = foreignKeyConstraints.join(',\n  ');
    
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns,
  $constraints
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4''';
  }
}

class MySQLMaterialsTableSchema implements TableSchema {
  @override
  String get tableName => 'materials';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'material_name': 'varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL',
    'material_code': 'varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'material_type': 'varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT \'其他\'',
    'specification': 'text COLLATE utf8mb4_unicode_ci',
    'unit': 'varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT \'个\'',
    'default_price': 'decimal(10,2) NOT NULL DEFAULT 0.00',
    'stock_quantity': 'int(11) NOT NULL DEFAULT 0',
    'min_stock': 'int(11) NOT NULL DEFAULT 0',
    'supplier': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'description': 'text COLLATE utf8mb4_unicode_ci',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_materials_name ON $tableName (material_name)',
    'CREATE INDEX idx_materials_code ON $tableName (material_code)',
    'CREATE INDEX idx_materials_type ON $tableName (material_type)',
  ];

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci''';
  }
}

class MySQLUsersTableSchema implements TableSchema {
  @override
  String get tableName => 'users';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'username': 'varchar(20) NOT NULL',
    'email': 'varchar(120) NOT NULL',
    'doctor': 'text',
    'password': 'text NOT NULL',
    'role': 'varchar(20) NOT NULL',
    'created_at': 'datetime NOT NULL',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    'avatar': 'varchar(50) DEFAULT \'avatar_1\'',
    'image_data': 'longblob',
    'module_permissions': 'JSON',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE UNIQUE INDEX idx_username ON $tableName (username)',
    'CREATE UNIQUE INDEX idx_email ON $tableName (email)',
  ];

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4''';
  }
}

class MySQLMaterialImagesTableSchema implements TableSchema {
  @override
  String get tableName => 'material_images';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'material_id': 'int(11) DEFAULT NULL',
    'image_data': 'longblob NOT NULL',
    'thumbnail_data': 'longblob',
    'image_type': 'varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL',
    'file_size': 'int(11) DEFAULT NULL',
    'thumbnail_size': 'int(11) DEFAULT NULL',
    'original_name': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'created_at': 'varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL',
    'has_thumbnail': 'int(11) DEFAULT NULL',
    'image_path': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_material_id ON $tableName (material_id)',
  ];

  @override
  List<String> get foreignKeyConstraints => [
    'CONSTRAINT material_images_ibfk_1 FOREIGN KEY (material_id) REFERENCES patient_materials (id)',
  ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');
    
    final constraints = foreignKeyConstraints.join(',\n  ');
    
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns,
  $constraints
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci''';
  }
}

class MySQLPatientMaterialsTableSchema implements TableSchema {
  @override
  String get tableName => 'patient_materials';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'patient_id': 'int(11) NOT NULL',
    'description': 'text NOT NULL',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_patient_id ON $tableName (patient_id)',
  ];

  @override
  List<String> get foreignKeyConstraints => [
    'CONSTRAINT patient_materials_ibfk_1 FOREIGN KEY (patient_id) REFERENCES patients (id)',
  ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');
    
    final constraints = foreignKeyConstraints.join(',\n  ');
    
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns,
  $constraints
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4''';
  }
}

class MySQLPurchaseRecordsTableSchema implements TableSchema {
  @override
  String get tableName => 'purchase_records';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'purchase_date': 'date NOT NULL',
    'total_quantity': 'int(11) NOT NULL',
    'total_amount': 'decimal(10,2) NOT NULL',
    'supplier': 'varchar(200) DEFAULT NULL',
    'notes': 'text',
    'doctor': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4''';
  }
}

class MySQLPurchaseItemsTableSchema implements TableSchema {
  @override
  String get tableName => 'purchase_items';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'purchase_record_id': 'int(11) DEFAULT NULL',
    'material_id': 'int(11) DEFAULT NULL',
    'material_name': 'varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL',
    'quantity': 'int(11) DEFAULT NULL',
    'unit_price': 'decimal(10,2) NOT NULL',
    'total_price': 'decimal(10,2) NOT NULL',
    'unit': 'varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'created_at': 'varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL',
    'updated_at': 'varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_purchase_record_id ON $tableName (purchase_record_id)',
  ];

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
) ENGINE=InnoDB AUTO_INCREMENT=34 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci''';
  }
}

class MySQLPatientMedicalRecordsTableSchema implements TableSchema {
  @override
  String get tableName => 'patient_medical_records';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'patient_id': 'int(11) NOT NULL',
    'record_number': 'varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL',
    'record_date': 'datetime NOT NULL',
    'chief_complaint': 'text COLLATE utf8mb4_unicode_ci',
    'present_illness': 'text COLLATE utf8mb4_unicode_ci',
    'past_medical_history': 'text COLLATE utf8mb4_unicode_ci',
    'past_dental_history': 'text COLLATE utf8mb4_unicode_ci',
    'allergy_history': 'text COLLATE utf8mb4_unicode_ci',
    'oral_examination': 'text COLLATE utf8mb4_unicode_ci',
    'diagnosis': 'text COLLATE utf8mb4_unicode_ci',
    'treatment_plan': 'text COLLATE utf8mb4_unicode_ci',
    'notes': 'text COLLATE utf8mb4_unicode_ci',
    'doctor_name': 'varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'created_by_doctor': 'varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'selected_dental_condition_date': 'varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_patient_medical_records_patient_id ON $tableName (patient_id)',
    'CREATE INDEX idx_patient_medical_records_record_number ON $tableName (record_number)',
    'CREATE INDEX idx_patient_medical_records_record_date ON $tableName (record_date)',
    'CREATE INDEX idx_patient_medical_records_doctor ON $tableName (doctor_name)',
  ];

  @override
  List<String> get foreignKeyConstraints => [
    'CONSTRAINT patient_medical_records_ibfk_1 FOREIGN KEY (patient_id) REFERENCES patients (id)',
  ];

  @override
  String get createTableSql {
    final columns = columnDefinitions.entries
        .map((e) => '  ${e.key} ${e.value}')
        .join(',\n');
    
    final constraints = foreignKeyConstraints.join(',\n  ');
    
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  $columns,
  $constraints
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC''';
  }
}

class MySQLMedicalRecordTemplatesTableSchema implements TableSchema {
  @override
  String get tableName => 'medical_record_templates';

  @override
  Map<String, String> get columnDefinitions => {
    'id': 'int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY',
    'category': 'varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL',
    'name': 'varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL',
    'parent_name': 'varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'description': 'text COLLATE utf8mb4_unicode_ci',
    'is_active': 'tinyint(1) DEFAULT 1',
    'sort_order': 'int(11) DEFAULT 0',
    'created_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
  };

  @override
  List<String> get indexDefinitions => [
    'CREATE INDEX idx_medical_record_templates_category ON $tableName (category)',
    'CREATE INDEX idx_medical_record_templates_name ON $tableName (name)',
    'CREATE INDEX idx_medical_record_templates_parent ON $tableName (parent_name)',
    'CREATE INDEX idx_medical_record_templates_active ON $tableName (is_active)',
  ];

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC''';
  }
}

