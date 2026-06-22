import '../models/patient.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';

export 'sqlite_patient_data_source.dart';
export 'mysql_patient_data_source.dart';

/// 抽象患者数据源接口
/// 定义了所有患者管理相关的底层数据库操作协议
abstract class PatientDataSource {
  Future<List<Patient>> getAllPatients();
  Future<Patient?> getPatientById(int id);
  Future<int> createPatient(Patient patient);
  Future<bool> updatePatient(Patient patient);
  Future<bool> deletePatient(int id);
  Future<List<Patient>> searchPatients(String query);
  
  // 分页查询方法
  Future<int> getPatientsCount({String? searchQuery});
  Future<Map<String, dynamic>> getPatientsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  });
  
  // 患者特有方法
  Future<List<Patient>> getPatientsByDoctor(String doctorName);
  Future<List<int>> searchPatientIds(String query);
  Future<List<Patient>> getPatientsByIds(List<int> ids);
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber, [int? excludePatientId]);
  Future<bool> checkPatientNameExists(String name, [int? excludePatientId]);
  Future<void> updateAllPatientsPinyin();
  
  // 患者材料相关方法
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material);
  Future<List<PatientMaterial>> getPatientMaterials(int patientId);
  Future<bool> updatePatientMaterial(PatientMaterial material);
  Future<bool> deletePatientMaterial(int id);
  
  // 患者材料图片相关方法
  Future<List<MaterialImage>> getMaterialImages(int materialId);
  Future<MaterialImage?> getMaterialImage(int imageId);
  Future<MaterialImage> addMaterialImage(MaterialImage image);
  Future<bool> updateMaterialImage(MaterialImage image);
  Future<bool> deleteMaterialImage(int imageId);
}
