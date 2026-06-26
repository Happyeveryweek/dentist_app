import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

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
    final p = MapParser(map, context: 'PatientMaterial');
    return PatientMaterial(
      id: p.optional('id', (v) => v as int),
      patientId: p.integer('patient_id'),
      description: p.string('description'),
      createdAt: p.dateTime('created_at'),
      updatedAt: p.dateTime('updated_at'),
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
