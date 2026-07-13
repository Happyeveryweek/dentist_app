import 'package:mysql1/mysql1.dart';
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';

/// 病历模板数据模型
/// 用于存储疾病类型等模板数据，支持牙科疾病、全身疾病、过敏类型三大类别
class MedicalRecordTemplate {
  final int? id;
  final String category; // 类别：dental_disease, systemic_disease, allergy
  final String name; // 疾病名称
  final String? parentName; // 父级疾病名称（用于子类型）
  final String description; // 详细描述
  final bool isActive; // 是否启用
  final int sortOrder; // 排序顺序
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalRecordTemplate({
    this.id,
    required this.category,
    required this.name,
    this.parentName,
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从Map构造MedicalRecordTemplate对象
  factory MedicalRecordTemplate.fromMap(Map<String, dynamic> map) {
    // 辅助方法：安全转换字符串，处理BLOB类型
    String safeStringFromField(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Blob) {
        try {
          return String.fromCharCodes(field.toBytes());
        } catch (e) {
          LogManager.e('MedicalRecordTemplate',
              'MedicalRecordTemplate.fromMap: Blob转换失败',
              error: e);
          return '';
        }
      }
      try {
        return field.toString();
      } catch (e) {
        LogManager.e(
            'MedicalRecordTemplate', 'MedicalRecordTemplate.fromMap: 字段转换失败',
            error: e);
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
          createdAt =
              DateTimeFormatter.fromDbString(map['created_at'].toString());
        }
      } catch (e) {
        LogManager.e(
            'MedicalRecordTemplate', '解析created_at错误: ${map['created_at']}');
      }
    }

    DateTime updatedAt = DateTime.now();
    if (map['updated_at'] != null) {
      try {
        if (map['updated_at'] is DateTime) {
          updatedAt = map['updated_at'];
        } else {
          updatedAt =
              DateTimeFormatter.fromDbString(map['updated_at'].toString());
        }
      } catch (e) {
        LogManager.e(
            'MedicalRecordTemplate', '解析updated_at错误: ${map['updated_at']}');
      }
    }

    // 处理parent_name字段，确保NULL值被正确识别
    String? parentName;
    if (map['parent_name'] == null) {
      parentName = null;
    } else {
      final parentNameStr = safeStringFromField(map['parent_name']);
      // 检查是否为空字符串、"null"字符串或"(Null)"字符串
      if (parentNameStr.isEmpty ||
          parentNameStr.toLowerCase() == 'null' ||
          parentNameStr == '(Null)') {
        parentName = null;
      } else {
        parentName = parentNameStr;
      }
    }

    return MedicalRecordTemplate(
      id: map['id'],
      category: safeStringFromField(map['category']),
      name: safeStringFromField(map['name']),
      parentName: parentName,
      description: safeStringFromField(map['description']),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 将MedicalRecordTemplate对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'parent_name': parentName,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  /// 复制MedicalRecordTemplate对象，但可以修改部分属性
  MedicalRecordTemplate copyWith({
    int? id,
    String? category,
    String? name,
    String? parentName,
    String? description,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalRecordTemplate(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      parentName: parentName ?? this.parentName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // 更新时间总是使用当前时间
    );
  }

  /// 获取完整的显示名称（包含父级疾病）
  String get fullDisplayName {
    final parent = parentName;
    if (parent != null && parent.isNotEmpty) {
      return '$parent - $name';
    }
    return name;
  }

  /// 检查是否为主疾病类型（没有父级）
  bool get isMainType => parentName?.isEmpty ?? true;

  /// 检查是否为子类型（有父级）
  bool get isSubType => parentName?.isNotEmpty ?? false;

  @override
  String toString() {
    return 'MedicalRecordTemplate{id: $id, category: $category, name: $name, parentName: $parentName, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalRecordTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          name == other.name &&
          parentName == other.parentName;

  @override
  int get hashCode =>
      id.hashCode ^
      category.hashCode ^
      name.hashCode ^
      (parentName?.hashCode ?? 0);
}

/// 病历模板类别常量
class MedicalRecordTemplateCategory {
  static const String dentalDisease = 'dental_disease'; // 牙科疾病
  static const String systemicDisease = 'systemic_disease'; // 全身疾病
  static const String allergy = 'allergy'; // 过敏史

  static const List<String> all = [
    dentalDisease,
    systemicDisease,
    allergy,
  ];

  /// 获取类别的中文名称
  static String getCategoryName(String category) {
    switch (category) {
      case dentalDisease:
        return '牙科疾病';
      case systemicDisease:
        return '全身疾病';
      case allergy:
        return '过敏类型';
      default:
        return '未知类别';
    }
  }
}
