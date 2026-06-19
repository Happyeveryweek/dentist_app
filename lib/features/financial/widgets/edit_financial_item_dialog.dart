import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/modern_date_picker.dart';
import '../../../widgets/success_toast.dart'
    show AppToastManager;
import '../helpers/amount_input_formatter.dart';
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
          
          // 第一行：应收费金额和已收费金额
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountInputFormatter],
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountInputFormatter],
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
          
          // 第二行：加工费
          Row(
            children: [
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      labelStyle: TextStyle(color: Colors.purple[600]),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountInputFormatter],
                  ),
                ),
              ),
              // 占位，保持与第一行等宽
              const Expanded(child: SizedBox()),
            ],
          ),
          
          // 欠费金额显示已移除
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
        AppToastManager.showSuccess(context, message: '收费项目更新成功');
      } else {
        AppToastManager.showError(context, message: '更新失败，请重试');
      }
    } catch (e) {
      AppToastManager.showError(context, message: '操作出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
