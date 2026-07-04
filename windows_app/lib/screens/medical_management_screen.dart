import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/medical_record_provider.dart';
import '../models/medical_record_template.dart';
import '../features/medical_records/widgets/disease_type_edit_dialog.dart';
import '../features/medical_records/widgets/medical_template_initialize_confirm_dialog.dart';
import '../features/medical_records/widgets/medical_template_initialize_progress_dialog.dart';
import '../features/medical_records/widgets/medical_management_empty_state.dart';
import '../features/medical_records/widgets/medical_template_list_header.dart';
import '../features/medical_records/widgets/medical_template_type_card.dart';
import '../features/medical_records/services/medical_template_initialization_service.dart';
import '../widgets/success_toast.dart';
import '../widgets/mysql_connection_warning.dart';
import 'medical_template_management_screen.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../utils/log_manager.dart';

/// 病历管理界面
/// 包含三个标签页：牙科疾病、全身疾病、过敏类型
class MedicalManagementScreen extends StatefulWidget {
  const MedicalManagementScreen({Key? key}) : super(key: key);

  @override
  State<MedicalManagementScreen> createState() =>
      _MedicalManagementScreenState();
}

class _MedicalManagementScreenState extends State<MedicalManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  // 用于强制刷新的键
  int _refreshKey = 0;

  late MedicalTemplateInitializationService _initializationService;

  // 标签页配置
  final List<Map<String, dynamic>> _tabs = [
    {
      'title': '牙科疾病',
      'category': MedicalRecordTemplateCategory.dentalDisease,
      'icon': Icons.medical_services,
    },
    {
      'title': '全身疾病',
      'category': MedicalRecordTemplateCategory.systemicDisease,
      'icon': Icons.health_and_safety,
    },
    {
      'title': '过敏类型',
      'category': MedicalRecordTemplateCategory.allergy,
      'icon': Icons.warning_amber,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
    _initializationService = MedicalTemplateInitializationService(provider);

    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查医疗记录提供者中的刷新标志
    final medicalRecordProvider =
        Provider.of<MedicalRecordProvider>(context, listen: false);
    if (medicalRecordProvider.templatesNeedRefresh) {
      // 如果医疗记录数据需要刷新，则静默刷新当前标签页
      _refreshCurrentTab();
      // 重置刷新标志
      medicalRecordProvider.resetTemplatesRefreshFlag();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载指定类别的模板数据
  Future<List<MedicalRecordTemplate>> _loadTemplatesForCategory(
      String category) async {
    try {
      final provider =
          Provider.of<MedicalRecordProvider>(context, listen: false);

      // 优先使用缓存，必要时由 provider 自行回源
      final templates = await provider.getTemplatesByCategory(category);

      return templates;
    } catch (e) {
      LogManager.e('MedicalManagementScreen',
          'MedicalManagementScreen._loadTemplatesForCategory: 加载模板数据失败',
          error: e);
      return [];
    }
  }

  /// 初始化数据
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider =
          Provider.of<MedicalRecordProvider>(context, listen: false);

      // 等待数据源准备就绪
      int retryCount = 0;
      while (!provider.isDataSourceReady && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }

      if (!provider.isDataSourceReady) {
        LogManager.e('MedicalManagementScreen',
            'MedicalManagementScreen: 数据源未准备就绪，显示错误状态');
        setState(() {
          _isLoading = false;
          _errorMessage = '数据源未初始化，请重试';
        });
        return;
      }

      // 检查是否有模板数据
      final hasData = await provider.hasTemplateData();

      if (!hasData) {
        // 如果没有数据，不自动初始化，而是显示空状态让用户手动初始化
        setState(() {
          _isLoading = false;
          _errorMessage = null; // 不显示错误，显示空状态
        });
        return;
      }

      // 预加载所有类别的模板数据
      await provider.getAllTemplates(forceRefresh: true);

      // 数据加载完成
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      LogManager.e(
          'MedicalManagementScreen', 'MedicalManagementScreen: 初始化数据时出错',
          error: e);
      // 出错时也不显示错误状态，而是显示空状态让用户手动初始化
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化失败: $e'; // 显示具体错误信息
      });
    } finally {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.pageBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_information_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '病历管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: context.tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _refreshData,
              tooltip: '刷新数据',
            ),
          ),
          // 模板管理按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.tokens.secondaryAccent.withValues(alpha: 0.85),
                  context.tokens.secondaryAccent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon:
                  const Icon(Icons.library_books_rounded, color: Colors.white),
              onPressed: _openTemplateManagement,
              tooltip: '模板管理',
            ),
          ),
          // 初始化按钮
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.tokens.warning.withValues(alpha: 0.85),
                  context.tokens.warning,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_backup_restore_rounded,
                  color: Colors.white),
              onPressed: _showInitializeDialog,
              tooltip: '初始化',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MySQL Connection Warning
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: MySQLConnectionWarning(moduleName: '病历管理'),
          ),

          // Tab Bar Container - Compact margin
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.tokens.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: context.tokens.cardShadow,
            ),
            child: TabBar(
              controller: _tabController,
              padding: const EdgeInsets.all(4),
              indicator: BoxDecoration(
                color: context.tokens.selectedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: context.tokens.focusRing),
              ),
              labelColor: context.tokens.primaryAccent,
              unselectedLabelColor: context.colors.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: _tabs
                  .map((tab) => Tab(
                        height: 40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tab['icon'], size: 18),
                            const SizedBox(width: 6),
                            Text(tab['title']),
                          ],
                        ),
                      ))
                  .toList(),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),

          // Tab Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.tokens.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: context.tokens.elevatedShadow,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : TabBarView(
                          controller: _tabController,
                          children: _tabs
                              .map((tab) => _buildTabContent(
                                    tab['category'] as String,
                                    tab['title'] as String,
                                  ))
                              .toList(),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建错误显示组件
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: context.tokens.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '',
            style: TextStyle(
              fontSize: 16,
              color: context.tokens.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 构建标签页内容
  Widget _buildTabContent(String category, String title) {
    return FutureBuilder<List<MedicalRecordTemplate>>(
      key: ValueKey('${category}_$_refreshKey'), // 使用刷新键强制重建
      future: _loadTemplatesForCategory(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red[300]),
                
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _refreshCurrentTab(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final templates = snapshot.data ?? [];

        if (templates.isEmpty) {
          return MedicalManagementEmptyState(
            category: category,
            title: title,
            onInitialize: _showInitializeDialog,
            onAdd: () => _addDiseaseType(category),
          );
        }

        return _buildTemplateList(templates, category, title);
      },
    );
  }

  /// 构建模板列表
  Widget _buildTemplateList(
      List<MedicalRecordTemplate> templates, String category, String title) {
    // 按层级组织数据
    final mainTypes = templates.where((t) => t.isMainType).toList();
    final subTypes = <String, List<MedicalRecordTemplate>>{};

    for (final template in templates.where((t) => t.isSubType)) {
      final parentName = template.parentName;
      if (parentName == null) continue;
      if (!subTypes.containsKey(parentName)) {
        subTypes[parentName] = [];
      }
      subTypes[parentName]?.add(template);
    }

    return Column(
      children: [
        // 工具栏
        MedicalTemplateListHeader(
          category: category,
          title: title,
          count: templates.length,
          onAdd: () => _addDiseaseType(category),
        ),
        // 列表内容
        Expanded(
          child: ListView.builder(
            itemCount: mainTypes.length,
            itemBuilder: (context, index) {
              final mainType = mainTypes[index];
              final children = subTypes[mainType.name] ?? [];

              return MedicalTemplateTypeCard(
                mainType: mainType,
                children: children,
                category: category,
                onEdit: () => _handleMainTypeAction('edit', mainType, category),
                onDelete: () =>
                    _handleMainTypeAction('delete', mainType, category),
                onAddSubType: () => _addSubType(category, mainType.name),
                onSubTypeEdit: (subType) =>
                    _handleSubTypeAction('edit', subType, category),
                onSubTypeDelete: (subType) =>
                    _handleSubTypeAction('delete', subType, category),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用 Service 清除缓存
      _initializationService.clearTemplateCache();

      // 使用 Service 强制刷新所有模板数据
      await _initializationService.refreshAllTemplates();

      // 增加刷新键强制重建UI
      setState(() {
        _refreshKey++;
      });

      // 显示刷新成功提示
      if (mounted) {
        AppToastManager.showInfo(
          context,
          message: '数据刷新完成',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '刷新数据失败: $e';
      });

      // 显示刷新失败提示
      if (mounted) {
        AppToastManager.showError(
          context,
          message: '刷新数据失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 显示初始化对话框
  Future<void> _showInitializeDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MedicalTemplateInitializeConfirmDialog(
        onConfirm: _startInitialization,
      ),
    );
  }

  /// 开始初始化流程
  Future<void> _startInitialization() async {
    // 显示初始化进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MedicalTemplateInitializeProgressDialog(),
    );

    try {
      // 使用 Service 执行初始化
      final result = await _initializationService.executeInitialization();

      if (result['success'] == true) {
        // 重新加载数据
        if (mounted) {
          await _initializeData();

          if (!mounted) return;
          // 重置错误状态
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });

          // 关闭进度对话框
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }

          // 显示成功提示
          AppToastManager.showSuccess(
            context,
            message: '病历模板数据初始化完成！',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      LogManager.e('MedicalManagementScreen', '病历模板数据初始化过程中出现异常', error: e);

      if (!mounted) return;
      // 关闭进度对话框
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // 显示错误提示
      AppToastManager.showError(
        context,
        message: '初始化失败: $e',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// 添加疾病类型
  void _addDiseaseType(String category) {
    _showDiseaseTypeDialog(category: category);
  }

  /// 添加子类型
  void _addSubType(String category, String parentName) {
    _showDiseaseTypeDialog(category: category, parentName: parentName);
  }

  /// 显示疾病类型编辑对话框
  void _showDiseaseTypeDialog({
    String? category,
    String? parentName,
    MedicalRecordTemplate? template,
  }) {
    showDialog(
      context: context,
      builder: (context) => DiseaseTypeEditDialog(
        category: category ?? template?.category,
        parentName: parentName,
        template: template,
        onSaved: (savedTemplate) {
          _refreshCurrentTab();
        },
      ),
    );
  }

  /// 刷新当前标签页
  void _refreshCurrentTab() {
    // 增加刷新键并触发界面重建
    setState(() {
      _refreshKey++;
    });
  }

  /// 处理主类型操作
  void _handleMainTypeAction(
      String action, MedicalRecordTemplate template, String category) {
    switch (action) {
      case 'edit':
        _showDiseaseTypeDialog(template: template);
        break;
      case 'delete':
        _showDeleteConfirmDialog(template);
        break;
    }
  }

  /// 处理子类型操作
  void _handleSubTypeAction(
      String action, MedicalRecordTemplate template, String category) {
    switch (action) {
      case 'edit':
        _showDiseaseTypeDialog(template: template);
        break;
      case 'delete':
        _showDeleteConfirmDialog(template);
        break;
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(MedicalRecordTemplate template) async {
    String message;
    String title = '确认删除';

    if (template.isMainType) {
      // 使用 Service 获取子类型数量
      final allTemplates = await _initializationService
          .getTemplatesByCategory(template.category);
      final childCount = allTemplates
          .where((t) => t.parentName != null && t.parentName == template.name)
          .length;

      if (childCount > 0) {
        title = '确认删除主类型';
        message =
            '您确定要删除主类型"{itemName}"吗？\n\n⚠️ 警告：删除主类型将同时删除其下的 $childCount 个子类型！\n\n此操作不可撤销，请谨慎操作。';
      } else {
        message = '您确定要删除主类型"{itemName}"吗？\n此操作不可撤销。';
      }
    } else {
      message = '您确定要删除子类型"{itemName}"吗？\n此操作不可撤销。';
    }

    if (!mounted) return;
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: title,
      message: message,
      itemName: template.name,
      confirmText: '删除',
      cancelText: '取消',
    );

    if (confirmed) {
      if (!mounted) return;
      await _deleteTemplate(template);
    }
  }

  /// 删除模板
  Future<void> _deleteTemplate(MedicalRecordTemplate template) async {
    // 使用 Service 执行删除
    final result = await _initializationService.deleteTemplate(template);

    if (result['success'] == true) {
      if (!mounted) return;
      AppToastManager.showDelete(
        context,
        message: '已删除"${template.name}"',
        duration: const Duration(seconds: 2),
      );

      _refreshCurrentTab();
    } else {
      if (!mounted) return;
      AppToastManager.showError(
        context,
        message: '删除失败: ${result['error']}',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// 打开模板管理页面
  void _openTemplateManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MedicalTemplateManagementScreen(),
      ),
    );
  }
}
