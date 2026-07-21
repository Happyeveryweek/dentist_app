import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/material.dart' as material_models;
import '../providers/material_provider.dart';
import '../widgets/dental_icons.dart';
import '../widgets/unified_search_field.dart';
import '../widgets/success_toast.dart';
import '../widgets/hoverable_list_card.dart';
import '../widgets/mysql_connection_warning.dart';
import '../features/materials/widgets/material_stat_card.dart';
import '../widgets/pagination_control.dart';
import '../features/materials/widgets/compact_material_action_button.dart';
import '../features/materials/widgets/dental_material_initialize_dialog.dart';
import '../features/materials/widgets/material_detail_dialog.dart';
import '../features/materials/widgets/material_form_dialog.dart';
import '../features/materials/services/material_initialization_service.dart';
import '../features/materials/services/material_filter_pagination_service.dart';
import '../utils/log_manager.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({Key? key}) : super(key: key);

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<material_models.MaterialInfo> _materials = [];
  List<material_models.MaterialInfo> _filteredMaterials = [];
  List<material_models.MaterialInfo> _displayedMaterials = []; // 当前页面显示的材料
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedType = '全部'; // 新增：选中的材料类型
  bool _isTypeHover = false; // 类型筛选悬停态
  late TextEditingController _searchController;

  // 分页相关变量
  int _currentPage = 1;
  final int _materialsPerPage = 10;
  int _totalMaterials = 0;
  int _totalPages = 0;

  // 筛选分页服务
  late MaterialFilterPaginationService _filterPaginationService;

  // 新增：材料类型列表
  final List<String> _materialTypes = [
    '全部',
    '药品',
    '局部麻醉药',
    '消毒用品',
    '一次性用品',
    '牙科材料',
    '牙科器械',
    '根管治疗器械',
    '牙科耗材',
    '正畸材料',
    '口腔护理用品',
    '防护用品',
    '办公用品',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    // 初始化筛选分页服务
    _filterPaginationService = MaterialFilterPaginationService(
      materialsPerPage: _materialsPerPage,
    );

    // 确保初始状态没有错误
    _hasError = false;
    _errorMessage = '';

    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查材料提供者中的刷新标志
    final materialProvider =
        Provider.of<MaterialProvider>(context, listen: false);
    if (materialProvider.materialsNeedRefresh) {
      // 如果材料数据需要刷新，则重新加载
      _loadData(showLoading: false, forceRefresh: true);
      // 重置刷新标志
      materialProvider.resetMaterialsRefreshFlag();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 尝试修复可能的编码混淆：有时数据库以 UTF-8 存储字节，但被当作 Latin1/单字节直接构造为 String 导致乱码
  // 策略：如果原始字符串不包含中文但对其 codeUnits 使用 utf8.decode 后包含中文，则返回解码后的结果
  String _fixMaybeDecoded(String? s) {
    if (s == null || s.isEmpty) return s ?? '';
    final original = s;
    final cjkRe = RegExp(r'[\u4e00-\u9fff]');
    final origHasCJK = cjkRe.hasMatch(original);
    if (origHasCJK) return original;

    try {
      final decoded = utf8.decode(original.codeUnits, allowMalformed: true);
      final decodedHasCJK = cjkRe.hasMatch(decoded);
      if (decodedHasCJK) return decoded;
    } catch (e) {
      // ignore
    }
    return original;
  }

  FilterResult _currentFilterResult() {
    return FilterResult(
      filteredMaterials: _filteredMaterials,
      displayedMaterials: _displayedMaterials,
      totalMaterials: _totalMaterials,
      totalPages: _totalPages,
      currentPage: _currentPage,
    );
  }

  void _applyFilterResult(FilterResult result) {
    setState(() {
      _filteredMaterials = result.filteredMaterials;
      _displayedMaterials = result.displayedMaterials;
      _totalMaterials = result.totalMaterials;
      _totalPages = result.totalPages;
      _currentPage = result.currentPage;
    });
  }

  Future<void> _loadData({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = ''; // 确保错误消息被清空
      });
    } else {
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      final materialProvider =
          Provider.of<MaterialProvider>(context, listen: false);
      final materials = await materialProvider.getAllMaterials(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      // 不再自动初始化材料，只在用户主动点击时才执行
      setState(() {
        _materials = materials;
        _isLoading = false;
        _hasError = false;
        _errorMessage = '';
      });

      // 重新应用当前筛选条件（保留用户选择的类型和搜索词，保留当前页）
      _filterMaterials(resetPage: false);

      // 打印调试信息
      LogManager.e('MaterialsScreen',
          '材料数据加载成功，错误状态已重置: _hasError=$_hasError, _errorMessage=');

      // 额外确保错误状态被重置
      if (_hasError || _errorMessage.isNotEmpty) {
        LogManager.e('MaterialsScreen', '检测到错误状态仍然存在，强制重置...');
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
        LogManager.e('MaterialsScreen',
            '强制重置后错误状态: _hasError=$_hasError, _errorMessage=');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = '加载材料数据失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 开始初始化流程
  Future<void> _startInitialization() async {
    // 显示初始化进度对话框
    _showInitializationProgressDialog();

    try {
      // 执行初始化
      final materialProvider =
          Provider.of<MaterialProvider>(context, listen: false);
      final initializationService = MaterialInitializationService(
        materialProvider: materialProvider,
      );

      final result = await initializationService.initializeDefaultMaterials();

      // 重新加载数据
      if (mounted) {
        await _loadData(showLoading: false, forceRefresh: true);

        if (!mounted) return;
        // 重置错误状态
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });

        // 显示成功提示
        if (result.success) {
          AppToastManager.showSuccess(context,
              message:
                  '材料数据初始化完成！成功 ${result.successCount} 个，失败 ${result.failCount} 个');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('初始化失败: ${result.error}'),
              backgroundColor: context.tokens.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      LogManager.e('MaterialsScreen', '材料数据初始化过程中出现异常', error: e);

      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化失败: $e'),
            backgroundColor: context.tokens.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _closeInitializationProgressDialog();
    }
  }

  /// 显示初始化进度对话框

  /// 关闭初始化进度对话框
  void _closeInitializationProgressDialog() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _filterMaterials({bool resetPage = true}) {
    final result = _filterPaginationService.filterMaterials(
      materials: _materials,
      selectedType: _selectedType,
      searchQuery: _searchQuery,
      currentPage: _currentPage,
      resetPage: resetPage,
    );
    _applyFilterResult(result);
  }

  // 跳转到指定页面
  void _goToPage(int page) {
    _applyFilterResult(
        _filterPaginationService.goToPage(_currentFilterResult(), page));
  }

  Future<void> _showMaterialDetail(
      material_models.MaterialInfo material) async {
    showDialog(
      context: context,
      builder: (context) => MaterialDetailDialog(
        material: material,
        onEdit: () => _showMaterialDialog(material),
        fixMaybeDecoded: _fixMaybeDecoded,
      ),
    );
  }

  // 构建现代化表单字段

  // 构建现代化下拉字段

  // 构建现代化下拉容器

  // 构建现代化单位下拉框

  // 构建类型筛选下拉框

  // 构建详情行

  Future<void> _deleteMaterial(material_models.MaterialInfo material) async {
    final confirmed = await DeleteConfirmDialogManager.showMaterialDelete(
      context,
      materialName: material.materialName,
    );

    if (confirmed == true) {
      try {
        final materialId = material.id;
        if (materialId == null) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '无法删除无 ID 的材料');
          return;
        }
        if (!mounted) return;
        final materialProvider =
            Provider.of<MaterialProvider>(context, listen: false);
        final success = await materialProvider.deleteMaterial(materialId);

        if (success) {
          await _loadData(showLoading: false);
          if (!mounted) return;
          AppToastManager.showDelete(context, message: '材料删除成功');
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('删除失败'),
              backgroundColor: context.tokens.error,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    }
  }

  // 紧凑型材料操作按钮

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                DentalIcons.pills,
                color: tokens.cardBackground,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '材料管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: context.tokens.shellBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: tokens.cardBackground),
              onPressed: () async {
                await _loadData(showLoading: false, forceRefresh: true);
                if (!context.mounted) return;
                // 使用公用成功提示组件
                AppToastManager.showSuccess(context, message: '数据已刷新');
              },
              tooltip: '刷新数据',
            ),
          ),
          // 初始化按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tokens.warning.withValues(alpha: 0.85),
                  tokens.warning,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.settings_backup_restore_rounded,
                  color: tokens.cardBackground),
              onPressed: () => _showInitializeDialog(),
              tooltip: '初始化默认材料',
            ),
          ),
          // 添加按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: tokens.cardBackground),
              onPressed: () => _showMaterialDialog(),
              tooltip: '添加材料',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MySQL连接状态检查
          const MySQLConnectionWarning(moduleName: '材料管理'),
          // 搜索栏和类型筛选（一行布局）
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.tokens.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.tokens.border),
                boxShadow: [
                  BoxShadow(
                      color: context.tokens.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  // 搜索栏 - 自适应长度
                  Expanded(
                    child: UnifiedSearchField(
                      controller: _searchController,
                      labelText: '搜索材料',
                      hintText: '输入材料名称、编码、供应商或描述',
                      prefixIcon: Icons.search_rounded,
                      searchQuery: _searchQuery,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _filterMaterials();
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _searchController.clear();
                        _filterMaterials();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 类型筛选器 - 靠右固定宽度
                  Container(
                    constraints: const BoxConstraints(minWidth: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_rounded,
                            color: context.tokens.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Text('类型:',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.colors.onSurface)),
                        const SizedBox(width: 12),
                        _buildModernTypeDropdown(
                          value: _selectedType,
                          items: _materialTypes,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                            });
                            _filterMaterials();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 统计信息 - 紧凑版
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_rounded,
                    label: '材料总数',
                    value: _filteredMaterials.length.toString(),
                    color: context.tokens.primaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money_rounded,
                    label: '总价值',
                    value:
                        '¥${_filteredMaterials.fold<double>(0.0, (sum, material) => sum + material.defaultPrice).toStringAsFixed(0)}',
                    color: context.tokens.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.category_rounded,
                    label: '类型数',
                    value: _filteredMaterials
                        .map((m) => m.materialType)
                        .toSet()
                        .length
                        .toString(),
                    color: context.tokens.primaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.business_rounded,
                    label: '供应商数',
                    value: _filteredMaterials
                        .map((m) => m.supplier)
                        .where((s) => s != null)
                        .toSet()
                        .length
                        .toString(),
                    color: context.tokens.warning,
                  ),
                ),
              ],
            ),
          ),

          // 分页信息显示

          const SizedBox(height: 16),

          // 材料列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_hasError && _errorMessage.isNotEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: context.tokens.error),
                            const SizedBox(height: 16),
                            Text(
                              '加载失败',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: context.tokens.error,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: context.tokens.textMuted,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _filteredMaterials.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.inventory_outlined
                                      : Icons.search_off,
                                  size: 64,
                                  color: context.tokens.iconMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? '暂无材料数据' : '未找到匹配的材料',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: context.tokens.textMuted,
                                      ),
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '点击"添加材料"开始创建您的第一个材料',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: context.tokens.textMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showMaterialDialog(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('添加材料'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // 材料列表
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _displayedMaterials.length,
                                  itemBuilder: (context, index) {
                                    return _buildMaterialCard(
                                        _displayedMaterials[index]);
                                  },
                                ),
                              ),

                              // 分页控件
                              if (_totalPages > 1) _buildPagination(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(material_models.MaterialInfo material) {
    return HoverableListCard(
      onTap: () => _showMaterialDetail(material),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.tokens.primaryAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              DentalIcons.pills,
              color: context.tokens.cardBackground,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  material.materialName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.tokens.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money,
                              size: 11, color: context.tokens.success),
                          const SizedBox(width: 3),
                          Text(
                            '¥${material.defaultPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.tokens.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.tokens.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory,
                              size: 11, color: context.tokens.info),
                          const SizedBox(width: 3),
                          Text(
                            material.unit,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.tokens.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.tokens.primaryAccent
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category_rounded,
                                size: 11, color: context.tokens.primaryAccent),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                material.materialType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: context.tokens.primaryAccent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (material.supplier != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                context.tokens.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business,
                                  size: 11, color: context.tokens.warning),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  material.supplier ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: context.tokens.warning,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompactMaterialActionButton(
                icon: Icons.visibility,
                color: context.tokens.info,
                tooltip: '查看',
                onPressed: () => _showMaterialDetail(material),
              ),
              const SizedBox(width: 6),
              CompactMaterialActionButton(
                icon: Icons.edit,
                color: context.tokens.warning,
                tooltip: '编辑',
                onPressed: () => _showMaterialDialog(material),
              ),
              const SizedBox(width: 6),
              CompactMaterialActionButton(
                icon: Icons.delete,
                color: context.tokens.error,
                tooltip: '删除',
                onPressed: () => _deleteMaterial(material),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return PaginationControl(
      currentPage: _currentPage,
      pageSize: _materialsPerPage,
      totalRecords: _totalMaterials,
      onPageChanged: _goToPage,
    );
  }

  // 构建类型筛选下拉框
  Widget _buildModernTypeDropdown({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isTypeHover = true),
      onExit: (_) => setState(() => _isTypeHover = false),
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (_selectedType != '全部' || _isTypeHover)
                ? context.tokens.primaryAccent.withValues(alpha: 0.6)
                : context.tokens.border,
            width: 1.5,
          ),
          boxShadow: [
            if (_isTypeHover)
              BoxShadow(
                color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: PopupMenuButton<String>(
          initialValue: value,
          onSelected: onChanged,
          constraints: const BoxConstraints(maxHeight: 320, minWidth: 240),
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
          itemBuilder: (context) => [
            // 标题栏
            PopupMenuItem<String>(
              enabled: false,
              height: 44,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: context.tokens.primaryHeaderGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category_rounded,
                        size: 18, color: context.tokens.cardBackground),
                    const SizedBox(width: 10),
                    Text(
                      '材料类型',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.cardBackground,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.tokens.cardBackground
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}项',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.tokens.cardBackground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 分割线
            const PopupMenuDivider(height: 1),
            // 选项列表
            ...items.map((type) {
              final isSelected = type == value;
              return PopupMenuItem<String>(
                value: type,
                height: 38,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.tokens.primaryAccent.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected
                              ? context.tokens.primaryHeaderGradient
                              : null,
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : context.tokens.border,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check,
                                size: 12, color: context.tokens.cardBackground)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? context.tokens.primaryAccent
                                : context.colors.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.tokens.primaryAccent
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '已选',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.tokens.primaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: (_selectedType != '全部' || _isTypeHover)
                        ? context.tokens.primaryAccent
                        : context.tokens.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedType,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (_selectedType != '全部' || _isTypeHover)
                          ? context.tokens.primaryAccent
                          : context.tokens.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: (_selectedType != '全部' || _isTypeHover)
                        ? context.tokens.primaryAccent
                        : context.tokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return MaterialStatCard(
      icon: icon,
      label: label,
      value: value,
      color: color,
    );
  }

  Future<void> _showInitializeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DentalMaterialInitializeDialog(),
    );

    if (confirmed == true) {
      await _startInitialization();
    }
  }

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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.tokens.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.tokens.warning),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '正在初始化材料数据...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.tokens.warning,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '请稍候，系统正在添加304种默认材料到数据库中。\n此过程可能需要几秒钟时间。',
                style: TextStyle(
                  fontSize: 14,
                  color: context.tokens.textMuted,
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

  Future<void> _showMaterialDialog(
      [material_models.MaterialInfo? material]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MaterialFormDialog(
        material: material,
        materialTypes: _materialTypes,
        onSuccess: () => _loadData(showLoading: false),
        fixMaybeDecoded: _fixMaybeDecoded,
      ),
    );

    if (result == true) {
      await _loadData(showLoading: false);
    }
  }
}

// 可悬浮的材料卡片组件
