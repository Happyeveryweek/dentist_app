import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';

export 'sqlite_medical_record_data_source.dart';
export 'mysql_medical_record_data_source.dart';

/// 抽象病历数据源接口
/// 定义了所有病历管理相关的底层数据库操作协议
abstract class MedicalRecordDataSource {
  // 病历主记录操作
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId);
  Future<PatientMedicalRecord?> getMedicalRecordById(int id);
  Future<int> createMedicalRecord(PatientMedicalRecord record);
  Future<bool> updateMedicalRecord(PatientMedicalRecord record);
  Future<bool> deleteMedicalRecord(int id);

  // 搜索和统计功能
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId});
  Future<int> getMedicalRecordsCount(int patientId);
  
  // 基于医生的查询方法
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName, {int? patientId});
  Future<int> getDoctorMedicalRecordsCount(String doctorName, {int? patientId});
  
  // 分页查询
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  });

  // 模板数据操作
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category);
  Future<MedicalRecordTemplate?> getTemplateById(int id);
  Future<int> createTemplate(MedicalRecordTemplate template);
  Future<bool> updateTemplate(MedicalRecordTemplate template);
  Future<bool> deleteTemplate(int id);
  
  // 初始化预设数据
  Future<bool> initializeDefaultTemplates();
  Future<bool> hasTemplateData();
  
  // 检查关联数据
  Future<bool> hasRelatedRecords(int templateId);
  
  // 模板数据搜索和过滤
  Future<List<MedicalRecordTemplate>> searchTemplates(String category, String query);
  Future<Map<String, List<String>>> getDiseaseOptions(String category);

  /// 确保病历相关表存在（DDL）
  Future<void> ensureTablesExist();
}
