import 'dart:convert';
import 'package:mysql1/mysql1.dart';
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';
import '../utils/map_parser.dart';

// 患者模型
class Patient {
  final int? id;
  final String name;
  final String? namePinyin; // 姓名拼音
  final String? nameInitials; // 姓名首字母缩写
  final int age;
  final String gender;
  final dynamic phone; // 可以是字符串或JSON数组字符串
  final int? medicalRecordNumber;
  final String? address;
  final String? addressPinyin; // 地址拼音
  final String? identificationNumber;
  final String? doctor;
  final String? dentalCondition; // JSON字符串格式
  final String? treatmentItems;
  final DateTime firstVisitDate;
  final double totalCost;
  final String? medicalHistory; // 病史信息
  final DateTime createdAt; // 添加创建时间字段
  final DateTime updatedAt; // 添加更新时间字段

  Patient({
    this.id,
    required this.name,
    this.namePinyin,
    this.nameInitials,
    required this.age,
    required this.gender,
    required this.phone,
    this.medicalRecordNumber,
    this.address,
    this.addressPinyin,
    this.identificationNumber,
    this.doctor,
    this.dentalCondition,
    this.treatmentItems,
    required this.firstVisitDate,
    this.totalCost = 0.0,
    this.medicalHistory, // 病史信息
    DateTime? createdAt, // 添加创建时间参数
    DateTime? updatedAt, // 添加更新时间参数
  })  : createdAt = createdAt ?? DateTime.now(), // 如果未提供，则使用当前时间
        updatedAt = updatedAt ?? DateTime.now(); // 如果未提供，则使用当前时间

  // 安全转换字符串，处理BLOB类型
  static String? _safeStringFromField(dynamic field) {
    if (field == null) return null;
    if (field is String) return field;
    if (field is Blob) {
      try {
        return String.fromCharCodes(field.toBytes());
      } catch (e) {
        LogManager.e('Patient', 'Blob转换失败', error: e);
        return '';
      }
    }
    try {
      return field.toString();
    } catch (e) {
      LogManager.e('Patient', '字段转换失败', error: e);
      return '';
    }
  }

  // 从Map构造Patient对象
  factory Patient.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'Patient');

    DateTime parseDateTime(dynamic value) {
      if (value is DateTime) return value;
      final s = _safeStringFromField(value);
      if (s == null || s.isEmpty) return DateTime.now();
      try {
        return DateTimeFormatter.fromDbString(s);
      } catch (e) {
        LogManager.w('Patient', '日期解析失败: $value');
        return DateTime.now();
      }
    }

    return Patient(
      id: p.optional('id', (v) => v as int),
      name: _safeStringFromField(map['name']) ?? '',
      namePinyin: _safeStringFromField(map['name_pinyin']),
      nameInitials: _safeStringFromField(map['name_initials']),
      age: p.integer('age'),
      gender: _safeStringFromField(map['gender']) ?? '',
      phone: map['phone'] ?? '',
      medicalRecordNumber: p.optional('medical_record_number', (v) => v as int),
      address: _safeStringFromField(map['address']),
      addressPinyin: _safeStringFromField(map['address_pinyin']),
      identificationNumber: _safeStringFromField(map['identification_number']),
      doctor: _safeStringFromField(map['doctor']),
      dentalCondition: _safeStringFromField(map['dental_condition']),
      treatmentItems: _safeStringFromField(map['treatment_items']),
      firstVisitDate: parseDateTime(map['first_visit_date']),
      totalCost: p.decimal('total_cost'),
      medicalHistory: _safeStringFromField(map['medical_history']),
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
    );
  }

  // 为缺失患者信息的财务记录生成占位患者，
  // 在应显示姓名处展示财务记录 ID 以便定位问题。
  factory Patient.placeholderForFinancialRecord({
    required int? patientId,
    required int? recordId,
    required DateTime createdAt,
  }) {
    return Patient(
      id: patientId,
      name: '记录ID: ${recordId ?? patientId}',
      age: 0,
      gender: '',
      phone: '',
      firstVisitDate: createdAt,
      medicalRecordNumber: patientId,
    );
  }

  // 将Patient对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_pinyin': namePinyin,
      'name_initials': nameInitials,
      'age': age,
      'gender': gender,
      'phone': phone,
      'medical_record_number': medicalRecordNumber,
      'address': address,
      'address_pinyin': addressPinyin,
      'identification_number': identificationNumber,
      'doctor': doctor,
      'dental_condition': dentalCondition,
      'treatment_items': treatmentItems,
      'first_visit_date': DateTimeFormatter.toDbString(firstVisitDate),
      'total_cost': totalCost,
      'medical_history': medicalHistory, // 病史信息
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 复制Patient对象，但可以修改部分属性
  Patient copyWith({
    int? id,
    String? name,
    String? namePinyin,
    String? nameInitials,
    int? age,
    String? gender,
    dynamic phone,
    int? medicalRecordNumber,
    String? address,
    String? addressPinyin,
    String? identificationNumber,
    String? doctor,
    String? dentalCondition,
    String? treatmentItems,
    DateTime? firstVisitDate,
    double? totalCost,
    String? medicalHistory, // 病史信息
    DateTime? createdAt, // 添加创建时间参数
    DateTime? updatedAt, // 添加更新时间参数
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      namePinyin: namePinyin ?? this.namePinyin,
      nameInitials: nameInitials ?? this.nameInitials,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      medicalRecordNumber: medicalRecordNumber ?? this.medicalRecordNumber,
      address: address ?? this.address,
      addressPinyin: addressPinyin ?? this.addressPinyin,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      doctor: doctor ?? this.doctor,
      dentalCondition: dentalCondition ?? this.dentalCondition,
      treatmentItems: treatmentItems ?? this.treatmentItems,
      firstVisitDate: firstVisitDate ?? this.firstVisitDate,
      totalCost: totalCost ?? this.totalCost,
      medicalHistory: medicalHistory ?? this.medicalHistory, // 病史信息
      createdAt: createdAt ?? this.createdAt, // 设置创建时间
      updatedAt: updatedAt ?? this.updatedAt, // 设置更新时间
    );
  }

  // 获取电话号码列表
  List<String> get phoneList {
    if (phone == null) return [];

    // 如果已经是字符串列表，直接返回
    if (phone is List) {
      return (phone as List).map((e) => e.toString()).toList();
    }

    // 如果是字符串类型
    if (phone is String) {
      String phoneStr = phone.toString();
      try {
        // 尝试解析JSON
        if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
          var decoded = jsonDecode(phoneStr);

          // 处理可能的嵌套数组情况 [["123", "456"]]
          if (decoded is List) {
            if (decoded.isEmpty) return [];

            // 如果第一个元素也是数组，表示嵌套数组
            if (decoded[0] is List) {
              return (decoded[0] as List).map((e) => e.toString()).toList();
            }

            // 正常情况：["123", "456"]
            return decoded.map((e) => e.toString()).toList();
          }
        }

        // 如果JSON解析失败，尝试使用正则表达式
        RegExp regex = RegExp(r'"([^"]*)"');
        var matches = regex.allMatches(phoneStr);
        if (matches.isNotEmpty) {
          return matches
              .map((match) => match.group(1))
              .where((group) => group != null)
              .cast<String>()
              .toList();
        }
      } catch (e) {
        LogManager.e('Patient', '解析电话号码时出错', error: e);
      }

      // 如果所有解析都失败，将整个字符串作为一个电话号码
      return [phoneStr];
    }

    // 其他类型情况，转为字符串
    return [phone.toString()];
  }

  // 获取主要电话号码
  String get mainPhone {
    var phones = phoneList;
    return phones.isNotEmpty ? phones[0] : '';
  }

  // 获取备用电话号码
  String? get backupPhone {
    var phones = phoneList;
    return phones.length > 1 ? phones[1] : null;
  }

  // 获取显示用的电话号码字符串
  String displayPhone() {
    var phones = phoneList;
    if (phones.isEmpty) return '';
    if (phones.length == 1) return phones[0];
    return phones.join(', ');
  }

  // 获取牙齿状况数据
  Map<String, dynamic> get dentalCharts {
    final condition = dentalCondition;
    if (condition == null || condition.isEmpty) return {};

    try {
      return jsonDecode(condition) as Map<String, dynamic>;
    } catch (e) {
      LogManager.e('Patient', '解析牙齿状况数据时出错', error: e);
      return {};
    }
  }
}
