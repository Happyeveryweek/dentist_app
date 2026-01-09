import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient.dart';
import '../providers/financial_provider.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/success_toast.dart';
import '../widgets/success_toast.dart' show ErrorDialogManager;

class FinancialDetailFormDialog extends StatefulWidget {
  final Patient patient;
  final FinancialRecord? record;
  final FinancialItem? item;
  final Function(bool)? onResult;

  const FinancialDetailFormDialog({
    Key? key,
    required this.patient,
    this.record,
    this.item,
    this.onResult,
  }) : super(key: key);

  @override
  State<FinancialDetailFormDialog> createState() => _FinancialDetailFormDialogState();
}

class _FinancialDetailFormDialogState extends State<FinancialDetailFormDialog> {
  // 表单控制器
  final TextEditingController _chargeDateController = TextEditingController();
  final TextEditingController _treatmentItemsController = TextEditingController();
  final TextEditingController _receivableAmountController = TextEditingController();
  final TextEditingController _processingFeeController = TextEditingController();
  final TextEditingController _collectedAmountController = TextEditingController();

  // 焦点节点
  final FocusNode _receivableAmountFocusNode = FocusNode();
  final FocusNode _processingFeeFocusNode = FocusNode();
  final FocusNode _collectedAmountFocusNode = FocusNode();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    
    // 添加焦点监听器
    _receivableAmountFocusNode.addListener(_handleReceivableAmountFocus);
    _processingFeeFocusNode.addListener(_handleProcessingFeeFocus);
    _collectedAmountFocusNode.addListener(_handleCollectedAmountFocus);
  }

  @override
  void dispose() {
    _receivableAmountFocusNode.removeListener(_handleReceivableAmountFocus);
    _processingFeeFocusNode.removeListener(_handleProcessingFeeFocus);
    _collectedAmountFocusNode.removeListener(_handleCollectedAmountFocus);
    _receivableAmountFocusNode.dispose();
    _processingFeeFocusNode.dispose();
    _collectedAmountFocusNode.dispose();
    
    _chargeDateController.dispose();
    _treatmentItemsController.dispose();
    _receivableAmountController.dispose();
    _processingFeeController.dispose();
    _collectedAmountController.dispose();
    super.dispose();
  }

  // 初始化表单数据
  void _initializeForm() {
    final isEdit = widget.record != null;

    if (isEdit && widget.item != null) {
      // 编辑模式：使用收费日期charge_date
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(widget.item!.chargeDate);
      _treatmentItemsController.text = widget.item!.itemName;
      _receivableAmountController.text = widget.item!.itemPrice % 1 == 0 
          ? widget.item!.itemPrice.toInt().toString() 
          : widget.item!.itemPrice.toString();
      _processingFeeController.text = widget.item!.processingFee % 1 == 0 
          ? widget.item!.processingFee.toInt().toString() 
          : widget.item!.processingFee.toString();
      _collectedAmountController.text = widget.item!.totalPrice % 1 == 0 
          ? widget.item!.totalPrice.toInt().toString() 
          : widget.item!.totalPrice.toString();
    } else {
      // 新增模式
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _treatmentItemsController.text = '综合收费';
      _receivableAmountController.text = '0';
      _processingFeeController.text = '0';
      _collectedAmountController.text = '0';
    }
  }

  // 焦点处理函数
  void _handleReceivableAmountFocus() {
    if (!_receivableAmountFocusNode.hasFocus && _receivableAmountController.text.isEmpty) {
      _receivableAmountController.text = '0';
    }
  }

  void _handleProcessingFeeFocus() {
    if (!_processingFeeFocusNode.hasFocus && _processingFeeController.text.isEmpty) {
      _processingFeeController.text = '0';
    }
  }

  void _handleCollectedAmountFocus() {
    if (!_collectedAmountFocusNode.hasFocus && _collectedAmountController.text.isEmpty) {
      _collectedAmountController.text = '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.record != null;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[600]!, Colors.teal[600]!],
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdit ? Icons.edit_note : Icons.receipt_long,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEdit ? '编辑收费记录' : '添加收费记录',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minHeight: 400,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientInfoSection(),
              const SizedBox(height: 16),
              _buildChargeInfoSection(),
              const SizedBox(height: 16),
              _buildAmountInfoSection(),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  // 构建患者信息区域
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: infoBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: infoBorderColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: avatarBgColor,
            child: Text(
              widget.patient.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: infoBorderColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '患者信息',
                      style: TextStyle(
                        color: infoBorderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.patient.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.badge,
                        label: '病历号',
                        value: widget.patient.medical_record_number?.toString() ?? '未设置',
                        color: Colors.orange[600]!,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: '首诊日期',
                        value: DateFormat('MM-dd').format(widget.patient.first_visit_date),
                        color: Colors.purple[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建信息芯片
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // 构建收费信息区域
  Widget _buildChargeInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange[200]!.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.orange[700],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '收费信息',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 收费日期
          _buildStyledTextField(
            controller: _chargeDateController,
            label: '收费日期',
            icon: Icons.calendar_month,
            readOnly: true,
            onTap: _selectChargeDate,
            borderColor: Colors.orange[300]!,
            iconColor: Colors.orange[600]!,
          ),
          
          const SizedBox(height: 12),
          
          // 收费项目
          _buildStyledTextField(
            controller: _treatmentItemsController,
            label: '收费项目',
            icon: Icons.medical_services,
            hintText: '例如：洗牙、补牙、根管治疗等',
            borderColor: Colors.orange[300]!,
            iconColor: Colors.orange[600]!,
          ),
        ],
      ),
    );
  }

  // 构建金额信息区域
  Widget _buildAmountInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purple[200]!.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.purple[700],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '金额信息',
                style: TextStyle(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 第一行：应收费金额和加工费
          Row(
            children: [
              Expanded(
                child: _buildStyledTextField(
                  controller: _receivableAmountController,
                  focusNode: _receivableAmountFocusNode,
                  label: '应收费金额',
                  icon: Icons.request_quote,
                  keyboardType: TextInputType.number,
                  borderColor: Colors.blue[300]!,
                  iconColor: Colors.blue[600]!,
                  onTap: () {
                    if (_receivableAmountController.text == '0') {
                      _receivableAmountController.clear();
                    }
                  },
                  onChanged: (value) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStyledTextField(
                  controller: _processingFeeController,
                  focusNode: _processingFeeFocusNode,
                  label: '加工费',
                  icon: Icons.build,
                  keyboardType: TextInputType.number,
                  borderColor: Colors.orange[300]!,
                  iconColor: Colors.orange[600]!,
                  onTap: () {
                    if (_processingFeeController.text == '0') {
                      _processingFeeController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 第二行：已收费金额
          _buildStyledTextField(
            controller: _collectedAmountController,
            focusNode: _collectedAmountFocusNode,
            label: '已收费金额',
            icon: Icons.check_circle,
            keyboardType: TextInputType.number,
            borderColor: Colors.green[300]!,
            iconColor: Colors.green[600]!,
            onTap: () {
              if (_collectedAmountController.text == '0') {
                _collectedAmountController.clear();
              }
            },
            onChanged: (value) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // 构建样式化的文本字段
  Widget _buildStyledTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required IconData icon,
    String? hintText,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    required Color borderColor,
    required Color iconColor,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: iconColor, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // 构建操作按钮
  List<Widget> _buildActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 取消按钮
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '取消',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 保存按钮
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[500]!, Colors.teal[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.item != null ? '更新中...' : '保存中...',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        widget.record != null ? Icons.update : Icons.save,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.item != null ? '更新' : '保存',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // 选择收费日期
  Future<void> _selectChargeDate() async {
    final date = await showDialog<DateTime>(
      context: context,
      builder: (context) => ModernDatePickerDialog(
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        title: '选择收费日期',
      ),
    );
    
    if (date != null) {
      setState(() {
        _chargeDateController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  // 更新财务记录
  Future<void> _updateFinancialRecord() async {
    if (widget.record == null) return;
    
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await financialProvider.getFinancialItemsByRecordId(widget.record!.id!);
      final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 1));
      
      // 更新财务记录
      final updatedRecord = widget.record!.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );
      
      await financialProvider.updateFinancialRecord(updatedRecord);
    } catch (e) {
      print('更新财务记录失败: $e');
    }
  }

  // 保存记录
  Future<void> _saveRecord() async {
    // 验证表单
    if (_treatmentItemsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入收费项目名称')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final selectedDate = DateFormat('yyyy-MM-dd').parse(_chargeDateController.text);
      
      if (widget.item != null) {
        // 编辑模式：更新现有收费项
        final updatedItem = FinancialItem(
          id: widget.item!.id,
          financialRecordId: widget.item!.financialRecordId,
          itemName: _treatmentItemsController.text.trim(),
          itemPrice: double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
          processingFee: double.tryParse(_processingFeeController.text.replaceAll('¥', '').trim()) ?? 0.0,
          quantity: widget.item!.quantity,
          totalPrice: double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
          chargeDate: selectedDate,
          createdAt: widget.item!.createdAt,
          updatedAt: DateTime.now(),
        );
        
        final success = await financialProvider.updateFinancialItem(updatedItem);
        
        if (success) {
          // 更新财务记录的更新时间和收费项数量
          await _updateFinancialRecord();
          
          // 更新患者的总体财务统计信息
          await financialProvider.updatePatientFinancialSummary(widget.patient.id!);
          
          SuccessToastManager.show(context, message: '收费记录更新成功');
          if (widget.onResult != null) {
            widget.onResult!(true);
          }
        } else {
          SuccessToastManager.showError(context, message: '更新失败，请重试');
        }
      } else {
        // 新增模式：添加新的收费项到现有记录
        if (widget.record != null) {
          // 添加明细项到指定的财务记录
          final financialItem = FinancialItem(
            financialRecordId: widget.record!.id!,
            itemName: _treatmentItemsController.text.trim(),
            itemPrice: double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
            processingFee: double.tryParse(_processingFeeController.text.replaceAll('¥', '').trim()) ?? 0.0,
            quantity: 1,
            totalPrice: double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
            chargeDate: selectedDate,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await financialProvider.addFinancialItem(financialItem);
          
          // 更新财务记录的更新时间和收费项数量
          await _updateFinancialRecord();
          
          // 更新患者的总体财务统计信息
          await financialProvider.updatePatientFinancialSummary(widget.record!.patientId);
          
          SuccessToastManager.show(context, message: '收费记录添加成功');
          if (widget.onResult != null) {
            widget.onResult!(true);
          }
        } else {
          SuccessToastManager.showError(context, message: '没有找到财务记录，无法添加收费项');
        }
      }
    } catch (e) {
      final errMsg = e.toString();
      // 如果是 MySQL 外键导致的错误，给用户友好提示并建议同步数据
      if (errMsg.contains('Cannot add or update a child row') || errMsg.contains('foreign key') || errMsg.contains('financial_records_ibfk_1')) {
        await ErrorDialogManager.show(
          context,
          title: '无法添加收费记录',
          message: '检测到 MySQL 中不存在对应的患者，请将 SQLite 的患者数据同步到 MySQL 后重试。\n\n错误：${errMsg}',
        );
      } else {
        SuccessToastManager.showError(context, message: '操作出错: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
