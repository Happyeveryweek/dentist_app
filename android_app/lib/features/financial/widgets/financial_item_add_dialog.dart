import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_item.dart';
import '../helpers/amount_input_formatter.dart';
import '../helpers/financial_payment_method_helper.dart';
import '../../../widgets/modern_date_picker.dart';

/// 财务项目添加对话框
/// 职责：添加财务项目的对话框
class FinancialItemAddDialog extends StatefulWidget {
  final int financialRecordId;
  final Function(FinancialItem) onSave;

  const FinancialItemAddDialog({
    super.key,
    required this.financialRecordId,
    required this.onSave,
  });

  @override
  State<FinancialItemAddDialog> createState() => FinancialItemAddDialogState();
}

class FinancialItemAddDialogState extends State<FinancialItemAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _collectedAmountController = TextEditingController();
  final _processingFeeController = TextEditingController();
  final _chargeDateController = TextEditingController();
  String? _paymentMethod = FinancialPaymentMethodHelper.nonePaymentMethod;

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
    _itemNameController.text = '综合收费';
    _itemPriceController.text = '0';
    _collectedAmountController.text = '0';
    _processingFeeController.text = '0';
    // 移除数量字段，不再需要初始化
    _chargeDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());

    _setupFocusNodeAndController(
      _itemPriceFocusNode,
      _itemPriceController,
      '0',
    );
    _setupFocusNodeAndController(
      _collectedAmountFocusNode,
      _collectedAmountController,
      '0',
    );
    _setupFocusNodeAndController(
      _processingFeeFocusNode,
      _processingFeeController,
      '0',
    );
  }

  void _save() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final newItem = FinancialItem(
      financialRecordId: widget.financialRecordId,
      itemName: _itemNameController.text,
      itemPrice: double.tryParse(_itemPriceController.text) ?? 0.0,
      processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
      paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
        _paymentMethod,
      ),
      quantity: 1, // 固定数量为1
      totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
      chargeDate: DateFormat('yyyy-MM-dd').parse(_chargeDateController.text),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(newItem);
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
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
                              inputFormatters: [amountInputFormatter],
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
                              inputFormatters: [amountInputFormatter],
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
                        inputFormatters: [amountInputFormatter],
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

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: FinancialPaymentMethodHelper.uiValue(
                          _paymentMethod,
                        ),
                        decoration: InputDecoration(
                          labelText: '收费方式',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          prefixIcon: const Icon(Icons.payment),
                        ),
                        items:
                            FinancialPaymentMethodHelper.dropdownMethods.map((
                              method,
                            ) {
                              final iconPath =
                                  FinancialPaymentMethodHelper.iconAssetPathOrNull(
                                    method,
                                  );
                              final label =
                                  method ==
                                          FinancialPaymentMethodHelper
                                              .nonePaymentMethod
                                      ? '未选择'
                                      : FinancialPaymentMethodHelper.displayName(
                                        method,
                                      );
                              return DropdownMenuItem<String>(
                                value: method,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (iconPath != null) ...[
                                      Image.asset(
                                        iconPath,
                                        width: 16,
                                        height: 16,
                                        errorBuilder:
                                            (_, __, ___) => const Icon(
                                              Icons.payment,
                                              size: 16,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(label),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _paymentMethod = value;
                          });
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
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                title: '选择收费日期',
                              );
                            },
                          );
                          if (date != null) {
                            setState(() {
                              _chargeDateController.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(date);
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

  void _setupFocusNodeAndController(
    FocusNode focusNode,
    TextEditingController controller,
    String defaultValue,
  ) {
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
