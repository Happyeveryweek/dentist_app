import '../../../models/patient_material.dart';
import '../../../models/material_image.dart';
import '../../../models/patient_material_with_images.dart';
import '../../../data_sources/patient_data_source.dart';
import 'patient_material_sync_service.dart';

/// 患者材料服务
/// 负责处理患者材料的业务逻辑，SQL 操作委托给 Data Source
class PatientMaterialService {
  final PatientDataSource? Function() getCurrentDataSource;
  final PatientMaterialSyncService syncService;

  PatientMaterialService({
    required this.getCurrentDataSource,
    required this.syncService,
  });

  /// 添加患者材料
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material) async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    final savedMaterial = await ds.addPatientMaterial(material);
    if (savedMaterial.id != null && syncService.needsSync) {
      syncService.syncPatientMaterialToMySQL(savedMaterial, savedMaterial.id!);
    }
    return savedMaterial;
  }

  /// 获取患者的所有材料
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    final ds = getCurrentDataSource();
    if (ds == null) return [];
    return await ds.getPatientMaterials(patientId);
  }

  /// 更新患者材料
  Future<bool> updatePatientMaterial(PatientMaterial material) async {
    final ds = getCurrentDataSource();
    if (ds == null) return false;
    final success = await ds.updatePatientMaterial(material);
    if (success && material.id != null && syncService.needsSync) {
      syncService.syncPatientMaterialToMySQL(material, material.id!);
    }
    return success;
  }

  /// 删除患者材料
  Future<bool> deletePatientMaterial(int id) async {
    final ds = getCurrentDataSource();
    if (ds == null) return false;
    final success = await ds.deletePatientMaterial(id);
    if (success && syncService.needsSync) {
      syncService.syncDeletePatientMaterialToMySQL(id);
    }
    return success;
  }

  /// 添加材料图片
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    final savedImage = await ds.addMaterialImage(image);
    if (savedImage.id != null && syncService.needsSync) {
      syncService.syncMaterialImageToMySQL(savedImage, savedImage.id!);
    }
    return savedImage;
  }

  /// 获取材料的所有图片
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    final ds = getCurrentDataSource();
    if (ds == null) return [];
    return await ds.getMaterialImages(materialId);
  }

  /// 删除材料图片
  Future<bool> deleteMaterialImage(int imageId) async {
    final ds = getCurrentDataSource();
    if (ds == null) return false;
    final success = await ds.deleteMaterialImage(imageId);
    if (success && syncService.needsSync) {
      syncService.syncDeleteMaterialImageToMySQL(imageId);
    }
    return success;
  }

  /// 获取患者材料（包含图片信息）
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithImages(int patientId) async {
    final materials = await getPatientMaterials(patientId);
    List<PatientMaterialWithImages> result = [];
    for (var material in materials) {
      final images = await getMaterialImages(material.id!);
      result.add(PatientMaterialWithImages(material: material, images: images));
    }
    return result;
  }

  /// 获取单个材料图片
  Future<MaterialImage?> getMaterialImage(int imageId) async {
    final ds = getCurrentDataSource();
    if (ds == null) return null;
    try {
      return await ds.getMaterialImage(imageId);
    } catch (e) {
      print('获取单个材料图片失败: $e');
      return null;
    }
  }

  /// 获取患者材料缩略图
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithThumbnails(int patientId) async {
    // Data Source 接口统一返回图片数据，缩略图处理由上层 UI 控制
    return await getPatientMaterialsWithImages(patientId);
  }
}
