import 'package:mysql1/mysql1.dart';
import '../utils/datetime_formatter.dart';

/// 患者病历模型
class PatientMedicalRecord {
  final int? id;
  final int patientId;
  final String recordNumber;           // 病历编号
  final DateTime recordDate;           // 病历日期
  final String chiefComplaint;         // 主诉
  final String presentIllness;         // 现病史
  final String pastMedicalHistory;     // 全身疾病既往史
  final String pastDentalHistory;      // 口腔疾病既往史
  final String allergyHistory;         // 过敏史
  final String oralExamination;        // 口腔检查
  final String diagnosis;              // 诊断
  final String treatmentPlan;          // 治疗方案
  final String notes;                  // 注意事项
  final String doctorName;             // 医生姓名
  final String? createdByDoctor;       // 创建病历的医生姓名（用于权限控制）
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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从Map构造PatientMedicalRecord对象
  factory PatientMedicalRecord.fromMap(Map<String, dynamic> map) {
    // 辅助方法：安全转换字符串，处理BLOB类型
    String safeStringFromField(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Blob) {
        try {
          return String.fromCharCodes(field.toBytes());
        } catch (e) {
          print('PatientMedicalRecord.fromMap: Blob转换失败: $e');
          return '';
        }
      }
      try {
        return field.toString();
      } catch (e) {
        print('PatientMedicalRecord.fromMap: 字段转换失败: $e');
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

    // 处理病历日期
    DateTime recordDate = DateTime.now();
    if (map['record_date'] != null) {
      try {
        if (map['record_date'] is DateTime) {
          recordDate = map['record_date'];
        } else {
          recordDate = DateTimeFormatter.fromDbString(map['record_date'].toString());
        }
      } catch (e) {
        print('解析record_date错误: ${map['record_date']}');
      }
    }

    return PatientMedicalRecord(
      id: map['id'],
      patientId: map['patient_id'] ?? 0,
      recordNumber: safeStringFromField(map['record_number']),
      recordDate: recordDate,
      chiefComplaint: safeStringFromField(map['chief_complaint']),
      presentIllness: safeStringFromField(map['present_illness']),
      pastMedicalHistory: safeStringFromField(map['past_medical_history']),
      pastDentalHistory: safeStringFromField(map['past_dental_history']),
      allergyHistory: safeStringFromField(map['allergy_history']),
      oralExamination: safeStringFromField(map['oral_examination']),
      diagnosis: safeStringFromField(map['diagnosis']),
      treatmentPlan: safeStringFromField(map['treatment_plan']),
      notes: safeStringFromField(map['notes']),
      doctorName: safeStringFromField(map['doctor_name']),
      createdByDoctor: safeStringFromField(map['created_by_doctor']).isEmpty 
          ? null 
          : safeStringFromField(map['created_by_doctor']),
      selectedDentalConditionDate: safeStringFromField(map['selected_dental_condition_date']).isEmpty 
          ? null 
          : safeStringFromField(map['selected_dental_condition_date']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
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
      selectedDentalConditionDate: selectedDentalConditionDate ?? this.selectedDentalConditionDate,
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