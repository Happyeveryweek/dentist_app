import '../models/material.dart' as material_models;

export 'sqlite_material_data_source.dart';
export 'mysql_material_data_source.dart';

/// 抽象材料数据源接口
/// 定义了所有材料管理相关的底层数据库操作协议
abstract class MaterialDataSource {
  Future<List<material_models.MaterialInfo>> getAllMaterials();
  Future<material_models.MaterialInfo?> getMaterialById(int id);
  Future<material_models.MaterialInfo?> getMaterialByCode(String code);
  Future<int> createMaterial(material_models.MaterialInfo material);
  Future<bool> updateMaterial(material_models.MaterialInfo material);
  Future<bool> deleteMaterial(int id);
  
  // 搜索和分类方法
  Future<List<material_models.MaterialInfo>> searchMaterials(String query);
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(String category);
  
  // 分页查询方法
  Future<int> getMaterialsCount({String? searchQuery});
  Future<List<material_models.MaterialInfo>> getPaginatedMaterials({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? category,
  });
  
  // 统计方法
  Future<Map<String, dynamic>> getMaterialStatistics();
  
  // 材料编码相关
  Future<String> getNextMaterialCode();
  
  // 批量操作
  Future<bool> clearAllMaterials();
}
