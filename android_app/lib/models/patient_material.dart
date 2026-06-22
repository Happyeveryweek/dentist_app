import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';

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
    required this.createdAt,
    required this.updatedAt,
  });

  factory PatientMaterial.fromMap(Map<String, dynamic> map) {
    return PatientMaterial(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      description: map['description'] as String,
      createdAt: DateTimeFormatter.fromDbString(map['created_at'] as String),
      updatedAt: DateTimeFormatter.fromDbString(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'description': description,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

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
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        patientId.hashCode ^
        description.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
