/// 医疗模板数据模型
/// 用于存储治疗方案模板和医嘱模板
class MedicalTemplate {
  final String id;
  final String title;
  final String content;
  final String type; // 'treatment' 或 'notes'
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从Map构造MedicalTemplate对象
  factory MedicalTemplate.fromMap(Map<String, dynamic> map) {
    return MedicalTemplate(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'treatment',
      sortOrder: map['sortOrder'] ?? 0,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
    );
  }

  /// 将MedicalTemplate对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 复制MedicalTemplate对象，但可以修改部分属性
  MedicalTemplate copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MedicalTemplate{id: $id, title: $title, type: $type}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 医疗模板类型常量
class MedicalTemplateType {
  static const String treatment = 'treatment';  // 治疗方案模板
  static const String notes = 'notes';          // 医嘱模板

  static const List<String> all = [treatment, notes];

  /// 获取类型的中文名称
  static String getTypeName(String type) {
    switch (type) {
      case treatment:
        return '治疗方案模板';
      case notes:
        return '医嘱模板';
      default:
        return '未知类型';
    }
  }

  /// 检查是否为有效的类型
  static bool isValidType(String type) {
    return all.contains(type);
  }
}