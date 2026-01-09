import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/providers/financial_provider.dart';
import 'package:dentist_app/models/financial_record.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/screens/financial_detail_screen.dart';
import 'package:dentist_app/widgets/financial_record_dialog.dart';
import 'package:dentist_app/widgets/success_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/financial_statistics_dialog.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../providers/database_provider.dart';
import '../providers/patient_provider.dart';

/// 财务管理主页面
class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({super.key});

  @override
  State<FinancialManagementScreen> createState() => _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> {
  List<FinancialRecord> _financialRecords = [];
  List<FinancialRecord> _filteredRecords = []; // 添加过滤后的记录列表
  Map<int, List<FinancialItem>> _recordItemsMap = {}; // 存储记录ID到明细项的映射
  bool _isLoading = true;
  bool _isLoadingMore = false; // 后台加载更多数据的状态
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  
  // 排序相关
  String _currentSort = 'updated_time'; // 'updated_time', 'collected_amount', 'outstanding_amount'
  bool _ascending = false; // 默认降序
  
  // 时间筛选相关变量
  DateTime? _startDate;
  DateTime? _endDate;
  
  // 渐进式加载相关
  static const int _initialLoadCount = 20; // 首次加载20条
  bool _hasLoadedAll = false; // 是否已加载全部数据

  bool _hasInitialized = false; // 添加标志防止重复初始化

  @override
  void initState() {
    super.initState();
    // 首次加载数据
    _loadData(showToast: false); // 初始加载时不显示提示
    _hasInitialized = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ❌ 完全移除自动刷新逻辑，避免任何意外触发
    // 所有数据刷新都由用户明确操作触发（手动刷新、下拉刷新、增删改操作）
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 统计信息卡片
          _buildStatisticsCard(),
          
          // 搜索栏
          _buildSearchBar(),
          
          // 财务记录列表 - 添加下拉刷新
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorWidget()
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
                        child: _buildFinancialRecordsList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFinancialRecordDialog(context),
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: 'financial_add_button',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 搜索框和按钮行
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _hasLoadedAll 
                        ? '搜索患者姓名、拼音、拼音首字母...' 
                        : '搜索患者姓名、拼音（已加载${_financialRecords.length}条）...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterRecords();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 排序按钮
              Container(
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.shade200,
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.sort,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                  onPressed: () => _showSortOptions(context),
                  tooltip: '排序选项',
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 时间筛选按钮
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showCustomDateRangePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (_startDate == null && _endDate == null)
                                ? '全部时间'
                                : '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_startDate != null || _endDate != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() { 
                                _startDate = null; 
                                _endDate = null; 
                              });
                              _filterRecords();
                            },
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.black45),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 预设时间范围快捷按钮
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton('本月', 'this_month'),
                const SizedBox(width: 8),
                _buildPresetButton('上月', 'last_month'),
                const SizedBox(width: 8),
                _buildPresetButton('30天', '30d'),
                const SizedBox(width: 8),
                _buildPresetButton('今年', 'this_year'),
                const SizedBox(width: 8),
                _buildPresetButton('全部', 'all'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard() {
    // 获取统计数据（基于时间筛选和搜索条件）
    final filteredItems = _getFilteredItems();
    final uniquePatientCount = _calculateUniquePatientCount();
    final totalCollected = _calculateTotalCollected();
    final totalOutstanding = _calculateTotalOutstanding();
    final totalProcessingFee = _calculateTotalProcessingFee();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: _showStatisticsDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '患者数',
                    '${uniquePatientCount}${!_hasLoadedAll && _searchQuery.isEmpty && _startDate == null && _endDate == null ? '+' : ''}',
                    Icons.people,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '记录数',
                    '${filteredItems.length}${!_hasLoadedAll && _searchQuery.isEmpty && _startDate == null && _endDate == null ? '+' : ''}',
                    Icons.receipt_long,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '已收费',
                    '¥${NumberFormat('#,##0').format(totalCollected)}${!_hasLoadedAll && _searchQuery.isEmpty && _startDate == null && _endDate == null ? '+' : ''}',
                    Icons.payment,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总欠费',
                    '¥${NumberFormat('#,##0').format(totalOutstanding)}${!_hasLoadedAll && _searchQuery.isEmpty && _startDate == null && _endDate == null ? '+' : ''}',
                    Icons.money_off,
                    Colors.red[700]!,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '加工费',
                    '¥${NumberFormat('#,##0').format(totalProcessingFee)}${!_hasLoadedAll && _searchQuery.isEmpty && _startDate == null && _endDate == null ? '+' : ''}',
                    Icons.build,
                    Colors.teal,
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
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 构建财务记录列表
  Widget _buildFinancialRecordsList() {
    if (_filteredRecords.isEmpty) {
      if (_financialRecords.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '暂无财务记录',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        );
      } else {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '没有找到匹配的患者',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                '请尝试其他搜索关键词',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }
    }

    return Column(
      children: [
        // 显示加载状态提示
        if (_isLoadingMore && !_hasLoadedAll)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在加载更多数据...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        
        // 财务记录列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredRecords.length + (_hasLoadedAll ? 0 : (_isLoadingMore ? 0 : 1)),
            itemBuilder: (context, index) {
              // 如果是最后一项且还有更多数据要加载，显示加载提示
              if (index == _filteredRecords.length && !_hasLoadedAll && !_isLoadingMore) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '已显示 ${_filteredRecords.length} 条记录${_financialRecords.length > _filteredRecords.length ? '，正在后台加载更多...' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
              
              final record = _filteredRecords[index];
              return _buildFinancialRecordCard(record);
            },
          ),
        ),
      ],
    );
  }

  /// 构建错误显示组件
  Widget _buildErrorWidget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(fontSize: 18, color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _loadData(showToast: true, forceRefresh: true),
                  child: const Text('重试'),
                ),
                const SizedBox(width: 16),
                // 如果是MySQL连接错误，显示重连按钮
                if (_errorMessage.contains('数据库连接') || 
                    _errorMessage.contains('Socket') ||
                    _errorMessage.contains('Cannot write to socket'))
                  ElevatedButton(
                    onPressed: () => _reconnectDatabase(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重新连接'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 重新连接数据库
  Future<void> _reconnectDatabase() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      if (dbProvider.dbType == 'mysql') {
        // 直接重新加载数据，如果连接有问题会自动提示
        await _loadData(showToast: true, forceRefresh: true);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '重连过程中出错: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 构建财务记录卡片
  Widget _buildFinancialRecordCard(FinancialRecord record) {
    // 直接使用记录中的患者姓名，如果没有则显示"未知患者"
    final patientName = record.patientName?.trim().isNotEmpty == true ? record.patientName! : '未知患者';
    
    // 计算财务统计
    final items = _recordItemsMap[record.id!] ?? [];
    final totalReceivable = _calculatePatientLatestReceivableAmount(record.patientId);
    final totalCollected = _calculatePatientLatestCollectedAmount(record.patientId);
    final totalOutstanding = totalReceivable - totalCollected;
    
    // 判断是否已结清
    final isSettled = totalOutstanding <= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: InkWell(
          onTap: () => _showFinancialRecordDetails(context, record),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: '病历号: ${record.patientId}',
                        child: Text(
                          patientName, // 直接显示患者姓名作为主标题
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSettled ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSettled ? '已结清' : '未结清',
                        style: TextStyle(
                          color: isSettled ? Colors.green[800] : Colors.orange[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '应收费: ¥${NumberFormat('#,##0').format(totalReceivable)}',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      '已收费: ¥${NumberFormat('#,##0').format(totalCollected)}',
                      style: TextStyle(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.pending, size: 16, color: Colors.orange[600]),
                    const SizedBox(width: 4),
                    Text(
                      '欠费: ¥${NumberFormat('#,##0').format(totalOutstanding)}',
                      style: TextStyle(
                        color: totalOutstanding > 0 ? Colors.red[600] : Colors.grey[600], 
                        fontSize: 12, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.list, size: 16, color: Colors.purple[600]),
                    const SizedBox(width: 4),
                    Text(
                      '项目数: ${items.length}',
                      style: TextStyle(color: Colors.purple[600], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (record.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '备注: ${record.notes}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
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
                        IconButton(
                          icon: Icon(Icons.visibility, color: Theme.of(context).primaryColor, size: 20),
                          onPressed: () => _showFinancialRecordDetails(context, record),
                          tooltip: '查看详情',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteFinancialRecord(record),
                          tooltip: '删除记录',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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

  /// 加载数据 - 渐进式加载策略（增强连接管理）
  Future<void> _loadData({bool showToast = true, bool forceRefresh = false}) async {
    if (!mounted) return;
    
    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
    
    // 如果不是强制刷新且已有缓存数据，直接使用缓存
    if (!forceRefresh && financialProvider.hasCache) {
      print('✅ 使用缓存的财务数据，跳过重新加载');
      setState(() {
        _financialRecords = financialProvider.cachedRecords;
        _recordItemsMap = financialProvider.cachedItemsMap;
        _isLoading = false;
        _hasLoadedAll = true;
      });
      // 重要：应用过滤和排序
      _filterRecords();
      _sortRecords();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _hasLoadedAll = false;
    });

    try {
      print('🔄 开始${forceRefresh ? "强制" : ""}加载财务管理数据...');
      
      // 检查 Provider 是否可用
      if (!mounted) return;
      
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 验证 Provider 是否已初始化
      if (financialProvider == null || patientProvider == null) {
        throw Exception('Provider 未初始化，请检查应用配置');
      }
      
      // 初始化 FinancialProvider
      if (!financialProvider.initialized) {
        print('FinancialProvider未初始化，开始初始化...');
        await financialProvider.initializeFromDatabase(databaseProvider);
        print('FinancialProvider初始化完成: initialized = ${financialProvider.initialized}');
      }
      
      // 检查数据库是否已初始化
      if (!financialProvider.initialized) {
        throw Exception('数据库未初始化，请稍后重试');
      }
      
      // 增强的连接检查 - 使用智能连接检查
      if (databaseProvider.dbType == 'mysql') {
        print('🔍 检查MySQL连接状态...');
        if (!databaseProvider.isConnected) {
          throw Exception('数据库连接失败，请检查网络连接');
        }
        print('✅ 连接检查通过');
      }
      
      // 只在强制刷新时清除缓存
      if (forceRefresh) {
        print('🔄 强制刷新：清除缓存');
        financialProvider.clearCache();
      }
      
      print('🔄 第一阶段：快速加载前 $_initialLoadCount 条数据...');
      
      // 使用连接管理包装器执行数据库操作
      final allFinancialRecords = await _executeWithConnectionManagement(
        databaseProvider,
        '获取所有财务记录',
        () => financialProvider.getAllFinancialRecords(),
      );
      
      if (!mounted) return;
      
      print('数据加载结果: 总共 ${allFinancialRecords.length} 条记录');
      
      // 第一阶段：快速显示前20条数据
      final initialRecords = allFinancialRecords.take(_initialLoadCount).toList();
      
      // 为前20条记录加载明细项
      final initialRecordItemsMap = <int, List<FinancialItem>>{};
      for (final record in initialRecords) {
        if (!mounted) return; // 检查是否还在页面上
        
        if (record.id != null) {
          try {
            final items = await _executeWithConnectionManagement(
              databaseProvider,
              '获取财务记录${record.id}的明细项',
              () => financialProvider.getFinancialItemsByRecordId(record.id!),
            );
            if (!mounted) return; // 异步操作后再次检查
            initialRecordItemsMap[record.id!] = items;
          } catch (e) {
            if (!mounted) return; // 出错后也要检查
            print('加载财务记录 ${record.id} 的明细项失败: $e');
            initialRecordItemsMap[record.id!] = [];
          }
        }
      }
      
      if (!mounted) return;
      
      // 更新UI显示前20条数据
      setState(() {
        _financialRecords = initialRecords;
        _filteredRecords = initialRecords;
        _recordItemsMap = initialRecordItemsMap;
        _isLoading = false;
        _hasLoadedAll = allFinancialRecords.length <= _initialLoadCount;
      });
      
      print('✅ 第一阶段完成：已显示前 ${initialRecords.length} 条记录');
      
      // 应用排序
      _sortRecords();
      
      // 第二阶段：后台加载剩余数据
      if (allFinancialRecords.length > _initialLoadCount) {
        _loadRemainingDataInBackground(allFinancialRecords, financialProvider);
      } else {
        // 如果数据量少，第一阶段就加载完了，立即更新缓存
        financialProvider.updateCacheManually(_financialRecords, _recordItemsMap);
      }
      
      // 只有在showToast为true时才显示刷新成功提示
      if (mounted && showToast) {
        SuccessToastManager.show(
          context,
          message: '数据已刷新',
        );
      }
      
    } catch (e) {
      print('❌ 刷新财务数据失败: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '刷新数据失败: $e';
      });
      
      // 只有在showToast为true时才显示错误提示
      if (mounted && showToast) {
        SuccessToastManager.showError(
          context,
          message: '刷新数据失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// 使用连接管理执行数据库操作
  Future<T> _executeWithConnectionManagement<T>(
    DatabaseProvider databaseProvider,
    String operationName,
    Future<T> Function() operation,
  ) async {
    // 不再从 context 获取 provider，而是使用传入的参数
    
    // 如果是MySQL，使用增强的连接管理
    if (databaseProvider.dbType == 'mysql') {
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          // 在操作前检查连接
          if (databaseProvider.dbType == 'mysql' && !databaseProvider.isConnected) {
            throw Exception('数据库连接不可用');
          }
          
          // 执行操作
          return await operation();
          
        } catch (e) {
          retryCount++;
          print('❌ $operationName 失败 (尝试 $retryCount/$maxRetries): $e');
          
          // 检查是否是连接相关错误
          if (_isConnectionError(e) && retryCount < maxRetries) {
            print('🔄 检测到连接错误，等待重试...');
            await Future.delayed(Duration(seconds: retryCount));
            continue;
          }
          
          rethrow;
        }
      }
      
      throw Exception('$operationName 重试次数已用完');
    } else {
      // SQLite直接执行
      return await operation();
    }
  }

  /// 检查是否是连接相关错误
  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    return errorString.contains('connection') ||
           errorString.contains('socket') ||
           errorString.contains('timeout') ||
           errorString.contains('network') ||
           errorString.contains('broken pipe') ||
           errorString.contains('connection reset');
  }
  
  /// 后台加载剩余数据 - 即使页面切换也继续加载
  Future<void> _loadRemainingDataInBackground(
    List<FinancialRecord> allRecords,
    FinancialProvider financialProvider,
  ) async {
    // 标记开始后台加载
    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }
    
    try {
      print('🔄 第二阶段：后台加载剩余 ${allRecords.length - _initialLoadCount} 条数据...');
      print('📌 后台加载将持续进行，即使切换页面也不会中断');
      
      // 获取剩余的记录
      final remainingRecords = allRecords.skip(_initialLoadCount).toList();
      
      // 创建完整的记录列表和明细项映射（用于最终更新缓存）
      final completeRecords = List<FinancialRecord>.from(allRecords);
      final completeItemsMap = <int, List<FinancialItem>>{};
      
      // 先复制已加载的明细项
      completeItemsMap.addAll(_recordItemsMap);
      
      // 分批加载，避免一次性加载太多数据造成卡顿
      const batchSize = 10;
      int loadedCount = _initialLoadCount;
      
      for (int i = 0; i < remainingRecords.length; i += batchSize) {
        final batch = remainingRecords.skip(i).take(batchSize).toList();
        
        for (final record in batch) {
          if (record.id != null) {
            try {
              final items = await financialProvider.getFinancialItemsByRecordId(record.id!);
              completeItemsMap[record.id!] = items;
              loadedCount++;
            } catch (e) {
              print('加载财务记录 ${record.id} 的明细项失败: $e');
              completeItemsMap[record.id!] = [];
            }
          }
        }
        
        // 每批次加载完后，如果页面还在就更新UI，否则只更新缓存
        if (mounted) {
          setState(() {
            _financialRecords = completeRecords.take(loadedCount).toList();
            _recordItemsMap = Map.from(completeItemsMap);
            // 如果没有搜索条件，更新过滤后的记录
            if (_searchQuery.isEmpty) {
              _filteredRecords = List.from(_financialRecords);
            } else {
              _filterRecords();
            }
            // 应用排序
            _sortRecords();
          });
        } else {
          // 页面已切换，但继续在后台加载并更新缓存
          print('📦 页面已切换，继续后台加载... (${loadedCount}/${allRecords.length})');
        }
        
        // 实时更新缓存，确保数据不丢失
        financialProvider.updateCacheManually(
          completeRecords.take(loadedCount).toList(),
          Map.from(completeItemsMap),
        );
        
        // 添加小延迟，避免阻塞UI
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // 最终更新缓存
      financialProvider.updateCacheManually(completeRecords, completeItemsMap);
      print('✅ 第二阶段完成：所有 ${allRecords.length} 条记录加载完毕，缓存已更新');
      
      // 如果页面还在，更新加载状态
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasLoadedAll = true;
          _financialRecords = completeRecords;
          _recordItemsMap = completeItemsMap;
          // 重新过滤和排序
          if (_searchQuery.isEmpty) {
            _filteredRecords = List.from(_financialRecords);
          } else {
            _filterRecords();
          }
          _sortRecords();
        });
      }
      
    } catch (e) {
      print('❌ 后台加载剩余数据失败: $e');
      
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// 过滤记录 - 支持拼音搜索和时间筛选
  void _filterRecords() {
    List<FinancialRecord> filtered = _financialRecords;
    
    // 时间范围筛选
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((record) {
        // 使用财务记录的创建时间进行筛选
        return _isWithinRange(record.createdAt);
      }).toList();
    }
    
    // 搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      final lowercaseQuery = _searchQuery.toLowerCase();
      final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');
      
      filtered = filtered.where((record) {
        final patientName = record.patientName ?? '';
        final patientNamePinyin = record.patientNamePinyin ?? '';
        final patientNameInitials = record.patientNameInitials ?? '';
        
        // 支持多种搜索方式
        return patientName.toLowerCase().contains(lowercaseQuery) ||
               patientNamePinyin.toLowerCase().contains(lowercaseQuery) ||
               patientNamePinyin.toLowerCase().contains(noSpaceQuery) ||
               patientNamePinyin.replaceAll(' ', '').toLowerCase().contains(lowercaseQuery) ||
               patientNameInitials.toLowerCase().contains(lowercaseQuery);
      }).toList();
    }
    
    setState(() {
      _filteredRecords = filtered;
    });
    
    // 过滤后重新排序
    _sortRecords();
  }

  /// 时间范围选择方法
  Future<void> _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final DateTime initialStart = _startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = _endDate ?? now;
    final picked = await ReusableDateRangePicker.show(
      context, 
      start: initialStart, 
      end: initialEnd, 
      title: '选择财务记录日期范围'
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterRecords();
    }
  }

  /// 检查日期是否在范围内
  bool _isWithinRange(DateTime date) {
    if (_startDate == null && _endDate == null) {
      return true; // 如果没有设置日期范围，则认为所有日期都有效
    }
    
    final d = DateTime(date.year, date.month, date.day);
    
    // 检查开始日期
    if (_startDate != null) {
      final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      if (d.isBefore(s)) {
        return false;
      }
    }
    
    // 检查结束日期
    if (_endDate != null) {
      final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      if (d.isAfter(e)) {
        return false;
      }
    }
    
    return true;
  }

  /// 构建预设时间范围按钮
  Widget _buildPresetButton(String label, String preset) {
    final isSelected = _isPresetSelected(preset);
    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 检查预设是否被选中
  bool _isPresetSelected(String preset) {
    if (preset == 'all') {
      return _startDate == null && _endDate == null;
    }
    
    final now = DateTime.now();
    DateTime? expectedStart;
    DateTime? expectedEnd;
    
    switch (preset) {
      case 'this_month':
        expectedStart = DateTime(now.year, now.month, 1);
        expectedEnd = DateTime(now.year, now.month + 1, 0);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        expectedStart = DateTime(lastMonth.year, lastMonth.month, 1);
        expectedEnd = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case '30d':
        expectedStart = now.subtract(const Duration(days: 29));
        expectedEnd = now;
        break;
      case 'this_year':
        expectedStart = DateTime(now.year, 1, 1);
        expectedEnd = DateTime(now.year, 12, 31);
        break;
    }
    
    if (expectedStart == null || expectedEnd == null) return false;
    
    return _startDate != null && 
           _endDate != null &&
           _isSameDay(_startDate!, expectedStart) &&
           _isSameDay(_endDate!, expectedEnd);
  }

  /// 检查两个日期是否是同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// 应用预设时间范围
  void _applyPreset(String preset) {
    if (preset == 'all') {
      // 清空日期筛选，显示所有数据
      setState(() {
        _startDate = null;
        _endDate = null;
      });
      _filterRecords();
      return;
    }
    
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);
    
    switch (preset) {
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        start = DateTime(lastMonth.year, lastMonth.month, 1);
        end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case '30d':
        start = now.subtract(const Duration(days: 29));
        end = now;
        break;
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31);
        break;
      default:
        return;
    }

    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _filterRecords();
  }

  /// 显示排序选项对话框
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '排序选项',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按更新时间排序',
                  icon: Icons.update,
                  isSelected: _currentSort == 'updated_time',
                  isAscending: _ascending,
                  onTap: () {
                    _changeSort('updated_time');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按已收金额排序',
                  icon: Icons.payment,
                  isSelected: _currentSort == 'collected_amount',
                  isAscending: _ascending,
                  onTap: () {
                    _changeSort('collected_amount');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按欠费金额排序',
                  icon: Icons.money_off,
                  isSelected: _currentSort == 'outstanding_amount',
                  isAscending: _ascending,
                  onTap: () {
                    _changeSort('outstanding_amount');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建排序选项
  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isAscending,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.purple[600] : Colors.grey[600],
      ),
      title: Text(title),
      trailing: isSelected
          ? Icon(
              isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.purple[600],
              size: 18,
            )
          : null,
      onTap: onTap,
      selected: isSelected,
      selectedColor: Colors.purple[600],
    );
  }

  /// 改变排序方式
  void _changeSort(String sortType) {
    setState(() {
      if (_currentSort == sortType) {
        // 如果已经是当前排序项，则切换顺序
        _ascending = !_ascending;
      } else {
        // 否则更改排序项并设置为降序
        _currentSort = sortType;
        _ascending = false;
      }
    });
    
    // 应用排序
    _sortRecords();
  }

  /// 对记录进行排序（基于缓存数据）
  void _sortRecords() {
    setState(() {
      switch (_currentSort) {
        case 'updated_time':
          _filteredRecords.sort((a, b) {
            return _ascending
                ? a.updatedAt.compareTo(b.updatedAt)
                : b.updatedAt.compareTo(a.updatedAt);
          });
          break;
        case 'collected_amount':
          _filteredRecords.sort((a, b) {
            final aCollected = _calculatePatientLatestCollectedAmount(a.patientId);
            final bCollected = _calculatePatientLatestCollectedAmount(b.patientId);
            return _ascending
                ? aCollected.compareTo(bCollected)
                : bCollected.compareTo(aCollected);
          });
          break;
        case 'outstanding_amount':
          _filteredRecords.sort((a, b) {
            final aReceivable = _calculatePatientLatestReceivableAmount(a.patientId);
            final aCollected = _calculatePatientLatestCollectedAmount(a.patientId);
            final aOutstanding = aReceivable - aCollected;
            
            final bReceivable = _calculatePatientLatestReceivableAmount(b.patientId);
            final bCollected = _calculatePatientLatestCollectedAmount(b.patientId);
            final bOutstanding = bReceivable - bCollected;
            
            return _ascending
                ? aOutstanding.compareTo(bOutstanding)
                : bOutstanding.compareTo(aOutstanding);
          });
          break;
      }
    });
  }

  /// 显示添加财务记录对话框
  void _showAddFinancialRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => const FinancialRecordDialog(),
    ).then((result) {
      if (result == true) {
        print('🔄 财务记录添加成功，正在刷新数据...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true, forceRefresh: true); // 添加成功后显示提示并强制刷新
          }
        });
      }
    });
  }

  /// 显示财务记录详情
  void _showFinancialRecordDetails(BuildContext context, FinancialRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialDetailScreen(record: record),
      ),
    ).then((result) {
      // 如果从详情页返回true，说明有数据变更，需要刷新
      if (result == true) {
        print('🔄 从详情页返回，检测到数据变更，正在刷新...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true, forceRefresh: true); // 有数据变更时显示提示并强制刷新
          }
        });
      }
    });
  }

  /// 显示统计信息对话框
  void _showStatisticsDialog() {
    if (_financialRecords.isEmpty) {
      SuccessToastManager.showInfo(
        context,
        message: '暂无财务数据可统计',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.9,
          child: FinancialStatisticsDialog(
            financialRecords: _financialRecords,
            recordItemsMap: _recordItemsMap,
            financialProvider: Provider.of<FinancialProvider>(context, listen: false),
          ),
        ),
      ),
    );
  }

  /// 删除财务记录
  Future<void> _deleteFinancialRecord(FinancialRecord record) async {
    // 直接使用记录中的患者姓名
    final patientName = record.patientName ?? '未知患者';
    
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: '患者 "$patientName" 的财务记录',
    );

    if (confirmed == true) {
      try {
        final provider = Provider.of<FinancialProvider>(context, listen: false);
        await provider.deleteFinancialRecord(record.id!);
        
        if (mounted) {
          // 使用新的成功提示组件
          SuccessToastManager.show(
            context,
            message: '财务记录删除成功',
            duration: const Duration(seconds: 2),
          );
          // 延迟重新加载数据，确保数据库操作完成
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _loadData(showToast: true, forceRefresh: true); // 删除成功后显示提示并强制刷新
            }
          });
        }
      } catch (e) {
        if (mounted) {
          // 使用新的错误提示组件
          SuccessToastManager.showError(
            context,
            message: '删除失败: $e',
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  /// 获取患者最新财务记录
  FinancialRecord? _getLatestFinancialRecord(int patientId) {
    try {
      final patientRecords = _financialRecords
          .where((record) => record.patientId == patientId)
          .toList();
      
      if (patientRecords.isEmpty) return null;
      
      // 按更新时间排序，最新的排到最前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return patientRecords.first;
    } catch (e) {
      print('获取患者最新财务记录失败: $e');
      return null;
    }
  }

  /// 计算患者最新应收费金额
  double _calculatePatientLatestReceivableAmount(int patientId) {
    try {
      final latestRecord = _getLatestFinancialRecord(patientId);
      if (latestRecord == null) return 0.0;
      
      final items = _recordItemsMap[latestRecord.id!] ?? [];
      if (items.isEmpty) return 0.0;
      
      // 计算应收费总额（仅项目价格，不包含加工费）
      double totalReceivable = 0.0;
      for (final item in items) {
        totalReceivable += item.itemPrice;
      }
      return totalReceivable;
    } catch (e) {
      print('计算患者最新应收费金额失败: $e');
      return 0.0;
    }
  }

  /// 计算患者最新已收费金额
  double _calculatePatientLatestCollectedAmount(int patientId) {
    try {
      final latestRecord = _getLatestFinancialRecord(patientId);
      if (latestRecord == null) return 0.0;
      
      final items = _recordItemsMap[latestRecord.id!] ?? [];
      if (items.isEmpty) return 0.0;
      
      // 计算已收费总额
      double totalCollected = 0.0;
      for (final item in items) {
        totalCollected += item.totalPrice;
      }
      return totalCollected;
    } catch (e) {
      print('计算患者最新已收费金额失败: $e');
      return 0.0;
    }
  }

  /// 计算总金额
  double _calculateTotalAmount() {
    double total = 0.0;
    for (final record in _filteredRecords) {
      final items = _recordItemsMap[record.id!] ?? [];
      for (final item in items) {
        total += item.totalPrice;
      }
    }
    return total;
  }

  /// 计算已结清记录数
  int _calculateSettledCount() {
    return _filteredRecords.where((record) {
      final items = _recordItemsMap[record.id!] ?? [];
      return items.isNotEmpty && items.every((item) => item.totalPrice > 0);
    }).length;
  }

  /// 计算唯一患者数量（基于财务项目，与财务图表逻辑保持一致）
  int _calculateUniquePatientCount() {
    final Set<int> patientIds = {};
    final filteredItems = _getFilteredItems();
    
    // 遍历过滤后的财务项目
    for (final item in filteredItems) {
      final record = _financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      if (record.patientId != 0) {
        patientIds.add(record.patientId);
      }
    }
    
    return patientIds.length;
  }

  /// 计算总记录数
  int _calculateTotalRecords() {
    return _filteredRecords.length;
  }

  /// 获取过滤后的财务项目（按收费日期过滤，与统计图表逻辑一致）
  List<FinancialItem> _getFilteredItems() {
    final List<FinancialItem> allItems = [];
    
    // 获取所有财务项目
    for (final record in _financialRecords) {
      if (record.id != null && _recordItemsMap.containsKey(record.id)) {
        allItems.addAll(_recordItemsMap[record.id]!);
      }
    }
    
    // 按收费日期过滤（与统计图表逻辑完全一致）
    List<FinancialItem> timeFilteredItems = allItems;
    if (_startDate != null || _endDate != null) {
      timeFilteredItems = allItems.where((item) {
        return _isWithinRange(item.chargeDate);
      }).toList();
    }
    
    // 如果有搜索条件，进一步过滤（只影响显示的记录，不影响统计数据）
    if (_searchQuery.isNotEmpty) {
      // 获取匹配搜索条件的患者ID
      final Set<int> matchingPatientIds = {};
      for (final record in _financialRecords) {
        final patientName = record.patientName ?? '';
        final patientNamePinyin = record.patientNamePinyin ?? '';
        final patientNameInitials = record.patientNameInitials ?? '';
        final lowercaseQuery = _searchQuery.toLowerCase();
        final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');
        
        if (patientName.toLowerCase().contains(lowercaseQuery) ||
            patientNamePinyin.toLowerCase().contains(lowercaseQuery) ||
            patientNamePinyin.toLowerCase().contains(noSpaceQuery) ||
            patientNamePinyin.replaceAll(' ', '').toLowerCase().contains(lowercaseQuery) ||
            patientNameInitials.toLowerCase().contains(lowercaseQuery)) {
          matchingPatientIds.add(record.patientId);
        }
      }
      
      // 只返回匹配患者的财务项目
      return timeFilteredItems.where((item) {
        final record = _financialRecords.firstWhere(
          (r) => r.id == item.financialRecordId,
          orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );
        return matchingPatientIds.contains(record.patientId);
      }).toList();
    }
    
    return timeFilteredItems;
  }

  /// 计算总应收费金额（基于过滤后的财务项目）
  double _calculateTotalReceivable() {
    final filteredItems = _getFilteredItems();
    return filteredItems.fold<double>(0.0, (sum, item) => sum + item.itemPrice);
  }

  /// 计算总已收费金额（基于过滤后的财务项目）
  double _calculateTotalCollected() {
    final filteredItems = _getFilteredItems();
    return filteredItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// 计算总欠费金额（按患者维度计算，与统计图表逻辑完全一致）
  double _calculateTotalOutstanding() {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};
    
    // 获取所有财务项目
    final List<FinancialItem> allItems = [];
    for (final record in _financialRecords) {
      if (record.id != null && _recordItemsMap.containsKey(record.id)) {
        allItems.addAll(_recordItemsMap[record.id]!);
      }
    }
    
    // 按截止日期过滤：只计算结束日期之前的所有财务项目（与统计图表逻辑一致）
    List<FinancialItem> itemsBeforeEndDate = allItems;
    if (_endDate != null) {
      final endDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      itemsBeforeEndDate = allItems.where((item) {
        final itemDate = DateTime(item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
        return itemDate.isBefore(endDate) || itemDate.isAtSameMomentAs(endDate);
      }).toList();
    }
    
    // 如果有搜索条件，进一步过滤
    if (_searchQuery.isNotEmpty) {
      // 获取匹配搜索条件的患者ID
      final Set<int> matchingPatientIds = {};
      for (final record in _financialRecords) {
        final patientName = record.patientName ?? '';
        final patientNamePinyin = record.patientNamePinyin ?? '';
        final patientNameInitials = record.patientNameInitials ?? '';
        final lowercaseQuery = _searchQuery.toLowerCase();
        final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');
        
        if (patientName.toLowerCase().contains(lowercaseQuery) ||
            patientNamePinyin.toLowerCase().contains(lowercaseQuery) ||
            patientNamePinyin.toLowerCase().contains(noSpaceQuery) ||
            patientNamePinyin.replaceAll(' ', '').toLowerCase().contains(lowercaseQuery) ||
            patientNameInitials.toLowerCase().contains(lowercaseQuery)) {
          matchingPatientIds.add(record.patientId);
        }
      }
      
      // 只计算匹配患者的欠费
      itemsBeforeEndDate = itemsBeforeEndDate.where((item) {
        final record = _financialRecords.firstWhere(
          (r) => r.id == item.financialRecordId,
          orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );
        return matchingPatientIds.contains(record.patientId);
      }).toList();
    }

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      final record = _financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      
      if (record.patientId != 0) {
        final pid = record.patientId;
        receivableByPatient[pid] = (receivableByPatient[pid] ?? 0) + item.itemPrice;
        receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
      }
    }

    // 计算每个患者的欠费，只累加正数欠费
    double totalDebt = 0.0;
    receivableByPatient.forEach((pid, receivable) {
      final received = receivedByPatient[pid] ?? 0.0;
      final debt = receivable - received;
      if (debt > 0) {
        totalDebt += debt;
      }
    });

    return totalDebt;
  }

  /// 计算总加工费金额（基于过滤后的财务项目）
  double _calculateTotalProcessingFee() {
    final filteredItems = _getFilteredItems();
    return filteredItems.fold<double>(0.0, (sum, item) => sum + item.processingFee);
  }
}