import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';

// 抽象病历数据源接口
abstract class MedicalRecordDataSource {
  // 患者病历相关方法
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId);
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId);
  Future<int> createMedicalRecord(PatientMedicalRecord record);
  Future<bool> updateMedicalRecord(PatientMedicalRecord record);
  Future<bool> deleteMedicalRecord(int recordId);
  Future<bool> hasMedicalRecords(int patientId);

  // 病历模板相关方法
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates();
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category);
  Future<int> createTemplate(MedicalRecordTemplate template);
  Future<bool> updateTemplate(MedicalRecordTemplate template);
  Future<bool> deleteTemplate(int templateId);
}
