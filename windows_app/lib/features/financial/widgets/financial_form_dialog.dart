import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../widgets/modern_date_picker.dart';
import '../../../widgets/success_toast.dart'
    show AppToastManager, ErrorDialogManager;
import '../helpers/amount_input_formatter.dart';
import '../helpers/financial_payment_method_helper.dart';
import './patient_selection_dialog.dart';
import '../../../utils/log_manager.dart';

class FinancialFormDialog extends StatefulWidget {
  final FinancialRecord? record;
  final Patient? contextPatient;
  final FinancialItem? item;
  final Function(bool)? onResult;
  final bool showNotesField;
  final bool notifyOnSave;

  const FinancialFormDialog({
    Key? key,
    this.record,
    this.contextPatient,
    this.item,
    this.onResult,
    this.showNotesField = true,
    this.notifyOnSave = true,
  }) : super(key: key);

  @override
  State<FinancialFormDialog> createState() => _FinancialFormDialogState();
}

class _FinancialFormDialogState extends State<FinancialFormDialog> {
  // 表单控制器
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _chargeDateController = TextEditingController();
  final TextEditingController _treatmentItemsController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _receivableAmountController =
      TextEditingController();
  final TextEditingController _processingFeeController =
      TextEditingController();
  final TextEditingController _collectedAmountController =
      TextEditingController();
  String? _paymentMethod;

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
    final record = widget.record;
    final item = widget.item;
    final isEdit = record != null;
    final selectedPatient = widget.contextPatient;

    if (isEdit && selectedPatient != null) {
      _patientController.text = selectedPatient.name;

      // 编辑模式：使用收费日期charge_date
      final DateTime displayDate;
      if (item != null) {
        displayDate = item.chargeDate;
      } else {
        displayDate = record.createdAt;
      }
      _chargeDateController.text = DateFormat('yyyy-MM-dd').format(displayDate);

      if (item != null) {
        _treatmentItemsController.text = item.itemName;
        _paymentMethod = item.paymentMethod;
        _receivableAmountController.text = item.itemPrice % 1 == 0
            ? item.itemPrice.toInt().toString()
            : item.itemPrice.toString();
        _processingFeeController.text = item.processingFee % 1 == 0
            ? item.processingFee.toInt().toString()
            : item.processingFee.toString();
        _collectedAmountController.text = item.totalPrice % 1 == 0
            ? item.totalPrice.toInt().toString()
            : item.totalPrice.toString();
        _notesController.text = record.notes ?? '';
      } else {
        final notes = record.notes;
        _treatmentItemsController.text =
            notes != null && notes.isNotEmpty ? notes : '综合收费';
        _notesController.text = notes ?? '';
        _receivableAmountController.text = '0';
        _processingFeeController.text = '0';
        _collectedAmountController.text = '0';
      }
    } else {
      final contextPatient = widget.contextPatient;
      if (contextPatient != null) {
        _patientController.text = contextPatient.name;
      }
      _chargeDateController.text =
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      _treatmentItemsController.text = '综合收费';
      _paymentMethod = FinancialPaymentMethodHelper.defaultPaymentMethod;
      _receivableAmountController.text = '0';
      _processingFeeController.text = '0';
      _collectedAmountController.text = '0';
    }

    _currentSelectedPatient = selectedPatient;
  }

  // 焦点处理函数
  void _handleReceivableAmountFocus() {
    if (!_receivableAmountFocusNode.hasFocus &&
        _receivableAmountController.text.isEmpty) {
      _receivableAmountController.text = '0';
    }
  }

  void _handleProcessingFeeFocus() {
    if (!_processingFeeFocusNode.hasFocus &&
        _processingFeeController.text.isEmpty) {
      _processingFeeController.text = '0';
    }
  }

  void _handleCollectedAmountFocus() {
    if (!_collectedAmountFocusNode.hasFocus &&
        _collectedAmountController.text.isEmpty) {
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
            colors: [Colors.blue.shade600, Colors.purple.shade600],
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
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
        border: Border.all(color: Colors.blue.shade200, width: 1),
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
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: InkWell(
                    onTap: disablePatientSelection
                        ? null
                        : () => _showPatientSelectionDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: disablePatientSelection
                            ? Colors.grey[100]
                            : Colors.white,
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
                            child: Icon(Icons.person,
                                color: Colors.blue[600], size: 18),
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
                                      ? (disablePatientSelection
                                          ? '已自动填写患者姓名'
                                          : '点击选择患者')
                                      : _patientController.text,
                                  style: TextStyle(
                                    color: _patientController.text.isEmpty
                                        ? Colors.grey[600]
                                        : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: _patientController.text.isEmpty
                                        ? FontWeight.normal
                                        : FontWeight.w500,
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
    final selectedPatient = _currentSelectedPatient;
    if (selectedPatient == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200, width: 1),
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
                  '已选择患者: ${selectedPatient.name}',
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
                        value: selectedPatient.medicalRecordNumber
                                ?.toString() ??
                            '未设置',
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: '首诊日期',
                        value: DateFormat('yyyy-MM-dd')
                            .format(selectedPatient.firstVisitDate),
                        color: Colors.orange.shade600,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
        border: Border.all(color: Colors.orange.shade200, width: 1),
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
                border: Border.all(color: Colors.orange.shade200, width: 1),
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
                    child: Icon(Icons.calendar_month,
                        color: Colors.orange[600], size: 18),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.orange.shade200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.orange.shade400, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
              border: Border.all(color: Colors.orange.shade200, width: 1),
            ),
            child: TextField(
              controller: _treatmentItemsController,
              onTap: () {
                if (_treatmentItemsController.text == '综合收费') {
                  _treatmentItemsController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _treatmentItemsController.text.length,
                  );
                }
              },
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
                  child: Icon(Icons.medical_services,
                      color: Colors.orange[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade400, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
        border: Border.all(color: Colors.purple.shade200, width: 1),
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

          // 第一行：应收费金额和已收费金额
          Row(
            children: [
              // 应收费金额
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1),
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
                        child: Icon(Icons.description,
                            color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade200, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade400, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountInputFormatter],
                    onTap: () {
                      if (_receivableAmountController.text == '0') {
                        _receivableAmountController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _receivableAmountController.text.length,
                        );
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

              // 已收费金额
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1),
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
                        child: Icon(Icons.check_circle,
                            color: Colors.green[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade200, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade400, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountInputFormatter],
                    onTap: () {
                      if (_collectedAmountController.text == '0') {
                        _collectedAmountController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _collectedAmountController.text.length,
                        );
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

          const SizedBox(height: 12),

          // 第二行：加工费
          Row(
            children: [
              // 加工费
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1),
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
                        child: Icon(Icons.build,
                            color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade200, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade400, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountInputFormatter],
                    onTap: () {
                      if (_processingFeeController.text == '0') {
                        _processingFeeController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _processingFeeController.text.length,
                        );
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

              // 收费方式
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                        FinancialPaymentMethodHelper.uiValue(_paymentMethod)),
                    initialValue:
                        FinancialPaymentMethodHelper.uiValue(_paymentMethod),
                    hint: Text(
                      '未选择',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    decoration: InputDecoration(
                      labelText: '收费方式',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.payment,
                            color: Colors.purple[600], size: 18),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade200, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.purple.shade400, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    icon: Icon(Icons.arrow_drop_down,
                        color: Colors.grey[600], size: 18),
                    isExpanded: true,
                    menuMaxHeight: 220,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: Colors.white,
                    items: FinancialPaymentMethodHelper.dropdownMethods
                        .map(
                          (method) => DropdownMenuItem<String>(
                            value: method,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  if (method ==
                                      FinancialPaymentMethodHelper
                                          .nonePaymentMethod)
                                    Icon(
                                      Icons.do_not_disturb_alt,
                                      size: 16,
                                      color: Colors.grey[500],
                                    )
                                  else
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: Image.asset(
                                        FinancialPaymentMethodHelper
                                            .iconAssetPath(method),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      method ==
                                              FinancialPaymentMethodHelper
                                                  .nonePaymentMethod
                                          ? '无'
                                          : FinancialPaymentMethodHelper
                                              .displayNameOrDefault(method),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _paymentMethod = value;
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

  // 构建备注信息区域

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200, width: 1),
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
              border: Border.all(color: Colors.teal.shade200, width: 1),
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
                  borderSide: BorderSide(color: Colors.teal.shade200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal.shade400, width: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                  colors: [Colors.green.shade500, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);
      final patientsDataSourceType = financialProvider.dataSourceType;

      // 患者选择必须跟随财务模块当前数据源，否则会把其他库的 patient.id 写进财务记录。
      List<Patient> patients;
      try {
        patients = await patientProvider.getAllPatientsInDataSource(
          patientsDataSourceType,
        );
      } on DatabaseException catch (e) {
        LogManager.e('FinancialFormDialog',
            'PatientProvider 获取患者列表失败，尝试从 DatabaseProvider 兜底',
            error: e);
        patients = await patientProvider.getAllPatientsInDataSource(
          patientsDataSourceType,
        );
      }

      if (!mounted) return;

      if (patients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无患者数据')),
        );
        return;
      }

      // 按更新时间排序，最新的在前面
      patients.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final Patient? selected = await showDialog<Patient>(
        context: context,
        builder: (context) => PatientSelectionDialog(patients: patients),
      );

      if (selected != null) {
        if (!mounted) return;
        setState(() {
          _currentSelectedPatient = selected;
          _patientController.text = selected.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择患者失败: $e')),
      );
    }
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
    final selectedPatient = _currentSelectedPatient;
    if (selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择患者')),
      );
      return;
    }

    final patientId = selectedPatient.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('患者ID为空，无法保存')),
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
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);
      final selectedDate =
          DateFormat('yyyy-MM-dd').parse(_chargeDateController.text);
      final existingRecord = widget.record;
      final editingItem = widget.item;
      final onResult = widget.onResult;

      if (existingRecord != null) {
        // 编辑模式：更新现有记录
        final newRecord = FinancialRecord(
          id: existingRecord.id,
          patientId: patientId,
          totalQuantity: existingRecord.totalQuantity,
          notes: widget.showNotesField
              ? (_notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim())
              : existingRecord.notes,
          createdAt: existingRecord.createdAt,
          updatedAt: DateTime.now(),
        );

        // 更新主财务记录
          final success =
              await financialProvider.updateFinancialRecord(newRecord);
          if (success) {
            // 更新或创建财务明细项
            try {
              final recordId = existingRecord.id;
              if (recordId == null) {
                throw Exception('编辑的财务记录ID为空');
              }
              final existingItems = await financialProvider
                  .getFinancialItemsByRecordId(recordId);

              if (existingItems.isNotEmpty) {
                // 如果已有明细项，更新第一个明细项
                FinancialItem? itemToUpdate;
                if (editingItem != null) {
                  final editingItemId = editingItem.id;
                  itemToUpdate = existingItems.firstWhere(
                    (existingItem) =>
                        editingItemId != null &&
                        existingItem.id == editingItemId,
                    orElse: () => existingItems.first,
                  );
                } else {
                  itemToUpdate = existingItems.first;
                }

                final updatedItem = FinancialItem(
                  id: itemToUpdate.id,
                  financialRecordId: recordId,
                itemName: _treatmentItemsController.text.trim(),
                paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
                  _paymentMethod,
                ),
                itemPrice: double.tryParse(_receivableAmountController.text
                        .replaceAll('¥', '')
                        .trim()) ??
                    0.0,
                processingFee: double.tryParse(_processingFeeController.text
                        .replaceAll('¥', '')
                        .trim()) ??
                    0.0,
                quantity: 1,
                totalPrice: double.tryParse(_collectedAmountController.text
                        .replaceAll('¥', '')
                        .trim()) ??
                    0.0,
                chargeDate: selectedDate,
                createdAt: itemToUpdate.createdAt,
                updatedAt: DateTime.now(),
              );
              await financialProvider.updateFinancialItem(updatedItem);
            } else {
              // 如果没有明细项，创建一个新的
              final newItem = FinancialItem(
                financialRecordId: recordId,
                itemName: _treatmentItemsController.text.trim(),
                paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
                  _paymentMethod,
                ),
                itemPrice: double.tryParse(_receivableAmountController.text
                        .replaceAll('¥', '')
                        .trim()) ??
                    0.0,
                processingFee: double.tryParse(_processingFeeController.text
                        .replaceAll('¥', '')
                        .trim()) ??
                    0.0,
                quantity: 1,
                totalPrice: double.tryParse(_collectedAmountController.text
                        .replaceAll('¥', '')
                        .trim()) ??
                    0.0,
                chargeDate: selectedDate,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await financialProvider.addFinancialItem(newItem);
            }

            if (widget.notifyOnSave) {
              await financialProvider
                  .updatePatientFinancialSummary(existingRecord.patientId);
            }

            if (!mounted) return;
            AppToastManager.showSuccess(context, message: '收费记录更新成功');
            onResult?.call(true);
            Navigator.of(context).pop(true);
          } catch (e) {
            LogManager.e('FinancialFormDialog', '更新财务明细项时出错', error: e);
            if (!mounted) return;
            AppToastManager.showError(context, message: '更新明细项失败: $e');
          }
        } else {
          if (!mounted) return;
          AppToastManager.showError(context, message: '更新失败，请重试');
        }
      } else {
        // 新增模式：检查该用户是否已有财务记录
        // 首先尝试根据患者ID获取所有财务记录

        final existingRecords = await financialProvider
            .getFinancialRecordsByPatientId(patientId);

        // 如果找到现有记录，使用第一个记录（最早的记录）
        if (existingRecords.isNotEmpty) {
          final existingRecord = existingRecords.first;
          final existingRecordId = existingRecord.id;
          if (existingRecordId == null) {
            throw Exception('现有财务记录ID为空');
          }

          // 该用户已有财务记录，只添加明细项到现有记录
          final financialItem = FinancialItem(
            financialRecordId: existingRecordId,
            itemName: _treatmentItemsController.text.trim(),
            paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
              _paymentMethod,
            ),
            itemPrice: double.tryParse(_receivableAmountController.text
                    .replaceAll('¥', '')
                    .trim()) ??
                0.0,
            processingFee: double.tryParse(
                    _processingFeeController.text.replaceAll('¥', '').trim()) ??
                0.0,
            quantity: 1,
            totalPrice: double.tryParse(_collectedAmountController.text
                    .replaceAll('¥', '')
                    .trim()) ??
                0.0,
            chargeDate: selectedDate,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await financialProvider.addFinancialItem(financialItem);

          if (widget.notifyOnSave) {
            await financialProvider
                .updatePatientFinancialSummary(existingRecord.patientId);
          }

          if (!mounted) return;
          AppToastManager.showSuccess(context,
              message: '收费明细项添加成功（已添加到现有财务记录）');
          onResult?.call(true);
          Navigator.of(context).pop(true);
        } else {
          // 该用户没有财务记录，创建新记录和明细项

          final newRecord = FinancialRecord(
            id: null,
            patientId: patientId,
            totalQuantity: 1,
            notes: widget.showNotesField
                ? (_notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim())
                : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // 先保存主记录

          final recordId =
              await financialProvider.addFinancialRecord(newRecord);

          if (recordId > 0) {
            // 创建并保存明细项
            final financialItem = FinancialItem(
              financialRecordId: recordId,
              itemName: _treatmentItemsController.text.trim(),
              paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
                _paymentMethod,
              ),
              itemPrice: double.tryParse(_receivableAmountController.text
                      .replaceAll('¥', '')
                      .trim()) ??
                  0.0,
              processingFee: double.tryParse(_processingFeeController.text
                      .replaceAll('¥', '')
                      .trim()) ??
                  0.0,
              quantity: 1,
              totalPrice: double.tryParse(_collectedAmountController.text
                      .replaceAll('¥', '')
                      .trim()) ??
                  0.0,
              chargeDate: selectedDate,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await financialProvider.addFinancialItem(financialItem);

            if (widget.notifyOnSave) {
              await financialProvider
                  .updatePatientFinancialSummary(newRecord.patientId);
            }

            if (!mounted) return;
            AppToastManager.showSuccess(context, message: '收费记录添加成功（新建财务记录）');
            onResult?.call(true);
            Navigator.of(context).pop(true);
          } else {
            LogManager.e('FinancialFormDialog', '创建财务记录失败，返回ID');
            if (!mounted) return;
            AppToastManager.showError(context, message: '添加失败，请重试');
          }
        }
      }
    } catch (e) {
      LogManager.e('FinancialFormDialog', '保存收费记录时出错', error: e);
      if (!mounted) return;
      final errMsg = e.toString();
      // 如果是 MySQL 外键导致的错误，给用户友好提示并建议同步数据
      if (errMsg.contains('Cannot add or update a child row') ||
          errMsg.contains('foreign key') ||
          errMsg.contains('financial_records_ibfk_1')) {
        await ErrorDialogManager.show(
          context,
          title: '无法添加收费记录',
          message:
              '检测到 MySQL 中不存在对应的患者，请将 SQLite 的患者数据同步到 MySQL 后重试。\n\n错误：$errMsg',
        );
      } else {
        AppToastManager.showError(context, message: '操作出错: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
