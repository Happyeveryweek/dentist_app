import '../../../providers/medical_record_provider.dart';
import '../../../models/medical_record_template.dart';

/// 病历模板初始化服务
/// 负责病历模板的初始化流程编排
class MedicalTemplateInitializationService {
  final MedicalRecordProvider _provider;

  MedicalTemplateInitializationService(this._provider);

  /// 执行初始化流程
  /// 
  /// 返回初始化结果，成功返回 true，失败返回 false 和错误信息
  Future<Map<String, dynamic>> executeInitialization() async {
    try {
      // 执行初始化
      await _provider.initializeDefaultTemplates();
      
      return {
        'success': true,
        'error': null,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 清除模板缓存
  void clearTemplateCache() {
    _provider.clearTemplateCache();
  }

  /// 强制刷新所有模板数据
  Future<void> refreshAllTemplates() async {
    await _provider.getAllTemplates(forceRefresh: true);
  }

  /// 检查是否有模板数据
  Future<bool> hasTemplateData() async {
    return await _provider.hasTemplateData();
  }

  /// 删除模板
  /// 
  /// 返回删除结果，成功返回 true，失败返回 false 和错误信息
  Future<Map<String, dynamic>> deleteTemplate(MedicalRecordTemplate template) async {
    try {
      // 检查是否有关联记录
      final hasRelated = await _provider.hasRelatedRecords(template.id!);
      
      if (hasRelated) {
        return {
          'success': false,
          'error': '该疾病类型已被病历记录使用',
        };
      }
      
      final deleteResult = await _provider.deleteTemplate(template.id!);
      
      if (deleteResult) {
        return {
          'success': true,
          'error': null,
        };
      } else {
        return {
          'success': false,
          'error': '删除操作失败',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 获取指定类别的模板数据
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    return await _provider.getTemplatesByCategory(category, forceRefresh: true);
  }
}
