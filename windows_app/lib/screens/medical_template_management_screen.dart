import 'package:flutter/material.dart';
import '../models/medical_template.dart';
import '../services/medical_template_service.dart';
import '../widgets/dental_icons.dart';
import '../features/medical_records/widgets/medical_template_edit_dialog.dart';
import '../features/medical_records/widgets/medical_template_card.dart';
import '../features/medical_records/widgets/medical_template_empty_state.dart';
import '../features/medical_records/widgets/medical_template_list.dart';
import '../features/medical_records/widgets/medical_template_initialize_dialog.dart';
import '../widgets/success_toast.dart';
import '../theme/app_theme.dart';

/// 医疗模板管理页面
/// 管理治疗方案模板和医嘱模板
class MedicalTemplateManagementScreen extends StatefulWidget {
  const MedicalTemplateManagementScreen({Key? key}) : super(key: key);

  @override
  State<MedicalTemplateManagementScreen> createState() => _MedicalTemplateManagementScreenState();
}

class _MedicalTemplateManagementScreenState extends State<MedicalTemplateManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  
  // 用于强制刷新的键
  int _refreshKey = 0;

  // 标签页配置
  final List<Map<String, dynamic>> _tabs = [
    {
      'title': '治疗方案模板',
      'type': MedicalTemplateType.treatment,
      'icon': Icons.healing_rounded,
    },
    {
      'title': '医嘱模板',
      'type': MedicalTemplateType.notes,
      'icon': Icons.note_add_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _checkTemplateData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 检查模板数据
  Future<void> _checkTemplateData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasData = await MedicalTemplateService.hasTemplateData();
      
      if (!hasData) {
        // 如果没有数据，显示空状态
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '检查模板数据失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.library_books_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '模板管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.withOpacity(0.15),
          ),
        ),
        actions: [
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _refreshData,
              tooltip: '刷新数据',
            ),
          ),

          // 初始化按钮
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.white),
              onPressed: _showInitializeDialog,
              tooltip: '初始化默认模板',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 标签页头部
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((tab) => Tab(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab['icon'], size: 20),
                    const SizedBox(width: 8),
                    Text(tab['title']),
                  ],
                ),
              )).toList(),
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 内容区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : TabBarView(
                        controller: _tabController,
                        children: _tabs.map((tab) => _buildTabContent(
                          tab['type'] as String,
                          tab['title'] as String,
                        )).toList(),
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
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkTemplateData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 构建标签页内容
  Widget _buildTabContent(String templateType, String title) {
    return FutureBuilder<List<MedicalTemplate>>(
      key: ValueKey('${templateType}_$_refreshKey'),
      future: MedicalTemplateService.getTemplates(templateType),
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
          return MedicalTemplateEmptyState(
            templateType: templateType,
            title: title,
            onInitialize: _showInitializeDialog,
            onAdd: () => _addTemplate(templateType),
          );
        }

        return MedicalTemplateList(
          templates: templates,
          templateType: templateType,
          title: title,
          onAdd: () => _addTemplate(templateType),
          onEdit: (template) => _handleTemplateAction('edit', template, templateType),
          onDelete: (template) => _handleTemplateAction('delete', template, templateType),
        );
      },
    );
  }




  /// 刷新数据
  Future<void> _refreshData() async {
    setState(() {
      _refreshKey++;
    });
    
    AppToastManager.showInfo(
      context,
      message: '数据刷新完成',
      duration: const Duration(seconds: 2),
    );
  }

  /// 刷新当前标签页
  void _refreshCurrentTab() {
    setState(() {
      _refreshKey++;
    });
  }

  /// 显示初始化对话框
  Future<void> _showInitializeDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MedicalTemplateInitializeDialog(
        onConfirm: _initializeDefaultTemplates,
      ),
    );
  }

  /// 初始化默认模板
  Future<void> _initializeDefaultTemplates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await MedicalTemplateService.initializeDefaultTemplates();
      
      setState(() {
        _isLoading = false;
        _refreshKey++;
      });
      
      AppToastManager.showSuccess(
        context,
        message: '默认模板初始化成功！',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      AppToastManager.showError(
        context,
        message: '初始化失败: $e',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// 添加模板
  void _addTemplate(String templateType) {
    _showTemplateDialog(templateType: templateType);
  }

  /// 显示模板编辑对话框
  void _showTemplateDialog({
    required String templateType,
    MedicalTemplate? template,
  }) {
    showDialog(
      context: context,
      builder: (context) => MedicalTemplateEditDialog(
        templateType: templateType,
        template: template,
        onSaved: (savedTemplate) {
          _refreshCurrentTab();
        },
      ),
    );
  }

  /// 处理模板操作
  void _handleTemplateAction(String action, MedicalTemplate template, String templateType) {
    switch (action) {
      case 'edit':
        _showTemplateDialog(templateType: templateType, template: template);
        break;
      case 'delete':
        _showDeleteConfirmDialog(template, templateType);
        break;
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(MedicalTemplate template, String templateType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('您确定要删除模板"${template.title}"吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTemplate(template, templateType);
    }
  }

  /// 删除模板
  Future<void> _deleteTemplate(MedicalTemplate template, String templateType) async {
    try {
      await MedicalTemplateService.deleteTemplate(templateType, template.id);
      
      AppToastManager.showSuccess(
        context,
        message: '已删除"${template.title}"',
        duration: const Duration(seconds: 2),
      );
      
      _refreshCurrentTab();
    } catch (e) {
      AppToastManager.showError(
        context,
        message: '删除失败: $e',
        duration: const Duration(seconds: 4),
      );
    }
  }

}