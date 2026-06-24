import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/models/financial_record.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/providers/financial_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import '../helpers/financial_payment_method_helper.dart';
import 'patient_search_dialog.dart';
import 'dialog_header.dart';
import 'patient_selection_section.dart';
import 'charge_info_section.dart';
import 'notes_section.dart';
import '../../../utils/app_logger.dart';

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
  String? _paymentMethod = FinancialPaymentMethodHelper.nonePaymentMethod;

  // 焦点控制器
  final _receivableFocusNode = FocusNode();
  final _processingFocusNode = FocusNode();
  final _collectedFocusNode = FocusNode();
  // 欠费金额控制器已移除，UI中不再显示欠费字段

  List<FinancialItem> _financialItems = [];
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
      _chargeDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(widget.record!.createdAt);
      _notesController.text = widget.record!.notes ?? '';

      // 如果有财务项目，使用第一个项目的数据初始化金额控制器
      if (_financialItems.isNotEmpty) {
        final firstItem = _financialItems.first;
        String fmt(double v) =>
            (v % 1 == 0) ? v.toInt().toString() : v.toString();
        _receivableAmountController.text = fmt(firstItem.itemPrice);
        _processingFeeController.text = fmt(firstItem.processingFee);
        _collectedAmountController.text = fmt(firstItem.totalPrice);
        _itemNameController.text = firstItem.itemName;
        _paymentMethod = FinancialPaymentMethodHelper.uiValue(
          firstItem.paymentMethod,
        );
      } else {
        // 如果没有项目，设置默认值
        _receivableAmountController.text = '0';
        _processingFeeController.text = '0';
        _collectedAmountController.text = '0';
        _itemNameController.text = '';
        _paymentMethod = FinancialPaymentMethodHelper.nonePaymentMethod;
      }
      // 不再初始化欠费金额显示
    } else {
      _chargeDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTimeFormatter.nowLocal());

      // 初始化金额控制器
      _receivableAmountController.text = '0';
      _processingFeeController.text = '0';
      _collectedAmountController.text = '0';
      _itemNameController.text = '';
      _paymentMethod = FinancialPaymentMethodHelper.nonePaymentMethod;
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

  /// 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange(
    FinancialProvider provider,
    FinancialRecord record,
  ) async {
    try {
      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await provider.getFinancialItemsByRecordId(record.id!);
      final totalQuantity = items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      // 更新财务记录
      final updatedRecord = record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTimeFormatter.nowLocal(),
      );

      await provider.updateFinancialRecord(updatedRecord);
      AppLogger.info('✅ 财务记录更新成功：总数量 = $totalQuantity');
    } catch (e) {
      AppLogger.info('❌ 更新财务记录失败: $e');
    }
  }

  Future<void> _loadPatients() async {
    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      await patientProvider.getAllPatients();
    } catch (e) {
      AppLogger.info('加载患者失败: $e');
    }
  }

  Future<void> _loadFinancialItems() async {
    if (!_isEditing) return;

    try {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      final items = await financialProvider.getFinancialItemsByRecordId(
        widget.record!.id!,
      );
      setState(() {
        _financialItems = items;
        if (_financialItems.isNotEmpty) {
          final firstItem = _financialItems.first;
          String fmt(double v) =>
              (v % 1 == 0) ? v.toInt().toString() : v.toString();
          _receivableAmountController.text = fmt(firstItem.itemPrice);
          _processingFeeController.text = fmt(firstItem.processingFee);
          _collectedAmountController.text = fmt(firstItem.totalPrice);
          _itemNameController.text = firstItem.itemName;
          _paymentMethod = FinancialPaymentMethodHelper.uiValue(
            firstItem.paymentMethod,
          );
        }
      });
    } catch (e) {
      AppLogger.info('加载财务项目失败: $e');
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
      if (_selectedPatient == null ||
          _selectedPatient!.id == null ||
          _selectedPatient!.id == 0) {
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
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      final existingPatient = await patientProvider.getPatientById(
        _selectedPatient!.id!,
      );
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
          SnackBar(content: Text('验证患者失败: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!mounted) return;
    try {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );

      if (_isEditing) {
        // 更新现有记录
        final updatedRecord = widget.record!.copyWith(
          patientId: _selectedPatient!.id!,
          notes: _notesController.text.trim(),
          updatedAt: DateTimeFormatter.nowLocal(),
          createdAt: DateTimeFormatter.fromDbString(
            "${_chargeDateController.text} 00:00:00",
          ),
        );

        await financialProvider.updateFinancialRecord(updatedRecord);

        // 如果不是仅编辑备注模式，更新财务项目
        if (!widget.isEditingNotesOnly) {
          // 更新第一个财务项目，如果没有则创建新的
          if (_financialItems.isNotEmpty) {
            final updatedItem = _financialItems.first.copyWith(
              itemName: _itemNameController.text.trim(),
              paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
                _paymentMethod,
              ),
              itemPrice:
                  double.tryParse(_receivableAmountController.text) ?? 0.0,
              processingFee:
                  double.tryParse(_processingFeeController.text) ?? 0.0,
              totalPrice:
                  double.tryParse(_collectedAmountController.text) ?? 0.0,
              chargeDate: DateTimeFormatter.fromDbString(
                "${_chargeDateController.text} 00:00:00",
              ),
              updatedAt: DateTimeFormatter.nowLocal(),
            );
            await financialProvider.updateFinancialItem(updatedItem);
          } else {
            // 如果没有项目，创建新的
            final newItem = FinancialItem(
              financialRecordId: widget.record!.id!,
              itemName: '诊疗费用',
              paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
                _paymentMethod,
              ),
              itemPrice:
                  double.tryParse(_receivableAmountController.text) ?? 0.0,
              processingFee:
                  double.tryParse(_processingFeeController.text) ?? 0.0,
              quantity: 1,
              totalPrice:
                  double.tryParse(_collectedAmountController.text) ?? 0.0,
              chargeDate: DateTimeFormatter.fromDbString(
                "${_chargeDateController.text} 00:00:00",
              ),
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            );
            await financialProvider.addFinancialItem(newItem);
          }

          // 更新财务记录的收费项数量和更新时间
          await _updateFinancialRecordAfterItemChange(
            financialProvider,
            widget.record!,
          );
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          SuccessToastManager.show(context, message: '财务记录更新成功');
        }
      } else {
        // 创建新记录
        final newRecord = FinancialRecord(
          patientId: _selectedPatient!.id!,
          totalQuantity: 1, // 固定为1，因为我们是直接创建一个项目
          notes: _notesController.text.trim(),
          createdAt: DateTimeFormatter.fromDbString(
            "${_chargeDateController.text} 00:00:00",
          ), // 使用选择的日期
          updatedAt: DateTimeFormatter.nowLocal(),
        );

        final recordId = await financialProvider.addFinancialRecord(newRecord);

        // 创建新的财务项目
        final newItem = FinancialItem(
          financialRecordId: recordId,
          itemName: _itemNameController.text.trim(), // 使用用户输入的项目名称
          paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
            _paymentMethod,
          ),
          itemPrice: double.tryParse(_receivableAmountController.text) ?? 0.0,
          processingFee: double.tryParse(_processingFeeController.text) ?? 0.0,
          quantity: 1,
          totalPrice: double.tryParse(_collectedAmountController.text) ?? 0.0,
          chargeDate: DateTimeFormatter.fromDbString(
            "${_chargeDateController.text} 00:00:00",
          ),
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
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            DialogHeader(
              title:
                  widget.isEditingNotesOnly
                      ? '编辑备注'
                      : (_isEditing ? '编辑记录' : '添加记录'),
              isEditing: _isEditing,
              onClose: () => Navigator.of(context).pop(),
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
                      PatientSelectionSection(
                        selectedPatient: _selectedPatient,
                        patientNameController: _patientNameController,
                        onTap:
                            widget.isEditingNotesOnly
                                ? null
                                : () => _showPatientSearchDialog(),
                        isEditingNotesOnly: widget.isEditingNotesOnly,
                      ),

                      const SizedBox(height: 16),

                      if (!widget.isEditingNotesOnly) ...[
                        ChargeInfoSection(
                          chargeDateController: _chargeDateController,
                          itemNameController: _itemNameController,
                          receivableAmountController:
                              _receivableAmountController,
                          collectedAmountController: _collectedAmountController,
                          processingFeeController: _processingFeeController,
                          paymentMethod: _paymentMethod,
                          receivableFocusNode: _receivableFocusNode,
                          collectedFocusNode: _collectedFocusNode,
                          processingFocusNode: _processingFocusNode,
                          onPaymentMethodChanged: (value) {
                            setState(() {
                              _paymentMethod = value;
                            });
                          },
                          itemNameValidator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入收费项目名称';
                            }
                            return null;
                          },
                          receivableValidator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入金额';
                            }
                            if (double.tryParse(value) == null) {
                              return '无效金额';
                            }
                            return null;
                          },
                          collectedValidator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入金额';
                            }
                            if (double.tryParse(value) == null) {
                              return '无效金额';
                            }
                            return null;
                          },
                          processingValidator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入加工费';
                            }
                            if (double.tryParse(value) == null) {
                              return '无效金额';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      NotesSection(notesController: _notesController),

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
                        onPressed:
                            _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
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
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
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
}
