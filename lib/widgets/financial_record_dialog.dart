import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../models/database_models.dart';
import 'success_toast.dart';
import '../utils/datetime_formatter.dart';
import '../providers/database_provider.dart'; // Added import for DatabaseProvider
import '../widgets/modern_date_picker.dart';

class FinancialRecordDialog extends StatefulWidget {
  final FinancialRecord? record;
  final bool isEditingNotesOnly;
  
  const FinancialRecordDialog({
    super.key,
    this.record,
    this.isEditingNotesOnly = false,
  });

  @override
  State<FinancialRecordDialog> createState() => _FinancialRecordDialogState();
}

class _FinancialRecordDialogState extends State<FinancialRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _chargeDateController = TextEditingController();
  final _notesController = TextEditingController();
  final _patientSearchController = TextEditingController();
  final _itemNameController = TextEditingController();
  
  // 新增金额输入控制器
  final _receivableAmountController = TextEditingController();
  final _processingFeeController = TextEditingController();
  final _collectedAmountController = TextEditingController();
  
  // 焦点控制器
  final _receivableFocusNode = FocusNode();
  final _processingFocusNode = FocusNode();
  final _collectedFocusNode = FocusNode();
  // 欠费金额控制器已移除，UI中不再显示欠费字段
  
  List<FinancialItem> _financialItems = [];
  List<Patient> _availablePatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = false;
  bool _isEditing = false;
  Patient? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.record != null;
    _initializeControllers();
    if (widget.isEditingNotesOnly) {
      // 在仅编辑备注模式下，我们不需要加载所有患者
      // 但需要设置 _selectedPatient 以便显示患者姓名
      _selectedPatient = Patient(
        id: widget.record!.patientId,
        name: widget.record!.patientName ?? '未知患者',
        age: 0, // 提供一个默认值
        gender: '', // 提供一个默认值
        phone: '', // 提供一个默认值
        // 其他字段可以为空，因为它们不会被使用
        firstVisitDate: DateTimeFormatter.nowLocal(),
        medicalRecordNumber: null,
      );
    } else {
      _loadPatients();
    }
    if (_isEditing) {
      _loadFinancialItems();
    }
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _patientNameController.dispose();
    _chargeDateController.dispose();
    _notesController.dispose();
    _patientSearchController.dispose();
    _itemNameController.dispose();
    
    // 释放金额控制器
    _receivableAmountController.dispose();
    _processingFeeController.dispose();
    _collectedAmountController.dispose();
    
    // 释放焦点控制器
    _receivableFocusNode.dispose();
    _processingFocusNode.dispose();
    _collectedFocusNode.dispose();
    
    super.dispose();
  }

  void _initializeControllers() {
    if (_isEditing) {
      _patientIdController.text = widget.record!.patientId.toString();
      _patientNameController.text = widget.record!.patientName ?? ''; // 设置患者姓名
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(widget.record!.createdAt);
      _notesController.text = widget.record!.notes ?? '';
      
      // 如果有财务项目，使用第一个项目的数据初始化金额控制器
      if (_financialItems.isNotEmpty) {
        final firstItem = _financialItems.first;
        String fmt(double v) => (v % 1 == 0) ? v.toInt().toString() : v.toString();
        _receivableAmountController.text = fmt(firstItem.itemPrice);
        _processingFeeController.text = fmt(firstItem.processingFee);
        _collectedAmountController.text = fmt(firstItem.totalPrice);
        _itemNameController.text = firstItem.itemName;
      } else {
        // 如果没有项目，设置默认值
        _receivableAmountController.text = '0';
        _processingFeeController.text = '0';
        _collectedAmountController.text = '0';
        _itemNameController.text = '';
      }
  // 不再初始化欠费金额显示
    } else {
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(DateTimeFormatter.nowLocal());
      
      // 初始化金额控制器
      _receivableAmountController.text = '0';
      _processingFeeController.text = '0';
      _collectedAmountController.text = '0';
      _itemNameController.text = '';
  // 不再初始化欠费金额显示
    }
    
    // 设置焦点行为：聚焦时如果值为'0'则清空，失焦时如果为空则恢复'0'
    _receivableFocusNode.addListener(() {
      if (_receivableFocusNode.hasFocus) {
        if ((_receivableAmountController.text).trim() == '0') {
          _receivableAmountController.clear();
        }
      } else {
        if ((_receivableAmountController.text).trim().isEmpty) {
          _receivableAmountController.text = '0';
        }
      }
    });

    _processingFocusNode.addListener(() {
      if (_processingFocusNode.hasFocus) {
        if ((_processingFeeController.text).trim() == '0') {
          _processingFeeController.clear();
        }
      } else {
        if ((_processingFeeController.text).trim().isEmpty) {
          _processingFeeController.text = '0';
        }
      }
    });

    _collectedFocusNode.addListener(() {
      if (_collectedFocusNode.hasFocus) {
        if ((_collectedAmountController.text).trim() == '0') {
          _collectedAmountController.clear();
        }
      } else {
        if ((_collectedAmountController.text).trim().isEmpty) {
          _collectedAmountController.text = '0';
        }
      }
    });
  }

  /// 计算欠费金额
  double _calculateOutstanding() {
    try {
      final receivable = double.tryParse(_receivableAmountController.text) ?? 0.0;
      final collected = double.tryParse(_collectedAmountController.text) ?? 0.0;
      
      // 欠费金额 = 应收金额 - 已收金额（不包含加工费）
      return receivable - collected;
    } catch (e) {
      return 0.0;
    }
  }

  /// 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange(FinancialProvider provider, FinancialRecord record) async {
    try {
      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await provider.getFinancialItemsByRecordId(record.id!);
      final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 1));
      
      // 更新财务记录
      final updatedRecord = record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTimeFormatter.nowLocal(),
      );
      
      await provider.updateFinancialRecord(updatedRecord);
      print('✅ 财务记录更新成功：总数量 = $totalQuantity');
    } catch (e) {
      print('❌ 更新财务记录失败: $e');
    }
  }

  Future<void> _loadPatients() async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final patients = await patientProvider.getAllPatients();
      setState(() {
        _availablePatients = patients;
        _filteredPatients = patients; // 初始化过滤后的患者列表
      });
    } catch (e) {
      print('加载患者失败: $e');
    }
  }

  Future<void> _loadFinancialItems() async {
    if (!_isEditing) return;
    
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final items = await financialProvider.getFinancialItemsByRecordId(widget.record!.id!);
      setState(() {
        _financialItems = items;
      });
    } catch (e) {
      print('加载财务项目失败: $e');
    }
  }

  Future<void> _addFinancialItem() async {
    // 这里可以弹出一个对话框来添加财务项目
    // 暂时创建一个示例项目
    final newItem = FinancialItem(
      financialRecordId: widget.record?.id ?? 0,
      itemName: '治疗项目',
      itemPrice: 100.0,
      processingFee: 20.0,
      quantity: 1,
      totalPrice: 120.0,
      chargeDate: DateTimeFormatter.nowLocal(),
      createdAt: DateTimeFormatter.nowLocal(),
      updatedAt: DateTimeFormatter.nowLocal(),
    );
    
    setState(() {
      _financialItems.add(newItem);
    });
  }

  void _removeFinancialItem(FinancialItem item) {
    setState(() {
      _financialItems.remove(item);
    });
  }

  double _calculateTotalAmount() {
    return _financialItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateTotalReceivable() {
    return _financialItems.fold(0.0, (sum, item) => sum + (item.itemPrice + item.processingFee) * item.quantity);
  }

  double _calculateTotalCollected() {
    return _calculateTotalAmount();
  }

  /// 过滤患者列表
  void _filterPatients(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredPatients = _availablePatients;
      });
    } else {
      setState(() {
        _filteredPatients = _availablePatients.where((patient) {
          return patient.name.toLowerCase().contains(query.toLowerCase()) ||
                 patient.id.toString().contains(query);
        }).toList();
      });
    }
  }

  /// 显示患者搜索对话框
  void _showPatientSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => const PatientSearchDialog(),
    ).then((result) {
      if (result != null && result is Patient) {
        setState(() {
          _selectedPatient = result;
          _patientIdController.text = result.id.toString();
          _patientNameController.text = result.name;
        });
      }
    });
  }

  Future<void> _saveFinancialRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 只在非编辑备注模式下验证患者选择
    if (!widget.isEditingNotesOnly) {
      if (_selectedPatient == null || _selectedPatient!.id == null || _selectedPatient!.id == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择有效的患者'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // 验证患者是否存在
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final existingPatient = await patientProvider.getPatientById(_selectedPatient!.id!);
      if (existingPatient == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('选择的患者不存在，请重新选择'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('验证患者失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      if (_isEditing) {
        // 更新现有记录
        final updatedRecord = widget.record!.copyWith(
          patientId: _selectedPatient!.id!,
          notes: _notesController.text.trim(),
          updatedAt: DateTimeFormatter.nowLocal(),
          createdAt: DateTimeFormatter.fromDbString("${_chargeDateController.text} 00:00:00"),
        );
        
        await financialProvider.updateFinancialRecord(updatedRecord);
        
        // 如果不是仅编辑备注模式，更新财务项目
        if (!widget.isEditingNotesOnly) {
          // 更新第一个财务项目，如果没有则创建新的
          if (_financialItems.isNotEmpty) {
            final updatedItem = _financialItems.first.copyWith(
              itemName: _itemNameController.text.trim(),
              itemPrice: double.tryParse(_receivableAmountController.text) ?? 0.0,
              processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
              totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
              chargeDate: DateTimeFormatter.fromDbString("${_chargeDateController.text} 00:00:00"),
              updatedAt: DateTimeFormatter.nowLocal(),
            );
            await financialProvider.updateFinancialItem(updatedItem);
          } else {
            // 如果没有项目，创建新的
            final newItem = FinancialItem(
              financialRecordId: widget.record!.id!,
              itemName: '诊疗费用',
              itemPrice: double.tryParse(_receivableAmountController.text) ?? 0.0,
              processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
              quantity: 1,
              totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
              chargeDate: DateTimeFormatter.fromDbString("${_chargeDateController.text} 00:00:00"),
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            );
            await financialProvider.addFinancialItem(newItem);
          }
          
          // 更新财务记录的收费项数量和更新时间
          await _updateFinancialRecordAfterItemChange(financialProvider, widget.record!);
        }
        
        if (mounted) {
          Navigator.of(context).pop(true);
          SuccessToastManager.show(context, message: '财务记录更新成功');
        }
      } else {
        // 创建新记录
        final newRecord = FinancialRecord(
          patientId: _selectedPatient!.id!,
          totalQuantity: 1,  // 固定为1，因为我们是直接创建一个项目
          notes: _notesController.text.trim(),
          createdAt: DateTimeFormatter.fromDbString("${_chargeDateController.text} 00:00:00"),  // 使用选择的日期
          updatedAt: DateTimeFormatter.nowLocal(),
        );
        
        final recordId = await financialProvider.addFinancialRecord(newRecord);
        
        // 创建新的财务项目
        final newItem = FinancialItem(
          financialRecordId: recordId,
          itemName: _itemNameController.text.trim(),  // 使用用户输入的项目名称
          itemPrice: double.tryParse(_receivableAmountController.text) ?? 0.0,
          processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
          quantity: 1,
          totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
          chargeDate: DateTimeFormatter.fromDbString("${_chargeDateController.text} 00:00:00"),
          createdAt: DateTimeFormatter.nowLocal(),
          updatedAt: DateTimeFormatter.nowLocal(),
        );
        
        await financialProvider.addFinancialItem(newItem);
        
        if (mounted) {
          Navigator.of(context).pop(true);
          SuccessToastManager.show(context, message: '财务记录添加成功');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFinancialItemRow(FinancialItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // 项目名称列
          Expanded(
            flex: 3,
            child: Text(
              item.itemName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 数量列
          SizedBox(
            width: 50,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 单价列
          SizedBox(
            width: 60,
            child: Text(
              '¥${item.itemPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 总价列
          SizedBox(
            width: 60,
            child: Text(
              '¥${item.totalPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 操作列
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: () => _removeFinancialItem(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfoItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75, // 减少最大高度
          maxWidth: 400, // 限制最大宽度
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏 - 更紧凑的设计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isEditingNotesOnly ? '编辑备注' : (_isEditing ? '编辑记录' : '添加记录'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            
            // 表单内容 - 使用Flexible确保可以滚动
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 患者选择 - 简化设计
                      _buildSectionTitle('患者信息', Icons.person, Theme.of(context).primaryColor),
                      const SizedBox(height: 8),
                      
                      TextField(
                        controller: _patientNameController,
                        readOnly: true,
                        onTap: widget.isEditingNotesOnly ? null : () => _showPatientSearchDialog(),
                        decoration: InputDecoration(
                          hintText: '点击选择患者',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: _selectedPatient != null ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          suffixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 只在非编辑备注模式下显示收费信息部分
                      if (!widget.isEditingNotesOnly) ...[
                        _buildSectionTitle('收费信息', Icons.receipt, Colors.green),
                        const SizedBox(height: 8),
                        
                        // 收费日期和项目名称 - 紧凑布局
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _chargeDateController,
                                decoration: InputDecoration(
                                  labelText: '收费日期',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final date = await showDialog<DateTime>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return ModernDatePickerDialog(
                                        initialDate: DateTimeFormatter.nowLocal(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTimeFormatter.nowLocal().add(const Duration(days: 365)),
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
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 收费项目名称
                        TextFormField(
                          controller: _itemNameController,
                          decoration: InputDecoration(
                            labelText: '项目名称',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            hintText: '请输入收费项目名称',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入收费项目名称';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // 金额信息 - 紧凑的网格布局
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _receivableAmountController,
                                focusNode: _receivableFocusNode,
                                decoration: InputDecoration(
                                  labelText: '应收费',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  prefixText: '¥',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入金额';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return '无效金额';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _collectedAmountController,
                                focusNode: _collectedFocusNode,
                                decoration: InputDecoration(
                                  labelText: '已收费',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  prefixText: '¥',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入金额';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return '无效金额';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 加工费
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _processingFeeController,
                                focusNode: _processingFocusNode,
                                decoration: InputDecoration(
                                  labelText: '加工费',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  prefixText: '¥',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入加工费';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return '无效金额';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 占位空间，保持对齐
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                      
                      // 备注信息
                      _buildSectionTitle('备注信息', Icons.note, Colors.orange),
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: '备注',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          hintText: '请输入备注信息（可选）',
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            
            // 底部按钮 - 固定在底部，不会被键盘遮挡
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveFinancialRecord,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2.0,
                                ),
                              )
                            : Text(
                                _isEditing ? '更新' : '添加',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建节标题的辅助方法
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

/// 患者搜索对话框
class PatientSearchDialog extends StatefulWidget {
  const PatientSearchDialog({
    super.key,
  });

  @override
  State<PatientSearchDialog> createState() => _PatientSearchDialogState();
}

class _PatientSearchDialogState extends State<PatientSearchDialog> {
  final _searchController = TextEditingController();
  List<Patient> _allPatients = []; // 存储所有患者数据（使用 Patient 对象）
  List<Patient> _filteredPatients = []; // 过滤后的患者数据（Patient 对象）
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 从 PatientProvider 加载患者数据（使用 provider 的缓存与动态连接）
  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final patients = await patientProvider.getAllPatients();
      _allPatients = patients;
      // 初始化过滤后的列表
      _filteredPatients = List.from(_allPatients);
    } catch (e) {
      print('加载患者数据失败: $e');
      _allPatients = [];
      _filteredPatients = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 过滤患者列表
  void _filterPatients(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        // 如果搜索框为空，显示所有患者，按更新时间倒序排列
        _filteredPatients = List.from(_allPatients)
          ..sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
      } else {
        final qLower = query.toLowerCase();
        _filteredPatients = _allPatients
            .where((patient) {
              final name = (patient.name ?? '').toLowerCase();
              final id = (patient.id ?? 0).toString();
              return name.contains(qLower) || id.contains(query) || _containsPinyinInitials(name, qLower);
            })
            .toList()
          ..sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
      }
    });
  }

  /// 检查是否包含拼音首字母
  bool _containsPinyinInitials(String name, String query) {
    if (query.isEmpty || name.isEmpty) return false;
    
    try {
      // 获取姓名的拼音首字母
      final nameInitials = PinyinHelper.getShortPinyin(name).toLowerCase();
      // 获取姓名的完整拼音（无空格）
      final namePinyin = PinyinHelper.getPinyinE(name, separator: '', format: PinyinFormat.WITHOUT_TONE).toLowerCase();
      
      final queryLower = query.toLowerCase();
      
      // 支持多种搜索方式：
      // 1. 拼音首字母匹配 (例如: "zs" 匹配 "张三")
      // 2. 完整拼音匹配 (例如: "zhangsan" 匹配 "张三")
      // 3. 部分拼音匹配 (例如: "zhang" 匹配 "张三")
      return nameInitials.contains(queryLower) || 
             namePinyin.contains(queryLower) ||
             name.toLowerCase().contains(queryLower);
    } catch (e) {
      // 如果拼音转换失败，回退到简单的字符匹配
      return name.toLowerCase().contains(query.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // 标题栏 - 更紧凑的设计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_search,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '选择患者',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            
            // 搜索框 - 更紧凑的设计
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索患者姓名或拼音',
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filterPatients('');
                          },
                        )
                      : null,
                ),
                onChanged: _filterPatients,
              ),
            ),
            
            // 患者列表标题 - 减少padding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '患者列表 (${_filteredPatients.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            
            // 患者列表表头 - 减少padding，更紧凑
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.grey[600], size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '姓名',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey[600], size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '最近就诊',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 患者列表 - 减少行间距，更紧凑，与表头对齐
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '加载患者中...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredPatients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.people : Icons.search,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty ? '暂无患者数据' : '没有找到匹配的患者',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '请尝试其他搜索关键词',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
            : ListView.builder(
              padding: EdgeInsets.zero,
                          itemCount: _filteredPatients.length,
                          itemBuilder: (context, index) {
                            final patient = _filteredPatients[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 1),
                              child: InkWell(
                                onTap: () {
                                  final patientId = patient.id;
                                  if (patientId == null || patientId == 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('无效的患者ID，无法选择'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.of(context).pop(patient);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      // 姓名列 - 与表头对齐
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              color: Theme.of(context).primaryColor,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              patient.name ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 最近就诊列 - 与表头对齐
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          (patient.updatedAt ?? patient.createdAt ?? DateTimeFormatter.nowLocal()) is DateTime
                                              ? DateFormat('yyyy-MM-dd').format(patient.updatedAt ?? patient.createdAt ?? DateTimeFormatter.nowLocal())
                                              : DateFormat('yyyy-MM-dd').format(DateTimeFormatter.nowLocal()),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            // 底部按钮 - 减少padding
              // 已移除底部取消按钮，患者列表将直接延伸到对话框底部
          ],
        ),
      ),
    );
  }
}
