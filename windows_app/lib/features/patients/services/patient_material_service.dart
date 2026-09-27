import '../../../models/patient_material.dart';
import '../../../models/material_image.dart';
import '../../../models/patient_material_with_images.dart';
import '../../../data_sources/patient_data_source.dart';
import 'patient_material_sync_service.dart';
import '../../../utils/log_manager.dart';

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
    final savedId = savedMaterial.id;
    if (savedId != null && syncService.needsSync) {
      await syncService.upsertPatientMaterial(savedMaterial, savedId);
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
    final materialId = material.id;
    final success = await ds.updatePatientMaterial(material);
    if (success && materialId != null && syncService.needsSync) {
      await syncService.upsertPatientMaterial(material, materialId);
    }
    return success;
  }

  /// 删除患者材料
  Future<bool> deletePatientMaterial(int id) async {
    final ds = getCurrentDataSource();
    if (ds == null) return false;
    final success = await ds.deletePatientMaterial(id);
    if (success && syncService.needsSync) {
      await syncService.deletePatientMaterialFromMySQL(id);
    }
    return success;
  }

  /// 添加材料图片
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    final savedImage = await ds.addMaterialImage(image);
    final savedId = savedImage.id;
    if (savedId != null && syncService.needsSync) {
      await syncService.upsertMaterialImage(savedImage, savedId);
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
      await syncService.deleteMaterialImageFromMySQL(imageId);
    }
    return success;
  }

  /// 获取患者材料（包含图片信息）
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithImages(
      int patientId) async {
    final materials = await getPatientMaterials(patientId);
    List<PatientMaterialWithImages> result = [];
    for (var material in materials) {
      final materialId = material.id;
      if (materialId == null) continue;
      final images = await getMaterialImages(materialId);
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
      LogManager.e('PatientMaterialService', '获取单个材料图片失败', error: e);
      return null;
    }
  }

  /// 按 SQLite 当前内容补写材料和图片，并删除 MySQL 中已经不存在的记录。
  Future<bool> syncAllPatientMaterialsToMySQL(int patientId) async {
    if (!syncService.needsSync) return true;
    try {
      final materials = await getPatientMaterials(patientId);
      final localMaterialIds = <int>{};
      final localImageIdsByMaterial = <int, Set<int>>{};
      for (final material in materials) {
        final materialId = material.id;
        if (materialId == null) continue;
        localMaterialIds.add(materialId);
        final materialSynced =
            await syncService.upsertPatientMaterial(material, materialId);
        if (!materialSynced) return false;

        final images = await getMaterialImages(materialId);
        final localImageIds = <int>{};
        for (final image in images) {
          final imageId = image.id;
          if (imageId == null) continue;
          localImageIds.add(imageId);
          final imageSynced =
              await syncService.upsertMaterialImage(image, imageId);
          if (!imageSynced) return false;
        }
        localImageIdsByMaterial[materialId] = localImageIds;
      }
      return syncService.deleteMaterialsMissingLocally(
        patientId: patientId,
        localMaterialIds: localMaterialIds,
        localImageIdsByMaterial: localImageIdsByMaterial,
      );
    } catch (e) {
      LogManager.e('PatientMaterialService', '手动同步患者材料失败', error: e);
      return false;
    }
  }

  /// 对比该患者的材料和图片是否已经同步到 MySQL。
  Future<bool?> comparePatientMaterialsSyncStatus(int patientId) async {
    if (!syncService.needsSync) return null;
    try {
      final dataSource = getCurrentDataSource();
      if (dataSource == null) return null;
      final materials = await dataSource.getPatientMaterials(patientId);
      final imagesByMaterialId = <int, List<MaterialImage>>{};
      for (final material in materials) {
        final materialId = material.id;
        if (materialId == null) continue;
        imagesByMaterialId[materialId] =
            await dataSource.getMaterialImageMetadata(materialId);
      }
      return syncService.compareStoredMaterials(
        patientId: patientId,
        materials: materials,
        imagesByMaterialId: imagesByMaterialId,
      );
    } catch (e) {
      LogManager.e('PatientMaterialService', '对比患者材料同步状态失败', error: e);
      return null;
    }
  }

  /// 获取患者材料缩略图
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithThumbnails(
      int patientId) async {
    // Data Source 接口统一返回图片数据，缩略图处理由上层 UI 控制
    return await getPatientMaterialsWithImages(patientId);
  }
}
