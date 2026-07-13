import '../../../models/medical_record_template.dart';
import '../../../data_sources/medical_record_data_source.dart';
import 'medical_record_sync_service.dart';
import '../../../utils/log_manager.dart';

/// 病历模板管理服务
/// 负责处理所有与病历模板相关的业务逻辑
class MedicalRecordTemplateService {
  final MedicalRecordDataSource? Function() getCurrentDataSource;
  final void Function(bool) setLoading;
  final void Function() clearError;
  final void Function(String) setError;
  final void Function() notifyListeners;
  final void Function() markTemplatesNeedRefresh;
  final MedicalRecordSyncService syncService;

  MedicalRecordTemplateService({
    required this.getCurrentDataSource,
    required this.setLoading,
    required this.clearError,
    required this.setError,
    required this.notifyListeners,
    required this.markTemplatesNeedRefresh,
    required this.syncService,
  });

  /// 根据类别获取模板列表
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(
    String category, {
    bool forceRefresh = false,
    Map<String, List<MedicalRecordTemplate>>? cachedTemplates,
    DateTime? lastTemplateCacheTime,
    Duration cacheValidDuration = const Duration(minutes: 20),
    Function(String, List<MedicalRecordTemplate>)? updateTemplateCache,
  }) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      // 检查缓存
      final cached = cachedTemplates?[category];
      if (!forceRefresh &&
          lastTemplateCacheTime != null &&
          DateTime.now().difference(lastTemplateCacheTime) <
              cacheValidDuration &&
          cached != null) {
        return cached;
      }

      setLoading(true);

      // 从数据源获取数据
      final templates = await dataSource.getTemplatesByCategory(category);

      // 更新缓存
      if (updateTemplateCache != null) {
        updateTemplateCache(category, templates);
      }

      clearError();
      return templates;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '获取模板列表时出错', error: e);
      setError('获取模板列表失败: $e');

      // 优雅降级：如果有缓存数据，返回缓存
      final cached = cachedTemplates?[category];
      if (cached != null) {
        LogManager.e('MedicalRecordTemplateService',
            'MedicalRecordTemplateService: 连接失败，返回缓存数据');
        return cached;
      }

      return [];
    } finally {
      setLoading(false);
    }
  }

  /// 根据ID获取模板
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      final template = await dataSource.getTemplateById(id);

      clearError();
      return template;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '根据ID获取模板时出错', error: e);
      setError('获取模板失败: $e');
      return null;
    } finally {
      setLoading(false);
    }
  }

  /// 创建新模板
  Future<int> createTemplate(
    MedicalRecordTemplate template, {
    Map<String, List<MedicalRecordTemplate>>? cachedTemplates,
    Function()? clearTemplateCache,
  }) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 数据验证
      if (template.category.trim().isEmpty) {
        throw Exception('模板类别不能为空');
      }

      if (template.name.trim().isEmpty) {
        throw Exception('模板名称不能为空');
      }

      final id = await dataSource.createTemplate(template);

      if (id > 0) {
        // 就地更新缓存，避免整类模板在页面刷新时短暂丢失
        if (cachedTemplates != null) {
          final categoryTemplates = cachedTemplates[template.category];
          if (categoryTemplates != null) {
            final savedTemplate = template.copyWith(id: id);
            final index = categoryTemplates
                .indexWhere((item) => item.id == savedTemplate.id);
            if (index >= 0) {
              categoryTemplates[index] = savedTemplate;
            } else {
              categoryTemplates.add(savedTemplate);
            }
          }
        }

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (syncService.needsSync) {
          syncService.syncTemplateToMySQL(
              template.copyWith(id: id).toMap(), id);
        }

        clearError();
      } else {
        throw Exception('创建模板失败');
      }

      return id;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '创建模板时出错', error: e);
      setError('创建模板失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 更新模板
  Future<bool> updateTemplate(
    MedicalRecordTemplate template, {
    Map<String, List<MedicalRecordTemplate>>? cachedTemplates,
    Function()? clearTemplateCache,
  }) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 数据验证
      if (template.id == null) {
        throw Exception('更新模板时必须提供ID');
      }

      if (template.category.trim().isEmpty) {
        throw Exception('模板类别不能为空');
      }

      if (template.name.trim().isEmpty) {
        throw Exception('模板名称不能为空');
      }

      final success = await dataSource.updateTemplate(template);

      if (success) {
        // 只更新当前模板，不要整类清缓存，避免页面在刷新键重建后丢失其它子项
        if (cachedTemplates != null) {
          final categoryTemplates = cachedTemplates[template.category];
          if (categoryTemplates != null) {
            final index =
                categoryTemplates.indexWhere((item) => item.id == template.id);
            if (index >= 0) {
              categoryTemplates[index] = template;
            } else {
              categoryTemplates.add(template);
            }
          }
        }

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        final templateId = template.id;
        if (syncService.needsSync && templateId != null) {
          syncService.syncTemplateToMySQL(template.toMap(), templateId);
        }

        clearError();
      } else {
        throw Exception('更新模板失败');
      }

      return success;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '更新模板时出错', error: e);
      setError('更新模板失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 删除模板
  Future<bool> deleteTemplate(
    int id, {
    Function()? clearTemplateCache,
  }) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 先获取模板信息用于清除缓存
      final templateToDelete = await dataSource.getTemplateById(id);

      if (templateToDelete == null) {
        LogManager.e('MedicalRecordTemplateService',
            'MedicalRecordTemplateService: 错误：找不到要删除的模板，ID',
            error: id);
        return false;
      }

      final success = await dataSource.deleteTemplate(id);

      if (success) {
        clearTemplateCache?.call();
        markTemplatesNeedRefresh();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (syncService.needsSync) {
          syncService.syncDeleteTemplateToMySQL(id);
        }

        clearError();
        notifyListeners();
      } else {
        throw Exception('删除模板失败');
      }

      return success;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '删除模板时出错', error: e);
      setError('删除模板失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 初始化默认模板
  Future<bool> initializeDefaultTemplates({
    Function()? clearTemplateCache,
  }) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      final success = await dataSource.initializeDefaultTemplates();

      if (success) {
        // 清除所有模板缓存
        clearTemplateCache?.call();

        clearError();
        notifyListeners();
      } else {
        throw Exception('初始化默认模板失败');
      }

      return success;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '初始化默认模板时出错', error: e);
      setError('初始化默认模板失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 检查是否有模板数据
  Future<bool> hasTemplateData() async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      final hasData = await dataSource.hasTemplateData();
      clearError();
      return hasData;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '检查模板数据时出错', error: e);
      setError('检查模板数据失败: $e');
      return false;
    }
  }

  /// 获取疾病选项（供病历表单使用）
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      // 强制刷新模板数据，不使用缓存
      final templates = await dataSource.getTemplatesByCategory(category);
      final Map<String, List<String>> options = {};

      for (final template in templates) {
        if (template.isMainType) {
          // 主疾病类型
          if (!options.containsKey(template.name)) {
            options[template.name] = [];
          }
        } else {
          // 子类型
          final parentName = template.parentName;
          if (parentName == null) continue;
          final list = options.putIfAbsent(parentName, () => []);
          list.add(template.name);
        }
      }

      clearError();
      return options;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '获取疾病选项时出错', error: e);
      setError('获取疾病选项失败: $e');
      return {};
    }
  }

  /// 搜索模板
  Future<List<MedicalRecordTemplate>> searchTemplates(
      String category, String query) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      final templates = await dataSource.searchTemplates(category, query);
      clearError();
      return templates;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '搜索模板时出错', error: e);
      setError('搜索模板失败: $e');
      return [];
    } finally {
      setLoading(false);
    }
  }

  /// 检查模板是否有关联记录
  Future<bool> hasRelatedRecords(int templateId) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      final hasRelated = await dataSource.hasRelatedRecords(templateId);
      clearError();
      return hasRelated;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '检查模板关联记录时出错', error: e);
      setError('检查模板关联记录失败: $e');
      return false;
    }
  }

  /// 获取所有类别的模板数据（用于初始化）
  Future<Map<String, List<MedicalRecordTemplate>>> getAllTemplates({
    bool forceRefresh = false,
    Map<String, List<MedicalRecordTemplate>>? cachedTemplates,
    DateTime? lastTemplateCacheTime,
    Duration cacheValidDuration = const Duration(minutes: 20),
    Function(String, List<MedicalRecordTemplate>)? updateTemplateCache,
  }) async {
    try {
      setLoading(true);

      final Map<String, List<MedicalRecordTemplate>> allTemplates = {};

      // 获取所有类别的模板
      for (final category in MedicalRecordTemplateCategory.all) {
        final templates = await getTemplatesByCategory(
          category,
          forceRefresh: forceRefresh,
          cachedTemplates: cachedTemplates,
          lastTemplateCacheTime: lastTemplateCacheTime,
          cacheValidDuration: cacheValidDuration,
          updateTemplateCache: updateTemplateCache,
        );
        allTemplates[category] = templates;
      }

      clearError();
      return allTemplates;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '获取所有模板时出错', error: e);
      setError('获取所有模板失败: $e');
      return {};
    } finally {
      setLoading(false);
    }
  }

  /// 批量创建模板
  Future<List<int>> createTemplates(
    List<MedicalRecordTemplate> templates, {
    Map<String, List<MedicalRecordTemplate>>? cachedTemplates,
    Function()? clearTemplateCache,
  }) async {
    if (templates.isEmpty) {
      return [];
    }

    try {
      setLoading(true);

      final List<int> createdIds = [];
      final Set<String> affectedCategories = {};

      for (final template in templates) {
        final id = await createTemplate(
          template,
          cachedTemplates: cachedTemplates,
          clearTemplateCache: null, // 批量创建时不清除缓存，最后统一清除
        );
        createdIds.add(id);
        affectedCategories.add(template.category);
      }

      // 清除受影响类别的缓存
      for (final category in affectedCategories) {
        cachedTemplates?.remove(category);
      }

      clearError();
      notifyListeners();

      return createdIds;
    } catch (e) {
      LogManager.e('MedicalRecordTemplateService', '批量创建模板时出错', error: e);
      setError('批量创建模板失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 获取主疾病类型（没有父级的模板）
  Future<List<MedicalRecordTemplate>> getMainDiseaseTypes(
      String category) async {
    final templates = await getTemplatesByCategory(category);
    return templates.where((template) => template.isMainType).toList();
  }

  /// 获取子疾病类型（有父级的模板）
  Future<List<MedicalRecordTemplate>> getSubDiseaseTypes(
      String category, String parentName) async {
    final templates = await getTemplatesByCategory(category);
    return templates
        .where((template) =>
            template.isSubType && template.parentName == parentName)
        .toList();
  }
}
