import '../utils/datetime_formatter.dart';

/// 病历项目数据模型
/// 用于存储病历的详细项目信息，如检查项目、治疗项目等
class MedicalRecordItem {
  final int? id;
  final int medicalRecordId;       // 关联的病历ID
  final String itemType;           // 项目类型：examination, treatment, medication等
  final String itemName;           // 项目名称
  final String itemValue;          // 项目值/结果
  final String? itemUnit;          // 项目单位
  final String? itemNotes;         // 项目备注
  final int sortOrder;             // 排序顺序
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalRecordItem({
    this.id,
    required this.medicalRecordId,
    required this.itemType,
    required this.itemName,
    this.itemValue = '',
    this.itemUnit,
    this.itemNotes,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从Map构造MedicalRecordItem对象
  factory MedicalRecordItem.fromMap(Map<String, dynamic> map) {
    // 辅助方法：安全转换字符串
    String safeStringFromField(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is List<int>) {
        try {
          return String.fromCharCodes(field);
        } catch (e) {
          print('MedicalRecordItem.fromMap: Blob转换失败: $e');
          return '';
        }
      }
      try {
        return field.toString();
      } catch (e) {
        print('MedicalRecordItem.fromMap: 字段转换失败: $e');
        return '';
      }
    }

    // 处理时间字段
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

    return MedicalRecordItem(
      id: map['id'],
      medicalRecordId: map['medical_record_id'] ?? 0,
      itemType: safeStringFromField(map['item_type']),
      itemName: safeStringFromField(map['item_name']),
      itemValue: safeStringFromField(map['item_value']),
      itemUnit: safeStringFromField(map['item_unit']).isEmpty 
          ? null 
          : safeStringFromField(map['item_unit']),
      itemNotes: safeStringFromField(map['item_notes']).isEmpty 
          ? null 
          : safeStringFromField(map['item_notes']),
      sortOrder: map['sort_order'] ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 将MedicalRecordItem对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medical_record_id': medicalRecordId,
      'item_type': itemType,
      'item_name': itemName,
      'item_value': itemValue,
      'item_unit': itemUnit,
      'item_notes': itemNotes,
      'sort_order': sortOrder,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  /// JSON序列化支持
  Map<String, dynamic> toJson() => toMap();

  /// 从JSON构造对象
  factory MedicalRecordItem.fromJson(Map<String, dynamic> json) => 
      MedicalRecordItem.fromMap(json);

  /// 复制MedicalRecordItem对象，但可以修改部分属性
  MedicalRecordItem copyWith({
    int? id,
    int? medicalRecordId,
    String? itemType,
    String? itemName,
    String? itemValue,
    String? itemUnit,
    String? itemNotes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalRecordItem(
      id: id ?? this.id,
      medicalRecordId: medicalRecordId ?? this.medicalRecordId,
      itemType: itemType ?? this.itemType,
      itemName: itemName ?? this.itemName,
      itemValue: itemValue ?? this.itemValue,
      itemUnit: itemUnit ?? this.itemUnit,
      itemNotes: itemNotes ?? this.itemNotes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MedicalRecordItem{id: $id, medicalRecordId: $medicalRecordId, itemType: $itemType, itemName: $itemName}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalRecordItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          medicalRecordId == other.medicalRecordId &&
          itemType == other.itemType &&
          itemName == other.itemName;

  @override
  int get hashCode => id.hashCode ^ medicalRecordId.hashCode ^ itemType.hashCode ^ itemName.hashCode;
}

/// 病历项目类型常量
class MedicalRecordItemType {
  static const String examination = 'examination';     // 检查项目
  static const String treatment = 'treatment';         // 治疗项目
  static const String medication = 'medication';       // 用药记录
  static const String procedure = 'procedure';         // 操作记录
  static const String followUp = 'follow_up';          // 复查记录
  static const String other = 'other';                 // 其他

  static const List<String> all = [
    examination,
    treatment,
    medication,
    procedure,
    followUp,
    other,
  ];

  /// 获取项目类型的中文名称
  static String getTypeName(String type) {
    switch (type) {
      case examination:
        return '检查项目';
      case treatment:
        return '治疗项目';
      case medication:
        return '用药记录';
      case procedure:
        return '操作记录';
      case followUp:
        return '复查记录';
      case other:
        return '其他';
      default:
        return '未知类型';
    }
  }

  /// 检查是否为有效的项目类型
  static bool isValidType(String type) {
    return all.contains(type);
  }
}