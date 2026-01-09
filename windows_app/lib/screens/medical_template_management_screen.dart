import 'package:flutter/material.dart';
import '../models/medical_template.dart';
import '../services/medical_template_service.dart';
import '../widgets/dental_icons.dart';
import '../widgets/medical_template_edit_dialog.dart';
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
          return _buildEmptyState(templateType, title);
        }

        return _buildTemplateList(templates, templateType, title);
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(String templateType, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Icon(
              templateType == MedicalTemplateType.treatment 
                  ? Icons.healing_rounded 
                  : Icons.note_add_rounded,
              size: 64,
              color: Colors.orange.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无${title}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '您可以添加自定义模板或初始化默认模板',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showInitializeDialog,
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('初始化默认模板'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _addTemplate(templateType),
                icon: const Icon(Icons.add),
                label: const Text('添加模板'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建模板列表
  Widget _buildTemplateList(List<MedicalTemplate> templates, String templateType, String title) {
    final isTreatment = templateType == MedicalTemplateType.treatment;
    final themeColor = isTreatment ? Colors.blue : Colors.green;
    
    return Column(
      children: [
        // 美化的工具栏
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor.withOpacity(0.1),
                themeColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: themeColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // 图标和标题
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTreatment ? Icons.healing_rounded : Icons.note_add_rounded,
                  color: themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getColorDark(themeColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${templates.length} 个模板',
                      style: TextStyle(
                        fontSize: 14,
                        color: _getColorMedium(themeColor),
                      ),
                    ),
                  ],
                ),
              ),
              // 添加按钮
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, _getColorMedium(themeColor)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _addTemplate(templateType),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    '添加模板',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 列表内容
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return _buildTemplateCard(template, templateType);
            },
          ),
        ),
      ],
    );
  }

  /// 构建模板卡片
  Widget _buildTemplateCard(MedicalTemplate template, String templateType) {
    final isTreatment = templateType == MedicalTemplateType.treatment;
    final cardColor = isTreatment ? Colors.blue : Colors.green;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: cardColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模板图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cardColor,
                    cardColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isTreatment 
                    ? Icons.healing_rounded 
                    : Icons.note_add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            
            // 模板信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模板标题
                  Text(
                    template.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 模板类型标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cardColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isTreatment ? '治疗方案模板' : '医嘱模板',
                      style: TextStyle(
                        fontSize: 12,
                        color: cardColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 模板内容预览
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      template.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // 操作按钮
            Column(
              children: [
                // 编辑按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => _handleTemplateAction('edit', template, templateType),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: Colors.blue,
                    tooltip: '编辑模板',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
                const SizedBox(height: 8),
                
                // 删除按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => _handleTemplateAction('delete', template, templateType),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    tooltip: '删除模板',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    setState(() {
      _refreshKey++;
    });
    
    SuccessToastManager.showInfo(
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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部 - 橙色背景
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_backup_restore_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '初始化默认模板',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '此操作将初始化默认的医疗模板，包括：',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 模板项列表
                    _buildTemplateItem('治疗方案模板', '洁牙、充填、根管治疗等', Icons.healing_rounded),
                    _buildTemplateItem('医嘱模板', '术后护理、用药指导等', Icons.note_add_rounded),
                    
                    const SizedBox(height: 20),
                    
                    // 警告提示
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '如果已有同名模板，将会被覆盖',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 底部按钮
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          '开始初始化',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _initializeDefaultTemplates();
    }
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
      
      SuccessToastManager.show(
        context,
        message: '默认模板初始化成功！',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      SuccessToastManager.showError(
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
      
      SuccessToastManager.show(
        context,
        message: '已删除"${template.title}"',
        duration: const Duration(seconds: 2),
      );
      
      _refreshCurrentTab();
    } catch (e) {
      SuccessToastManager.showError(
        context,
        message: '删除失败: $e',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// 获取颜色的深色变体
  Color _getColorDark(Color color) {
    if (color == Colors.blue) return Colors.blue.shade700;
    if (color == Colors.green) return Colors.green.shade700;
    if (color == Colors.orange) return Colors.orange.shade700;
    return Colors.grey.shade700;
  }

  /// 获取颜色的中等变体
  Color _getColorMedium(Color color) {
    if (color == Colors.blue) return Colors.blue.shade600;
    if (color == Colors.green) return Colors.green.shade600;
    if (color == Colors.orange) return Colors.orange.shade600;
    return Colors.grey.shade600;
  }

  // 构建模板项
  Widget _buildTemplateItem(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}