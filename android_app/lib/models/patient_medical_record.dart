import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';
import '../utils/map_parser.dart';

/// 患者病历模型
class PatientMedicalRecord {
  final int? id;
  final int patientId;
  final String recordNumber; // 病历编号
  final DateTime recordDate; // 病历日期
  final String chiefComplaint; // 主诉
  final String presentIllness; // 现病史
  final String pastMedicalHistory; // 全身疾病既往史
  final String pastDentalHistory; // 口腔疾病既往史
  final String allergyHistory; // 过敏史
  final String oralExamination; // 口腔检查
  final String diagnosis; // 诊断
  final String treatmentPlan; // 治疗方案
  final String notes; // 注意事项
  final String doctorName; // 医生姓名
  final String? createdByDoctor; // 创建病历的医生姓名（用于权限控制）
  final String? selectedDentalConditionDate; // 关联的牙齿状况日期
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientMedicalRecord({
    this.id,
    required this.patientId,
    required this.recordNumber,
    required this.recordDate,
    this.chiefComplaint = '',
    this.presentIllness = '',
    this.pastMedicalHistory = '',
    this.pastDentalHistory = '',
    this.allergyHistory = '',
    this.oralExamination = '',
    this.diagnosis = '',
    this.treatmentPlan = '',
    this.notes = '',
    this.doctorName = '',
    this.createdByDoctor,
    this.selectedDentalConditionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 从Map构造PatientMedicalRecord对象
  factory PatientMedicalRecord.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'PatientMedicalRecord');

    String? toNullableString(dynamic field) {
      final s = _safeStringFromField(field);
      return s.isEmpty ? null : s;
    }

    return PatientMedicalRecord(
      id: p.optional('id', (v) => v as int),
      patientId: p.integer('patient_id'),
      recordNumber: _safeStringFromField(map['record_number']),
      recordDate: p.dateTime('record_date'),
      chiefComplaint: _safeStringFromField(map['chief_complaint']),
      presentIllness: _safeStringFromField(map['present_illness']),
      pastMedicalHistory: _safeStringFromField(map['past_medical_history']),
      pastDentalHistory: _safeStringFromField(map['past_dental_history']),
      allergyHistory: _safeStringFromField(map['allergy_history']),
      oralExamination: _safeStringFromField(map['oral_examination']),
      diagnosis: _safeStringFromField(map['diagnosis']),
      treatmentPlan: _safeStringFromField(map['treatment_plan']),
      notes: _safeStringFromField(map['notes']),
      doctorName: _safeStringFromField(map['doctor_name']),
      createdByDoctor: toNullableString(map['created_by_doctor']),
      selectedDentalConditionDate:
          toNullableString(map['selected_dental_condition_date']),
      createdAt: p.dateTime('created_at'),
      updatedAt: p.dateTime('updated_at'),
    );
  }

  // 辅助方法：安全转换字符串，处理各种数据类型（包括 Blob）
  static String _safeStringFromField(dynamic field) {
    if (field == null) return '';
    if (field is String) return field;
    // 处理SQLite和MySQL的Blob类型
    if (field is List<int>) {
      try {
        return String.fromCharCodes(field);
      } catch (e) {
        AppLogger.info('PatientMedicalRecord.fromMap: Blob转换失败: $e');
        return '';
      }
    }
    try {
      return field.toString();
    } catch (e) {
      AppLogger.info('PatientMedicalRecord.fromMap: 字段转换失败: $e');
      return '';
    }
  }

  /// 将PatientMedicalRecord对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'record_number': recordNumber,
      'record_date': DateTimeFormatter.toDbString(recordDate),
      'chief_complaint': chiefComplaint,
      'present_illness': presentIllness,
      'past_medical_history': pastMedicalHistory,
      'past_dental_history': pastDentalHistory,
      'allergy_history': allergyHistory,
      'oral_examination': oralExamination,
      'diagnosis': diagnosis,
      'treatment_plan': treatmentPlan,
      'notes': notes,
      'doctor_name': doctorName,
      'created_by_doctor': createdByDoctor,
      'selected_dental_condition_date': selectedDentalConditionDate,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  /// JSON序列化支持
  Map<String, dynamic> toJson() => toMap();

  /// 从JSON构造对象
  factory PatientMedicalRecord.fromJson(Map<String, dynamic> json) =>
      PatientMedicalRecord.fromMap(json);

  /// 复制PatientMedicalRecord对象，但可以修改部分属性
  PatientMedicalRecord copyWith({
    int? id,
    int? patientId,
    String? recordNumber,
    DateTime? recordDate,
    String? chiefComplaint,
    String? presentIllness,
    String? pastMedicalHistory,
    String? pastDentalHistory,
    String? allergyHistory,
    String? oralExamination,
    String? diagnosis,
    String? treatmentPlan,
    String? notes,
    String? doctorName,
    String? createdByDoctor,
    String? selectedDentalConditionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientMedicalRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      recordNumber: recordNumber ?? this.recordNumber,
      recordDate: recordDate ?? this.recordDate,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      presentIllness: presentIllness ?? this.presentIllness,
      pastMedicalHistory: pastMedicalHistory ?? this.pastMedicalHistory,
      pastDentalHistory: pastDentalHistory ?? this.pastDentalHistory,
      allergyHistory: allergyHistory ?? this.allergyHistory,
      oralExamination: oralExamination ?? this.oralExamination,
      diagnosis: diagnosis ?? this.diagnosis,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      notes: notes ?? this.notes,
      doctorName: doctorName ?? this.doctorName,
      createdByDoctor: createdByDoctor ?? this.createdByDoctor,
      selectedDentalConditionDate:
          selectedDentalConditionDate ?? this.selectedDentalConditionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // 更新时间总是使用当前时间
    );
  }

  @override
  String toString() {
    return 'PatientMedicalRecord{id: $id, patientId: $patientId, recordNumber: $recordNumber, recordDate: $recordDate, doctorName: $doctorName}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientMedicalRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          patientId == other.patientId &&
          recordNumber == other.recordNumber;

  @override
  int get hashCode => id.hashCode ^ patientId.hashCode ^ recordNumber.hashCode;
}
