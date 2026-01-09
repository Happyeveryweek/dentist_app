import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/success_toast.dart';

class FinancialFormDialog extends StatefulWidget {
  final FinancialRecord? record;
  final Patient? contextPatient;
  final FinancialItem? item;
  final Function(bool)? onResult;
  final bool showNotesField;

  const FinancialFormDialog({
    Key? key,
    this.record,
    this.contextPatient,
    this.item,
    this.onResult,
    this.showNotesField = true,
  }) : super(key: key);

  @override
  State<FinancialFormDialog> createState() => _FinancialFormDialogState();
}

class _FinancialFormDialogState extends State<FinancialFormDialog> {
  // 表单控制器
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _chargeDateController = TextEditingController();
  final TextEditingController _treatmentItemsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _receivableAmountController = TextEditingController();
  final TextEditingController _processingFeeController = TextEditingController();
  final TextEditingController _collectedAmountController = TextEditingController();

  // 焦点节点
  final FocusNode _receivableAmountFocusNode = FocusNode();
  final FocusNode _processingFeeFocusNode = FocusNode();
  final FocusNode _collectedAmountFocusNode = FocusNode();

  // 选中的患者
  Patient? _currentSelectedPatient;
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
    
    _patientController.dispose();
    _chargeDateController.dispose();
    _treatmentItemsController.dispose();
    _notesController.dispose();
    _receivableAmountController.dispose();
    _processingFeeController.dispose();
    _collectedAmountController.dispose();
    super.dispose();
  }

  // 初始化表单数据
  void _initializeForm() {
    final isEdit = widget.record != null;
    final selectedPatient = widget.record != null 
        ? widget.contextPatient 
        : widget.contextPatient;

    if (isEdit && selectedPatient != null) {
      _patientController.text = selectedPatient.name;
      
      // 编辑模式：使用收费日期charge_date
      DateTime displayDate;
      if (widget.item != null && widget.item!.chargeDate != null) {
        displayDate = widget.item!.chargeDate!;
      } else if (widget.record != null && widget.record!.createdAt != null) {
        displayDate = widget.record!.createdAt!;
      } else {
        displayDate = DateTime.now();
      }
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(displayDate);
      
      if (widget.item != null) {
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
        _notesController.text = widget.record!.notes ?? '';
      } else {
        _treatmentItemsController.text = widget.record!.notes?.isNotEmpty == true 
            ? widget.record!.notes! 
            : '综合收费';
        _notesController.text = widget.record!.notes ?? '';
        _receivableAmountController.text = '0';
        _processingFeeController.text = '0';
        _collectedAmountController.text = '0';
      }
    } else {
      if (widget.contextPatient != null) {
        _patientController.text = widget.contextPatient!.name;
      }
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _treatmentItemsController.text = '综合收费';
      _receivableAmountController.text = '0';
      _processingFeeController.text = '0';
      _collectedAmountController.text = '0';
    }

    _currentSelectedPatient = selectedPatient ?? widget.contextPatient;
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
    final bool disablePatientSelection = widget.contextPatient != null;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.purple[600]!],
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEdit ? '编辑财务记录' : '添加财务记录',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minHeight: 400,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientSection(disablePatientSelection),
              if (_currentSelectedPatient != null) ...[
                const SizedBox(height: 8),
                _buildSelectedPatientInfo(),
              ],
              const SizedBox(height: 12),
              _buildChargeInfoSection(),
              const SizedBox(height: 12),
              _buildAmountInfoSection(),
              if (widget.showNotesField) ...[
                const SizedBox(height: 12),
                _buildNotesSection(),
              ],
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  // 构建患者信息区域
  Widget _buildPatientSection(bool disablePatientSelection) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_search,
                color: Colors.blue[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '患者信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: InkWell(
                    onTap: disablePatientSelection ? null : () => _showPatientSelectionDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: disablePatientSelection ? Colors.grey[100] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.person, color: Colors.blue[600], size: 18),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '患者姓名',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _patientController.text.isEmpty 
                                      ? (disablePatientSelection ? '已自动填写患者姓名' : '点击选择患者')
                                      : _patientController.text,
                                  style: TextStyle(
                                    color: _patientController.text.isEmpty ? Colors.grey[600] : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: _patientController.text.isEmpty ? FontWeight.normal : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!disablePatientSelection)
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.blue[600],
                              size: 24,
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
    );
  }

  // 构建已选择患者信息显示
  Widget _buildSelectedPatientInfo() {
    if (_currentSelectedPatient == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user,
            color: Colors.green[700],
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选择患者: ${_currentSelectedPatient!.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.badge,
                        label: '病历号',
                        value: _currentSelectedPatient!.medical_record_number?.toString() ?? '未设置',
                        color: Colors.blue[600]!,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: '首诊日期',
                        value: DateFormat('yyyy-MM-dd').format(_currentSelectedPatient!.first_visit_date),
                        color: Colors.orange[600]!,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 构建收费信息区域
  Widget _buildChargeInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: Colors.orange[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '收费信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 收费日期（鼠标悬停小手）
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 1),
              ),
              child: TextField(
                controller: _chargeDateController,
                decoration: InputDecoration(
                  labelText: '收费日期',
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.calendar_month, color: Colors.orange[600], size: 18),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange[200]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange[400]!, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  labelStyle: TextStyle(color: Colors.orange[600]),
                ),
                readOnly: true,
                onTap: () => _selectChargeDate(),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 收费项目
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            child: TextField(
              controller: _treatmentItemsController,
              decoration: InputDecoration(
                labelText: '收费项目',
                hintText: '例如：洗牙、补牙、根管治疗等',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.medical_services, color: Colors.orange[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[200]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[400]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                labelStyle: TextStyle(color: Colors.orange[600]),
                alignLabelWithHint: true,
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                height: 1.2,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建金额信息区域
  Widget _buildAmountInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.purple[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '金额信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 第一行：应收费金额和加工费
          Row(
            children: [
              // 应收费金额
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: TextField(
                    controller: _receivableAmountController,
                    focusNode: _receivableAmountFocusNode,
                    decoration: InputDecoration(
                      labelText: '应收费金额',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.description, color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    onTap: () {
                      if (_receivableAmountController.text == '0') {
                        _receivableAmountController.clear();
                      }
                    },
                    onChanged: (value) {
                      setState(() {
                        // 触发UI更新以重新计算欠费金额
                      });
                    },
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 加工费
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: TextField(
                    controller: _processingFeeController,
                    focusNode: _processingFeeFocusNode,
                    decoration: InputDecoration(
                      labelText: '加工费',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.build, color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    onTap: () {
                      if (_processingFeeController.text == '0') {
                        _processingFeeController.clear();
                      }
                    },
                    onChanged: (value) {
                      setState(() {
                        // 触发UI更新以重新计算欠费金额
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 第二行：已收费金额（欠费显示已移除）
          Row(
            children: [
              // 已收费金额
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: TextField(
                    controller: _collectedAmountController,
                    focusNode: _collectedAmountFocusNode,
                    decoration: InputDecoration(
                      labelText: '已收费金额',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    onTap: () {
                      if (_collectedAmountController.text == '0') {
                        _collectedAmountController.clear();
                      }
                    },
                    onChanged: (value) {
                      setState(() {
                        // 触发UI更新
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 计算欠费金额
  String _calculateOutstandingAmount() {
    try {
      final receivableAmount = double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0;
      final collectedAmount = double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0;
      
      // 欠费金额 = 应收费金额 - 已收费金额（不包含加工费）
      final outstanding = receivableAmount - collectedAmount;
      
      return '¥${outstanding.toStringAsFixed(0)}';
    } catch (e) {
      return '¥0';
    }
  }

  // 构建备注信息区域
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_add,
                color: Colors.teal[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '备注信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.teal[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal[200]!, width: 1),
            ),
            child: TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '备注',
                hintText: '其他说明信息',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.note, color: Colors.teal[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[200]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[400]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                labelStyle: TextStyle(color: Colors.teal[600]),
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // 构建操作按钮
  List<Widget> _buildActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 取消按钮
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '取消',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 保存按钮
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[500]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.record != null ? '更新中...' : '保存中...',
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
                      const SizedBox(width: 8),
                      Text(
                        widget.record != null ? '更新' : '保存',
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

  // 显示患者选择对话框
  Future<void> _showPatientSelectionDialog() async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // 依据设置确定"患者管理"实际使用的数据源
      final String patientsDataSource = settingsProvider.dataSourceMode == 'modular'
          ? (settingsProvider.moduleDataSources['patients'] ?? settingsProvider.dataSourceType)
          : settingsProvider.dataSourceType;
      
      // 使用患者管理模块的数据源获取患者列表
      final patients = await patientProvider.getAllPatients();
      
      if (patients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无患者数据')),
        );
        return;
      }

      // 按更新时间排序，最新的在前面
      patients.sort((a, b) => b.updated_at.compareTo(a.updated_at));
      
      final Patient? selected = await showDialog<Patient>(
        context: context,
        builder: (context) => _PatientSelectionDialog(patients: patients),
      );
      
      if (selected != null) {
        setState(() {
          _currentSelectedPatient = selected;
          _patientController.text = selected.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择患者失败: $e')),
      );
    }
  }

  // 显示添加患者对话框
  void _showAddPatientDialog() {
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    final newPatient = Patient(
      name: _patientController.text,
      age: 0, // 默认年龄，用户后续可以编辑
      gender: '未知', // 默认性别，用户后续可以编辑
      phone: '', // 默认空电话
      medical_record_number: DateTime.now().millisecondsSinceEpoch % 100000, // 使用时间戳生成临时病历号
      first_visit_date: DateTime.now(),
    );
    patientProvider.addPatient(newPatient);
    _currentSelectedPatient = newPatient;
    _patientController.text = newPatient.name;
    Navigator.of(context).pop();
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

  // 保存记录
  Future<void> _saveRecord() async {
    // 验证表单
    if (_currentSelectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择患者')),
      );
      return;
    }
    
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
      
      if (widget.record != null) {
        // 编辑模式：更新现有记录
        final newRecord = FinancialRecord(
          id: widget.record!.id,
          patientId: _currentSelectedPatient!.id!,
          totalQuantity: widget.record!.totalQuantity,
          notes: widget.showNotesField ? (_notesController.text.trim().isEmpty ? null : _notesController.text.trim()) : widget.record!.notes,
          createdAt: widget.record!.createdAt,
          updatedAt: DateTime.now(),
        );
        
        // 更新主财务记录
        final success = await financialProvider.updateFinancialRecord(newRecord);
        if (success) {
          // 更新或创建财务明细项
          try {
            final existingItems = await financialProvider.getFinancialItemsByRecordId(widget.record!.id!);
            
            if (existingItems.isNotEmpty) {
              // 如果已有明细项，更新第一个明细项
              FinancialItem? itemToUpdate;
              if (widget.item != null) {
                itemToUpdate = existingItems.firstWhere(
                  (existingItem) => existingItem.id == widget.item!.id,
                  orElse: () => existingItems.first,
                );
              } else {
                itemToUpdate = existingItems.first;
              }
              
              final updatedItem = FinancialItem(
                id: itemToUpdate.id,
                financialRecordId: widget.record!.id!,
                itemName: _treatmentItemsController.text.trim(),
                itemPrice: double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
                processingFee: double.tryParse(_processingFeeController.text.replaceAll('¥', '').trim()) ?? 0.0,
                quantity: 1,
                totalPrice: double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
                chargeDate: selectedDate,
                createdAt: itemToUpdate.createdAt,
                updatedAt: DateTime.now(),
              );
              await financialProvider.updateFinancialItem(updatedItem);
            } else {
              // 如果没有明细项，创建一个新的
              final newItem = FinancialItem(
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
              await financialProvider.addFinancialItem(newItem);
            }
            
            // 更新患者的总体财务统计信息
            await financialProvider.updatePatientFinancialSummary(widget.record!.patientId);
            
            SuccessToastManager.show(context, message: '收费记录更新成功');
            if (widget.onResult != null) {
              widget.onResult!(true);
            }
            Navigator.of(context).pop(true);
          } catch (e) {
            print('更新财务明细项时出错: $e');
            SuccessToastManager.showError(context, message: '更新明细项失败: $e');
          }
        } else {
          SuccessToastManager.showError(context, message: '更新失败，请重试');
        }
      } else {
        // 新增模式：检查该用户是否已有财务记录
        // 首先尝试根据患者ID获取所有财务记录
        print('开始检查患者 ${_currentSelectedPatient!.name} (ID: ${_currentSelectedPatient!.id}) 是否已有财务记录...');
        final existingRecords = await financialProvider.getFinancialRecordsByPatientId(_currentSelectedPatient!.id!);
        print('查询结果: 找到 ${existingRecords.length} 条财务记录');
        
        // 如果找到现有记录，使用第一个记录（最早的记录）
        if (existingRecords.isNotEmpty) {
          final existingRecord = existingRecords.first;
          print('找到患者 ${_currentSelectedPatient!.name} 的现有财务记录，ID: ${existingRecord.id}');
          
          // 该用户已有财务记录，只添加明细项到现有记录
          final financialItem = FinancialItem(
            financialRecordId: existingRecord.id!,
            itemName: _treatmentItemsController.text.trim(),
            itemPrice: double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
            processingFee: double.tryParse(_processingFeeController.text.replaceAll('¥', '').trim()) ?? 0.0,
            quantity: 1,
            totalPrice: double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
            chargeDate: selectedDate,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          print('正在将收费明细项添加到现有财务记录 ${existingRecord.id}...');
          await financialProvider.addFinancialItem(financialItem);
          
          // 更新患者的总体财务统计信息
          await financialProvider.updatePatientFinancialSummary(existingRecord.patientId);
          
          SuccessToastManager.show(context, message: '收费明细项添加成功（已添加到现有财务记录）');
            if (widget.onResult != null) {
              widget.onResult!(true);
            }
            Navigator.of(context).pop(true);
        } else {
          // 该用户没有财务记录，创建新记录和明细项
          print('患者 ${_currentSelectedPatient!.name} 没有现有财务记录，创建新记录');
          
          final newRecord = FinancialRecord(
            id: null,
            patientId: _currentSelectedPatient!.id!,
            totalQuantity: 1,
            notes: widget.showNotesField ? (_notesController.text.trim().isEmpty ? null : _notesController.text.trim()) : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          // 先保存主记录
          print('正在创建新的财务记录...');
          final recordId = await financialProvider.addFinancialRecord(newRecord);
          
          if (recordId > 0) {
            print('新财务记录创建成功，ID: $recordId');
            // 创建并保存明细项
            final financialItem = FinancialItem(
              financialRecordId: recordId,
              itemName: _treatmentItemsController.text.trim(),
              itemPrice: double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
              processingFee: double.tryParse(_processingFeeController.text.replaceAll('¥', '').trim()) ?? 0.0,
              quantity: 1,
              totalPrice: double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
              chargeDate: selectedDate,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            print('正在创建收费明细项...');
            await financialProvider.addFinancialItem(financialItem);
            
            // 更新患者的总体财务统计信息
            await financialProvider.updatePatientFinancialSummary(newRecord.patientId);
            
            SuccessToastManager.show(context, message: '收费记录添加成功（新建财务记录）');
            if (widget.onResult != null) {
              widget.onResult!(true);
            }
            Navigator.of(context).pop(true);
          } else {
            print('创建财务记录失败，返回ID: $recordId');
            SuccessToastManager.showError(context, message: '添加失败，请重试');
          }
        }
      }
    } catch (e) {
      print('保存收费记录时出错: $e');
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

// 患者选择对话框
class _PatientSelectionDialog extends StatefulWidget {
  final List<Patient> patients;

  const _PatientSelectionDialog({required this.patients});

  @override
  State<_PatientSelectionDialog> createState() => _PatientSelectionDialogState();
}

class _PatientSelectionDialogState extends State<_PatientSelectionDialog> {
  String _searchQuery = '';
  List<Patient> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _filteredPatients = List.from(widget.patients);
  }

  void _filterPatients(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPatients = List.from(widget.patients);
      } else {
        _filteredPatients = widget.patients.where((patient) {
          // 姓名搜索
          final nameMatch = patient.name.toLowerCase().contains(query.toLowerCase());
          
          // 病历号搜索
          final medicalRecordMatch = patient.medical_record_number?.toString().contains(query) ?? false;
          
          // 姓名拼音搜索（支持带空格和不带空格）
          final namePinyinMatch = patient.name_pinyin?.toLowerCase().replaceAll(' ', '').contains(query.toLowerCase().replaceAll(' ', '')) ?? false;
          
          // 姓名拼音首字母搜索
          final nameInitialsMatch = patient.name_initials?.toLowerCase().contains(query.toLowerCase()) ?? false;
          
          return nameMatch || medicalRecordMatch || namePinyinMatch || nameInitialsMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 根据患者信息的更新时间排序，最新的排到最前面
    List<Patient> sortedPatients = List.from(widget.patients);
    sortedPatients.sort((a, b) => b.updated_at.compareTo(a.updated_at));
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.52,
          minHeight: 300,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF667eea).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏 - 带渐变背景
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_search,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '选择患者',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 14,
                        tooltip: '关闭',
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 搜索框
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '搜索患者 (姓名/拼音/首字母/病历号)',
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                        onChanged: _filterPatients,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 患者列表标题
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: const Color(0xFF667eea),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '患者列表 (${_filteredPatients.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 患者列表
                      Expanded(
                        child: _filteredPatients.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty ? '暂无患者数据' : '未找到匹配的患者',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '请尝试其他搜索关键词',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    children: [
                                      // 表头
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF667eea).withOpacity(0.1),
                                              const Color(0xFF667eea).withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    size: 16,
                                                    color: const Color(0xFF667eea),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    '姓名',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF667eea),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: const Color(0xFF667eea),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    '最近就诊',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF667eea),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 表格内容
                                      Expanded(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _filteredPatients.length,
                                          itemBuilder: (context, index) {
                                            final patient = _filteredPatients[index];
                                            final lastVisitDate = DateFormat('yyyy-MM-dd')
                                                .format(patient.updated_at);

                                            return Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: () {
                                                    // 选择患者并关闭对话框
                                                    Navigator.of(context).pop(patient);
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.person,
                                                                size: 16,
                                                                color: const Color(0xFF667eea),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                patient.name,
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            lastVisitDate,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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
      ),
    );
  }
}


// 财务统计对话框
class FinancialStatisticsDialog extends StatelessWidget {
  final List<FinancialRecord> financialRecords;
  final List<FinancialItem> financialItems;
  final List<Patient> patients;

  const FinancialStatisticsDialog({
    Key? key,
    required this.financialRecords,
    required this.financialItems,
    required this.patients,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 计算统计数据
    final totalRecords = financialRecords.length;
    final totalReceivable = financialItems.fold<double>(0.0, (sum, item) => sum + item.itemPrice);
    final totalReceived = financialItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    final totalDue = totalReceivable - totalReceived;
    final totalProcessingFee = financialItems.fold<double>(0.0, (sum, item) => sum + item.processingFee);
    
    // 按月份统计
    final Map<String, double> monthlyStats = {};
    for (final item in financialItems) {
      final monthKey = DateFormat('yyyy-MM').format(item.chargeDate);
      monthlyStats[monthKey] = (monthlyStats[monthKey] ?? 0.0) + item.totalPrice;
    }
    
    // 按收费项目统计
    final Map<String, double> itemStats = {};
    for (final item in financialItems) {
      itemStats[item.itemName] = (itemStats[item.itemName] ?? 0.0) + item.totalPrice;
    }
    
    // 按患者统计
    final Map<String, double> patientStats = {};
    for (final item in financialItems) {
      // 通过财务记录ID找到对应的患者
      final record = financialRecords.firstWhere(
        (record) => record.id == item.financialRecordId,
        orElse: () => FinancialRecord(
          patientId: 0,
          totalQuantity: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
             if (record.patientId > 0) {
         final patient = patients.firstWhere(
           (patient) => patient.id == record.patientId,
           orElse: () => Patient(
             id: 0,
             name: '未知患者',
             age: 0,
             gender: '未知',
             phone: '',
             medical_record_number: 0,
             address: '',
             first_visit_date: DateTime.now(),
           ),
         );
         
         if (patient.id != null && patient.id! > 0) {
           patientStats[patient.name] = (patientStats[patient.name] ?? 0.0) + item.totalPrice;
         }
       }
    }
    
    // 排序数据
    final sortedMonths = monthlyStats.keys.toList()..sort();
    final sortedItems = itemStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedPatients = patientStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.bar_chart, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  '收费图表统计',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 总体统计卡片
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.05),
                            Theme.of(context).primaryColor.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '总记录数',
                              '$totalRecords',
                              Icons.receipt_long_rounded,
                              Colors.blue[700]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总应收费',
                              '¥${totalReceivable.toStringAsFixed(0)}',
                              Icons.account_balance_wallet_rounded,
                              Colors.green[700]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总已收费',
                              '¥${totalReceived.toStringAsFixed(0)}',
                              Icons.check_circle_rounded,
                              Colors.blue[600]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总欠费',
                              '¥${totalDue.toStringAsFixed(0)}',
                              Icons.pending_rounded,
                              totalDue > 0 ? Colors.red[600]! : Colors.grey[600]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总加工费',
                              '¥${totalProcessingFee.toStringAsFixed(0)}',
                              Icons.build_rounded,
                              Colors.orange[600]!,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 月度趋势图
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
                          Text(
                            '月度收费趋势',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: sortedMonths.isEmpty
                                ? const Center(
                                    child: Text('暂无数据'),
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: sortedMonths.map((month) {
                                      final amount = monthlyStats[month] ?? 0.0;
                                      final maxAmount = monthlyStats.values.isEmpty 
                                          ? 1.0 
                                          : monthlyStats.values.reduce((a, b) => a > b ? a : b);
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
                    
                    const SizedBox(height: 24),
                    
                                         // 收费项目统计
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
                           Text(
                             '收费项目统计 (前10名)',
                             style: Theme.of(context).textTheme.titleLarge?.copyWith(
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           const SizedBox(height: 16),
                           if (sortedItems.isEmpty)
                             const Center(
                               child: Text('暂无数据'),
                             )
                           else
                             ...sortedItems.take(10).map((entry) {
                               final percentage = totalReceivable > 0 ? (entry.value / totalReceivable) * 100 : 0.0;
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: Row(
                                   children: [
                                     Expanded(
                                       flex: 2,
                                       child: Text(
                                         entry.key,
                                         style: Theme.of(context).textTheme.bodyMedium,
                                       ),
                                     ),
                                     Expanded(
                                       flex: 3,
                                       child: LinearProgressIndicator(
                                         value: percentage / 100,
                                         backgroundColor: Colors.grey[300],
                                         valueColor: AlwaysStoppedAnimation<Color>(
                                           Theme.of(context).primaryColor,
                                         ),
                                       ),
                                     ),
                                     const SizedBox(width: 16),
                                     SizedBox(
                                       width: 80,
                                       child: Text(
                                         '¥${entry.value.toStringAsFixed(0)}',
                                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                           fontWeight: FontWeight.bold,
                                         ),
                                         textAlign: TextAlign.right,
                                       ),
                                     ),
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
                         ],
                       ),
                     ),
                     
                     const SizedBox(height: 24),
                     
                     // 患者收费统计排行
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
                           Text(
                             '患者收费统计 (前10名)',
                             style: Theme.of(context).textTheme.titleLarge?.copyWith(
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           const SizedBox(height: 16),
                           if (sortedPatients.isEmpty)
                             const Center(
                               child: Text('暂无数据'),
                             )
                           else
                             ...sortedPatients.take(10).map((entry) {
                               final percentage = totalReceivable > 0 ? (entry.value / totalReceivable) * 100 : 0.0;
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: Row(
                                   children: [
                                     Expanded(
                                       flex: 2,
                                       child: Text(
                                         entry.key,
                                         style: Theme.of(context).textTheme.bodyMedium,
                                       ),
                                     ),
                                     Expanded(
                                       flex: 3,
                                       child: LinearProgressIndicator(
                                         value: percentage / 100,
                                         backgroundColor: Colors.grey[300],
                                         valueColor: AlwaysStoppedAnimation<Color>(
                                           Colors.green[600]!,
                                         ),
                                       ),
                                     ),
                                     const SizedBox(width: 16),
                                     SizedBox(
                                       width: 80,
                                       child: Text(
                                         '¥${entry.value.toStringAsFixed(0)}',
                                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                           fontWeight: FontWeight.bold,
                                         ),
                                         textAlign: TextAlign.right,
                                       ),
                                     ),
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
                         ],
                       ),
                     ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建统计卡片
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// 编辑财务明细项对话框
class EditFinancialItemDialog extends StatefulWidget {
  final FinancialItem financialItem;
  final Patient patient;
  final bool showNotesField;

  const EditFinancialItemDialog({
    Key? key,
    required this.financialItem,
    required this.patient,
    this.showNotesField = true,
  }) : super(key: key);

  @override
  State<EditFinancialItemDialog> createState() => _EditFinancialItemDialogState();
}

class _EditFinancialItemDialogState extends State<EditFinancialItemDialog> {
  // 表单控制器
  final TextEditingController _chargeDateController = TextEditingController();
  final TextEditingController _treatmentItemsController = TextEditingController();
  final TextEditingController _receivableAmountController = TextEditingController();
  final TextEditingController _processingFeeController = TextEditingController();
  final TextEditingController _collectedAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _chargeDateController.dispose();
    _treatmentItemsController.dispose();
    _receivableAmountController.dispose();
    _processingFeeController.dispose();
    _collectedAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 初始化表单数据
  void _initializeForm() {
    _chargeDateController.text = DateFormat('yyyy-MM-dd').format(widget.financialItem.chargeDate);
    _treatmentItemsController.text = widget.financialItem.itemName;
    _receivableAmountController.text = widget.financialItem.itemPrice % 1 == 0 
        ? widget.financialItem.itemPrice.toInt().toString() 
        : widget.financialItem.itemPrice.toString();
    _processingFeeController.text = widget.financialItem.processingFee % 1 == 0 
        ? widget.financialItem.processingFee.toInt().toString() 
        : widget.financialItem.processingFee.toString();
    _collectedAmountController.text = widget.financialItem.totalPrice % 1 == 0 
        ? widget.financialItem.totalPrice.toInt().toString() 
        : widget.financialItem.totalPrice.toString();
    
    // 获取备注信息（从关联的FinancialRecord中获取），仅在需要显示备注时加载
    if (widget.showNotesField) {
      _loadNotesFromRecord();
    }
  }

  // 从关联的FinancialRecord中加载备注信息
  Future<void> _loadNotesFromRecord() async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final record = await financialProvider.getFinancialRecordById(widget.financialItem.financialRecordId);
      if (record != null && record.notes != null && record.notes!.isNotEmpty) {
        _notesController.text = record.notes!;
      }
    } catch (e) {
      print('加载备注信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[600]!, Colors.red[600]!],
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '编辑收费项目',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 600,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientInfoSection(),
              const SizedBox(height: 12),
              _buildChargeInfoSection(),
              const SizedBox(height: 12),
              _buildAmountInfoSection(),
              const SizedBox(height: 12),
              if (widget.showNotesField) ...[
                const SizedBox(height: 12),
                _buildNotesSection(),
              ],
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  // 构建患者信息区域
  Widget _buildPatientInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.blue[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '患者信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.person,
                  label: '患者姓名',
                  value: widget.patient.name,
                  color: Colors.blue[600]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.badge,
                  label: '病历号',
                  value: widget.patient.medical_record_number?.toString() ?? '未设置',
                  color: Colors.orange[600]!,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 构建收费信息区域
  Widget _buildChargeInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: Colors.orange[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '收费信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 收费日期
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            child: TextField(
              controller: _chargeDateController,
              decoration: InputDecoration(
                labelText: '收费日期',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.calendar_month, color: Colors.orange[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[200]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[400]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                labelStyle: TextStyle(color: Colors.orange[600]),
              ),
              readOnly: true,
              onTap: () => _selectChargeDate(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 收费项目
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            child: TextField(
              controller: _treatmentItemsController,
              decoration: InputDecoration(
                labelText: '收费项目',
                hintText: '例如：洗牙、补牙、根管治疗等',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.medical_services, color: Colors.orange[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[200]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[400]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                labelStyle: TextStyle(color: Colors.orange[600]),
                alignLabelWithHint: true,
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                height: 1.2,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建金额信息区域
  Widget _buildAmountInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.purple[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '金额信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 第一行：应收费金额和加工费
          Row(
            children: [
              // 应收费金额
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: TextField(
                    controller: _receivableAmountController,
                    decoration: InputDecoration(
                      labelText: '应收费金额',
                      hintText: '¥0',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.description, color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        // 触发UI更新以重新计算欠费金额
                      });
                    },
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 加工费
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: TextField(
                    controller: _processingFeeController,
                    decoration: InputDecoration(
                      labelText: '加工费',
                      hintText: '¥0',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.build, color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 第二行：已收费金额和欠费金额
          Row(
            children: [
              // 已收费金额
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: TextField(
                    controller: _collectedAmountController,
                    decoration: InputDecoration(
                      labelText: '已收费金额',
                      hintText: '¥0',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        // 触发UI更新以重新计算欠费金额
                      });
                    },
                  ),
                ),
              ),
              
              // 欠费金额显示已移除
            ],
          ),
        ],
      ),
    );
  }

  // 计算欠费金额
  String _calculateOutstandingAmount() {
    try {
      final receivableAmount = double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0;
      final collectedAmount = double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0;
      
      // 欠费金额 = 应收费金额 - 已收费金额（不包含加工费）
      final outstanding = receivableAmount - collectedAmount;
      
      return '¥${outstanding.toStringAsFixed(0)}';
    } catch (e) {
      return '¥0';
    }
  }

  // 构建备注信息区域
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_add,
                color: Colors.teal[700],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '备注信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.teal[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal[200]!, width: 1),
            ),
            child: TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '备注',
                hintText: '其他说明信息',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.note, color: Colors.teal[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[200]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[400]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                labelStyle: TextStyle(color: Colors.teal[600]),
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // 构建操作按钮
  List<Widget> _buildActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 取消按钮
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '取消',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 保存按钮
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[500]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '更新中...',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.update,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '更新',
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
      
      // 更新财务明细项
      final updatedItem = FinancialItem(
        id: widget.financialItem.id,
        financialRecordId: widget.financialItem.financialRecordId,
        itemName: _treatmentItemsController.text.trim(),
        itemPrice: double.tryParse(_receivableAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
        processingFee: double.tryParse(_processingFeeController.text.replaceAll('¥', '').trim()) ?? 0.0,
        quantity: widget.financialItem.quantity,
        totalPrice: double.tryParse(_collectedAmountController.text.replaceAll('¥', '').trim()) ?? 0.0,
        chargeDate: selectedDate,
        createdAt: widget.financialItem.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final success = await financialProvider.updateFinancialItem(updatedItem);
      
      if (success) {
        // 更新关联的FinancialRecord的备注信息（仅在允许编辑备注时）
        if (widget.showNotesField) {
          try {
            final record = await financialProvider.getFinancialRecordById(widget.financialItem.financialRecordId);
            if (record != null) {
              final updatedRecord = FinancialRecord(
                id: record.id,
                patientId: record.patientId,
                totalQuantity: record.totalQuantity,
                notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                createdAt: record.createdAt,
                updatedAt: DateTime.now(),
              );
              await financialProvider.updateFinancialRecord(updatedRecord);
            }
          } catch (e) {
            print('更新备注信息失败: $e');
          }
        }
        
        // 更新患者的总体财务统计信息
        await financialProvider.updatePatientFinancialSummary(widget.patient.id!);
        
        Navigator.of(context).pop(true);
        SuccessToastManager.show(context, message: '收费项目更新成功');
      } else {
        SuccessToastManager.showError(context, message: '更新失败，请重试');
      }
    } catch (e) {
      SuccessToastManager.showError(context, message: '操作出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
