import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../../../providers/financial_provider.dart';
import '../../../widgets/modern_date_picker.dart';
import '../../../widgets/success_toast.dart'
    show DeleteConfirmDialogManager, InlineSuccessMessage, AppToastManager;
import '../../../theme/theme_context_extensions.dart';
import '../../../theme/medical_semantic_colors.dart';
import '../helpers/amount_input_formatter.dart';
import '../helpers/financial_payment_method_helper.dart';
import 'financial_detail_table_layout.dart';
import '../../../utils/log_manager.dart';

/// 财务记录编辑对话框
/// 显示收费信息列表并允许编辑备注信息
class FinancialRecordEditDialog extends StatefulWidget {
  final Patient patient;
  final FinancialRecord record;

  const FinancialRecordEditDialog({
    Key? key,
    required this.patient,
    required this.record,
  }) : super(key: key);

  @override
  State<FinancialRecordEditDialog> createState() =>
      _FinancialRecordEditDialogState();
}

class _FinancialRecordEditDialogState extends State<FinancialRecordEditDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  List<FinancialItem> _financialItems = [];

  // 内联编辑状态
  int? _editingItemId; // null表示无编辑，-1表示新增行
  final TextEditingController _editChargeDateController =
      TextEditingController();
  final TextEditingController _editItemNameController = TextEditingController();
  String? _editPaymentMethod =
      FinancialPaymentMethodHelper.defaultPaymentMethod;
  final TextEditingController _editItemPriceController =
      TextEditingController();
  final TextEditingController _editProcessingFeeController =
      TextEditingController();
  final TextEditingController _editTotalPriceController =
      TextEditingController();
  DateTime _editChargeDate = DateTime.now();

  // 成功消息显示
  String? _successMessage;
  bool _showSuccessMessage = false;
  bool _isDeleteMessage = false; // 是否是删除消息

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.record.notes ?? '';
    _loadFinancialItems();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _editChargeDateController.dispose();
    _editItemNameController.dispose();
    _editItemPriceController.dispose();
    _editProcessingFeeController.dispose();
    _editTotalPriceController.dispose();
    super.dispose();
  }

  // 加载财务明细项
  Future<void> _loadFinancialItems() async {
    final recordId = widget.record.id;
    if (recordId == null) return;

    try {
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);
      final items = await financialProvider.getFinancialItemsByRecordId(recordId);
      setState(() {
        _financialItems = items;
      });
    } catch (e) {
      LogManager.e('FinancialRecordEditDialog', '加载财务明细项失败', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: tokens.primaryHeaderGradient,
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
                color: colors.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit,
                color: colors.onPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '编辑财务记录',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          minHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientInfoSection(tokens, colors),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFinancialItemsSection(tokens, colors),
                    const SizedBox(height: 16),
                    _buildNotesSection(tokens, colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: _buildActions(tokens, colors),
    );
  }

  // 构建患者信息区域
  Widget _buildPatientInfoSection(AppThemeTokens tokens, ColorScheme colors) {
    final bool isFemale = (widget.patient.gender == '女') ||
        (widget.patient.gender.toLowerCase() == 'female');
    final Color baseColor = isFemale
        ? MedicalSemanticColors.femaleGender
        : MedicalSemanticColors.maleGender;
    final Color infoBgColor = baseColor.withValues(alpha: 0.14);
    final Color infoBorderColor = baseColor;
    final Color avatarBgColor = baseColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: infoBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: infoBorderColor.withValues(alpha: 0.1),
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
              style: TextStyle(
                color: colors.onPrimary,
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
                      '已选择患者',
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.badge,
                        label: '病历号',
                        value: widget.patient.medicalRecordNumber?.toString() ??
                            '未设置',
                        color: tokens.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: '首诊日期',
                        value: DateFormat('MM-dd')
                            .format(widget.patient.firstVisitDate),
                        color: tokens.primaryAccent,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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

  // 构建收费信息列表区域
  Widget _buildFinancialItemsSection(AppThemeTokens tokens, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.warningContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.warningContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: tokens.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '收费信息 (${_financialItems.length}条)',
                style: TextStyle(
                  color: tokens.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _addNewItemRow(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加收费项'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.warning,
                  foregroundColor: colors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 收费信息列表
          if (_financialItems.isEmpty && _editingItemId == null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
                border: Border.all(color: tokens.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: tokens.iconMuted),
                    const SizedBox(height: 8),
                    Text(
                      '暂无收费记录',
                      style: TextStyle(color: tokens.textMuted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                children: [
                  // 表头
                  SizedBox(
                    height: FinancialDetailTableLayout.rowHeight,
                    child: FinancialDetailTableLayout.buildHeader(
                    context,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  ),
                  // 新增行（放在最上面）
                  if (_editingItemId == -1)
                    SizedBox(
                      height: FinancialDetailTableLayout.rowHeight,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                        decoration: BoxDecoration(
                          color: tokens.successContainer,
                          border: Border(
                            bottom: BorderSide(
                                color: tokens.divider, width: 0.5),
                          ),
                        ),
                        child: _buildEditingItemRow(null, tokens, colors),
                      ),
                    ),
                  // 数据行
                  ...List.generate(_financialItems.length, (index) {
                    final item = _financialItems[index];
                    final isEditing = _editingItemId == item.id;

                    return SizedBox(
                      height: FinancialDetailTableLayout.rowHeight,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                        decoration: BoxDecoration(
                          color: isEditing
                              ? tokens.infoContainer
                              : (index % 2 == 0
                                  ? tokens.cardBackground
                                  : tokens.mutedBackground),
                          border: Border(
                            bottom: BorderSide(
                                color: tokens.divider, width: 0.5),
                          ),
                        ),
                        child: isEditing
                            ? _buildEditingItemRow(item, tokens, colors)
                            : _buildDisplayItemRow(item, tokens, colors),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 构建备注编辑区域
  Widget _buildNotesSection(AppThemeTokens tokens, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.successContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.success, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tokens.success.withValues(alpha: 0.1),
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
                  color: tokens.successContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: tokens.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '备注信息',
                style: TextStyle(
                  color: tokens.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 备注输入框
          Container(
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(tokens.borderRadius),
              border: Border.all(color: tokens.success, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: tokens.success.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '备注信息',
                hintText: '请输入备注信息...',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.successContainer,
                    borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
                  ),
                  child:
                      Icon(Icons.note_add, color: tokens.success, size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.borderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.borderRadius),
                  borderSide: BorderSide(color: tokens.success, width: 2),
                ),
                filled: true,
                fillColor: tokens.cardBackground,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: TextStyle(
                    color: tokens.success, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建操作按钮
  List<Widget> _buildActions(AppThemeTokens tokens, ColorScheme colors) {
    final successMessage = _successMessage;
    return [
      // 成功消息显示区域（在按钮上方）
      if (_showSuccessMessage && successMessage != null)
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
          child: InlineSuccessMessage(
            message: successMessage,
            isDelete: _isDeleteMessage,
            onDismiss: () {
              setState(() {
                _showSuccessMessage = false;
              });
            },
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 取消按钮
            Container(
              decoration: BoxDecoration(
                color: tokens.mutedBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.border),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: tokens.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '取消',
                      style: TextStyle(
                        color: tokens.textMuted,
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
                gradient: tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: tokens.elevatedShadow,
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: colors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: colors.onPrimary,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '保存中...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimary,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.save,
                        color: colors.onPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimary,
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

  // 添加新的收费项行（内联编辑模式）
  void _addNewItemRow() {
    setState(() {
      _editingItemId = -1; // -1表示新增行
      _editChargeDate = DateTime.now();
      _editChargeDateController.text =
          DateFormat('yyyy-MM-dd').format(_editChargeDate);
      _editItemNameController.text = '综合收费';
      _editPaymentMethod = FinancialPaymentMethodHelper.defaultPaymentMethod;
      _editItemPriceController.text = '0';
      _editProcessingFeeController.text = '0';
      _editTotalPriceController.text = '0';
    });
  }

  // 开始编辑收费项（内联编辑模式）
  void _startEditingItem(FinancialItem item) {
    setState(() {
      _editingItemId = item.id;
      _editChargeDate = item.chargeDate;
      _editChargeDateController.text =
          DateFormat('yyyy-MM-dd').format(item.chargeDate);
      _editItemNameController.text = item.itemName;
      _editPaymentMethod = item.paymentMethod;
      _editItemPriceController.text = item.itemPrice % 1 == 0
          ? item.itemPrice.toInt().toString()
          : item.itemPrice.toString();
      _editProcessingFeeController.text = item.processingFee % 1 == 0
          ? item.processingFee.toInt().toString()
          : item.processingFee.toString();
      _editTotalPriceController.text = item.totalPrice % 1 == 0
          ? item.totalPrice.toInt().toString()
          : item.totalPrice.toString();
    });
  }

  // 取消编辑
  void _cancelEditing() {
    setState(() {
      _editingItemId = null;
      _editChargeDateController.clear();
      _editItemNameController.clear();
      _editPaymentMethod = FinancialPaymentMethodHelper.defaultPaymentMethod;
      _editItemPriceController.clear();
      _editProcessingFeeController.clear();
      _editTotalPriceController.clear();
    });
  }

  // 保存当前编辑的收费项
  Future<bool> _commitEditingItem({bool showSuccessMessage = true}) async {
    final recordId = widget.record.id;
    if (recordId == null) {
      AppToastManager.showError(context, message: '财务记录ID为空');
      return false;
    }

    // 验证表单
    if (_editItemNameController.text.trim().isEmpty) {
      AppToastManager.showError(context, message: '请输入收费项目名称');
      return false;
    }

    try {
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);

      if (_editingItemId == -1) {
        // 新增收费项
        final newItem = FinancialItem(
          financialRecordId: recordId,
          itemName: _editItemNameController.text.trim(),
          paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
            _editPaymentMethod,
          ),
          itemPrice: double.tryParse(
                  _editItemPriceController.text.replaceAll('¥', '').trim()) ??
              0.0,
          processingFee: double.tryParse(_editProcessingFeeController.text
                  .replaceAll('¥', '')
                  .trim()) ??
              0.0,
          quantity: 1,
          totalPrice: double.tryParse(
                  _editTotalPriceController.text.replaceAll('¥', '').trim()) ??
              0.0,
          chargeDate: _editChargeDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await financialProvider.addFinancialItem(newItem);

        // 更新财务记录的收费项数量和更新时间
        await _updateFinancialRecordAfterItemChange();

        // 重新加载收费项列表
        await _loadFinancialItems();

        // 取消编辑状态
        _cancelEditing();

        // 显示成功消息（在对话框内）
        if (showSuccessMessage) {
          _showSuccessMessageInDialog('收费项添加成功');
        }
        return true;
      } else {
        // 更新现有收费项 - 先检查是否有变化
        final originalItem =
            _financialItems.firstWhere((item) => item.id == _editingItemId);

        final newItemName = _editItemNameController.text.trim();
        final newPaymentMethod = FinancialPaymentMethodHelper.toStorageValue(
          _editPaymentMethod,
        );
        final newItemPrice = double.tryParse(
                _editItemPriceController.text.replaceAll('¥', '').trim()) ??
            0.0;
        final newProcessingFee = double.tryParse(
                _editProcessingFeeController.text.replaceAll('¥', '').trim()) ??
            0.0;
        final newTotalPrice = double.tryParse(
                _editTotalPriceController.text.replaceAll('¥', '').trim()) ??
            0.0;

        // 检查是否有任何变化
        final hasChanges = originalItem.itemName != newItemName ||
            originalItem.paymentMethod != newPaymentMethod ||
            originalItem.itemPrice != newItemPrice ||
            originalItem.processingFee != newProcessingFee ||
            originalItem.totalPrice != newTotalPrice ||
            originalItem.chargeDate != _editChargeDate;

        if (!hasChanges) {
          // 没有变化，静默取消编辑
          _cancelEditing();
          return true;
        }

        final updatedItem = FinancialItem(
          id: originalItem.id,
          financialRecordId: originalItem.financialRecordId,
          itemName: newItemName,
          paymentMethod: newPaymentMethod,
          itemPrice: newItemPrice,
          processingFee: newProcessingFee,
          quantity: originalItem.quantity,
          totalPrice: newTotalPrice,
          chargeDate: _editChargeDate,
          createdAt: originalItem.createdAt,
          updatedAt: DateTime.now(),
        );

        await financialProvider.updateFinancialItem(updatedItem);

        // 更新财务记录的收费项数量和更新时间
        await _updateFinancialRecordAfterItemChange();

        // 重新加载收费项列表
        await _loadFinancialItems();

        // 取消编辑状态
        _cancelEditing();

        // 显示成功消息（在对话框内）
        if (showSuccessMessage) {
          _showSuccessMessageInDialog('收费项更新成功');
        }
        return true;
      }
    } catch (e) {
      AppToastManager.showError(context, message: '保存失败: $e');
      return false;
    }
  }

  Future<void> _saveEditingItem() async {
    await _commitEditingItem();
  }

  // 在对话框内显示成功消息
  void _showSuccessMessageInDialog(String message, {bool isDelete = false}) {
    setState(() {
      _successMessage = message;
      _showSuccessMessage = true;
      _isDeleteMessage = isDelete;
    });

    // 2秒后自动隐藏
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSuccessMessage = false;
        });
      }
    });
  }

  // 构建显示模式的收费项行
  Widget _buildDisplayItemRow(
      FinancialItem item, AppThemeTokens tokens, ColorScheme colors) {
    return FinancialDetailTableLayout.buildRow(
      children: [
        Text(
          DateFormat('yyyy-MM-dd').format(item.chargeDate),
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          item.itemName,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Center(
          child: Builder(
            builder: (context) {
              final iconPath = FinancialPaymentMethodHelper.iconAssetPathOrNull(
                  item.paymentMethod);
              if (iconPath == null) {
                return const SizedBox.shrink();
              }
              return Tooltip(
                message: FinancialPaymentMethodHelper.displayNameOrDefault(
                    item.paymentMethod),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
              );
            },
          ),
        ),
        Text(
          '¥${(item.itemPrice * item.quantity).toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            color: tokens.primaryAccent,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '¥${item.totalPrice.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            color: tokens.success,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '¥${item.processingFee.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            color: tokens.warning,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _startEditingItem(item),
              icon: Icon(Icons.edit, color: tokens.primaryAccent, size: 16),
              tooltip: '编辑',
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: () => _deleteFinancialItem(item),
              icon: Icon(Icons.delete, color: tokens.error, size: 16),
              tooltip: '删除',
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ],
    );
  }

  // 构建编辑模式的收费项行
  Widget _buildEditingItemRow(
      FinancialItem? item, AppThemeTokens tokens, ColorScheme colors) {
    return FinancialDetailTableLayout.buildRow(
      children: [
        InkWell(
          onTap: () async {
            final date = await showDialog<DateTime>(
              context: context,
              builder: (context) => ModernDatePickerDialog(
                initialDate: _editChargeDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                title: '选择收费日期',
              ),
            );
            if (date != null) {
              setState(() {
                _editChargeDate = date;
                _editChargeDateController.text =
                    DateFormat('yyyy-MM-dd').format(date);
              });
            }
          },
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.info),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: tokens.info),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _editChargeDateController.text,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.border),
          ),
          child: TextField(
            controller: _editItemNameController,
            onTap: () {
              if (_editItemNameController.text == '综合收费') {
                _editItemNameController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _editItemNameController.text.length,
                );
              }
            },
            decoration: const InputDecoration(
              hintText: '收费项目',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.border),
          ),
          child: DropdownButtonFormField<String>(
            key: ValueKey<String?>(
                FinancialPaymentMethodHelper.uiValue(_editPaymentMethod)),
            initialValue:
                FinancialPaymentMethodHelper.uiValue(_editPaymentMethod),
            hint: Text(
              '未选',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 2),
            ),
            icon:
                Icon(Icons.arrow_drop_down, color: tokens.iconMuted, size: 16),
            isExpanded: true,
            menuMaxHeight: 220,
            borderRadius: BorderRadius.circular(6),
            dropdownColor: tokens.cardBackground,
            items: FinancialPaymentMethodHelper.dropdownMethods
                .map(
                  (method) => DropdownMenuItem<String>(
                    value: method,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          if (method ==
                              FinancialPaymentMethodHelper.nonePaymentMethod)
                            Icon(
                              Icons.do_not_disturb_alt,
                              size: 14,
                              color: tokens.textMuted,
                            )
                          else
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: Image.asset(
                                FinancialPaymentMethodHelper.iconAssetPath(
                                    method),
                                fit: BoxFit.contain,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              method ==
                                      FinancialPaymentMethodHelper
                                          .nonePaymentMethod
                                  ? '无'
                                  : FinancialPaymentMethodHelper
                                      .displayNameOrDefault(method),
                              style: const TextStyle(fontSize: 12),
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
              setState(() {
                _editPaymentMethod = value;
              });
            },
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.border),
          ),
          child: TextField(
            controller: _editItemPriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [amountInputFormatter],
            textAlign: TextAlign.center,
            onTap: () {
              if (_editItemPriceController.text == '0') {
                _editItemPriceController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _editItemPriceController.text.length,
                );
              }
            },
            decoration: const InputDecoration(
              hintText: '0',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.border),
          ),
          child: TextField(
            controller: _editTotalPriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [amountInputFormatter],
            textAlign: TextAlign.center,
            onTap: () {
              if (_editTotalPriceController.text == '0') {
                _editTotalPriceController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _editTotalPriceController.text.length,
                );
              }
            },
            decoration: const InputDecoration(
              hintText: '0',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.border),
          ),
          child: TextField(
            controller: _editProcessingFeeController,
            keyboardType: TextInputType.number,
            inputFormatters: [amountInputFormatter],
            textAlign: TextAlign.center,
            onTap: () {
              if (_editProcessingFeeController.text == '0') {
                _editProcessingFeeController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _editProcessingFeeController.text.length,
                );
              }
            },
            decoration: const InputDecoration(
              hintText: '0',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _saveEditingItem,
              icon: Icon(Icons.check, color: tokens.success, size: 16),
              tooltip: '保存',
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: _cancelEditing,
              icon: Icon(Icons.close, color: tokens.iconMuted, size: 16),
              tooltip: '取消',
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ],
    );
  }

  // 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange() async {
    final recordId = widget.record.id;
    final patientId = widget.patient.id;
    if (recordId == null || patientId == null) return;

    try {
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);

      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await financialProvider.getFinancialItemsByRecordId(recordId);
      final totalQuantity =
          items.fold<int>(0, (sum, item) => sum + item.quantity);

      // 更新财务记录
      final updatedRecord = widget.record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );

      await financialProvider.updateFinancialRecord(updatedRecord);
      await financialProvider.updatePatientFinancialSummary(patientId);
    } catch (e) {
      LogManager.e('FinancialRecordEditDialog', '更新财务记录失败', error: e);
    }
  }

  // 删除收费项
  Future<void> _deleteFinancialItem(FinancialItem item) async {
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除这条收费记录吗？\n\n'
          '收费项目: ${item.itemName}\n'
          '收费日期: ${DateFormat('yyyy-MM-dd').format(item.chargeDate)}\n'
          '应收费: ¥${item.itemPrice % 1 == 0 ? item.itemPrice.toInt() : item.itemPrice}  '
          '加工费: ¥${item.processingFee % 1 == 0 ? item.processingFee.toInt() : item.processingFee}  '
          '已收费: ¥${item.totalPrice % 1 == 0 ? item.totalPrice.toInt() : item.totalPrice}\n\n'
          '删除后无法恢复！',
      confirmText: '删除',
      cancelText: '取消',
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final financialProvider =
            Provider.of<FinancialProvider>(context, listen: false);
        final itemId = item.id;
        if (itemId == null) {
          AppToastManager.showError(context, message: '收费项ID为空');
          return;
        }
        final success = await financialProvider.deleteFinancialItem(itemId);

        if (success) {
          // 更新财务记录的收费项数量和更新时间
          await _updateFinancialRecordAfterItemChange();
          await _loadFinancialItems();

          if (!mounted) return;
          // 显示成功消息（在对话框内，橙色）
          _showSuccessMessageInDialog('收费记录删除成功', isDelete: true);
        } else {
          if (!mounted) return;
          AppToastManager.showError(context, message: '删除失败');
        }
      } catch (e) {
        if (!mounted) return;
        AppToastManager.showError(context, message: '删除失败: $e');
      }
    }
  }

  // 保存备注信息
  Future<void> _saveNotes() async {
    final patientId = widget.patient.id;
    if (patientId == null) {
      AppToastManager.showError(context, message: '患者ID为空');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_editingItemId != null) {
        final itemSaved = await _commitEditingItem(showSuccessMessage: false);
        if (!itemSaved) {
          return;
        }
      }

      if (!mounted) return;
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);

      // 备注没有变化时，收费项已经在 _commitEditingItem 中保存并更新过财务记录，
      // 直接成功即可，避免重复调用 updateFinancialRecord 误报失败
      // 空字符串与 null 视为相同（数据库中可能存为空字符串）
      final newNotes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final notesChanged = (newNotes ?? '') != (widget.record.notes ?? '');

      if (notesChanged) {
        // 创建更新后的财务记录，只更新备注字段
        final updatedRecord = widget.record.copyWith(
          notes: newNotes,
          updatedAt: DateTime.now(),
        );

        // 更新财务记录
        final success =
            await financialProvider.updateFinancialRecord(updatedRecord);

        if (!success) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '更新失败，请重试');
          return;
        }
      }

      if (!mounted) return;
      AppToastManager.showSuccess(context, message: '财务记录更新成功');
      await financialProvider.updatePatientFinancialSummary(patientId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToastManager.showError(context, message: '操作出错: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
