import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/providers/purchase_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/screens/purchase_detail_screen.dart';
import 'package:dentist_app/widgets/purchase_record_dialog.dart';
import 'package:dentist_app/widgets/success_toast.dart'; // 添加新的公共组件导入
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../models/material.dart';
import '../providers/database_provider.dart';
import '../providers/material_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/purchase_record_dialog.dart';
import '../widgets/purchase_statistics_dialog.dart';
import '../widgets/success_toast.dart';
import '../widgets/connection_status_widget.dart';
import '../screens/purchase_detail_screen.dart';
// 移除缺失的导入

/// 采购记录管理主页面
class PurchaseRecordsScreen extends StatefulWidget {
  const PurchaseRecordsScreen({super.key});

  @override
  State<PurchaseRecordsScreen> createState() => _PurchaseRecordsScreenState();
}

class _PurchaseRecordsScreenState extends State<PurchaseRecordsScreen> with WidgetsBindingObserver {
  List<PurchaseRecord> _purchaseRecords = [];
  List<PurchaseRecord> _filteredRecords = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Map<String, dynamic> _statistics = {};
  bool _hasInitialized = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _loadData(showToast: false); // 初始加载时不显示提示
    _hasInitialized = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用从后台恢复时刷新数据
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ❌ 完全移除自动刷新逻辑，避免任何意外触发
    // 所有数据刷新都由用户明确操作触发（手动刷新、下拉刷新、增删改操作）
  }

  /// 检查并刷新数据（已废弃，不再使用）
  void _checkAndRefreshData() {
    // ❌ 不再使用这个方法，避免不必要的刷新检查
  }

  /// 焦点变化监听（已废弃，不再使用）
  void _onFocusChange() {
    // ❌ 不再监听焦点变化来触发刷新，避免从其他页面返回时误触发
    // 只在明确的操作（增删改）后通过回调触发刷新
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
        body: Column(
          children: [
            // 统计信息卡片
            _buildStatisticsCard(),
            
            // 搜索栏
            _buildSearchBar(),
            
            // 采购记录列表 - 添加下拉刷新
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadData(showToast: false, forceRefresh: true);
                        if (mounted) {
                          SuccessToastManager.show(
                            context,
                            message: '刷新成功',
                          );
                        }
                      },
                      child: _buildPurchaseRecordsList(),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddPurchaseRecordDialog(context),
          backgroundColor: Theme.of(context).primaryColor,
          heroTag: 'purchase_add_button',
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: _showPurchaseStatistics,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总记录',
                    '${_statistics['totalRecords'] ?? 0}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总金额',
                    '¥${NumberFormat('#,##0.00').format(_statistics['totalAmount'] ?? 0.0)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总采购量',
                    '${_statistics['totalQuantity'] ?? 0}',
                    Icons.inventory,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '材料种类',
                    '${_statistics['materialCount'] ?? 0}',
                    Icons.category,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建统计项目
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22), // 从24减少到22
        const SizedBox(height: 6), // 从8减少到6
        Text(
          value,
          style: TextStyle(
            fontSize: 15, // 从16减少到15
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11, // 从12减少到11
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索供应商、医生或备注...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterRecords();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建采购记录列表
  Widget _buildPurchaseRecordsList() {
    if (_filteredRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无采购记录',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12), // 从16减少到12
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        return _buildPurchaseRecordCard(record);
      },
    );
  }

  /// 构建采购记录卡片
  Widget _buildPurchaseRecordCard(PurchaseRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // 从12减少到8
      child: AppCard(
        child: InkWell(
          onTap: () => _showPurchaseRecordDetails(context, record),
          child: Padding(
            padding: const EdgeInsets.all(12), // 从16减少到12
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '采购记录 #${record.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15, // 从16减少到15
                            ),
                          ),
                          const SizedBox(height: 3), // 从4减少到3
                          Text(
                            '采购日期: ${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11, // 从12减少到11
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // 从8减少到6
                        vertical: 3, // 从4减少到3
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(10), // 从12减少到10
                      ),
                      child: Text(
                        '¥${NumberFormat('#,##0.00').format(record.totalAmount)}',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 11, // 从12减少到11
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6), // 从8减少到6
                Row(
                  children: [
                    Icon(Icons.inventory, size: 14, color: Colors.blue[600]), // 从16减少到14
                    const SizedBox(width: 3), // 从4减少到3
                    Text(
                      '总数量: ${record.totalQuantity}',
                      style: TextStyle(color: Colors.blue[600], fontSize: 11, fontWeight: FontWeight.w500), // 从12减少到11
                    ),
                    const SizedBox(width: 12), // 从16减少到12
                    Icon(Icons.list, size: 14, color: Colors.orange[600]), // 从16减少到14
                    const SizedBox(width: 3), // 从4减少到3
                    Text(
                      '项目数: ${record.totalQuantity > 0 ? record.totalQuantity : '待定'}',
                      style: TextStyle(color: Colors.orange[600], fontSize: 11, fontWeight: FontWeight.w500), // 从12减少到11
                    ),
                  ],
                ),
                if (record.supplier?.isNotEmpty == true) ...[
                  const SizedBox(height: 6), // 从8减少到6
                  Row(
                    children: [
                      Icon(Icons.business, size: 14, color: Colors.purple[600]), // 从16减少到14
                      const SizedBox(width: 3), // 从4减少到3
                      Expanded(
                        child: Text(
                          '供应商: ${record.supplier}',
                          style: TextStyle(color: Colors.purple[600], fontSize: 11, fontWeight: FontWeight.w500), // 从12减少到11
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (record.doctor?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.teal[600]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '采购医生: ${record.doctor}',
                          style: TextStyle(color: Colors.teal[600], fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                                 if (record.notes?.isNotEmpty == true) ...[
                   const SizedBox(height: 6), // 从8减少到6
                   Row(
                     children: [
                       Icon(Icons.note, size: 14, color: Colors.grey[600]), // 从16减少到14
                       const SizedBox(width: 3), // 从4减少到3
                       Expanded(
                         child: Text(
                           '备注: ${record.notes}',
                           style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500), // 从12减少到11
                           maxLines: 2,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     ],
                   ),
                 ],
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       '创建时间: ${DateFormat('yyyy-MM-dd').format(record.createdAt)}',
                       style: TextStyle(color: Colors.grey[600], fontSize: 12),
                     ),
                     Row(
                       children: [
                         Container(
                           margin: const EdgeInsets.only(right: 4),
                           child: Material(
                             color: Colors.blue[50],
                             borderRadius: BorderRadius.circular(6),
                             child: InkWell(
                               borderRadius: BorderRadius.circular(6),
                               onTap: () => _showPurchaseRecordDetails(context, record),
                               child: Container(
                                 padding: const EdgeInsets.all(8), // 增大点击区域
                                 child: Icon(
                                   Icons.visibility, 
                                   color: Colors.blue[700], 
                                   size: 18, // 从20减少到18但增加了padding
                                 ),
                               ),
                             ),
                           ),
                         ),
                         Container(
                           child: Material(
                             color: Colors.red[50],
                             borderRadius: BorderRadius.circular(6),
                             child: InkWell(
                               borderRadius: BorderRadius.circular(6),
                               onTap: () => _deletePurchaseRecord(record),
                               child: Container(
                                 padding: const EdgeInsets.all(8), // 增大点击区域
                                 child: Icon(
                                   Icons.delete, 
                                   color: Colors.red[700], 
                                   size: 18, // 从20减少到18但增加了padding
                                 ),
                               ),
                             ),
                           ),
                         ),
                       ],
                     ),
                   ],
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 加载数据
  Future<void> _loadData({bool showToast = true, bool forceRefresh = false}) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 确保PurchaseProvider已初始化
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      if (!provider.isInitialized) {
        await provider.initializeFromDatabase(dbProvider);
      }
      
      // 检查MySQL连接状态
      if (dbProvider.dbType == 'mysql') {
        if (!dbProvider.isConnected) {
          throw Exception('数据库连接失败，请检查网络连接');
        }
      }
      
      print('🔄 开始${forceRefresh ? "强制" : ""}刷新采购记录数据...');
      
      // 如果不是强制刷新且有缓存，使用缓存
      if (!forceRefresh && provider.hasCache) {
        print('✅ 使用缓存的采购数据，跳过重新加载');
        if (mounted) {
          setState(() {
            _purchaseRecords = provider.cachedRecords;
            _filteredRecords = _purchaseRecords;
            _isLoading = false;
          });
          _updateStatistics();
        }
        return;
      }
      
      // 只在强制刷新时清除缓存
      if (forceRefresh) {
        print('🔄 强制刷新：清除缓存');
        provider.clearCache();
      }
      
      // 直接调用getAllPurchaseRecords获取最新数据
      final records = await provider.getAllPurchaseRecords();
      
      if (mounted) {
        setState(() {
          _purchaseRecords = records;
          _filteredRecords = records;
          _isLoading = false;
        });
        
        // 异步更新统计信息
        _updateStatistics();
        
        print('✅ 采购记录数据刷新完成: ${records.length} 条记录');
        
        // 只有在showToast为true时才显示刷新成功提示
        if (mounted && showToast) {
          SuccessToastManager.show(
            context,
            message: '数据已刷新',
          );
        }
      }
    } catch (e) {
      print('❌ 刷新采购记录数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        SuccessToastManager.showError(
          context,
          message: '刷新数据失败: $e',
        );
      }
    }
  }

  /// 过滤记录
  void _filterRecords() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredRecords = _purchaseRecords;
      });
    } else {
      setState(() {
        _filteredRecords = _purchaseRecords.where((record) {
          return (record.supplier?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                 (record.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                 (record.doctor?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        }).toList();
      });
    }
  }

  /// 更新统计信息
  void _updateStatistics() async {
    if (_purchaseRecords.isEmpty) {
      setState(() {
        _statistics = {
          'totalRecords': 0,
          'totalAmount': 0.0,
          'totalQuantity': 0,
          'materialCount': 0,
        };
      });
      return;
    }

    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 计算基础统计信息
      double totalAmount = 0.0;
      int totalQuantity = 0;
      Set<String> materials = {};
      
      // 遍历所有采购记录
      for (var record in _purchaseRecords) {
        totalAmount += record.totalAmount;
        
        // 获取每个记录的采购项目来计算实际数量和材料种类
        if (record.id != null) {
          try {
            final items = await provider.getPurchaseItemsByRecordId(record.id!);
            for (final item in items) {
              totalQuantity += item.quantity; // 使用项目的实际数量
              materials.add(item.materialName); // 收集材料种类
            }
          } catch (e) {
            print('获取采购记录 ${record.id} 的项目失败: $e');
            // 如果获取项目失败，使用记录的总数量作为备用
            totalQuantity += record.totalQuantity;
          }
        } else {
          // 如果记录ID为空，使用记录的总数量
          totalQuantity += record.totalQuantity;
        }
      }

      if (mounted) {
        setState(() {
          _statistics = {
            'totalRecords': _purchaseRecords.length,
            'totalAmount': totalAmount,
            'totalQuantity': totalQuantity,
            'materialCount': materials.length,
          };
        });
        
        print('✅ 统计信息更新完成: 记录数=${_purchaseRecords.length}, 总金额=$totalAmount, 总数量=$totalQuantity, 材料种类=${materials.length}');
      }
    } catch (e) {
      print('❌ 更新统计信息失败: $e');
      
      // 如果完全失败，使用最基础的计算
      double totalAmount = 0.0;
      int totalQuantity = 0;

      for (var record in _purchaseRecords) {
        totalAmount += record.totalAmount;
        totalQuantity += record.totalQuantity;
      }

      if (mounted) {
        setState(() {
          _statistics = {
            'totalRecords': _purchaseRecords.length,
            'totalAmount': totalAmount,
            'totalQuantity': totalQuantity,
            'materialCount': 0, // 如果获取失败，设为0
          };
        });
      }
    }
  }

  /// 显示添加采购记录对话框
  void _showAddPurchaseRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => const PurchaseRecordDialog(),
    ).then((result) {
      if (result == true) {
        print('🔄 采购记录添加成功，正在刷新数据...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true); // 添加成功后显示提示
          }
        });
      }
    });
  }

  /// 显示采购记录详情
  void _showPurchaseRecordDetails(BuildContext context, PurchaseRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PurchaseDetailScreen(record: record),
      ),
    ).then((result) {
      // 如果从详情页返回true，说明有数据变更，需要刷新
      if (result == true) {
        print('🔄 从详情页返回，检测到数据变更，正在刷新...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true); // 有数据变更时显示提示
          }
        });
      }
    });
  }

  /// 编辑采购记录
  void _editPurchaseRecord(PurchaseRecord record) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => PurchaseRecordDialog(record: record),
    ).then((result) {
      if (result == true) {
        print('🔄 采购记录编辑成功，正在刷新数据...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true); // 编辑成功后显示提示
          }
        });
      }
    });
  }

  /// 删除采购记录
  void _deletePurchaseRecord(PurchaseRecord record) async {
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showPurchaseDelete(
      context,
      purchaseInfo: '采购记录 #${record.id}',
    );
    
    if (confirmed) {
      _confirmDeletePurchaseRecord(record);
    }
  }

  /// 确认删除采购记录
  Future<void> _confirmDeletePurchaseRecord(PurchaseRecord record) async {
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final result = await provider.deletePurchaseRecord(record.id!);
      
      if (mounted) {
        if (result > 0) {
          // 删除成功，立即从本地列表中移除
          setState(() {
            _purchaseRecords.removeWhere((r) => r.id == record.id);
            _filterRecords(); // 重新过滤
          });
          
          // 重新计算统计信息
          _updateStatistics();
          
          // 强制刷新Provider状态
          provider.markPurchasesNeedRefresh();
          
          // 显示成功提示
          if (mounted) {
            SuccessToastManager.show(
              context,
              message: '采购记录删除成功',
            );
          }
        } else {
          if (mounted) {
            SuccessToastManager.showError(
              context,
              message: '删除失败：未找到记录',
            );
          }
        }
      }
    } catch (e) {
      print('删除采购记录时出错: $e');
      if (mounted) {
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  /// 显示采购统计图表
  Future<void> _showPurchaseStatistics() async {
    try {
      // 显示加载提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 准备采购项目数据映射
      final Map<int, List<PurchaseItem>> recordItemsMap = {};
      
      for (final record in _purchaseRecords) {
        if (record.id != null) {
          try {
            final items = await provider.getPurchaseItemsByRecordId(record.id!);
            recordItemsMap[record.id!] = items;
          } catch (e) {
            print('加载采购记录 ${record.id} 的项目失败: $e');
            recordItemsMap[record.id!] = [];
          }
        }
      }

      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 显示统计图表对话框
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => PurchaseStatisticsDialog(
            purchaseRecords: _purchaseRecords,
            recordItemsMap: recordItemsMap,
            purchaseProvider: provider,
          ),
        );
      }
    } catch (e) {
      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      print('显示采购统计图表失败: $e');
      if (mounted) {
        SuccessToastManager.showError(
          context,
          message: '加载统计数据失败: $e',
        );
      }
    }
  }
}
