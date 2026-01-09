import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/medical_record_provider.dart';
import '../models/medical_record_template.dart';
import '../widgets/disease_type_edit_dialog.dart';
import '../widgets/success_toast.dart';
import '../screens/medical_template_management_screen.dart';
import '../theme/app_theme.dart';

/// 病历管理界面
/// 包含三个标签页：牙科疾病、全身疾病、过敏类型
class MedicalManagementScreen extends StatefulWidget {
  const MedicalManagementScreen({Key? key}) : super(key: key);

  @override
  State<MedicalManagementScreen> createState() => _MedicalManagementScreenState();
}

class _MedicalManagementScreenState extends State<MedicalManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  
  // 用于强制刷新的键
  int _refreshKey = 0;

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
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查医疗记录提供者中的刷新标志
    final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
    if (medicalRecordProvider.templatesNeedRefresh) {
      // 如果医疗记录数据需要刷新，则重新加载
      _initializeData();
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
  Future<List<MedicalRecordTemplate>> _loadTemplatesForCategory(String category) async {
    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 使用forceRefresh参数避免缓存问题
      final templates = await provider.getTemplatesByCategory(category, forceRefresh: true);
      
      return templates;
    } catch (e) {
      print('MedicalManagementScreen._loadTemplatesForCategory: 加载模板数据失败: $e');
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
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 等待数据源准备就绪
      int retryCount = 0;
      while (!provider.isDataSourceReady && retryCount < 10) {
        print('MedicalManagementScreen: 等待数据源准备就绪... (尝试 ${retryCount + 1}/10)');
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }
      
      if (!provider.isDataSourceReady) {
        print('MedicalManagementScreen: 数据源未准备就绪，显示错误状态');
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
      print('MedicalManagementScreen: 初始化数据时出错: $e');
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
      backgroundColor: Colors.white,
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
          // 模板管理按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.library_books_rounded, color: Colors.white),
              onPressed: _openTemplateManagement,
              tooltip: '模板管理',
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
              tooltip: '初始化',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 标签页导航
          Container(
            color: const Color(0xFFF5F5F5), //浅灰色
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
              indicatorWeight: 3,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
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
                          tab['category'] as String,
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
          return _buildEmptyState(category, title);
        }

        return _buildTemplateList(templates, category, title);
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(String category, String title) {
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
              Icons.settings_backup_restore_rounded,
              size: 64,
              color: Colors.orange.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '病历模板数据未初始化',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '请点击右上角的初始化按钮来导入预设的疾病类型数据',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '包括牙科疾病、全身疾病和过敏类型等模板数据',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
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
                label: const Text('初始化模板数据'),
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
                onPressed: () => _addDiseaseType(category),
                icon: const Icon(Icons.add),
                label: const Text('手动添加'),
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
  Widget _buildTemplateList(List<MedicalRecordTemplate> templates, String category, String title) {

    
    // 按层级组织数据
    final mainTypes = templates.where((t) => t.isMainType).toList();
    final subTypes = <String, List<MedicalRecordTemplate>>{};
    

    
    for (final template in templates.where((t) => t.isSubType)) {
      final parentName = template.parentName!;
      if (!subTypes.containsKey(parentName)) {
        subTypes[parentName] = [];
      }
      subTypes[parentName]!.add(template);
    }
    


    return Column(
      children: [
        // 美化的工具栏
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getCategoryColor(category).withOpacity(0.1),
                _getCategoryColor(category).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getCategoryColor(category).withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // 图标和标题
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: _getCategoryColor(category),
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
                        color: _getCategoryColorDark(category),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${templates.length} 个疾病类型',
                      style: TextStyle(
                        fontSize: 14,
                        color: _getCategoryColorMedium(category),
                      ),
                    ),
                  ],
                ),
              ),
              // 添加按钮
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_getCategoryColor(category), _getCategoryColorMedium(category)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getCategoryColor(category).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _addDiseaseType(category),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    '添加类型',
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
            itemCount: mainTypes.length,
            itemBuilder: (context, index) {
              final mainType = mainTypes[index];
              final children = subTypes[mainType.name] ?? [];
              
              return _buildDiseaseTypeCard(mainType, children, category);
            },
          ),
        ),
      ],
    );
  }

  /// 构建疾病类型卡片 - 紧凑版
  Widget _buildDiseaseTypeCard(
    MedicalRecordTemplate mainType,
    List<MedicalRecordTemplate> children,
    String category,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getCategoryColor(category),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              mainType.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          mainType.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        subtitle: mainType.description.isNotEmpty
            ? Text(
                mainType.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 子类型数量徽章
            if (children.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 11,
                      color: _getCategoryColor(category),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${children.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _getCategoryColor(category),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            // 编辑按钮
            IconButton(
              onPressed: () => _handleMainTypeAction('edit', mainType, category),
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: Colors.blue,
              tooltip: '编辑',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // 删除按钮
            IconButton(
              onPressed: () => _handleMainTypeAction('delete', mainType, category),
              icon: const Icon(Icons.delete_outline, size: 16),
              color: Colors.red,
              tooltip: '删除',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // 展开图标
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: Colors.grey.shade600,
            ),
          ],
        ),
        children: [
          if (children.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...children.map((child) => _buildSubTypeListTile(child, category)),
          ],
          // 添加子类型按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: InkWell(
              onTap: () => _addSubType(category, mainType.name),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '添加子类型',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建子类型列表项
  Widget _buildSubTypeListTile(MedicalRecordTemplate subType, String category) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 子类型图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.subdirectory_arrow_right,
                color: _getCategoryColor(category),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            
            // 子类型信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subType.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (subType.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subType.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 编辑按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: () => _handleSubTypeAction('edit', subType, category),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: Colors.blue,
                    tooltip: '编辑',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ),
                const SizedBox(width: 6),
                // 删除按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: () => _handleSubTypeAction('delete', subType, category),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.red,
                    tooltip: '删除',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 获取类别颜色
  Color _getCategoryColor(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Colors.blue;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Colors.green;
      case MedicalRecordTemplateCategory.allergy:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// 获取类别颜色的深色变体
  Color _getCategoryColorDark(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Colors.blue.shade700;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Colors.green.shade700;
      case MedicalRecordTemplateCategory.allergy:
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  /// 获取类别颜色的中等变体
  Color _getCategoryColorMedium(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Colors.blue.shade600;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Colors.green.shade600;
      case MedicalRecordTemplateCategory.allergy:
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  /// 获取类别图标
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Icons.medical_services;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Icons.health_and_safety;
      case MedicalRecordTemplateCategory.allergy:
        return Icons.warning_amber;
      default:
        return Icons.category;
    }
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 清除缓存，确保从数据库获取最新数据
      provider.clearTemplateCache();
      
      // 强制从数据库重新加载所有模板数据
      await provider.getAllTemplates(forceRefresh: true);
      
      // 增加刷新键强制重建UI
      setState(() {
        _refreshKey++;
      });
      
      // 显示刷新成功提示
      if (mounted) {
        SuccessToastManager.showInfo(
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
        SuccessToastManager.showError(
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
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.orange.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
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
                    const Expanded(
                      child: Text(
                        '初始化病历模板数据',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.orange.shade600,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '此操作将初始化病历模板数据，包括：\n\n'
                              '• 牙科疾病类型（龋齿、牙周病、根尖周病等）\n'
                              '• 全身疾病类型（高血压、糖尿病、心脏病等）\n'
                              '• 过敏类型（药物过敏、食物过敏等）\n\n'
                              '⚠️ 重要提醒：此操作将清空现有模板数据并重新初始化！\n\n'
                              '✅ 安全提示：此操作不会影响现有的患者病历数据。\n\n'
                              '如果您需要重置病历模板数据，请执行此操作。',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade800,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 按钮栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => _startInitialization(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        '开始初始化',
                        style: TextStyle(
                          fontSize: 16,
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
      ),
    );
  }

  /// 开始初始化流程
  Future<void> _startInitialization(BuildContext dialogContext) async {
    // 关闭确认对话框
    Navigator.of(dialogContext).pop(true);
    
    // 显示初始化进度对话框
    _showInitializationProgressDialog();
    
    try {
      // 执行初始化
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      await provider.initializeDefaultTemplates();
      
      // 重新加载数据
      if (mounted) {
        await _initializeData();
        
        // 重置错误状态
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        
        // 关闭进度对话框
        _closeInitializationProgressDialog();
        
        // 显示成功提示
        SuccessToastManager.show(
          context,
          message: '病历模板数据初始化完成！',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('病历模板数据初始化过程中出现异常: $e');
      
      // 关闭进度对话框
      _closeInitializationProgressDialog();
      
      // 显示错误提示
      if (mounted) {
        SuccessToastManager.showError(
          context,
          message: '初始化失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// 显示初始化进度对话框
  void _showInitializationProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 加载动画
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                ),
              ),
              const SizedBox(height: 24),
              
              // 标题
              Text(
                '正在初始化病历模板数据...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // 描述
              Text(
                '请稍候，系统正在创建数据库表并初始化预设的疾病类型数据。\n此过程可能需要几秒钟时间。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 关闭初始化进度对话框
  void _closeInitializationProgressDialog() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  /// 初始化默认模板（保留原方法作为备用）
  Future<void> _initializeDefaultTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      await provider.initializeDefaultTemplates();
      
      SuccessToastManager.show(
        context,
        message: '预设数据初始化成功',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      setState(() {
        _errorMessage = '初始化预设数据失败: $e';
      });
      
      SuccessToastManager.showError(
        context,
        message: '初始化失败: $e',
        duration: const Duration(seconds: 4),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
    
    // 清除缓存
    provider.clearTemplateCache();
    
    // 增加刷新键并触发界面重建
    setState(() {
      _refreshKey++;
    });
  }

  /// 处理主类型操作
  void _handleMainTypeAction(String action, MedicalRecordTemplate template, String category) {
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
  void _handleSubTypeAction(String action, MedicalRecordTemplate template, String category) {
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
      // 获取子类型数量
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      final allTemplates = await provider.getTemplatesByCategory(template.category, forceRefresh: true);
      final childCount = allTemplates.where((t) => t.parentName == template.name).length;
      
      if (childCount > 0) {
        title = '确认删除主类型';
        message = '您确定要删除主类型"{itemName}"吗？\n\n⚠️ 警告：删除主类型将同时删除其下的 $childCount 个子类型！\n\n此操作不可撤销，请谨慎操作。';
      } else {
        message = '您确定要删除主类型"{itemName}"吗？\n此操作不可撤销。';
      }
    } else {
      message = '您确定要删除子类型"{itemName}"吗？\n此操作不可撤销。';
    }
    
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: title,
      message: message,
      itemName: template.name,
      confirmText: '删除',
      cancelText: '取消',
    );
    
    if (confirmed) {
      await _deleteTemplate(template);
    }
  }

  /// 删除模板
  Future<void> _deleteTemplate(MedicalRecordTemplate template) async {
    print('MedicalManagementScreen._deleteTemplate: 开始删除模板: ${template.name} (ID: ${template.id})');
    
    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      // 检查是否有关联记录
      final hasRelated = await provider.hasRelatedRecords(template.id!);
      
      if (hasRelated) {
        SuccessToastManager.showError(
          context,
          message: '无法删除：该疾病类型已被病历记录使用',
          duration: const Duration(seconds: 4),
        );
        return;
      }
      
      final deleteResult = await provider.deleteTemplate(template.id!);
      
      if (deleteResult) {
        DeleteSuccessToastManager.show(
          context,
          message: '已删除"${template.name}"',
          duration: const Duration(seconds: 2),
        );
        
        _refreshCurrentTab();
      } else {
        throw Exception('删除操作失败');
      }
    } catch (e) {
      print('MedicalManagementScreen._deleteTemplate: 删除过程中出错: $e');
      SuccessToastManager.showError(
        context,
        message: '删除失败: $e',
        duration: const Duration(seconds: 4),
      );
    }
  }



  /// 获取类别显示名称
  String _getCategoryDisplayName(String category) {
    return MedicalRecordTemplateCategory.getCategoryName(category);
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