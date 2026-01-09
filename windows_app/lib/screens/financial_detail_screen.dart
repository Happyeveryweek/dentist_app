import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/success_toast.dart';
import '../utils/permission_utils.dart';
import 'financial_detail_form_dialog.dart';
import '../providers/settings_provider.dart';

class FinancialDetailScreen extends StatefulWidget {
  final Patient patient;
  final int? initialRecordId;

  const FinancialDetailScreen({
    Key? key,
    required this.patient,
    this.initialRecordId,
  }) : super(key: key);

  @override
  State<FinancialDetailScreen> createState() => _FinancialDetailScreenState();
}

class _FinancialDetailScreenState extends State<FinancialDetailScreen> {
  List<FinancialRecord> _patientRecords = [];
  List<Map<String, dynamic>> _detailedRecords = []; // 存储详细记录（包含明细项）
  bool _isLoading = true;
  bool _isEditing = false; // 新增：编辑状态标志
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();
  bool _hasDataChanged = false; // 跟踪数据是否有变动

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 检查权限，如果没有权限则不加载数据
    if (_canViewPatientFinancialRecords()) {
      _loadPatientRecords();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '权限不足：您只能查看自己医生的患者的财务记录';
      });
    }
  }

  // 加载患者的财务记录
  void _scrollToHighlightedRecord() {
    if (_detailedRecords.isEmpty) return;
    
    // 查找高亮记录的索引
    final highlightedIndex = _detailedRecords.indexWhere(
      (detailRecord) => detailRecord['isHighlighted'] as bool
    );
    
    if (highlightedIndex != -1 && _scrollController.hasClients) {
      // 计算滚动位置（居中显示）
      const itemHeight = 120.0; // 估计的卡片高度
      final screenHeight = MediaQuery.of(context).size.height;
      final scrollPosition = highlightedIndex * itemHeight - screenHeight / 2 + itemHeight / 2;
      
      _scrollController.animateTo(
        scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadPatientRecords() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final allRecords = await financialProvider.getAllFinancialRecords();
      
      // 获取该患者的所有财务记录
      final patientRecords = allRecords
          .where((record) => record.patientId == widget.patient.id)
          .toList();
      
      // 按日期排序，最新的在前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // 为每个财务记录加载其明细项
      final List<Map<String, dynamic>> detailedRecords = [];
      
      for (final record in patientRecords) {
        // 获取该财务记录的所有明细项
        final items = await financialProvider.getFinancialItemsByRecordId(record.id!);
        
        if (items.isNotEmpty) {
          // 如果有明细项，为每个明细项创建一个显示记录
          for (final item in items) {
            detailedRecords.add({
              'record': record,
              'item': item,
              'isDetail': true,
              'isHighlighted': widget.initialRecordId != null && record.id == widget.initialRecordId,
            });
          }
        } else {
          // 如果没有明细项，显示主记录
          detailedRecords.add({
            'record': record,
            'item': null,
            'isDetail': false,
            'isHighlighted': widget.initialRecordId != null && record.id == widget.initialRecordId,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _patientRecords = patientRecords;
          _detailedRecords = detailedRecords;
          _isLoading = false;
        });
        
        // 如果有初始记录ID，滚动到该记录
        if (widget.initialRecordId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToHighlightedRecord();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取财务记录失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否在弹窗中显示
    final isInDialog = ModalRoute.of(context)?.settings.name == null;
    
    if (isInDialog) {
      // 弹窗模式：不显示AppBar，直接显示内容
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 自定义标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.indigo[600]!],
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_hasDataChanged),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: '返回',
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.patient.name} - 财务详情',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_hasDataChanged),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            // 内容区域
            Expanded(child: _buildBody()),
          ],
        ),
      );
    } else {
      // 页面模式：显示完整的AppBar
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasDataChanged),
            tooltip: '返回',
          ),
          title: Text('${widget.patient.name} - 财务详情'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: _buildBody(),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_errorMessage, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPatientRecords,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_patientRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无收费记录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一条收费记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addFinancialRecord,
              icon: const Icon(Icons.add),
              label: const Text('添加记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 患者基本信息
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPatientInfoSection(),
        ),
        
        // 财务统计信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildFinancialStatsSection(),
        ),
        
        // 财务记录列表标题和表头
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16), // 添加顶部间距
              _buildRecordsListHeader(),
              const SizedBox(height: 8),
              _buildTableHeader(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // 财务记录列表 - 使用Expanded而不是SingleChildScrollView
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRecordsList(),
          ),
        ),
      ],
    );
  }

  // 构建患者基本信息区域
  Widget _buildPatientInfoSection() {
    final bool isFemale = (widget.patient.gender == '女') ||
        (widget.patient.gender.toLowerCase() == 'female');
    final Color? infoBgColor = isFemale ? Colors.pink[50] : Colors.blue[50];
    final Color infoBorderColor =
        isFemale ? Colors.pink[200]! : Colors.blue[200]!;
    final Color avatarBgColor = isFemale ? Colors.pink[400]! : Colors.blue[300]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: infoBorderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: avatarBgColor,
            child: Text(
              widget.patient.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text('病历号: ${widget.patient.medical_record_number ?? '未设置'}'),
                Text('首诊日期: ${DateFormat('yyyy-MM-dd').format(widget.patient.first_visit_date)}'),
                const SizedBox(height: 4),
                Text(
                  '备注信息: ${_getPatientNotes()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 获取患者备注信息
  String _getPatientNotes() {
    // 获取患者最新的财务记录备注信息
    if (_patientRecords.isNotEmpty) {
      final latestRecord = _patientRecords.first;
      if (latestRecord.notes != null && latestRecord.notes!.isNotEmpty) {
        return latestRecord.notes!;
      }
    }
    return '暂无备注信息';
  }

  // 获取或创建财务记录
  Future<FinancialRecord?> _getOrCreateFinancialRecord() async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 首先检查该患者是否已有财务记录
      final existingRecords = await financialProvider.getFinancialRecordsByPatientId(widget.patient.id!);
      
      if (existingRecords.isNotEmpty) {
        // 如果已有记录，返回第一个记录（通常按创建时间排序）
        return existingRecords.first;
      } else {
        // 如果没有记录，创建新的财务记录
        final newRecord = FinancialRecord(
          id: null,
          patientId: widget.patient.id!,
          totalQuantity: 0, // 初始数量为0，添加收费项时会更新
          notes: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final recordId = await financialProvider.addFinancialRecord(newRecord);
        
        if (recordId > 0) {
          // 返回创建的记录
          return newRecord.copyWith(id: recordId);
        } else {
          return null;
        }
      }
    } catch (e) {
      print('获取或创建财务记录失败: $e');
      return null;
    }
  }

  // 添加财务记录
  Future<void> _addFinancialRecord() async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能为自己医生的患者添加财务记录。',
      );
      return;
    }

    // 获取或创建财务记录
    FinancialRecord? targetRecord = await _getOrCreateFinancialRecord();
    
    if (targetRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法创建财务记录')),
      );
      return;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialDetailFormDialog(
        patient: widget.patient,
        record: targetRecord,
        item: null,
        onResult: (success) {
          Navigator.of(context).pop(success);
        },
      ),
    );
    
    if (result == true) {
      // 标记数据已变动
      _hasDataChanged = true;
      // 更新患者的财务统计
      await _updatePatientFinancialSummary();
      // 重新加载数据
      await _loadPatientRecords();
    }
  }

  // 编辑财务记录
  Future<void> _editFinancialRecord(FinancialRecord record, {FinancialItem? item, bool isDetail = false}) async {
    if (isDetail && item != null) {
      // 编辑明细项：使用财务详情页专用表单
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => FinancialDetailFormDialog(
          patient: widget.patient,
          record: record,
          item: item,
          onResult: (success) {
            Navigator.of(context).pop(success);
          },
        ),
      );
      
      if (result == true) {
        // 标记数据已变动
        _hasDataChanged = true;
        // 编辑明细项成功后，需要更新明细项数据
        try {
          // 更新患者的财务统计
          await _updatePatientFinancialSummary();
          // 重新加载数据
          await _loadPatientRecords();
        } catch (e) {
          print('更新明细项时出错: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新明细项失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // 编辑主记录：也使用财务详情页专用表单
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => FinancialDetailFormDialog(
          patient: widget.patient,
          record: record,
          item: null,
          onResult: (success) {
            Navigator.of(context).pop(success);
          },
        ),
      );
      
      if (result == true) {
        // 标记数据已变动
        _hasDataChanged = true;
        // 更新患者的财务统计
        await _updatePatientFinancialSummary();
        // 重新加载数据
        await _loadPatientRecords();
      }
    }
  }

  // 删除财务记录
  Future<void> _deleteFinancialRecord(FinancialRecord record, {FinancialItem? item, bool isDetail = false}) async {
    if (isDetail && item != null) {
      // 删除明细项
      final confirmed = await _showDeleteConfirmation(
        '确认删除',
        '确定要删除患者 "${widget.patient.name}" 的这条收费明细项吗？\n\n'
            '收费项目: ${item.itemName}\n'
            '收费日期: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\n\n'
            '删除后无法恢复！',
      );

      if (confirmed == true) {
        try {
          final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
          
          // 删除明细项
          final success = await financialProvider.deleteFinancialItem(item.id!);
          
          if (success) {
            // 标记数据已变动
            _hasDataChanged = true;
            // 更新财务记录的收费项数量和更新时间
            await _updateFinancialRecordAfterItemChange(record);
            // 删除成功后，更新患者的财务统计
            await _updatePatientFinancialSummary();
            // 重新加载数据
            await _loadPatientRecords();
            
            DeleteSuccessToastManager.show(
              context,
              message: '已删除患者 "${widget.patient.name}" 的收费明细项',
            );
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
    } else {
      // 删除整个财务记录
      final confirmed = await _showDeleteConfirmation(
        '确认删除',
        '确定要删除患者 "${widget.patient.name}" 的这条财务记录吗？\n\n'
            '收费项目: ${record.notes ?? '收费项目'}\n'
            '收费日期: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\n\n'
            '删除后无法恢复！',
      );

      if (confirmed == true) {
        try {
          final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
          final success = await financialProvider.deleteFinancialRecord(record.id!);
          
          if (success) {
            // 标记数据已变动
            _hasDataChanged = true;
            // 删除成功后，更新患者的财务统计
            await _updatePatientFinancialSummary();
            // 重新加载数据
            await _loadPatientRecords();
            
            DeleteSuccessToastManager.show(
              context,
              message: '已删除患者 "${widget.patient.name}" 的财务记录',
            );
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
  }

  // 显示删除确认对话框
  Future<bool> _showDeleteConfirmation(String title, String message) async {
    return await DeleteConfirmDialogManager.show(
      context,
      title: title,
      message: message,
    );
  }

  // 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange(FinancialRecord record) async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await financialProvider.getFinancialItemsByRecordId(record.id!);
      final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 1));
      
      // 更新财务记录
      final updatedRecord = record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );
      
      await financialProvider.updateFinancialRecord(updatedRecord);
    } catch (e) {
      print('更新财务记录失败: $e');
    }
  }

  // 更新患者的财务统计（在添加或删除记录后调用）
  Future<void> _updatePatientFinancialSummary() async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 调用新的方法更新患者的总体财务统计信息
      await financialProvider.updatePatientFinancialSummary(widget.patient.id!);
      
    } catch (e) {
      print('更新患者财务统计失败: $e');
    }
  }

  // 构建财务统计信息区域
  Widget _buildFinancialStatsSection() {
    return Container(
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
              icon: Icons.square,
              label: '应收费',
              value: '¥${(_totalReceivable % 1 == 0 ? _totalReceivable.toInt().toString() : _totalReceivable.toStringAsFixed(2))}',
              color: Colors.blue[700]!,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.check_circle,
              label: '已收费',
              value: '¥${(_totalPaid % 1 == 0 ? _totalPaid.toInt().toString() : _totalPaid.toStringAsFixed(2))}',
              color: Colors.green[700]!,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.more_horiz,
              label: '欠费金额',
              value: '¥${(_totalOutstanding % 1 == 0 ? _totalOutstanding.toInt().toString() : _totalOutstanding.toStringAsFixed(2))}',
              color: _totalOutstanding > 0 ? Colors.red[700]! : Colors.grey[600]!,
            ),
          ),
        ],
      ),
    );
  }

  // 构建统计项组件
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 计算统计数据
  double get _totalReceivable {
    // 从financial_items表中计算应收费金额（不包含加工费）
    double total = 0.0;
    for (final detailRecord in _detailedRecords) {
      final item = detailRecord['item'] as FinancialItem?;
      if (detailRecord['isDetail'] == true && item != null) {
        total += (item.itemPrice * (item.quantity ?? 1));
      }
    }
    return total;
  }
  
  double get _totalPaid {
    // 从financial_items表中计算已收费金额
    double total = 0.0;
    for (final detailRecord in _detailedRecords) {
      final item = detailRecord['item'] as FinancialItem?;
      if (detailRecord['isDetail'] == true && item != null) {
        total += item.totalPrice;
      }
    }
    return total;
  }
  
  double get _totalOutstanding {
    // 从financial_items表中计算欠费金额（应收费 - 已收费）
    return _totalReceivable - _totalPaid;
  }

  // 构建财务记录列表标题
  Widget _buildRecordsListHeader() {
    return Row(
      children: [
        Icon(Icons.list_alt, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '收费记录历史 (${_detailedRecords.length}条)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _addFinancialRecord,
          icon: const Icon(Icons.add),
          label: const Text('添加记录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // 构建表头
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('日期', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.left)),
          Expanded(flex: 3, child: Text('收费项目', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.left)),
          Expanded(flex: 2, child: Text('应收费', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.left)),
          Expanded(flex: 2, child: Text('加工费', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.left)),
          Expanded(flex: 2, child: Text('已收费', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.left)),
          SizedBox(width: 80, child: Text('操作', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  // 构建财务记录列表
  Widget _buildRecordsList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _detailedRecords.length,
      itemBuilder: (context, index) {
        final detailRecord = _detailedRecords[index];
        final record = detailRecord['record'] as FinancialRecord;
        final item = detailRecord['item'] as FinancialItem?;
        final isDetail = detailRecord['isDetail'] as bool;
        final isHighlighted = detailRecord['isHighlighted'] as bool;
        
        return _buildFinancialRecordCard(
          record, 
          item: item, 
          isDetail: isDetail, 
          isHighlighted: isHighlighted
        );
      },
    );
  }

  // 构建财务记录卡片
  Widget _buildFinancialRecordCard(FinancialRecord record, {FinancialItem? item, bool isDetail = false, bool isHighlighted = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isHighlighted ? Colors.blue[50] : null,
      elevation: isHighlighted ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 日期列
            Expanded(
              flex: 2, 
              child: Text(
                isDetail && item != null 
                  ? DateFormat('yyyy-MM-dd').format(item.chargeDate)
                  : DateFormat('yyyy-MM-dd').format(record.createdAt), 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.left,
              )
            ),
            // 收费项目列
            Expanded(
              flex: 3, 
              child: Text(
                isDetail && item != null ? item.itemName : (record.notes ?? '收费项目'), 
                style: Theme.of(context).textTheme.bodyMedium, 
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              )
            ),
            // 应收费列
            Expanded(
              flex: 2, 
              child: Text(
                isDetail && item != null ? '¥${((item.itemPrice * (item.quantity ?? 1)) % 1 == 0 ? (item.itemPrice * (item.quantity ?? 1)).toInt().toString() : (item.itemPrice * (item.quantity ?? 1)).toStringAsFixed(2))}' : '¥0', 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.blue[700], fontWeight: FontWeight.w500),
                textAlign: TextAlign.left,
              )
            ),
            // 加工费列
            Expanded(
              flex: 2, 
              child: Text(
                isDetail && item != null ? '¥${(item.processingFee % 1 == 0 ? item.processingFee.toInt().toString() : item.processingFee.toStringAsFixed(2))}' : '¥0', 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange[700], fontWeight: FontWeight.w500),
                textAlign: TextAlign.left,
              )
            ),
            // 已收费列
            Expanded(
              flex: 2, 
              child: Text(
                isDetail && item != null ? '¥${(item.totalPrice % 1 == 0 ? item.totalPrice.toInt().toString() : item.totalPrice.toStringAsFixed(2))}' : '¥0', 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green[700], fontWeight: FontWeight.w500),
                textAlign: TextAlign.left,
              )
            ),
            // 欠费列 已移除，UI不再显示单项欠费
            // 操作列
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isEditing 
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        ),
                      )
                    : IconButton(
                        onPressed: () => _editFinancialRecordFromList(record, item: item, isDetail: isDetail),
                        icon: Icon(Icons.edit, color: Colors.blue[600]),
                        tooltip: '编辑',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  IconButton(
                    onPressed: _isEditing ? null : () => _deleteFinancialRecord(record, item: item, isDetail: isDetail),
                    icon: Icon(Icons.delete, color: _isEditing ? Colors.grey[400] : Colors.red[600]),
                    tooltip: _isEditing ? '正在编辑中...' : '删除',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 从财务管理列表编辑财务记录
  /// 这是专门用于财务管理列表编辑按钮的方法，与其他编辑方法分离
  Future<void> _editFinancialRecordFromList(FinancialRecord record, {FinancialItem? item, bool isDetail = false}) async {
    try {
      setState(() {
        _isEditing = true; // 使用专门的编辑状态
      });

      // 获取患者基础信息
      final patient = widget.patient;
      
      // 直接使用传入的 record 和 item 参数，而不是重新获取最新的
      FinancialRecord? latestRecord = record;
      FinancialItem? latestFinancialItem = item;

      setState(() {
        _isEditing = false; // 数据加载完成，关闭编辑状态
      });

      // 检查是否找到了财务记录
      if (latestRecord == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('患者 "${patient.name}" 暂无财务记录，无法编辑'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 验证财务记录数据的有效性
      if (latestRecord.patientId != patient.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('财务记录数据异常，患者ID不匹配'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 如果找到了明细项，验证其有效性
      if (latestFinancialItem != null && latestFinancialItem.financialRecordId != latestRecord.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('财务明细项数据异常，记录ID不匹配'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 显示编辑对话框
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // 防止误触关闭
        builder: (context) => FinancialDetailFormDialog(
          patient: patient,
          record: latestRecord,
          item: latestFinancialItem,
          onResult: (success) {
            Navigator.of(context).pop(success);
          },
        ),
      );
      
      if (result == true) {
        // 编辑成功后，更新患者的财务统计
        await _updatePatientFinancialSummary();
        // 重新加载数据
        await _loadPatientRecords();
        
        // 标记数据已变动
        _hasDataChanged = true;
        // 显示成功提示
        if (mounted) {
          SuccessToastManager.show(
            context,
            message: '已成功编辑患者 "${patient.name}" 的财务记录',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isEditing = false; // 发生错误时也要关闭编辑状态
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('编辑财务记录失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // 记录错误日志
      print('编辑财务记录时发生错误: $e');
    }
  }

  /// SQLite 数据源：获取患者最近的一条财务记录
  Future<FinancialRecord?> _getLatestFinancialRecordSQLite(int patientId) async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final allRecords = await financialProvider.getAllFinancialRecords();
      
      // 筛选该患者的记录并按时间排序
      final patientRecords = allRecords
          .where((record) => record.patientId == patientId)
          .toList();
      
      if (patientRecords.isEmpty) return null;
      
      // 按更新时间排序，最新的在前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return patientRecords.first;
    } catch (e) {
      print('SQLite获取患者最近财务记录失败: $e');
      return null;
    }
  }

  /// MySQL 数据源：获取患者最近的一条财务记录
  Future<FinancialRecord?> _getLatestFinancialRecordMySQL(int patientId) async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final allRecords = await financialProvider.getAllFinancialRecords();
      
      // 筛选该患者的记录并按时间排序
      final patientRecords = allRecords
          .where((record) => record.patientId == patientId)
          .toList();
      
      if (patientRecords.isEmpty) return null;
      
      // 按更新时间排序，最新的在前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return patientRecords.first;
    } catch (e) {
      print('MySQL获取患者最近财务记录失败: $e');
      return null;
    }
  }

  /// SQLite 数据源：获取财务记录最近的一条明细项
  Future<FinancialItem?> _getLatestFinancialItemSQLite(int recordId) async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final items = await financialProvider.getFinancialItemsByRecordId(recordId);
      
      if (items.isEmpty) return null;
      
      // 按收费日期排序，最新的在前面
      items.sort((a, b) => b.chargeDate.compareTo(a.chargeDate));
      
      return items.first;
    } catch (e) {
      print('SQLite获取最近财务明细项失败: $e');
      return null;
    }
  }

  /// MySQL 数据源：获取财务记录最近的一条明细项
  Future<FinancialItem?> _getLatestFinancialItemMySQL(int recordId) async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final items = await financialProvider.getFinancialItemsByRecordId(recordId);
      
      if (items.isEmpty) return null;
      
      // 按收费日期排序，最新的在前面
      items.sort((a, b) => b.chargeDate.compareTo(a.chargeDate));
      
      return items.first;
    } catch (e) {
      print('MySQL获取最近财务明细项失败: $e');
      return null;
    }
  }

  /// 获取当前数据源类型
  String get _dataSourceType {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      // 优先使用模块化数据源配置，如果没有则使用全局数据源类型
      final effectiveDataSourceType = settingsProvider.moduleDataSources['financial'] ?? settingsProvider.dataSourceType;
      print('财务详情页 - 当前数据源类型: ${settingsProvider.dataSourceType}, 模块化数据源类型: ${settingsProvider.moduleDataSources['financial']}, 最终使用: $effectiveDataSourceType');
      return effectiveDataSourceType;
    } catch (e) {
      return 'sqlite'; // 默认使用 SQLite
    }
  }

  /// 检查当前用户是否可以查看该患者的财务记录
  bool _canViewPatientFinancialRecords() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      print('=== 财务详情页权限检查 ===');
      print('当前用户: ${currentUser?.username}');
      print('用户角色: ${currentUser?.role}');
      print('用户医生: ${currentUser?.doctor}');
      print('患者姓名: ${widget.patient.name}');
      print('患者医生: ${widget.patient.doctor}');
      print('用户是否为管理员: ${currentUser?.isAdmin}');
      
      if (currentUser == null) {
        print('权限检查结果: false (用户未登录)');
        return false;
      }
      
      // 管理员拥有所有权限
      if (currentUser.isAdmin) {
        print('权限检查结果: true (管理员权限)');
        return true;
      }
      
      // 非管理员用户只能查看自己医生的患者的财务记录
      // 如果患者没有指定医生，或者当前用户的医生与患者的医生匹配，则允许查看
      if (widget.patient.doctor == null || widget.patient.doctor!.isEmpty) {
        // 如果患者没有指定医生，所有用户都可以查看
        print('权限检查结果: true (患者未指定医生)');
        return true;
      }
      
      // 检查当前用户的医生是否与患者的医生匹配
      final hasPermission = currentUser.doctor != null && currentUser.doctor == widget.patient.doctor;
      print('权限检查结果: $hasPermission (医生匹配检查)');
      return hasPermission;
    } catch (e) {
      print('检查财务记录查看权限时出错: $e');
      return false;
    }
  }
}