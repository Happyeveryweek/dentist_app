import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import 'schemas/table_schema.dart';
import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';
import '../utils/map_parser.dart';

// 数据库助手类
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;
  static String? _customDbPath;

  factory DatabaseHelper() => _instance ??= DatabaseHelper._();

  DatabaseHelper._();

  // 设置自定义数据库路径
  static void setCustomDbPath(String dbPath) {
    _customDbPath = dbPath;
    _database = null; // 清除现有数据库实例，以便重新连接
  }

  // 获取数据库路径
  Future<String> getDatabasePath() async {
    if (_customDbPath != null && _customDbPath!.isNotEmpty) {
      // 保存当前路径
      _currentDatabasePath = _customDbPath;
      return _customDbPath!;
    }

    // 使用默认路径
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'dental_clinic.db');
    // 保存当前路径
    _currentDatabasePath = path;
    return path;
  }

  // 获取数据库实例
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      AppLogger.info('返回已存在的数据库实例');
      return _database!;
    }
    AppLogger.info('初始化新的数据库实例');
    _database = await _initDatabase();
    return _database!;
  }

  // 关闭数据库连接
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      AppLogger.info('关闭数据库连接');
      await _database!.close();
      _database = null;
    }
  }

  // 初始化数据库
  Future<Database> _initDatabase() async {
    AppLogger.info('获取数据库路径');
    final dbPath = await getDatabasePath();
    AppLogger.info('打开数据库: $dbPath');
    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _createDb,
      onOpen: _onOpen,
      onUpgrade: _onUpgrade,
    );
  }

  // 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      AppLogger.info('数据库从版本1升级到版本2');
      await _upgradeUsersTable(db);
      await _upgradePatientsTable(db);
    }
  }

  Future<void> _upgradeUsersTable(Database db) async {
    try {
      final result = await db.rawQuery("PRAGMA table_info(users)");
      final columns = result.map((e) => e['name']?.toString() ?? '').toList();

      if (!columns.contains('updated_at')) {
        await db.execute('ALTER TABLE users ADD COLUMN updated_at TEXT');
        AppLogger.info('users表添加updated_at列');
      }

      if (!columns.contains('avatar')) {
        await db.execute(
          "ALTER TABLE users ADD COLUMN avatar TEXT DEFAULT 'avatar_1'",
        );
        AppLogger.info('users表添加avatar列');
      }
    } catch (e) {
      AppLogger.info('升级users表失败: $e');
    }
  }

  Future<void> _upgradePatientsTable(Database db) async {
    try {
      final result = await db.rawQuery("PRAGMA table_info(patients)");
      final columns = result.map((e) => e['name']?.toString() ?? '').toList();

      if (!columns.contains('name_initials')) {
        await db.execute(
          'ALTER TABLE patients ADD COLUMN name_initials VARCHAR(200)',
        );
        AppLogger.info('patients表添加name_initials列');
      }
    } catch (e) {
      AppLogger.info('升级patients表失败: $e');
    }
  }

  // 数据库打开回调
  Future<void> _onOpen(Database db) async {
    try {
      AppLogger.info('数据库已打开，检查必要的表');
      // 检查tables表是否存在，不存在则创建必要的表
      var tableExists = false;

      try {
        // 尝试查询患者表，如果不存在会抛出异常
        await db.rawQuery('SELECT 1 FROM patients LIMIT 1');
        AppLogger.info('患者表已存在');
        tableExists = true;
      } catch (e) {
        AppLogger.info('表不存在，将创建新表: $e');
        tableExists = false;
      }

      // 如果表不存在，则创建表
      if (!tableExists) {
        AppLogger.info('创建必要的数据库表');
        await _createDb(db, 1);
      } else {
        AppLogger.info('所有必要的表已存在');
      }
    } catch (e) {
      AppLogger.info('数据库打开错误: $e');
      rethrow; // 重新抛出异常以便上层处理
    }
  }

  // 创建数据库表
  Future<void> _createDb(Database db, int version) async {
    try {
      // 使用SQLite表结构创建所有表
      final tableNames = [
        'patients',
        'appointments',
        'financial_records',
        'financial_items',
        'materials',
        'purchase_records',
        'purchase_items',
        'patient_materials',
        'material_images',
        'users',
        'patient_medical_records',
        'medical_record_templates',
      ];

      for (final tableName in tableNames) {
        final schema = TableSchemaFactory.getSchema(
          tableName,
          DatabaseType.sqlite,
        );

        // 创建表
        await db.execute(schema.createTableSql);

        // 创建索引
        for (final indexSql in schema.indexDefinitions) {
          await db.execute(indexSql);
        }

        AppLogger.info('成功创建表: ${schema.tableName}');
      }

      // 创建默认管理员用户
      await _createDefaultUser(db);
    } catch (e) {
      AppLogger.info('创建表错误: $e');
    }
  }

  // 创建默认用户
  Future<void> _createDefaultUser(Database db) async {
    try {
      // 检查是否已存在用户
      final existingUsers = await db.query('users', limit: 1);

      if (existingUsers.isEmpty) {
        // 创建默认管理员用户
        final now = DateTime.now();
        final defaultUser = {
          'username': 'admin',
          'email': 'admin@dental.com',
          'password': '123456', // 简单密码，生产环境应该使用加密
          'role': 'admin',
          'doctor': '系统管理员',
          'avatar': 'avatar_1',
          'module_permissions': jsonEncode({
            'patients': true,
            'appointments': true,
            'financial': true,
            'materials': true,
            'purchase': true,
            'reports': true,
            'settings': true,
          }),
          'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        };

        await db.insert('users', defaultUser);
        AppLogger.info('✅ 已创建默认管理员用户: admin/123456');

        // 可选：创建一个普通员工用户作为示例
        final staffUser = {
          'username': 'staff',
          'email': 'staff@dental.com',
          'password': '123456',
          'role': 'staff',
          'doctor': '普通员工',
          'avatar': 'avatar_2',
          'module_permissions': jsonEncode({
            'patients': true,
            'appointments': true,
            'financial': false,
            'materials': true,
            'purchase': false,
            'reports': false,
            'settings': false,
          }),
          'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        };

        await db.insert('users', staffUser);
        AppLogger.info('✅ 已创建默认员工用户: staff/123456');
      } else {
        AppLogger.info('ℹ️ 用户表已存在数据，跳过创建默认用户');
      }
    } catch (e) {
      AppLogger.info('❌ 创建默认用户失败: $e');
    }
  }

  // 获取当前数据库路径
  String? get databasePath {
    return _currentDatabasePath ?? _customDbPath;
  }

  // 存储当前数据库路径
  String? _currentDatabasePath;
}

// 用户模型
class User {
  final int? id;
  final String username;
  final String email;
  final String password;
  final String role;
  final String? doctor;
  final String? avatar;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    this.role = 'staff',
    this.doctor,
    this.avatar = 'avatar_1',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      'doctor': doctor,
      'avatar': avatar,
      'created_at': dateFormat.format(createdAt),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'User');
    return User(
      id: p.optional('id', (v) => v as int),
      username: p.string('username'),
      email: p.string('email'),
      password: p.string('password'),
      role: p.string('role', defaultValue: 'staff'),
      doctor: p.stringOptional('doctor'),
      avatar: p.string('avatar', defaultValue: 'avatar_1'),
      createdAt: p.dateTime('created_at'),
    );
  }
}

// 患者模型
class Patient {
  int? id;
  int? medicalRecordNumber;
  String name;
  String? namePinyin;
  String? nameInitials;
  int age;
  String gender;
  String phone;
  String? address;
  String? addressPinyin;
  String? identificationNumber;
  String? doctor;
  DateTime firstVisitDate;
  String? dentalCondition;
  String? treatmentItems;
  double totalCost;
  DateTime createdAt;
  DateTime updatedAt;

  Patient({
    this.id,
    this.medicalRecordNumber,
    required this.name,
    this.namePinyin,
    this.nameInitials,
    required this.age,
    required this.gender,
    required this.phone,
    this.address,
    this.addressPinyin,
    this.identificationNumber,
    this.doctor,
    DateTime? firstVisitDate,
    this.dentalCondition,
    this.treatmentItems,
    this.totalCost = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : firstVisitDate = firstVisitDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Patient.fromMap(Map<String, dynamic> map) {
    // 减少日志输出，只在调试模式下显示
    // if (kDebugMode) {
    //   AppLogger.info('Patient.fromMap 调用，原始数据: $map');
    // }

    // 处理日期字段 - 使用统一格式
    DateTime dateFromField(dynamic field) {
      if (field == null) return DateTime.now();
      if (field is DateTime) return field;

      try {
        if (field is String) {
          // 只使用统一的标准格式 YYYY-MM-DD HH:MM:SS
          return DateTimeFormatter.fromDbString(field);
        }
        return DateTime.now();
      } catch (e) {
        if (kDebugMode) {
          AppLogger.info('日期解析错误: $e，使用当前日期');
        }
        return DateTime.now();
      }
    }

    // 确保从字段获取正确类型的值
    String getStringField(Map<String, dynamic> map, String key) {
      var value = map[key];
      if (value == null) return '';
      return value.toString();
    }

    int getIntField(
      Map<String, dynamic> map,
      String key, {
      int defaultValue = 0,
    }) {
      var value = map[key];
      if (value == null) return defaultValue;

      if (value is int) return value;

      try {
        return int.parse(value.toString());
      } catch (e) {
        if (kDebugMode) {
          AppLogger.info('转换int字段 $key 错误: $e，使用默认值 $defaultValue');
        }
        return defaultValue;
      }
    }

    double getDoubleField(
      Map<String, dynamic> map,
      String key, {
      double defaultValue = 0.0,
    }) {
      var value = map[key];
      if (value == null) return defaultValue;

      if (value is double) return value;
      if (value is int) return value.toDouble();

      try {
        return double.parse(value.toString());
      } catch (e) {
        if (kDebugMode) {
          AppLogger.info('转换double字段 $key 错误: $e，使用默认值 $defaultValue');
        }
        return defaultValue;
      }
    }

    // 检查主要字段是否有效 - 减少日志输出
    // if (kDebugMode) {
    //   AppLogger.info('检查必要字段:');
    //   AppLogger.info('  id: ${map['id']}');
    //   AppLogger.info('  name: ${map['name']}');
    //   AppLogger.info('  age: ${map['age']}');
    //   AppLogger.info('  gender: ${map['age']}');
    //   AppLogger.info('  phone: ${map['phone']}');
    //   AppLogger.info('  doctor: ${map['doctor']}');
    //   AppLogger.info('  address: ${map['address']}');
    // }

    // 特殊处理年龄字段 - 在某些情况下，年龄字段可能存储在gender或者其他字段中
    int ageValue = 0;
    if (map.containsKey('age') && map['age'] != null) {
      try {
        // 尝试直接从age字段获取
        ageValue = getIntField(map, 'age');
      } catch (e) {
        if (kDebugMode) {
          AppLogger.info('解析年龄字段错误: $e');
        }
      }
    }

    // 如果age为0但gender是数字，可能数据字段错位了
    if (ageValue == 0 && map.containsKey('gender') && map['gender'] != null) {
      var genderValue = map['gender'];
      if (genderValue is int || int.tryParse(genderValue.toString()) != null) {
        try {
          ageValue = getIntField(map, 'gender');
          if (kDebugMode) {
            AppLogger.info('从gender字段中提取年龄值: $ageValue');
          }
        } catch (e) {
          if (kDebugMode) {
            AppLogger.info('从gender提取年龄错误: $e');
          }
        }
      }
    }

    // 特殊处理性别字段
    String genderValue = '未知';
    if (map.containsKey('gender') && map['gender'] != null) {
      var rawGender = map['gender'].toString().toLowerCase();

      // 根据值判断正确的性别
      if (rawGender == 'male' ||
          rawGender == 'm' ||
          rawGender == '男' ||
          rawGender == '1') {
        genderValue = '男';
      } else if (rawGender == 'female' ||
          rawGender == 'f' ||
          rawGender == '女' ||
          rawGender == '0') {
        genderValue = '女';
      } else if (map.containsKey('phone') && map['phone'] != null) {
        // 如果gender不是有效的性别值，检查phone字段是否包含性别信息
        var phoneValue = map['phone'].toString().toLowerCase();
        if (phoneValue == '男' || phoneValue == 'male' || phoneValue == 'm') {
          genderValue = '男';
          if (kDebugMode) {
            AppLogger.info('从phone字段中提取性别: 男');
          }
        } else if (phoneValue == '女' ||
            phoneValue == 'female' ||
            phoneValue == 'f') {
          genderValue = '女';
          if (kDebugMode) {
            AppLogger.info('从phone字段中提取性别: 女');
          }
        }
      }
    }

    // 特殊处理电话字段
    String phoneValue = '';
    if (map.containsKey('phone') && map['phone'] != null) {
      var rawPhone = map['phone'].toString();

      // 检查phone是否实际上包含性别信息
      if (rawPhone == '男' ||
          rawPhone == '女' ||
          rawPhone.toLowerCase() == 'male' ||
          rawPhone.toLowerCase() == 'female') {
        // phone字段存储的是性别信息，尝试从其他字段获取电话
        if (map.containsKey('doctor') && map['doctor'] != null) {
          phoneValue = map['doctor'].toString();
          if (kDebugMode) {
            AppLogger.info('从doctor字段中提取电话: $phoneValue');
          }
        }
      } else {
        // 正常处理电话
        phoneValue = rawPhone;

        // 检查是否为JSON格式
        if (phoneValue.startsWith('[') && phoneValue.endsWith(']')) {
          try {
            var phones = jsonDecode(phoneValue);
            if (phones is List && phones.isNotEmpty) {
              phoneValue = phones.join(',');
            }
          } catch (e) {
            if (kDebugMode) {
              AppLogger.info('解析电话JSON错误: $e');
            }
          }
        }
      }
    }

    // 特殊处理医生字段
    String doctorValue = '';
    if (map.containsKey('doctor') && map['doctor'] != null) {
      doctorValue = map['doctor'].toString();

      // 检查doctor是否可能存储了电话号码
      bool looksLikePhone =
          doctorValue.length > 5 &&
          doctorValue.replaceAll(RegExp(r'[0-9,]'), '').length < 3;

      if (looksLikePhone && phoneValue.isEmpty) {
        // doctor字段可能存储了电话号码，电话字段为空，则交换它们
        phoneValue = doctorValue;
        doctorValue = '';
        if (kDebugMode) {
          AppLogger.info('doctor字段可能存储了电话号码，已调整');
        }
      }
    }

    return Patient(
      id: getIntField(map, 'id'),
      medicalRecordNumber:
          map['medical_record_number'] != null
              ? getIntField(map, 'medical_record_number')
              : null,
      name: getStringField(map, 'name'),
      namePinyin: map['name_pinyin']?.toString(),
      nameInitials: map['name_initials']?.toString(),
      age: ageValue,
      gender: genderValue,
      phone: phoneValue,
      address: map['address']?.toString(),
      addressPinyin: map['address_pinyin']?.toString(),
      identificationNumber: map['identification_number']?.toString(),
      doctor: doctorValue,
      firstVisitDate: dateFromField(map['first_visit_date']),
      dentalCondition: map['dental_condition']?.toString(),
      treatmentItems: map['treatment_items']?.toString(),
      totalCost: getDoubleField(map, 'total_cost'),
      createdAt: dateFromField(map['created_at']),
      updatedAt: dateFromField(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    // 检查是否有多个电话号码
    String phoneValue = phone;
    try {
      // 直接检查电话号码是否已经是有效的JSON格式
      if (phone.startsWith('[') && phone.endsWith(']')) {
        // 尝试解析JSON
        try {
          jsonDecode(phone);
          // 确保是有效的JSON格式，但不要重新编码，直接使用原始字符串
          // 避免重复编码导致格式问题
          phoneValue = phone;
          if (kDebugMode) {
            AppLogger.info('Patient.toMap: 检测到有效的JSON格式电话号码，直接使用');
          }
        } catch (e) {
          if (kDebugMode) {
            AppLogger.info('Patient.toMap: JSON格式无效，需要修复: $e');
          }

          // 特殊处理双重编码情况
          if (phone.contains(r'\"') && phone.contains(r'[\"')) {
            try {
              // 解析外层JSON
              List<dynamic> outerList = jsonDecode(phone);
              List<String> cleanPhones = [];

              // 处理每一项，去除转义字符
              for (var item in outerList) {
                String str = item.toString();
                str =
                    str
                        .replaceAll(r'\"', '')
                        .replaceAll(r'\\', '')
                        .replaceAll(r'[', '')
                        .replaceAll(r']', '')
                        .replaceAll('"', '')
                        .trim();
                if (str.isNotEmpty) {
                  cleanPhones.add(str);
                }
              }

              // 生成正确格式的JSON
              phoneValue = jsonEncode(cleanPhones);
              if (kDebugMode) {
                AppLogger.info('Patient.toMap: 修复了双重编码的电话号码: $phoneValue');
              }
            } catch (e) {
              if (kDebugMode) {
                AppLogger.info('Patient.toMap: 尝试修复双重编码失败: $e');
              }

              // 解析失败，尝试使用正则表达式提取电话号码
              final RegExp phonePattern = RegExp(r'\d+');
              final matches = phonePattern.allMatches(phone);
              List<String> extractedPhones = [];

              for (Match match in matches) {
                String number = match.group(0) ?? '';
                if (number.length >= 3) {
                  // 只保留可能是电话号码的数字串
                  extractedPhones.add(number);
                }
              }

              if (extractedPhones.isNotEmpty) {
                phoneValue = jsonEncode(extractedPhones);
                if (kDebugMode) {
                  AppLogger.info('Patient.toMap: 通过正则表达式提取的电话号码: $phoneValue');
                }
              } else {
                // 无法提取，使用原始值
                phoneValue = phone;
              }
            }
          } else {
            // 其他无效JSON格式的处理
            // 去掉可能的嵌套引号和转义字符
            String cleanedPhone = phone
                .replaceAll("\\\"", '"') // 替换转义的双引号
                .replaceAll("\\\\", "\\") // 替换转义的反斜杠
                .replaceAll("\"[", "[") // 修复格式问题
                .replaceAll("]\"", "]"); // 修复格式问题

            try {
              // 尝试修复后再解析
              final List<dynamic> fixedPhones = jsonDecode(cleanedPhone);
              phoneValue = jsonEncode(fixedPhones);
              if (kDebugMode) {
                AppLogger.info('Patient.toMap: 修复后的JSON格式: $phoneValue');
              }
            } catch (fixError) {
              // 如果仍然失败，回退到简单处理
              if (kDebugMode) {
                AppLogger.info('Patient.toMap: JSON修复失败: $fixError，使用简单分隔');
              }
              // 去除JSON符号，分割后重新编码
              String content = phone
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .replaceAll('"', '')
                  .replaceAll('\\', '');
              List<String> phoneList =
                  content
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
              phoneValue = jsonEncode(phoneList);
              if (kDebugMode) {
                AppLogger.info('Patient.toMap: 手动分割重组后的电话号码: $phoneValue');
              }
            }
          }
        }
      } else if (phone.contains(',')) {
        // 逗号分隔的多个电话号码
        final phones = phone.split(',').map((p) => p.trim()).toList();
        phoneValue = jsonEncode(phones);
        if (kDebugMode) {
          AppLogger.info('Patient.toMap: 多个电话号码已编码为JSON: $phoneValue');
        }
      } else {
        // 单个电话号码 - 不需要JSON编码
        if (kDebugMode) {
          AppLogger.info('Patient.toMap: 单个电话号码: $phone');
        }
      }

      // 最后检查电话数据长度以防止DB错误
      if (phoneValue.length > 255) {
        if (kDebugMode) {
          AppLogger.info('电话号码数据过长(${phoneValue.length}字符)，截断为255字符');
        }
        // 简单截断或者只保留第一个电话号码
        try {
          final List<dynamic> phones = jsonDecode(phoneValue);
          if (phones.isNotEmpty) {
            phoneValue = phones[0].toString();
          } else {
            phoneValue = phoneValue.substring(0, 254);
          }
        } catch (e) {
          phoneValue = phoneValue.substring(0, 254);
        }
        if (kDebugMode) {
          AppLogger.info('截断后的电话号码: $phoneValue');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.info('处理电话号码错误: $e');
      }
    }

    // 创建包含所有字段的Map
    return {
      'id': id,
      'medical_record_number': medicalRecordNumber,
      'name': name,
      'name_pinyin': namePinyin,
      'age': age,
      'gender': gender,
      'phone': phoneValue,
      'address': address,
      'address_pinyin': addressPinyin,
      'identification_number': identificationNumber,
      'doctor': doctor,
      'first_visit_date': DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(firstVisitDate),
      'dental_condition': dentalCondition,
      'treatment_items': treatmentItems,
      'total_cost': totalCost,
      'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt),
      'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(updatedAt),
    };
  }

  String get originalPhone => phone;

  // 允许修改电话号码
  set phoneNumber(String newPhone) {
    phone = newPhone;
  }

  // 创建包含给定电话号码的新患者对象
  Patient copyWithPhone(String newPhone) {
    return Patient(
      id: id,
      medicalRecordNumber: medicalRecordNumber,
      name: name,
      namePinyin: namePinyin,
      nameInitials: nameInitials,
      age: age,
      gender: gender,
      phone: newPhone,
      address: address,
      addressPinyin: addressPinyin,
      identificationNumber: identificationNumber,
      doctor: doctor,
      firstVisitDate: firstVisitDate,
      dentalCondition: dentalCondition,
      treatmentItems: treatmentItems,
      totalCost: totalCost,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // 将电话号码转换为JSON格式
  Patient withPhoneAsJson() {
    if (phone.contains(',') && !phone.startsWith('[')) {
      List<String> phones =
          phone
              .split(',')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
      if (phones.length > 1) {
        String jsonPhone = jsonEncode(phones);
        return copyWithPhone(jsonPhone);
      }
    }
    return this;
  }

  // 添加调试方法，输出电话号码格式信息
  void debugPhoneFormat() {
    if (kDebugMode) {
      AppLogger.info('Patient.debugPhoneFormat: $phone (${phone.runtimeType})');
      if (phone.startsWith('[') && phone.endsWith(']')) {
        AppLogger.info('Patient.debugPhoneFormat: JSON格式');
      } else if (phone.contains(',')) {
        AppLogger.info('Patient.debugPhoneFormat: 逗号分隔格式');
      } else {
        AppLogger.info('Patient.debugPhoneFormat: 单个电话号码格式');
      }
    }
  }
}

// 预约模型
class Appointment {
  int? id;
  int patientId;
  DateTime appointmentDate;
  String status;
  String? treatmentType;
  String? notes;
  double cost; // 本次预约费用
  DateTime createdAt;
  DateTime updatedAt;

  // 非数据库字段，用于UI显示
  String? patientName;

  Appointment({
    this.id,
    required this.patientId,
    required this.appointmentDate,
    this.status = 'scheduled',
    this.treatmentType,
    this.notes,
    this.cost = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.patientName,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Appointment.fromMap(Map<String, dynamic> map) {
    // 通用的日期解析辅助函数 - 使用统一格式
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        // 只使用统一的标准格式 YYYY-MM-DD HH:MM:SS
        return DateTimeFormatter.fromDbString(value);
      }
      AppLogger.info('不支持的日期类型: ${value.runtimeType}，值: $value');
      return DateTime.now();
    }

    return Appointment(
      id: map['id'],
      patientId: map['patient_id'],
      appointmentDate: parseDateTime(map['appointment_date']),
      status: map['status'] ?? '已预约',
      treatmentType: map['treatment_type'],
      notes: map['notes'],
      cost:
          map['cost'] != null
              ? (map['cost'] is int ? map['cost'].toDouble() : map['cost'])
              : 0.0,
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
      patientName: map['patient_name'],
    );
  }

  Map<String, dynamic> toMap() {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return {
      'id': id,
      'patient_id': patientId,
      'appointment_date': dateFormat.format(appointmentDate),
      'status': status,
      'treatment_type': treatmentType,
      'notes': notes,
      'cost': cost,
      'created_at': dateFormat.format(createdAt),
      'updated_at': dateFormat.format(updatedAt),
    };
  }

  // 添加copyWith方法
  Appointment copyWith({
    int? id,
    int? patientId,
    DateTime? appointmentDate,
    String? status,
    String? treatmentType,
    String? notes,
    double? cost,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      status: status ?? this.status,
      treatmentType: treatmentType ?? this.treatmentType,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      patientName: patientName ?? this.patientName,
    );
  }
}
