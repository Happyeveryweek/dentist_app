import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/material.dart';
import '../../../providers/material_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/toast_manager.dart';
import '../services/material_catalog.dart';
import '../widgets/material_detail_sheet.dart';
import '../widgets/material_form_sheet.dart';
import '../widgets/material_type_filter_menu.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DentalMaterial> _materials = [];
  MaterialListQuery _query = filterMaterials(
    materials: [],
    selectedType: '全部',
    searchQuery: '',
  );
  String _selectedType = '全部';
  String _searchQuery = '';
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_query.hasMore || _isLoading) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_query.hasMore) return;
    setState(() {
      _query = loadMoreMaterials(_query);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  Future<void> _loadData({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final provider = context.read<MaterialProvider>();
      final ready = await provider.ensureReady();
      if (!ready) {
        throw Exception('数据库未初始化');
      }
      final materials = await provider.getAllMaterials(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
      _applyFilter(resetPage: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = '加载材料数据失败: $error';
        _isLoading = false;
      });
    }
  }

  void _applyFilter({required bool resetPage}) {
    setState(() {
      _query = filterMaterials(
        materials: _materials,
        selectedType: _selectedType,
        searchQuery: _searchQuery,
        currentPage: _query.currentPage,
        resetPage: resetPage,
      );
    });
    if (!resetPage) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _refresh() async {
    await _loadData(showLoading: false, forceRefresh: true);
    if (!mounted) return;
    SuccessToastManager.show(context, message: '刷新成功');
  }

  Future<void> _showTypeFilter() async {
    final selected = await showMaterialTypeFilter(
      context: context,
      value: _selectedType,
      items: materialTypeOptions,
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedType = selected);
    _applyFilter(resetPage: true);
  }

  Future<bool> _openForm(DentalMaterial? material) {
    return Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => MaterialFormPage(material: material),
          ),
        )
        .then((saved) => saved == true);
  }

  Future<void> _showForm({DentalMaterial? material}) async {
    final saved = await _openForm(material);
    if (!saved || !mounted) return;
    await _loadData(showLoading: false, forceRefresh: true);
    if (!mounted || _hasError) return;
    SuccessToastManager.show(
      context,
      message: material == null ? '材料添加成功' : '材料更新成功',
    );
  }

  Future<void> _showDetail(DentalMaterial material) async {
    final outcome = await Navigator.of(context).push<MaterialDetailOutcome>(
      MaterialPageRoute<MaterialDetailOutcome>(
        builder:
            (context) => MaterialDetailPage(
              material: material,
              onEdit: () => _openForm(material),
              onDelete: () => _deleteMaterial(material),
            ),
      ),
    );
    if (!mounted || outcome == null) return;
    await _loadData(showLoading: false, forceRefresh: true);
    if (!mounted || _hasError) return;
    if (outcome == MaterialDetailOutcome.deleted) {
      DeleteSuccessToastManager.show(context, message: '材料删除成功');
      return;
    }
    SuccessToastManager.show(context, message: '材料更新成功');
  }

  Future<void> _deleteFromList(DentalMaterial material) async {
    final confirmed = await confirmDeleteMaterial(context, material);
    if (!confirmed || !mounted) return;
    final deleted = await _deleteMaterial(material);
    if (!deleted || !mounted) return;
    await _loadData(showLoading: false, forceRefresh: true);
    if (!mounted || _hasError) return;
    DeleteSuccessToastManager.show(context, message: '材料删除成功');
  }

  Future<bool> _deleteMaterial(DentalMaterial material) async {
    final materialId = material.id;
    if (materialId == null) {
      SuccessToastManager.showError(context, message: '无法删除无 ID 的材料');
      return false;
    }

    try {
      final count = await context.read<MaterialProvider>().deleteMaterial(
        materialId,
      );
      if (!mounted) return false;
      if (count <= 0) {
        SuccessToastManager.showError(context, message: '删除失败');
        return false;
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      SuccessToastManager.showError(context, message: '删除失败: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = MaterialListStats.fromMaterials(_query.filtered);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: 'materials_add_button',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '输入材料名称、编码、供应商或描述',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchQuery.isEmpty
                        ? null
                        : IconButton(
                          tooltip: '清除',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _applyFilter(resetPage: true);
                          },
                          icon: const Icon(Icons.clear),
                        ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilter(resetPage: true);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showTypeFilter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.category_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '类型',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedType,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.inventory_rounded,
                        label: materialQuantityLabel(_selectedType),
                        value: stats.count.toString(),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.attach_money_rounded,
                        label: '总价值',
                        value: stats.totalValueText,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.category_rounded,
                        label: '类型数',
                        value: stats.typeCount.toString(),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.business_rounded,
                        label: '供应商数',
                        value: stats.supplierCount.toString(),
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _refresh,
                      child: _buildBody(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSummary() {
    final searching = _searchQuery.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey[50],
      child: Row(
        children: [
          Text(
            searching ? '搜索结果: ${_query.total} 条' : '共 ${_query.total} 条记录',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          Text(
            '第${_query.currentPage}页 | 已显示 ${_query.displayed.length} 条',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError && _errorMessage.isNotEmpty) {
      return _scrollableMessage(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_query.filtered.isEmpty) {
      final searching = _searchQuery.isNotEmpty;
      return _scrollableMessage(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.inventory_outlined,
              size: 64,
              color: AppTheme.lightText,
            ),
            const SizedBox(height: 16),
            Text(
              searching ? '未找到匹配的材料' : '暂无材料数据',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 8),
              const Text(
                '点击右下角添加材料',
                style: TextStyle(color: AppTheme.secondaryText),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildListSummary(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _query.displayed.length + (_query.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _query.displayed.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '已显示 ${_query.displayed.length} / ${_query.total} 条，向下滚动加载更多',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                );
              }
              final material = _query.displayed[index];
              return _MaterialCard(
                material: material,
                onOpen: () => _showDetail(material),
                onEdit: () => _showForm(material: material),
                onDelete: () => _deleteFromList(material),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _scrollableMessage({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Padding(padding: const EdgeInsets.all(24), child: child),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final DentalMaterial material;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final supplier = material.supplier;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.materialName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(
                          icon: Icons.attach_money,
                          text: '¥${material.defaultPrice.toStringAsFixed(0)}',
                          color: AppTheme.successColor,
                        ),
                        _Tag(
                          icon: Icons.inventory,
                          text: material.unit,
                          color: AppTheme.infoColor,
                        ),
                        _Tag(
                          icon: Icons.category_rounded,
                          text: material.materialType,
                          color: AppTheme.primaryColor,
                        ),
                        if (supplier != null && supplier.isNotEmpty)
                          _Tag(
                            icon: Icons.business,
                            text: supplier,
                            color: AppTheme.warningColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: AppTheme.warningColor),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete, color: AppTheme.errorColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
