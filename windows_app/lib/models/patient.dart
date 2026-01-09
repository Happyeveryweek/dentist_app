import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:mysql1/mysql1.dart'; // 添加MySQL导入以支持Blob类型
import '../utils/datetime_formatter.dart';

// 患者模型
class Patient {
  final int? id;
  final String name;
  final String? name_pinyin; // 姓名拼音
  final String? name_initials; // 姓名首字母缩写
  final int age;
  final String gender;
  final dynamic phone; // 可以是字符串或JSON数组字符串
  final int? medical_record_number;
  final String? address;
  final String? address_pinyin; // 地址拼音
  final String? identification_number;
  final String? doctor;
  final String? dental_condition; // JSON字符串格式
  final String? treatment_items;
  final DateTime first_visit_date;
  final double total_cost;
  final String? medical_history; // 病史信息
  final DateTime created_at; // 添加创建时间字段
  final DateTime updated_at; // 添加更新时间字段

  Patient({
    this.id,
    required this.name,
    this.name_pinyin,
    this.name_initials,
    required this.age,
    required this.gender,
    required this.phone,
    this.medical_record_number,
    this.address,
    this.address_pinyin,
    this.identification_number,
    this.doctor,
    this.dental_condition,
    this.treatment_items,
    required this.first_visit_date,
    this.total_cost = 0.0,
    this.medical_history, // 病史信息
    DateTime? created_at, // 添加创建时间参数
    DateTime? updated_at, // 添加更新时间参数
  })  : created_at = created_at ?? DateTime.now(), // 如果未提供，则使用当前时间
        updated_at = updated_at ?? DateTime.now(); // 如果未提供，则使用当前时间

  // 从Map构造Patient对象
  factory Patient.fromMap(Map<String, dynamic> map) {
    // 辅助方法：安全转换字符串，处理BLOB类型
    String? safeStringFromField(dynamic field) {
      if (field == null) return null;
      if (field is String) return field;
      if (field is Blob) {
        try {
          return String.fromCharCodes(field.toBytes());
        } catch (e) {
          print('Patient.fromMap: Blob转换失败: $e');
          return '';
        }
      }
      // 安全地转换为字符串，避免递归调用
      try {
        return field.toString();
      } catch (e) {
        print('Patient.fromMap: 字段转换失败: $e');
        return '';
      }
    }

    // 处理创建时间和更新时间
    DateTime createdAt = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          createdAt = map['created_at'];
        } else {
          createdAt = DateTimeFormatter.fromDbString(map['created_at'].toString());
        }
      } catch (e) {
        print('解析created_at错误: ${map['created_at']}');
      }
    }

    DateTime updatedAt = DateTime.now();
    if (map['updated_at'] != null) {
      try {
        if (map['updated_at'] is DateTime) {
          updatedAt = map['updated_at'];
        } else {
          updatedAt = DateTimeFormatter.fromDbString(map['updated_at'].toString());
        }
      } catch (e) {
        print('解析updated_at错误: ${map['updated_at']}');
      }
    }

    return Patient(
      id: map['id'],
      name: safeStringFromField(map['name']) ?? '',
      name_pinyin: safeStringFromField(map['name_pinyin']),
      name_initials: safeStringFromField(map['name_initials']),
      age: map['age'] ?? 0,
      gender: safeStringFromField(map['gender']) ?? '',
      phone: map['phone'] ?? '',
      medical_record_number: map['medical_record_number'],
      address: safeStringFromField(map['address']),
      address_pinyin: safeStringFromField(map['address_pinyin']),
      identification_number: safeStringFromField(map['identification_number']),
      doctor: safeStringFromField(map['doctor']),
      dental_condition: safeStringFromField(map['dental_condition']),
      treatment_items: safeStringFromField(map['treatment_items']),
      first_visit_date: map['first_visit_date'] is DateTime
          ? map['first_visit_date']
          : map['first_visit_date'] != null 
              ? DateTimeFormatter.fromDbString(safeStringFromField(map['first_visit_date']) ?? DateTimeFormatter.nowDbString())
              : DateTime.now(),
      total_cost: map['total_cost']?.toDouble() ?? 0.0,
      medical_history: safeStringFromField(map['medical_history']), // 病史信息
      created_at: createdAt, // 设置创建时间
      updated_at: updatedAt, // 设置更新时间
    );
  }

  // 将Patient对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_pinyin': name_pinyin,
      'name_initials': name_initials,
      'age': age,
      'gender': gender,
      'phone': phone,
      'medical_record_number': medical_record_number,
      'address': address,
      'address_pinyin': address_pinyin,
      'identification_number': identification_number,
      'doctor': doctor,
      'dental_condition': dental_condition,
      'treatment_items': treatment_items,
      'first_visit_date': DateTimeFormatter.toDbString(first_visit_date),
      'total_cost': total_cost,
      'medical_history': medical_history, // 病史信息
      'created_at': DateTimeFormatter.toDbString(created_at),
      'updated_at': DateTimeFormatter.toDbString(updated_at),
    };
  }

  // 复制Patient对象，但可以修改部分属性
  Patient copyWith({
    int? id,
    String? name,
    String? name_pinyin,
    String? name_initials,
    int? age,
    String? gender,
    dynamic phone,
    int? medical_record_number,
    String? address,
    String? address_pinyin,
    String? identification_number,
    String? doctor,
    String? dental_condition,
    String? treatment_items,
    DateTime? first_visit_date,
    double? total_cost,
    String? medical_history, // 病史信息
    DateTime? created_at, // 添加创建时间参数
    DateTime? updated_at, // 添加更新时间参数
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      name_pinyin: name_pinyin ?? this.name_pinyin,
      name_initials: name_initials ?? this.name_initials,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      medical_record_number:
          medical_record_number ?? this.medical_record_number,
      address: address ?? this.address,
      address_pinyin: address_pinyin ?? this.address_pinyin,
      identification_number:
          identification_number ?? this.identification_number,
      doctor: doctor ?? this.doctor,
      dental_condition: dental_condition ?? this.dental_condition,
      treatment_items: treatment_items ?? this.treatment_items,
      first_visit_date: first_visit_date ?? this.first_visit_date,
      total_cost: total_cost ?? this.total_cost,
      medical_history: medical_history ?? this.medical_history, // 病史信息
      created_at: created_at ?? this.created_at, // 设置创建时间
      updated_at: updated_at ?? this.updated_at, // 设置更新时间
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
          return matches.map((match) => match.group(1)!).toList();
        }
      } catch (e) {
        print('解析电话号码时出错: $e');
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
    if (dental_condition == null || dental_condition!.isEmpty) return {};

    try {
      return jsonDecode(dental_condition!) as Map<String, dynamic>;
    } catch (e) {
      print('解析牙齿状况数据时出错: $e');
      return {};
    }
  }
}
