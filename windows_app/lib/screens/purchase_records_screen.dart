import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../models/material.dart' as material_models;
import '../providers/purchase_provider.dart';
import '../providers/material_provider.dart';
import '../providers/database_provider.dart';
import '../providers/user_provider.dart';
import '../providers/app_state.dart';
import '../widgets/mysql_connection_warning.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/unified_search_field.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/purchase_export_dialog.dart';
import '../widgets/success_toast.dart';
import 'purchase_statistics_dialog.dart';

class PurchaseRecordsScreen extends StatefulWidget {
  const PurchaseRecordsScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseRecordsScreen> createState() => _PurchaseRecordsScreenState();
}

class _PurchaseRecordsScreenState extends State<PurchaseRecordsScreen> {
  List<PurchaseRecord> _purchaseRecords = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  late TextEditingController _searchController;

  // 分页状态
  int _currentPage = 1;
  final int _recordsPerPage = 10;
  int _totalRecords = 0;
  int _totalPages = 0;
  
  // 统计信息
  int _totalQuantity = 0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查采购提供者中的刷新标志
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    if (purchaseProvider.purchasesNeedRefresh) {
      // 如果采购数据需要刷新，则重新加载
      _loadData();
      // 重置刷新标志
      purchaseProvider.resetPurchasesRefreshFlag();
    }
  }

  // 分页控件（无日期过滤，仅搜索）
  Widget _buildPagination() {
    final totalPages = _totalPages > 0 ? _totalPages : 1;
    final String infoText = '每页 $_recordsPerPage 条 · 共 $_totalRecords 条 / $totalPages 页';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -2))],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页
          _pageIconButton(Icons.keyboard_arrow_left, enabled: _currentPage > 1, onTap: () {
            setState(() { _currentPage--; });
            _loadData();
          }),
          const SizedBox(width: 8),
          // 页码窗口（最多5个）
          ...List.generate(totalPages < 5 ? totalPages : 5, (i) {
            int pageNum;
            if (totalPages <= 5) {
              pageNum = i + 1;
            } else if (_currentPage <= 3) {
              pageNum = i + 1;
            } else if (_currentPage >= totalPages - 2) {
              pageNum = totalPages - 4 + i;
            } else {
              pageNum = _currentPage - 2 + i;
            }
            final bool active = pageNum == _currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: active ? null : () { setState(() { _currentPage = pageNum; }); _loadData(); },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40, height: 36, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? Theme.of(context).primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.25)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text('$pageNum', style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // 下一页
          _pageIconButton(Icons.keyboard_arrow_right, enabled: _currentPage < totalPages, onTap: () {
            setState(() { _currentPage++; });
            _loadData();
          }),
          const SizedBox(width: 16),
          // 信息块
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(infoText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _pageIconButton(IconData icon, {required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
          color: enabled ? Colors.white : Colors.grey.shade100,
        ),
        child: Icon(icon, size: 20, color: enabled ? Colors.black87 : Colors.grey),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 先获取总数
      final total = await purchaseProvider.getPurchaseRecordsCount(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      // 获取统计信息（所有记录的汇总）
      await _loadStatistics();
      
      // 计算总页数并校正当前页
      final computedTotalPages = (total / _recordsPerPage).ceil().clamp(1, 1 << 30);
      if (_currentPage > computedTotalPages && computedTotalPages > 0) {
        _currentPage = computedTotalPages;
      }
      
      // 再获取当前页
      List<PurchaseRecord> records = await purchaseProvider.getPurchaseRecords(
        page: _currentPage,
        pageSize: _recordsPerPage,
        sortBy: 'updated_at',
        sortOrder: 'DESC',
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      // 如果存在数据但当前页为空，回退到第一页重试
      if (records.isEmpty && total > 0 && _currentPage != 1) {
        _currentPage = 1;
        records = await purchaseProvider.getPurchaseRecords(
          page: _currentPage,
          pageSize: _recordsPerPage,
          sortBy: 'updated_at',
          sortOrder: 'DESC',
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
      }
      
      setState(() {
        _purchaseRecords = records;
        _totalRecords = total;
        _totalPages = computedTotalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '加载采购记录失败: $e';
        _isLoading = false;
      });
    }
  }

  // 加载统计信息
  Future<void> _loadStatistics() async {
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 如果没有搜索条件，获取所有记录统计
      if (_searchQuery.isEmpty) {
        final allRecords = await purchaseProvider.getAllPurchaseRecords();
        _totalQuantity = allRecords.fold<int>(0, (sum, record) => sum + record.totalQuantity);
        _totalAmount = allRecords.fold<double>(0.0, (sum, record) => sum + record.totalAmount);
      } else {
        // 有搜索条件时，获取所有记录然后过滤
        final allRecords = await purchaseProvider.getAllPurchaseRecords();
        final filteredRecords = allRecords.where((record) {
          final query = _searchQuery.toLowerCase();
          return (record.supplier?.toLowerCase().contains(query) ?? false) ||
                 (record.doctor?.toLowerCase().contains(query) ?? false) ||
                 (record.notes?.toLowerCase().contains(query) ?? false);
        }).toList();
        
        _totalQuantity = filteredRecords.fold<int>(0, (sum, record) => sum + record.totalQuantity);
        _totalAmount = filteredRecords.fold<double>(0.0, (sum, record) => sum + record.totalAmount);
      }
      
    } catch (e) {
      print('加载统计信息失败: $e');
      _totalQuantity = 0;
      _totalAmount = 0.0;
    }
  }

  void _applySearch(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<material_models.MaterialInfo?> _showMaterialSelectionDialog(BuildContext context) async {
    final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
    List<material_models.MaterialInfo> materials = [];
    final materialSearchController = TextEditingController();
    
    try {
      materials = await materialProvider.getAllMaterials();
    } catch (e) {
      print('加载材料数据失败: $e');
    }

    // 确保在弹窗关闭时 dispose 控制器
    final result = await showDialog<material_models.MaterialInfo>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 监听控制器以更新UI
          void listener() {
            setDialogState(() {});
          }
          materialSearchController.addListener(listener);

          final filteredMaterials = materials.where((material) {
            final query = materialSearchController.text.toLowerCase();
            if (query.isEmpty) return true;
            return material.materialName.toLowerCase().contains(query) ||
                   (material.materialCode?.toLowerCase().contains(query) ?? false);
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                width: 500,
                height: 600,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 标题栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '选择材料',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // 搜索框
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: materialSearchController,
                        decoration: InputDecoration(
                          hintText: '搜索材料 (名称/编码)',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: materialSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    materialSearchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    
                    // 材料列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = filteredMaterials[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                child: Icon(DentalIcons.pills, size: 20),
                              ),
                              title: Text(material.materialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('编码: ${material.materialCode ?? 'N/A'}'),
                              trailing: Text(
                                '¥${material.defaultPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop(material);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // 底部操作栏
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey[300]!),
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
        },
      ),
    );
    materialSearchController.dispose();
    return result;
  }

  Future<void> _showPurchaseRecordDialog([PurchaseRecord? record]) async {
    final isEditing = record != null;
    final dateController = TextEditingController(
      text: isEditing
        ? DateFormat('yyyy-MM-dd').format(record!.purchaseDate)
        : DateFormat('yyyy-MM-dd').format(DateTime.now())
    );
    final supplierController = TextEditingController(text: record?.supplier ?? '');
    
    // 设置医生字段的初始值
    String initialDoctorName = '';
    
    if (isEditing) {
      // 编辑模式：使用数据库中的值（可能为空）
      initialDoctorName = record?.doctor ?? '';
      print('编辑模式：使用数据库中的医生值: "${initialDoctorName}"');
    } else {
      // 新增模式：通过UserProvider获取当前用户信息作为默认值
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = userProvider.currentUser ?? await userProvider.getCurrentUser();
        
        if (currentUser != null && currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
          // 如果当前用户有医生姓名，使用它作为默认值
          initialDoctorName = currentUser.doctor!;
          print('新增模式：设置默认采购医生为: ${currentUser.doctor}');
        } else if (currentUser != null && currentUser.role == 'doctor') {
          // 如果是医生角色但没有设置医生姓名，使用用户名
          initialDoctorName = currentUser.username;
          print('新增模式：设置默认采购医生为用户名: ${currentUser.username}');
        } else {
          // 默认为空，让用户自己填写
          initialDoctorName = '';
          print('新增模式：当前用户没有医生姓名，采购医生字段留空');
        }
      } catch (e) {
        print('通过UserProvider获取当前用户信息失败: $e');
        initialDoctorName = '';
      }
    }
    
    final doctorController = TextEditingController(text: initialDoctorName);
    final notesController = TextEditingController(text: record?.notes ?? '');

    List<Map<String, dynamic>> purchaseItems = [];
    List<TextEditingController> materialNameControllers = [];
    List<TextEditingController> quantityControllers = [];
    List<TextEditingController> unitPriceControllers = [];
    List<TextEditingController> unitControllers = [];

    if (isEditing) {
      // 加载现有采购项目
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final items = await purchaseProvider.getPurchaseItemsByRecordId(record!.id!);
        print('编辑模式：成功加载采购项目 ${items.length} 项');
        for (final item in items) {
          purchaseItems.add({
            'materialId': item.materialId, // 保留材料ID
            'materialName': item.materialName,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
            'totalPrice': item.totalPrice,
            'unit': item.unit ?? '个',
          });
          materialNameControllers.add(TextEditingController(text: item.materialName));
          quantityControllers.add(TextEditingController(text: item.quantity.toString()));
          unitPriceControllers.add(TextEditingController(text: item.unitPrice == 0.0 ? '' : item.unitPrice.toString()));
          unitControllers.add(TextEditingController(text: item.unit ?? '个'));
        }
      } catch (e) {
        print('加载采购项目失败: $e');
        // 如果加载失败，显示提示信息
        purchaseItems.add({
          'materialId': null,
          'materialName': '加载失败，请重新添加',
          'quantity': 1,
          'unitPrice': 0.0,
          'totalPrice': 0.0,
          'unit': '个',
        });
        materialNameControllers.add(TextEditingController(text: '加载失败，请重新添加'));
        quantityControllers.add(TextEditingController(text: '1'));
        unitPriceControllers.add(TextEditingController(text: ''));
        unitControllers.add(TextEditingController(text: '个'));
      }
    }

    bool _isLoading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(DentalIcons.shoppingCart, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '采购记录详情',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 导出按钮
            Container(
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                onPressed: () {
                  if (record != null && record.id != null) {
                    // 将 Map 转换为 PurchaseItem 对象
                    final items = purchaseItems.map((item) => PurchaseItem(
                      id: null,
                      purchaseRecordId: record.id!,
                      materialName: item['materialName'] as String,
                      quantity: item['quantity'] as int,
                      unitPrice: item['unitPrice'] as double,
                      totalPrice: item['totalPrice'] as double,
                      unit: item['unit'] as String?,
                    )).toList();
                    _showExportDialog(record, items);
                  }
                },
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                tooltip: '导出为图片',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
              tooltip: '关闭',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
        content: Container(
          width: 700,
          height: 800,
          child: Column(
            children: [
              // 基本信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '基本信息',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        height: 48, // 调整为原来的三分之二
                        child: TextField(
                      controller: dateController,
                              decoration: InputDecoration(
                        labelText: '采购日期 *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[600]),
                                filled: true,
                                fillColor: Colors.white,
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDialog<DateTime>(
                          context: context,
                          builder: (context) => ModernDatePickerDialog(
                            initialDate: isEditing ? record!.purchaseDate : DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            title: '选择采购日期',
                          ),
                        );
                        if (date != null) {
                          dateController.text = DateFormat('yyyy-MM-dd').format(date);
                        }
                      },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                          child: Container(
                            height: 48, // 调整为原来的三分之二
                    child: TextField(
                      controller: supplierController,
                              decoration: InputDecoration(
                        labelText: '供应商',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.business, color: Colors.green[600]),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            child: TextField(
                              controller: doctorController,
                              decoration: InputDecoration(
                                labelText: '采购医生',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.person, color: Colors.purple[600]),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 48,
                            child: TextField(
                              controller: notesController,
                              decoration: InputDecoration(
                                labelText: '备注',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.note, color: Colors.orange[600]),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 采购项目区域
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                children: [
                        Icon(Icons.shopping_cart, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                    '采购项目',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setDialogState(() {
                            // 将新项目插入到列表最前面（索引0位置）
                            purchaseItems.insert(0, {
                              'materialId': null, // 初始化为null，选择材料后会更新
                              'materialName': '',
                              'quantity': 1,
                              'unitPrice': 0.0,
                              'totalPrice': 0.0,
                              'unit': '个',
                            });
                            // 对应的控制器也插入到最前面
                            materialNameControllers.insert(0, TextEditingController(text: ''));
                            quantityControllers.insert(0, TextEditingController(text: '1'));
                            unitPriceControllers.insert(0, TextEditingController(text: ''));
                            unitControllers.insert(0, TextEditingController(text: '个'));
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: Colors.blue.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '添加项目',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // 采购项目表头
              if (purchaseItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '材料名称',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '数量',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '单位',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '单价',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '总价',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '操作',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
                             // 采购项目列表
               Expanded(
                 child: purchaseItems.isEmpty
                     ? Container(
                         padding: const EdgeInsets.all(32),
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Container(
                               padding: const EdgeInsets.all(20),
                               decoration: BoxDecoration(
                                 color: Colors.grey.shade100,
                                 borderRadius: BorderRadius.circular(20),
                               ),
                               child: Icon(
                                 Icons.inventory_2_outlined,
                                 size: 48,
                                 color: Colors.grey.shade400,
                               ),
                             ),
                             const SizedBox(height: 16),
                             Text(
                               '暂无采购项目',
                               style: TextStyle(
                                 fontSize: 18,
                                 fontWeight: FontWeight.w600,
                                 color: Colors.grey.shade600,
                               ),
                             ),
                             const SizedBox(height: 8),
                             Text(
                               '点击"添加项目"开始添加采购项目',
                               style: TextStyle(
                                 fontSize: 14,
                                 color: Colors.grey.shade500,
                               ),
                             ),
                           ],
                         ),
                       )
                     : ListView.builder(
                         itemCount: purchaseItems.length,
                         itemBuilder: (context, index) {
                           final item = purchaseItems[index];
                           return Container(
                             margin: const EdgeInsets.only(bottom: 8),
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.grey.shade200),
                             ),
                             child: Row(
                               children: [
                                 // 材料名称
                                 Expanded(
                                   flex: 3,
                                   child: Row(
                                     children: [
                                       Expanded(
                                         child: Container(
                                           height: 40,
                                           decoration: BoxDecoration(
                                             color: Colors.grey.shade50,
                                             borderRadius: BorderRadius.circular(4),
                                           ),
                                           child: TextField(
                                             controller: materialNameControllers[index],
                                             decoration: const InputDecoration(
                                               hintText: '材料名称',
                                               border: InputBorder.none,
                                               enabledBorder: InputBorder.none,
                                               focusedBorder: InputBorder.none,
                                               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                             ),
                                             style: const TextStyle(fontSize: 14),
                                             onChanged: (value) {
                                               setDialogState(() {
                                                 item['materialName'] = value;
                                                 // 不在这里清除materialId，因为：
                                                 // 1. 如果是手动输入，materialId本来就是null
                                                 // 2. 如果是通过选择按钮，会在选择时设置materialId
                                               });
                                             },
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       InkWell(
                                         onTap: () async {
                                           final selectedMaterial = await _showMaterialSelectionDialog(context);
                                           if (selectedMaterial != null) {
                                             setDialogState(() {
                                               item['materialId'] = selectedMaterial.id; // 保存材料ID
                                               item['materialName'] = selectedMaterial.materialName;
                                               item['unit'] = selectedMaterial.unit;
                                               if (selectedMaterial.defaultPrice > 0) {
                                                 item['unitPrice'] = selectedMaterial.defaultPrice;
                                                 item['totalPrice'] = (item['quantity'] as int) * selectedMaterial.defaultPrice;
                                               }
                                               materialNameControllers[index].text = selectedMaterial.materialName;
                                               unitControllers[index].text = selectedMaterial.unit;
                                               if (selectedMaterial.defaultPrice > 0) {
                                                 unitPriceControllers[index].text = selectedMaterial.defaultPrice.toString();
                                               }
                                               print('选择材料: ${selectedMaterial.materialName}, materialId: ${selectedMaterial.id}');
                                             });
                                           }
                                         },
                                         child: Container(
                                           width: 32,
                                           height: 32,
                                           decoration: BoxDecoration(
                                             color: Colors.blue.shade100,
                                             borderRadius: BorderRadius.circular(4),
                                           ),
                                           child: Icon(Icons.search, size: 16, color: Colors.blue.shade600),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 // 数量
                                 Expanded(
                                   child: Container(
                                     height: 40,
                                     decoration: BoxDecoration(
                                       color: Colors.grey.shade50,
                                       borderRadius: BorderRadius.circular(4),
                                     ),
                                     child: TextField(
                                       controller: quantityControllers[index],
                                       decoration: const InputDecoration(
                                         hintText: '数量',
                                         border: InputBorder.none,
                                         enabledBorder: InputBorder.none,
                                         focusedBorder: InputBorder.none,
                                         contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                       ),
                                       style: const TextStyle(fontSize: 14),
                                       textAlign: TextAlign.center,
                                       keyboardType: TextInputType.number,
                                       onChanged: (value) {
                                         final quantity = int.tryParse(value) ?? 1;
                                         setDialogState(() {
                                           item['quantity'] = quantity;
                                           item['totalPrice'] = quantity * (item['unitPrice'] as double);
                                         });
                                       },
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 // 单位
                                 Expanded(
                                   child: Container(
                                     height: 40,
                                     decoration: BoxDecoration(
                                       color: Colors.grey.shade50,
                                       borderRadius: BorderRadius.circular(4),
                                     ),
                                     child: TextField(
                                       controller: unitControllers[index],
                                       decoration: const InputDecoration(
                                         hintText: '单位',
                                         border: InputBorder.none,
                                         enabledBorder: InputBorder.none,
                                         focusedBorder: InputBorder.none,
                                         contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                       ),
                                       style: const TextStyle(fontSize: 14),
                                       textAlign: TextAlign.center,
                                       onChanged: (value) {
                                         setDialogState(() {
                                           item['unit'] = value;
                                         });
                                       },
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 // 单价
                                 Expanded(
                                   child: Container(
                                     height: 40,
                                     decoration: BoxDecoration(
                                       color: Colors.grey.shade50,
                                       borderRadius: BorderRadius.circular(4),
                                     ),
                                     child: TextField(
                                       controller: unitPriceControllers[index],
                                       decoration: const InputDecoration(
                                         hintText: '单价',
                                         border: InputBorder.none,
                                         enabledBorder: InputBorder.none,
                                         focusedBorder: InputBorder.none,
                                         contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                       ),
                                       style: const TextStyle(fontSize: 14),
                                       textAlign: TextAlign.center,
                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                       onChanged: (value) {
                                         final unitPrice = double.tryParse(value) ?? 0.0;
                                         setDialogState(() {
                                           item['unitPrice'] = unitPrice;
                                           item['totalPrice'] = (item['quantity'] as int) * unitPrice;
                                         });
                                       },
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 // 总价
                                 Expanded(
                                   child: Container(
                                     height: 40,
                                     decoration: BoxDecoration(
                                       color: Colors.green.shade50,
                                       borderRadius: BorderRadius.circular(4),
                                     ),
                                     child: Align(
                                       alignment: Alignment.bottomCenter,
                                       child: Padding(
                                         padding: const EdgeInsets.only(bottom: 8),
                                         child: Text(
                                           '¥${item['totalPrice'].toStringAsFixed(2)}',
                                           style: TextStyle(
                                             color: Colors.green.shade700,
                                             fontWeight: FontWeight.w600,
                                             fontSize: 14,
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 // 删除按钮
                                 InkWell(
                                   onTap: () {
                                     setDialogState(() {
                                       purchaseItems.removeAt(index);
                                       materialNameControllers.removeAt(index);
                                       quantityControllers.removeAt(index);
                                       unitPriceControllers.removeAt(index);
                                       unitControllers.removeAt(index);
                                     });
                                   },
                                   child: Container(
                                     width: 32,
                                     height: 32,
                                     decoration: BoxDecoration(
                                       color: Colors.red.shade100,
                                       borderRadius: BorderRadius.circular(4),
                                     ),
                                     child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade600),
                                   ),
                                 ),
                               ],
                             ),
                           );
                         },
                       ),
               ),
            ],
          ),
        ),
                 actions: [
           // 取消按钮
           Container(
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [
                   Colors.grey.shade100,
                   Colors.grey.shade200,
                 ],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(
                 color: Colors.grey.withOpacity(0.25),
                 width: 1.5,
               ),
               boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(0.06),
                   blurRadius: 8,
                   offset: const Offset(0, 2),
                 ),
               ],
             ),
             child: Material(
               color: Colors.transparent,
               child: InkWell(
                 borderRadius: BorderRadius.circular(16),
                 onTap: () => Navigator.of(context).pop(false),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Container(
                         padding: const EdgeInsets.all(4),
                         decoration: BoxDecoration(
                           color: Colors.grey.withOpacity(0.15),
                           borderRadius: BorderRadius.circular(6),
                         ),
                         child: Icon(
                           Icons.close_rounded,
                           size: 16,
                           color: Colors.grey.shade600,
                         ),
                       ),
                       const SizedBox(width: 10),
                       Text(
                         '取消',
                         style: TextStyle(
                           fontSize: 15,
                           fontWeight: FontWeight.w700,
                           color: Colors.grey.shade700,
                           letterSpacing: 0.3,
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           ),
           const SizedBox(width: 16),
           // 保存/更新按钮
           Container(
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [
                   Colors.teal.shade400,
                   Colors.teal.shade600,
                 ],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               borderRadius: BorderRadius.circular(16),
               boxShadow: [
                 BoxShadow(
                   color: Colors.teal.withOpacity(0.3),
                   blurRadius: 12,
                   offset: const Offset(0, 4),
                 ),
               ],
             ),
             child: Material(
               color: Colors.transparent,
               child: InkWell(
                 borderRadius: BorderRadius.circular(16),
                 onTap: _isLoading ? null : () async {
               // 验证必填字段
               if (purchaseItems.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(
                     content: Text('请至少添加一个采购项目'),
                     backgroundColor: Colors.red,
                   ),
                 );
                 return;
               }

               // 验证采购项目
               for (int i = 0; i < purchaseItems.length; i++) {
                 final item = purchaseItems[i];
                        // 从控制器获取最新值
                        final materialName = materialNameControllers[i].text.trim();
                        final quantity = int.tryParse(quantityControllers[i].text) ?? 0;
                        final unitPrice = double.tryParse(unitPriceControllers[i].text) ?? 0.0;
                        final unit = unitControllers[i].text.trim();

                        if (materialName.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text('第${i + 1}个项目的材料名称不能为空'),
                       backgroundColor: Colors.red,
                     ),
                   );
                   return;
                 }
                        if (quantity <= 0) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text('第${i + 1}个项目的数量必须大于0'),
                       backgroundColor: Colors.red,
                     ),
                   );
                   return;
                 }
                        if (unitPrice < 0) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text('第${i + 1}个项目的单价不能为负数'),
                       backgroundColor: Colors.red,
                     ),
                   );
                   return;
                 }

                        // 更新数据结构（保留materialId，它在选择材料时已经设置）
                        item['materialName'] = materialName;
                        item['quantity'] = quantity;
                        item['unitPrice'] = unitPrice;
                        item['unit'] = unit;
                        item['totalPrice'] = quantity * unitPrice;
                        // 注意：item['materialId'] 保持不变，它在选择材料时已经被设置
               }

               // 设置加载状态
               setDialogState(() {
                 _isLoading = true;
               });

               try {
                 final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);

                 // 计算总数量和总金额
                 final totalQuantity = purchaseItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
                 final totalAmount = purchaseItems.fold<double>(0.0, (sum, item) => sum + (item['totalPrice'] as double));

                 // 创建采购记录
                 final purchaseRecord = PurchaseRecord(
                   id: record?.id,
                   purchaseDate: DateFormat('yyyy-MM-dd').parse(dateController.text),
                   totalQuantity: totalQuantity,
                   totalAmount: totalAmount,
                   supplier: supplierController.text.trim().isEmpty ? null : supplierController.text.trim(),
                   doctor: doctorController.text.trim().isEmpty ? null : doctorController.text.trim(),
                   notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                 );

                 bool success;
                 int? recordId;

                 if (isEditing) {
                   success = await purchaseProvider.updatePurchaseRecord(purchaseRecord);
                   recordId = record?.id;
                 } else {
                   recordId = await purchaseProvider.addPurchaseRecord(purchaseRecord);
                   success = recordId != null && recordId > 0;
                 }

                 if (success && recordId != null) {
                   // 获取旧的采购项目用于对比
                   List<PurchaseItem> oldItems = [];
                   if (isEditing) {
                     oldItems = await purchaseProvider.getPurchaseItemsByRecordId(recordId!);
                   }

                   // 创建新项目的映射（用于快速查找）
                   List<Map<String, dynamic>> itemsToAdd = [];
                   List<PurchaseItem> itemsToUpdate = [];
                   List<PurchaseItem> itemsToDelete = [];

                   // 处理所有新项目
                   for (final newItem in purchaseItems) {
                     if (newItem['materialName'].toString().contains('请重新添加') ||
                         newItem['materialName'].toString().contains('加载失败')) {
                       continue;
                     }

                     bool foundMatch = false;
                     for (final oldItem in oldItems) {
                       if (oldItem.materialName == newItem['materialName'].toString().trim()) {
                         // 检查是否有变化（数量、单价、单位、材料ID）
                         bool hasChanges = oldItem.quantity != newItem['quantity'] ||
                                         oldItem.unitPrice != newItem['unitPrice'] ||
                                         oldItem.unit != newItem['unit'] ||
                                         oldItem.materialId != newItem['materialId']; // 也检查materialId是否变化

                         if (hasChanges) {
                            // 更新现有项目，更新内容和时间戳
                            print('更新采购项目: ${newItem['materialName']}, 旧materialId: ${oldItem.materialId}, 新materialId: ${newItem['materialId']}');
                            final updatedItem = PurchaseItem(
                              id: oldItem.id,
                              purchaseRecordId: recordId!,
                              materialId: newItem['materialId'] as int?, // 直接使用新的materialId（可能是null或新选择的ID）
                              materialName: newItem['materialName'].toString().trim(),
                              quantity: newItem['quantity'] as int,
                              unitPrice: newItem['unitPrice'] as double,
                              totalPrice: newItem['totalPrice'] as double,
                              unit: newItem['unit'] as String?,
                              createdAt: oldItem.createdAt,
                              updatedAt: DateTime.now(), // 更新为当前本地时间
                            );
                            itemsToUpdate.add(updatedItem);
                          }

                         // 从oldItems中移除已处理的项目
                         oldItems.remove(oldItem);
                         foundMatch = true;
                         break;
                       }
                     }

                     if (!foundMatch) {
                       // 新增项目
                       itemsToAdd.add(newItem);
                     }
                   }

                   // 剩下的oldItems是需要删除的项目
                   itemsToDelete.addAll(oldItems);

                   // 执行删除操作（不更新时间戳）
                   for (final itemToDelete in itemsToDelete) {
                     await purchaseProvider.deletePurchaseItem(itemToDelete.id!);
                   }
                   if (itemsToDelete.isNotEmpty) {
                     print('已删除采购项目: ${itemsToDelete.length} 项');
                   }

                   // 执行更新操作（更新时间戳）
                    for (final itemToUpdate in itemsToUpdate) {
                      await purchaseProvider.updatePurchaseItem(itemToUpdate);
                    }
                    if (itemsToUpdate.isNotEmpty) {
                      print('已更新采购项目: ${itemsToUpdate.length} 项（更新时间戳）');
                    }

                   // 执行添加操作（设置更新时间）
                   for (final itemToAdd in itemsToAdd) {
                     final purchaseItem = PurchaseItem(
                       purchaseRecordId: recordId!,
                       materialId: itemToAdd['materialId'] as int?, // 保存材料ID
                       materialName: itemToAdd['materialName'].toString().trim(),
                       quantity: itemToAdd['quantity'] as int,
                       unitPrice: itemToAdd['unitPrice'] as double,
                       totalPrice: itemToAdd['totalPrice'] as double,
                       unit: itemToAdd['unit'] as String?,
                       createdAt: DateTime.now(),
                       updatedAt: DateTime.now(),
                     );
                     await purchaseProvider.addPurchaseItem(purchaseItem);
                   }
                   if (itemsToAdd.isNotEmpty) {
                     print('已添加采购项目: ${itemsToAdd.length} 项（设置更新时间）');
                   }

                   print('采购项目处理完成 - 删除: ${itemsToDelete.length}, 更新: ${itemsToUpdate.length}, 添加: ${itemsToAdd.length}');

                   Navigator.of(context).pop(true);
                   SuccessToastManager.show(context, message: isEditing ? '采购记录更新成功' : '采购记录添加成功');
                 } else {
                   Navigator.of(context).pop();
                   SuccessToastManager.showError(context, message: '保存失败');
                 }
               } catch (e) {
                 Navigator.of(context).pop();
                 SuccessToastManager.showError(context, message: '保存失败: $e');
               } finally {
                 // 重置加载状态
                 setDialogState(() {
                   _isLoading = false;
                 });
               }
                 },
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       if (_isLoading) ...[
                         SizedBox(
                           width: 16,
                           height: 16,
                           child: CircularProgressIndicator(
                             color: Colors.white,
                             strokeWidth: 2,
                           ),
                         ),
                         const SizedBox(width: 10),
                         Text(
                           isEditing ? '更新中...' : '保存中...',
                           style: const TextStyle(
                             fontSize: 14,
                             fontWeight: FontWeight.w600,
                             color: Colors.white,
                           ),
                         ),
                       ] else ...[
                         Icon(
                           isEditing ? Icons.update : Icons.add,
                           size: 16,
                           color: Colors.white,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           isEditing ? '更新记录' : '添加记录',
                           style: const TextStyle(
                             fontSize: 14,
                             fontWeight: FontWeight.w600,
                             color: Colors.white,
                           ),
                         ),
                       ],
                     ],
                   ),
                 ),
               ),
             ),
           ),
         ],
       ),
     ));

    // 对话框关闭后刷新数据
      _loadData();
    }

  Future<void> _showPurchaseDetail(PurchaseRecord record) async {
    // 获取该采购记录的所有采购项目
    List<PurchaseItem> purchaseItems = [];
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      purchaseItems = await purchaseProvider.getPurchaseItemsByRecordId(record.id!);
      print('成功加载采购项目: ${purchaseItems.length} 项');
    } catch (e) {
      print('加载采购项目失败: $e');
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(DentalIcons.shoppingCart, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text('采购记录详情'),
            ),
            // 导出按钮
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => _showExportDialog(record, purchaseItems),
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                tooltip: '导出为图片',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: '关闭',
            ),
          ],
        ),
        content: Container(
          width: 700,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 采购记录基本信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        DentalIcons.shoppingCart,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '采购记录 #${record.id}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('采购日期: ${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}'),
                          if (record.supplier != null) Text('供应商: ${record.supplier}'),
                          if (record.doctor != null) Text('采购医生: ${record.doctor}'),
                          if (record.notes != null) Text('备注: ${record.notes}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 采购统计信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.inventory,
                        label: '总采购数量',
                        value: '${record.totalQuantity}',
                        color: Colors.green[700]!,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.attach_money,
                        label: '总采购金额',
                        value: '¥${record.totalAmount.toStringAsFixed(2)}',
                        color: Colors.blue[700]!,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.shopping_cart,
                        label: '采购项目数',
                        value: '${purchaseItems.length}',
                        color: Colors.orange[700]!,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 采购项目列表标题
              Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '采购项目明细 (${purchaseItems.length}项)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _showPurchaseRecordDialog(record);
                      // 编辑完成后重新显示详情页面
                      _showPurchaseDetail(record);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('编辑记录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // 采购项目列表
              Expanded(
                child: purchaseItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无采购项目',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击上方按钮编辑记录添加采购项目',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // 表头
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '材料名称',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '数量',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '单价',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '单位',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '总价',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 项目列表
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: purchaseItems.length,
                              itemBuilder: (context, index) {
                                final item = purchaseItems[index];
                                return _buildDetailItemCard(item);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItemCard(PurchaseItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 材料名称
            Expanded(
              flex: 3,
              child: Text(
                item.materialName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 数量
            Expanded(
              flex: 1,
              child: Text(
                '${item.quantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 单价
            Expanded(
              flex: 1,
              child: Text(
                '¥${item.unitPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 单位
            Expanded(
              flex: 1,
              child: Text(
                item.formattedUnit,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 总价
            Expanded(
              flex: 1,
              child: Text(
                '¥${item.totalPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePurchaseRecord(PurchaseRecord record) async {
    final confirmed = await DeleteConfirmDialogManager.showPurchaseRecordDelete(
      context,
      purchaseInfo: '采购记录 "${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}"',
    );

    if (confirmed == true) {
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final success = await purchaseProvider.deletePurchaseRecord(record.id!);
        
        if (success) {
          _loadData();
          DeleteSuccessToastManager.show(context, message: '采购记录删除成功');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPurchaseRecordCard(PurchaseRecord record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return _HoverablePurchaseRecordCard(
      onTap: () => _showPurchaseDetail(record),
      isPurpleTheme: isPurpleTheme,
      child: Row(
              children: [
                // 采购图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    DentalIcons.shoppingCart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 采购信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 第一行：日期和供应商
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 11, color: Colors.blue[700]),
                                const SizedBox(width: 3),
                                Text(
                                  DateFormat('yyyy-MM-dd').format(record.purchaseDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (record.supplier != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.business, size: 11, color: Colors.orange[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.supplier!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (record.doctor != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person, size: 11, color: Colors.purple[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.doctor!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.purple[700],
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
                      
                      const SizedBox(height: 6),
                      
                      // 第二行：数量和金额
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory, size: 11, color: Colors.green[700]),
                                const SizedBox(width: 3),
                                Text(
                                  '数量: ${record.totalQuantity}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_money, size: 11, color: Colors.red[700]),
                                const SizedBox(width: 3),
                                Text(
                                  '¥${record.totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (record.notes != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.note, size: 11, color: Colors.grey[600]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.notes!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
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
                
                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactActionButton(
                      icon: Icons.visibility,
                      color: Colors.blue,
                      tooltip: '查看',
                      onPressed: () => _showPurchaseDetail(record),
                    ),
                    const SizedBox(width: 6),
                    _buildCompactActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      tooltip: '编辑',
                      onPressed: () => _showPurchaseRecordDialog(record),
                    ),
                    const SizedBox(width: 6),
                    _buildCompactActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      tooltip: '删除',
                      onPressed: () => _deletePurchaseRecord(record),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // 紧凑型操作按钮
  Widget _buildCompactActionButton({
    required IconData icon,
    required MaterialColor color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color[600]),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: DentalColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                gradient: DentalColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                DentalIcons.shoppingCart,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '采购管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () async {
                await _loadData();
                // 使用公用成功提示组件
                SuccessToastManager.show(context, message: '数据已刷新');
              },
              tooltip: '刷新数据',
            ),
          ),
          // 添加按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => _showPurchaseRecordDialog(),
              tooltip: '添加采购记录',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: DentalColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.success.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: DentalColors.success,
              ),
              onPressed: _showPurchaseChart,
              tooltip: '采购图表统计',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MySQL连接状态检查
          Consumer<AppState>(
            builder: (context, appState, _) {
              if (!appState.isMySQLConnected) {
                return const MySQLConnectionWarning(moduleName: '采购管理');
              }
              return const SizedBox.shrink();
            },
          ),
          
          // 搜索栏（白色模块容器包裹）
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
              children: [
                Expanded(
                  child: UnifiedSearchField(
                    controller: _searchController,
                    hintText: '输入供应商、医生或备注信息',
                    labelText: '搜索采购记录',
                    prefixIcon: Icons.search_rounded,
                    searchQuery: _searchQuery,
                    onChanged: (value) {
                      _applySearch(value);
                    },
                    onClear: () {
                      setState(() { _searchQuery = ''; _currentPage = 1; });
                      _searchController.clear();
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
            ),
          ),
          
          // 统计信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_cart_rounded,
                    label: '采购记录数',
                    value: _totalRecords.toString(),
                    color: DentalColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_rounded,
                    label: '总采购数量',
                    value: _totalQuantity.toString(),
                    color: DentalColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money_rounded,
                    label: '总采购金额',
                    value: '¥${_totalAmount.toStringAsFixed(2)}',
                    color: DentalColors.warning,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 采购记录列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.red[300],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.red[300],
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
                        ),
                      )
                    : _purchaseRecords.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isEmpty ? Icons.shopping_cart_outlined : Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty ? '暂无采购记录' : '未找到匹配的采购记录',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '点击"添加采购记录"开始创建您的第一个采购记录',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => _showPurchaseRecordDialog(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('添加采购记录'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _purchaseRecords.length,
                                  itemBuilder: (context, index) {
                                    return _buildPurchaseRecordCard(_purchaseRecords[index]);
                                  },
                                ),
                              ),
                              _buildPagination(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchaseChart() async {
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    final allRecords = await purchaseProvider.getAllPurchaseRecords();

    // 移除数据为空时的弹窗提示，直接显示统计页面
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 5 / 6,
              height: MediaQuery.of(context).size.height * 5 / 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PurchaseStatsDialog(
                  purchaseRecords: allRecords,
                  purchaseProvider: purchaseProvider,
                ),
              ),
            ),
          );
        },
      );
    }
  }
  
  Widget _buildPurchaseChart(List<PurchaseRecord> records) {
    // 按月份统计采购金额和数量
    final Map<String, double> monthlyData = {};
    final Map<String, int> monthlyCount = {};
    final Map<String, int> monthlyQuantity = {};
    
    // 材料统计
    final Map<String, double> materialData = {};
    final Map<String, int> materialCount = {};
    
    double totalAmount = 0;
    int totalQuantity = 0;
    int totalRecords = records.length;
    
    for (final record in records) {
      final date = record.purchaseDate;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      // 月度统计
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + record.totalAmount;
      monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
      monthlyQuantity[monthKey] = (monthlyQuantity[monthKey] ?? 0) + record.totalQuantity;
      
      // 材料统计（通过采购项目统计）
      // 这里我们使用供应商名称作为材料分类，实际项目中可能需要从采购项目表获取
      if (record.supplier != null) {
        materialData[record.supplier!] = (materialData[record.supplier!] ?? 0) + record.totalAmount;
        materialCount[record.supplier!] = (materialCount[record.supplier!] ?? 0) + 1;
      }
      
      // 累计统计
      totalAmount += record.totalAmount;
      totalQuantity += record.totalQuantity;
    }
    
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // 总体统计卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: '总采购金额',
                    value: '¥${totalAmount.toStringAsFixed(2)}',
                    color: Colors.blue[700]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory,
                    label: '总采购数量',
                    value: totalQuantity.toString(),
                    color: Colors.green[700]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_cart,
                    label: '采购记录数',
                    value: totalRecords.toString(),
                    color: Colors.orange[700]!,
                  ),
                ),
                const SizedBox(width: 16),
                                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _buildMaterialRankingChart(records),
                          builder: (context, snapshot) {
                            String value = '计算中...';
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              value = snapshot.data!.length.toString();
                            }
                            
                            return _buildStatCard(
                              icon: Icons.inventory,
                              label: '材料种类数',
                              value: value,
                              color: Colors.purple[700]!,
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          const SizedBox(height: 24),
          
          // 月度采购金额统计
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '月度采购金额趋势',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: sortedMonths.map((month) {
                      final amount = monthlyData[month] ?? 0;
                      final maxAmount = monthlyData.values.isEmpty ? 1.0 : monthlyData.values.reduce((a, b) => a > b ? a : b);
                      final height = maxAmount > 0 ? (amount / maxAmount) * 150 : 0.0;
                      
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 30,
                              height: height,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              month,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '¥${amount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          const SizedBox(height: 24),
          

          
          // 采购材料统计排行
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.purple[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '采购材料统计排行 (前10名)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(按金额排序)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buildMaterialRankingChart(records),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('暂无材料数据', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    
                                        final materialData = snapshot.data!;
                    final maxAmount = materialData.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b);
                    
                    return Column(
                      children: [
                        // 表头
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  '材料名称',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  '占比',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '金额',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '数量',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '占比',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 数据行
                        Column(
                          children: materialData.take(10).map((item) {
                            final amount = item['amount'] as double;
                            final quantity = item['quantity'] as int;
                            final percentage = maxAmount > 0 ? (amount / maxAmount) * 100 : 0.0;
                        
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // 材料名称
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      item['name'] as String,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 水平条形图
                                  Expanded(
                                    child: Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: maxAmount > 0 ? (amount / maxAmount) : 0.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.purple[600],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 金额
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '¥${amount.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple[700],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 数量
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${quantity}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.blue[700],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 百分比
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建材料排行图表数据
  Future<List<Map<String, dynamic>>> _buildMaterialRankingChart(List<PurchaseRecord> records) async {
    final Map<String, double> materialAmountData = {};
    final Map<String, int> materialQuantityData = {};
    
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 遍历每个采购记录，获取其采购项目
      for (final record in records) {
        final purchaseItems = await purchaseProvider.getPurchaseItemsByRecordId(record.id!);
        
        for (final item in purchaseItems) {
          // 使用 PurchaseItem 对象的属性访问
          final materialName = item.materialName;
          
          // 累计金额
          final amount = item.totalPrice;
          materialAmountData[materialName] = (materialAmountData[materialName] ?? 0) + amount;
          
          // 累计数量
          final quantity = item.quantity;
          materialQuantityData[materialName] = (materialQuantityData[materialName] ?? 0) + quantity;
        }
      }
    } catch (e) {
      print('获取采购项目数据失败: $e');
    }
    
    // 按金额排序
    final sortedMaterials = materialAmountData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedMaterials.map((entry) => {
      'name': entry.key,
      'amount': entry.value,
      'quantity': materialQuantityData[entry.key] ?? 0,
    }).toList();
  }

  /// 显示导出内容选择对话框
  Future<void> _showExportDialog(PurchaseRecord record, List<PurchaseItem> purchaseItems) async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PurchaseExportDialog(),
    );
    
    // 如果用户选择了导出选项，则执行导出
    if (result != null) {
      _exportPurchaseRecordAsImage(record, purchaseItems, result);
    }
  }

  /// 导出采购记录为图片
  Future<void> _exportPurchaseRecordAsImage(PurchaseRecord record, List<PurchaseItem> purchaseItems, Map<String, bool> exportOptions) async {
    try {
      // 创建图片数据
      final imageData = await _generatePurchaseRecordImage(record, purchaseItems, exportOptions);
      
      // 直接保存到下载目录
      final result = await _saveImageToDownloads(imageData);
      
      if (result != null) {
        // 显示成功提示
        SuccessToastManager.show(context, message: '导出成功！图片已保存到下载目录');
      } else {
        // 显示失败提示
        SuccessToastManager.showError(context, message: '图片保存失败');
      }
    } catch (e) {
      SuccessToastManager.showError(context, message: '导出失败: $e');
    }
  }

  /// 生成采购记录图片
  Future<Uint8List> _generatePurchaseRecordImage(PurchaseRecord record, List<PurchaseItem> purchaseItems, Map<String, bool> exportOptions) async {
    
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();
    
    // 超高分辨率 - 确保最佳清晰度
    const scaleFactor = 3.0; // 3倍分辨率，提供超高DPI
    const width = 1200.0 * scaleFactor; // 3600像素宽度
    
    // 动态计算高度，避免内容重叠
    double estimatedHeight = 200 * scaleFactor; // 标题区域
    
    if (exportOptions['purchaseRecord'] == true) {
      estimatedHeight += 200 * scaleFactor; // 基本信息区域
    }
    
    if (exportOptions['purchaseSummary'] == true) {
      estimatedHeight += 150 * scaleFactor; // 汇总统计区域
    }
    
    if (exportOptions['purchaseDetails'] == true) {
      estimatedHeight += 150 * scaleFactor; // 表头区域
      estimatedHeight += purchaseItems.length * 70 * scaleFactor; // 每行项目
      estimatedHeight += 100 * scaleFactor; // 总计行
    }
    
    estimatedHeight += 150 * scaleFactor; // 底部信息和边距
    
    final height = estimatedHeight;
    double currentY = 60 * scaleFactor;
    
    // 白色背景
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
    
    // 标题 - 进一步增大和加粗字体
    paint.color = const Color(0xFF000000);
    final titleStyle = TextStyle(
      fontSize: 48 * scaleFactor, // 增大到144px
      fontWeight: FontWeight.w900, // 使用最粗字体
      color: const Color(0xFF000000),
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: '采购记录详情', style: titleStyle),
      textDirection: ui.TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, currentY));
    currentY += 100 * scaleFactor;
    
    // 采购记录基本信息
    if (exportOptions['purchaseRecord'] == true) {
      final basicInfoStyle = TextStyle(fontSize: 32 * scaleFactor, fontWeight: FontWeight.w800, color: const Color(0xFF000000));
      
      // 构建基本信息文本，包含医生字段
      String basicInfoText = '采购记录 #${record.id}\n'
          '采购日期: ${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}\n';
      
      if (record.supplier != null && record.supplier!.isNotEmpty) {
        basicInfoText += '供应商: ${record.supplier}\n';
      }
      
      if (record.doctor != null && record.doctor!.isNotEmpty) {
        basicInfoText += '采购医生: ${record.doctor}\n';
      }
      
      if (record.notes != null && record.notes!.isNotEmpty) {
        basicInfoText += '备注: ${record.notes}\n';
      }
      
      final basicInfoPainter = TextPainter(
        text: TextSpan(
          text: basicInfoText,
          style: basicInfoStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      );
      basicInfoPainter.layout(maxWidth: width - 150 * scaleFactor);
      basicInfoPainter.paint(canvas, Offset(75 * scaleFactor, currentY));
      currentY += basicInfoPainter.height + 50 * scaleFactor;
    }
    
    // 采购汇总统计信息
    if (exportOptions['purchaseSummary'] == true) {
      final statStyle = TextStyle(fontSize: 30 * scaleFactor, fontWeight: FontWeight.w800, color: const Color(0xFF000000));
      final statPainter = TextPainter(
        text: TextSpan(
          text: '总采购数量: ${record.totalQuantity}\n'
              '总采购金额: ¥${record.totalAmount.toStringAsFixed(2)}\n'
              '采购项目数: ${purchaseItems.length}',
          style: statStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      );
      statPainter.layout(maxWidth: width - 150 * scaleFactor);
      statPainter.paint(canvas, Offset(75 * scaleFactor, currentY));
      currentY += statPainter.height + 50 * scaleFactor;
    }
    
    // 采购项目明细
    if (exportOptions['purchaseDetails'] == true) {
      // 表格标题
      final tableTitleStyle = TextStyle(fontSize: 36 * scaleFactor, fontWeight: FontWeight.w900, color: Colors.blue[800]);
      final tableTitlePainter = TextPainter(
        text: TextSpan(text: '采购项目明细', style: tableTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      tableTitlePainter.layout();
      tableTitlePainter.paint(canvas, Offset(75 * scaleFactor, currentY));
      currentY += 80 * scaleFactor;
      
      // 表格头部 - 进一步增大和加粗字体
      final headerStyle = TextStyle(fontSize: 26 * scaleFactor, fontWeight: FontWeight.w900, color: const Color(0xFF000000));
      final headers = ['材料名称', '数量', '单位', '单价', '总价'];
      final columnWidths = [450.0 * scaleFactor, 120.0 * scaleFactor, 120.0 * scaleFactor, 150.0 * scaleFactor, 180.0 * scaleFactor];
      double currentX = 75 * scaleFactor;
      
      // 绘制表头背景
      final headerBgPaint = ui.Paint()..color = const Color(0xFFE0E0E0); // 加深表头灰色
      canvas.drawRect(
        Rect.fromLTWH(75 * scaleFactor, currentY - 8 * scaleFactor, width - 150 * scaleFactor, 50 * scaleFactor),
        headerBgPaint,
      );
      
      // 绘制表头文字
      for (int i = 0; i < headers.length; i++) {
        final headerPainter = TextPainter(
          text: TextSpan(text: headers[i], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        headerPainter.layout();
        // 材料名称列左对齐，其他列居中对齐
        if (i == 0) {
          // 材料名称列左对齐
          headerPainter.paint(canvas, Offset(currentX + 12 * scaleFactor, currentY));
        } else {
          // 其他列居中对齐
          headerPainter.paint(canvas, Offset(currentX + (columnWidths[i] - headerPainter.width) / 2, currentY));
        }
        currentX += columnWidths[i];
      }
      
      // 绘制表头分隔线
      paint.color = const Color(0xFFE0E0E0);
      canvas.drawLine(
        Offset(75 * scaleFactor, currentY + 42 * scaleFactor),
        Offset(width - 75 * scaleFactor, currentY + 42 * scaleFactor),
        paint,
      );
      
      currentY += 60 * scaleFactor;
      
      // 表格内容 - 进一步增大和加粗字体
      final contentStyle = TextStyle(fontSize: 24 * scaleFactor, fontWeight: FontWeight.w700, color: const Color(0xFF000000));
      
      for (var entry in purchaseItems.asMap().entries) {
        final int index = entry.key;
        final PurchaseItem item = entry.value;

        // 交替行背景色 (偶数行加背景色)
        if (index % 2 == 1) {
            paint.color = Colors.grey[100]!;
            canvas.drawRect(Rect.fromLTWH(75 * scaleFactor, currentY - 8 * scaleFactor, width - 150 * scaleFactor, 70 * scaleFactor), paint);
        }

        currentX = 75 * scaleFactor;
        
        // 材料名称
        final namePainter = TextPainter(
          text: TextSpan(text: item.materialName, style: contentStyle),
          textDirection: ui.TextDirection.ltr,
          maxLines: 2,
        );
        namePainter.layout(maxWidth: columnWidths[0]);
        namePainter.paint(canvas, Offset(currentX + 12 * scaleFactor, currentY));
        currentX += columnWidths[0];
        
        // 数量
        final quantityPainter = TextPainter(
          text: TextSpan(text: '${item.quantity}', style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        quantityPainter.layout();
        quantityPainter.paint(canvas, Offset(currentX + (columnWidths[1] - quantityPainter.width) / 2, currentY));
        currentX += columnWidths[1];
        
        // 单位
        final unitPainter = TextPainter(
          text: TextSpan(text: item.formattedUnit, style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitPainter.layout();
        unitPainter.paint(canvas, Offset(currentX + (columnWidths[2] - unitPainter.width) / 2, currentY));
        currentX += columnWidths[2];
        
        // 单价
        final unitPricePainter = TextPainter(
          text: TextSpan(text: '¥${item.unitPrice.toStringAsFixed(2)}', style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitPricePainter.layout();
        unitPricePainter.paint(canvas, Offset(currentX + (columnWidths[3] - unitPricePainter.width) / 2, currentY));
        currentX += columnWidths[3];
        
        // 总价
        final totalPricePainter = TextPainter(
          text: TextSpan(text: '¥${item.totalPrice.toStringAsFixed(2)}', style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        totalPricePainter.layout();
        totalPricePainter.paint(canvas, Offset(currentX + (columnWidths[4] - totalPricePainter.width) / 2, currentY));
        
        currentY += 70 * scaleFactor; // 增加行高避免重叠
        
        // 添加分隔线
        paint.color = const Color(0xFFE0E0E0);
        canvas.drawLine(
          Offset(75 * scaleFactor, currentY - 10 * scaleFactor),
          Offset(width - 75 * scaleFactor, currentY - 10 * scaleFactor),
          paint,
        );
      }
      // 总计行
      final totalAmount = purchaseItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
      final totalRect = Rect.fromLTWH(75 * scaleFactor, currentY, width - 150 * scaleFactor, 80 * scaleFactor);
      paint.color = Colors.green[50]!;
      canvas.drawRect(totalRect, paint);

      final totalLabelPainter = TextPainter(
        text: TextSpan(text: '总计', style: headerStyle),
        textDirection: ui.TextDirection.ltr,
      );
      totalLabelPainter.layout();
      totalLabelPainter.paint(canvas, Offset(90 * scaleFactor, currentY + (80 * scaleFactor - totalLabelPainter.height) / 2));
      
      final totalAmountPainter = TextPainter(
        text: TextSpan(text: '¥${totalAmount.toStringAsFixed(2)}', style: headerStyle.copyWith(color: Colors.red[700])),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      totalAmountPainter.layout(minWidth: columnWidths[3] + columnWidths[4]);
      totalAmountPainter.paint(canvas, Offset(width - 75 * scaleFactor - totalAmountPainter.width, currentY + (80 * scaleFactor - totalAmountPainter.height) / 2));
      
      currentY += 100 * scaleFactor; // 增加间距
    }
    
    // 底部信息
    final footerStyle = TextStyle(fontSize: 20 * scaleFactor, fontWeight: FontWeight.w600, color: const Color(0xFF757575));
    final footerPainter = TextPainter(
      text: TextSpan(
        text: '导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n'
            '牙医诊所管理系统',
        style: footerStyle,
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerPainter.layout(maxWidth: width - 150 * scaleFactor);
    footerPainter.paint(canvas, Offset(75 * scaleFactor, currentY + 30 * scaleFactor));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    return bytes;
  }

  /// 保存图片到下载目录 - 使用PNG格式确保最高质量
  Future<String?> _saveImageToDownloads(Uint8List imageData) async {
    try {
      final directory = await getDownloadsDirectory();
      final saveDir = directory ?? await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // 始终使用PNG格式保持最佳质量
      final fileName = '采购记录_${timestamp}.png';
      final file = File('${saveDir.path}/$fileName');
      
      await file.writeAsBytes(imageData);
      return file.path;
    } catch (e) {
      print('保存图片失败: $e');
      return null;
    }
  }

  /// 打开文件所在文件夹
  void _openFileLocation(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        // 在Windows上打开文件所在文件夹
        Process.run('explorer', ['/select,', filePath]);
      }
    } catch (e) {
      print('打开文件夹失败: $e');
    }
  }
}

// 可悬浮的采购记录卡片组件
class _HoverablePurchaseRecordCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool isPurpleTheme;
  final Widget child;

  const _HoverablePurchaseRecordCard({
    Key? key,
    required this.onTap,
    required this.isPurpleTheme,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverablePurchaseRecordCard> createState() => _HoverablePurchaseRecordCardState();
}

class _HoverablePurchaseRecordCardState extends State<_HoverablePurchaseRecordCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered 
                ? Color(0xFFE3F2FD)  // 淡蓝色
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}