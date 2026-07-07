import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';

// 患者材料模型
class PatientMaterial {
  final int? id;
  final int patientId;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientMaterial({
    this.id,
    required this.patientId,
    required this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 从Map构造PatientMaterial对象
  factory PatientMaterial.fromMap(Map<String, dynamic> map) {
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
        LogManager.e('PatientMaterial', '解析created_at错误: ${map['created_at']}');
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
        LogManager.e('PatientMaterial', '解析updated_at错误: ${map['updated_at']}');
      }
    }

    final result = PatientMaterial(
      id: map['id'],
      patientId: map['patient_id'],
      description: map['description'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    LogManager.e('PatientMaterial',
        'PatientMaterial.fromMap - 创建结果: ID=${result.id}, 描述=${result.description}');
    return result;
  }

  // 将PatientMaterial对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'description': description,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 复制PatientMaterial对象，但可以修改部分属性
  PatientMaterial copyWith({
    int? id,
    int? patientId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientMaterial(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PatientMaterial(id: $id, patientId: $patientId, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatientMaterial &&
        other.id == id &&
        other.patientId == patientId &&
        other.description == description;
  }

  @override
  int get hashCode {
    return id.hashCode ^ patientId.hashCode ^ description.hashCode;
  }
}
