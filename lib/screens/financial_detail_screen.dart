import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/database_models.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/success_toast.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/financial_record_dialog.dart';
import '../utils/permission_utils.dart';

/// 财务记录详情页面
class FinancialDetailScreen extends StatefulWidget {
  final FinancialRecord record;

  const FinancialDetailScreen({
    super.key,
    required this.record,
  });

  @override
  State<FinancialDetailScreen> createState() => _FinancialDetailScreenState();
}

class _FinancialDetailScreenState extends State<FinancialDetailScreen> {
  List<FinancialItem> _items = [];
  Patient? _patient;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.record.patientName ?? _patient?.name ?? '患者'} - 财务详情'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<String?>(
            future: _getRecordPatientDoctor(),
            builder: (context, snapshot) {
              final patientDoctor = snapshot.data;
              return PermissionWrapper(
                module: 'financial',
                action: 'edit',
                recordDoctor: patientDoctor,
                onPermissionDenied: () {
                  PermissionUtils.showPermissionDeniedMessage(
                    context,
                    customMessage: '您只能编辑自己负责患者的财务记录',
                  );
                },
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editRecord(context),
                  tooltip: '编辑备注',
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteRecord(context),
            tooltip: '删除记录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 患者基本信息卡片
                    _buildPatientInfoCard(),
                    
                    const SizedBox(height: 16),
                    
                    // 财务统计卡片
                    _buildFinancialSummaryCard(),
                    
                    const SizedBox(height: 16),
                    
                    // 收费记录历史卡片
                    _buildPaymentHistoryCard(),
                  ],
                ),
              ),
            ),
    );
  }

  /// 构建患者基本信息卡片
  Widget _buildPatientInfoCard() {
    // 优先使用FinancialRecord中的patientName，如果为空再使用_patient
    final displayName = widget.record.patientName ?? _patient?.name ?? '未知患者';
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 患者头像
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  displayName.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 患者信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '病历号: ${_patient?.medicalRecordNumber ?? _patient?.id ?? widget.record.patientId}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '首诊日期: ${DateFormat('yyyy-MM-dd').format(_patient?.firstVisitDate ?? DateTime.now())}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  // 添加备注字段显示
                  if (widget.record.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '备注: ${widget.record.notes}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建财务统计卡片
  Widget _buildFinancialSummaryCard() {
    final recordCount = _items.length;
    final totalReceivable = _items.fold<double>(
      0.0,
      (sum, item) => sum + item.itemPrice, // 与Windows端一致，不乘数量
    );
    final totalCollected = _items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final totalOutstanding = totalReceivable - totalCollected;
    final totalProcessingFee = _items.fold<double>(
      0.0,
      (sum, item) => sum + item.processingFee,
    );

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '财务统计',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 显示应收费、已收费、欠费
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '应收费',
                    '¥${NumberFormat('#,##0').format(totalReceivable)}',
                    Icons.account_balance_wallet,
                    Colors.green[600]!,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '已收费',
                    '¥${NumberFormat('#,##0').format(totalCollected)}',
                    Icons.payment,
                    Colors.orange[600]!,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总欠费',
                    '¥${NumberFormat('#,##0').format(totalOutstanding)}',
                    Icons.money_off,
                    totalOutstanding > 0 ? Colors.red[600]! : Colors.grey[600]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建收费记录历史卡片
  Widget _buildPaymentHistoryCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '收费记录历史 (${_items.length}条)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加记录', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '暂无收费记录',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _items.map((item) => _buildItemCard(item)).toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建收费项目卡片
  Widget _buildItemCard(FinancialItem item) {
    // per-item outstanding removed (show only totals in summary)
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：日期和操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM-dd HH:mm').format(item.chargeDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  FutureBuilder<String?>(
                    future: _getRecordPatientDoctor(),
                    builder: (context, snapshot) {
                      final patientDoctor = snapshot.data;
                      return PermissionWrapper(
                        module: 'financial',
                        action: 'edit',
                        recordDoctor: patientDoctor,
                        onPermissionDenied: () {
                          PermissionUtils.showPermissionDeniedMessage(
                            context,
                            customMessage: '您只能编辑自己负责患者的财务记录',
                          );
                        },
                        child: IconButton(
                          icon: Icon(Icons.edit, size: 18, color: Theme.of(context).primaryColor),
                          onPressed: () => _editItem(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => _deleteItem(item),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 第二行：收费项目名称
          Text(
            item.itemName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 第三行：金额信息（已移除每行欠费列，保留应收费/加工费/已收费）
          Row(
            children: [
              Expanded(
                child: _buildAmountInfo('应收费', '¥${NumberFormat('#,##0').format((item.itemPrice * (item.quantity ?? 1)))}', Theme.of(context).primaryColor),
              ),
              Expanded(
                child: _buildAmountInfo('加工费', '¥${NumberFormat('#,##0').format(item.processingFee)}', Colors.green[600]!),
              ),
              Expanded(
                child: _buildAmountInfo('已收费', '¥${NumberFormat('#,##0').format(item.totalPrice)}', Colors.orange[600]!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建金额信息项
  Widget _buildAmountInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);

      final items = await financialProvider.getFinancialItemsByRecordId(widget.record.id!);
      final patient = await patientProvider.getPatientById(widget.record.patientId!);
      
      setState(() {
        _items = items;
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 获取财务记录关联患者的医生字段，用于权限检查
  Future<String?> _getRecordPatientDoctor() async {
    try {
      if (_patient != null) {
        return _patient!.doctor;
      }
      
      // 如果患者数据还没加载，尝试获取
      if (widget.record.patientId != null) {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        final patient = await patientProvider.getPatientById(widget.record.patientId!);
        return patient?.doctor;
      }
      
      return null;
    } catch (e) {
      print('获取财务记录患者医生信息失败: $e');
      return null;
    }
  }

  /// 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange() async {
    try {
      final provider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await provider.getFinancialItemsByRecordId(widget.record.id!);
      final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 1));
      
      // 更新财务记录
      final updatedRecord = widget.record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );
      
      await provider.updateFinancialRecord(updatedRecord);
      print('✅ 财务记录更新成功：总数量 = $totalQuantity');
    } catch (e) {
      print('❌ 更新财务记录失败: $e');
    }
  }

  /// 编辑记录（仅备注）
  void _editRecord(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FinancialRecordDialog(
        record: widget.record,
        isEditingNotesOnly: true, // 传递一个标志，表示只编辑备注
      ),
    ).then((result) {
      if (result == true) {
        _loadData(); // 刷新数据以显示更新后的备注
        // 通知父页面有修改
        Navigator.of(context).pop(true);
      }
    });
  }

  /// 删除整个财务记录
  void _deleteRecord(BuildContext context) async {
    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: '患者 "${widget.record.patientName ?? _patient?.name ?? '该患者'}" 的财务记录',
    );

    if (confirmed == true) {
      try {
        final provider = Provider.of<FinancialProvider>(context, listen: false);
        // 注意：这里我们假设有一个 `deleteFinancialRecordByPatientId` 方法
        // 但从 `financial_management_screen.dart` 来看，更可能是按 `record.id` 删除
        await provider.deleteFinancialRecord(widget.record.id!);
        
        if (mounted) {
          DeleteSuccessToastManager.show(
            context,
            message: '财务记录删除成功',
          );
          Navigator.of(context).pop(true); // 返回并通知列表刷新
        }
      } catch (e) {
        if (mounted) {
          SuccessToastManager.showError(
            context,
            message: '删除失败: $e',
          );
        }
      }
    }
  }

  /// 添加收费项目
  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _FinancialItemAddDialog(
        financialRecordId: widget.record.id!,
        onSave: (newItem) async {
          try {
            final provider = Provider.of<FinancialProvider>(context, listen: false);
            await provider.addFinancialItem(newItem);
            
            // 更新财务记录的收费项数量和更新时间
            await _updateFinancialRecordAfterItemChange();
            
            if (mounted) {
              SuccessToastManager.show(
                context,
                message: '收费项目添加成功',
              );
              Navigator.of(context).pop(); // 关闭添加对话框
              _loadData(); // 重新加载数据
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('添加失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// 编辑收费项目
  void _editItem(FinancialItem item) {
    showDialog(
      context: context,
      builder: (context) => _FinancialItemEditDialog(
        item: item,
        onSave: (updatedItem) async {
          try {
            final provider = Provider.of<FinancialProvider>(context, listen: false);
            await provider.updateFinancialItem(updatedItem);
            
            // 更新财务记录的收费项数量和更新时间
            await _updateFinancialRecordAfterItemChange();
            
            if (mounted) {
              SuccessToastManager.show(
                context,
                message: '收费项目更新成功',
              );
              Navigator.of(context).pop(); // 关闭编辑对话框
              _loadData(); // 重新加载数据
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('更新失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// 删除收费项目
  void _deleteItem(FinancialItem item) async {
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: '收费项目"${item.itemName}"',
    );
    
    if (confirmed == true) {
      await _confirmDeleteItem(item);
    }
  }

  /// 确认删除收费项目
  Future<void> _confirmDeleteItem(FinancialItem item) async {
    try {
      final provider = Provider.of<FinancialProvider>(context, listen: false);
      await provider.deleteFinancialItem(item.id!);
      
      // 更新财务记录的收费项数量和更新时间
      await _updateFinancialRecordAfterItemChange();
      
      if (mounted) {
        // 使用公共组件的删除成功提示
        DeleteSuccessToastManager.show(
          context,
          message: '收费项目删除成功',
        );
        _loadData(); // 重新加载数据
      }
    } catch (e) {
      if (mounted) {
        // 使用公共组件的错误提示
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }
}

/// 财务项目编辑对话框
class _FinancialItemEditDialog extends StatefulWidget {
  final FinancialItem item;
  final Function(FinancialItem) onSave;

  const _FinancialItemEditDialog({
    required this.item,
    required this.onSave,
  });

  @override
  State<_FinancialItemEditDialog> createState() => _FinancialItemEditDialogState();
}

class _FinancialItemEditDialogState extends State<_FinancialItemEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _collectedAmountController = TextEditingController();
  final _processingFeeController = TextEditingController();
  final _chargeDateController = TextEditingController();

  final _itemPriceFocusNode = FocusNode();
  final _collectedAmountFocusNode = FocusNode();
  final _processingFeeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _collectedAmountController.dispose();
    _processingFeeController.dispose();
    _chargeDateController.dispose();

    _itemPriceFocusNode.dispose();
    _collectedAmountFocusNode.dispose();
    _processingFeeFocusNode.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _itemNameController.text = widget.item.itemName;
    _itemPriceController.text = widget.item.itemPrice.toInt().toString();
    _collectedAmountController.text = widget.item.totalPrice.toInt().toString();
    _processingFeeController.text = widget.item.processingFee.toInt().toString();
    _chargeDateController.text = DateFormat('yyyy-MM-dd').format(widget.item.chargeDate);

    _setupFocusNodeAndController(_itemPriceFocusNode, _itemPriceController, '0');
    _setupFocusNodeAndController(_collectedAmountFocusNode, _collectedAmountController, '0');
    _setupFocusNodeAndController(_processingFeeFocusNode, _processingFeeController, '0');
  }

  /// 计算欠费金额
  double _calculateOutstanding() {
    try {
      final receivable = double.tryParse(_itemPriceController.text) ?? 0.0;
      final collected = double.tryParse(_collectedAmountController.text) ?? 0.0;
      
      // 欠费金额 = 应收费 - 已收费
      return receivable - collected;
    } catch (e) {
      return 0.0;
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final updatedItem = widget.item.copyWith(
        itemName: _itemNameController.text,
        itemPrice: double.tryParse(_itemPriceController.text) ?? 0.0,
        processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
        quantity: 1, // 固定数量为1
        totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
        chargeDate: DateFormat('yyyy-MM-dd').parse(_chargeDateController.text),
        updatedAt: DateTime.now(),
      );
      
      widget.onSave(updatedItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '编辑收费项目',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
            
            // 表单内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 收费项目名称
                      TextFormField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          labelText: '收费项目名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入收费项目名称';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 金额信息行
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _itemPriceController,
                              focusNode: _itemPriceFocusNode,
                              decoration: const InputDecoration(
                                labelText: '应收费',
                                border: OutlineInputBorder(),
                                prefixText: '¥',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入应收费金额';
                                }
                                if (double.tryParse(value) == null) {
                                  return '请输入有效金额';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _collectedAmountController,
                              focusNode: _collectedAmountFocusNode,
                              decoration: const InputDecoration(
                                labelText: '已收费',
                                border: OutlineInputBorder(),
                                prefixText: '¥',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入已收费金额';
                                }
                                if (double.tryParse(value) == null) {
                                  return '请输入有效金额';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 加工费行
                      TextFormField(
                        controller: _processingFeeController,
                        focusNode: _processingFeeFocusNode,
                        decoration: const InputDecoration(
                          labelText: '加工费',
                          border: OutlineInputBorder(),
                          prefixText: '¥',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入加工费';
                          }
                          if (double.tryParse(value) == null) {
                            return '请输入有效金额';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 收费日期
                      TextFormField(
                        controller: _chargeDateController,
                        decoration: const InputDecoration(
                          labelText: '收费日期',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final date = await showDialog<DateTime>(
                            context: context,
                            builder: (BuildContext context) {
                              return ModernDatePickerDialog(
                                initialDate: DateFormat('yyyy-MM-dd').parse(_chargeDateController.text),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                title: '选择收费日期',
                              );
                            },
                          );
                          if (date != null) {
                            setState(() {
                              _chargeDateController.text = DateFormat('yyyy-MM-dd').format(date);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _setupFocusNodeAndController(FocusNode focusNode, TextEditingController controller, String defaultValue) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (controller.text == defaultValue) {
          controller.clear();
        }
      } else {
        if (controller.text.isEmpty) {
          controller.text = defaultValue;
        }
      }
    });
  }
}

/// 财务项目添加对话框
class _FinancialItemAddDialog extends StatefulWidget {
  final int financialRecordId;
  final Function(FinancialItem) onSave;

  const _FinancialItemAddDialog({
    required this.financialRecordId,
    required this.onSave,
  });

  @override
  State<_FinancialItemAddDialog> createState() => _FinancialItemAddDialogState();
}

class _FinancialItemAddDialogState extends State<_FinancialItemAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _collectedAmountController = TextEditingController();
  final _processingFeeController = TextEditingController();
  final _chargeDateController = TextEditingController();

  final _itemPriceFocusNode = FocusNode();
  final _collectedAmountFocusNode = FocusNode();
  final _processingFeeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _collectedAmountController.dispose();
    _processingFeeController.dispose();
    _chargeDateController.dispose();

    _itemPriceFocusNode.dispose();
    _collectedAmountFocusNode.dispose();
    _processingFeeFocusNode.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _itemNameController.text = '';
    _itemPriceController.text = '0';
    _collectedAmountController.text = '0';
    _processingFeeController.text = '0';
    // 移除数量字段，不再需要初始化
    _chargeDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _setupFocusNodeAndController(_itemPriceFocusNode, _itemPriceController, '0');
    _setupFocusNodeAndController(_collectedAmountFocusNode, _collectedAmountController, '0');
    _setupFocusNodeAndController(_processingFeeFocusNode, _processingFeeController, '0');
  }

  /// 计算欠费金额
  double _calculateOutstanding() {
    try {
      final receivable = double.tryParse(_itemPriceController.text) ?? 0.0;
      final collected = double.tryParse(_collectedAmountController.text) ?? 0.0;
      
      // 欠费金额 = 应收费 - 已收费
      return receivable - collected;
    } catch (e) {
      return 0.0;
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newItem = FinancialItem(
        financialRecordId: widget.financialRecordId,
        itemName: _itemNameController.text,
        itemPrice: double.tryParse(_itemPriceController.text) ?? 0.0,
        processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
        quantity: 1, // 固定数量为1
        totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
        chargeDate: DateFormat('yyyy-MM-dd').parse(_chargeDateController.text),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      widget.onSave(newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '添加收费项目',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
            
            // 表单内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 收费项目名称
                      TextFormField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          labelText: '收费项目名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入收费项目名称';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 金额信息行
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _itemPriceController,
                              focusNode: _itemPriceFocusNode,
                              decoration: const InputDecoration(
                                labelText: '应收费',
                                border: OutlineInputBorder(),
                                prefixText: '¥',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入应收费金额';
                                }
                                if (double.tryParse(value) == null) {
                                  return '请输入有效金额';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _collectedAmountController,
                              focusNode: _collectedAmountFocusNode,
                              decoration: const InputDecoration(
                                labelText: '已收费',
                                border: OutlineInputBorder(),
                                prefixText: '¥',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入已收费金额';
                                }
                                if (double.tryParse(value) == null) {
                                  return '请输入有效金额';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 加工费行
                      TextFormField(
                        controller: _processingFeeController,
                        focusNode: _processingFeeFocusNode,
                        decoration: const InputDecoration(
                          labelText: '加工费',
                          border: OutlineInputBorder(),
                          prefixText: '¥',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入加工费';
                          }
                          if (double.tryParse(value) == null) {
                            return '请输入有效金额';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 收费日期
                      TextFormField(
                        controller: _chargeDateController,
                        decoration: const InputDecoration(
                          labelText: '收费日期',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final date = await showDialog<DateTime>(
                            context: context,
                            builder: (BuildContext context) {
                              return ModernDatePickerDialog(
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                title: '选择收费日期',
                              );
                            },
                          );
                          if (date != null) {
                            setState(() {
                              _chargeDateController.text = DateFormat('yyyy-MM-dd').format(date);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setupFocusNodeAndController(FocusNode focusNode, TextEditingController controller, String defaultValue) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (controller.text == defaultValue) {
          controller.clear();
        }
      } else {
        if (controller.text.isEmpty) {
          controller.text = defaultValue;
        }
      }
    });
  }
}
