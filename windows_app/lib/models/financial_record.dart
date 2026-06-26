import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

class FinancialRecord {
  final int? id;
  final int patientId;
  final int totalQuantity; // 新增：收费总条数
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialRecord({
    this.id,
    required this.patientId,
    required this.totalQuantity, // 新增：收费总条数
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // 从Map创建FinancialRecord
  factory FinancialRecord.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'FinancialRecord');

    return FinancialRecord(
      id: p.optional('id', (v) => v as int),
      patientId: p.required('patient_id', (v) => v as int),
      totalQuantity: p.integer('total_quantity'),
      notes: p.optional('notes', (v) => v.toString()),
      createdAt: p.required(
        'created_at',
        (v) => v is DateTime ? v : DateTimeFormatter.fromDbString(v.toString()),
      ),
      updatedAt: p.required(
        'updated_at',
        (v) => v is DateTime ? v : DateTimeFormatter.fromDbString(v.toString()),
      ),
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'total_quantity': totalQuantity, // 新增：收费总条数
      'notes': notes,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 复制并修改
  FinancialRecord copyWith({
    int? id,
    int? patientId,
    int? totalQuantity, // 新增：收费总条数
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      totalQuantity: totalQuantity ?? this.totalQuantity, // 新增：收费总条数
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FinancialRecord(id: $id, patientId: $patientId, totalQuantity: $totalQuantity, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialRecord &&
        other.id == id &&
        other.patientId == patientId &&
        other.totalQuantity == totalQuantity &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        patientId.hashCode ^
        totalQuantity.hashCode ^
        notes.hashCode;
  }
}
