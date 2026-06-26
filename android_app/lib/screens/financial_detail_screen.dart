import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/database_models.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/toast_manager.dart';
import '../widgets/confirm_dialogs.dart';
import '../features/financial/widgets/financial_record_dialog.dart';
import '../utils/permission_utils.dart';
import '../features/financial/widgets/financial_item_edit_dialog.dart';
import '../features/financial/widgets/financial_item_add_dialog.dart';
import '../features/financial/widgets/patient_info_card.dart';
import '../features/financial/widgets/financial_summary_card.dart';
import '../features/financial/widgets/payment_history_card.dart';
import '../features/financial/widgets/financial_item_card.dart';
import '../utils/app_logger.dart';

/// 财务记录详情页面
class FinancialDetailScreen extends StatefulWidget {
  final FinancialRecord record;

  const FinancialDetailScreen({super.key, required this.record});

  @override
  State<FinancialDetailScreen> createState() => _FinancialDetailScreenState();
}

class _FinancialDetailScreenState extends State<FinancialDetailScreen> {
  List<FinancialItem> _items = [];
  Patient? _patient;
  bool _isLoading = false;

  int get _recordId {
    final id = widget.record.id;
    if (id == null) {
      throw Exception('财务记录ID无效');
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
        title: Text(
          '${widget.record.patientName ?? _patient?.name ?? '患者'} - 财务详情',
        ),
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 患者基本信息卡片
                      PatientInfoCard(patient: _patient, record: widget.record),

                      const SizedBox(height: 16),

                      // 财务统计卡片
                      FinancialSummaryCard(items: _items),

                      const SizedBox(height: 16),

                      // 收费记录历史卡片
                      PaymentHistoryCard(
                        items: _items,
                        onAddItem: _addItem,
                        itemBuilder:
                            (item) => FinancialItemCard(
                              item: item,
                              onEdit: () => _editItem(item),
                              onDelete: () => _deleteItem(item),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  /// 加载数据
  Future<void> _loadData() async {
    final recordId = widget.record.id;
    if (recordId == null) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('财务记录ID无效'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      final items = await financialProvider.getFinancialItemsByRecordId(
        recordId,
      );
      final patient = await patientProvider.getPatientById(
        widget.record.patientId,
      );

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
          SnackBar(content: Text('加载数据失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 获取财务记录关联患者的医生字段，用于权限检查
  Future<String?> _getRecordPatientDoctor() async {
    try {
      final loadedPatient = _patient;
      if (loadedPatient != null) {
        return loadedPatient.doctor;
      }

      // 如果患者数据还没加载，尝试获取
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      final patient = await patientProvider.getPatientById(
        widget.record.patientId,
      );
      return patient?.doctor;
    } catch (e) {
      AppLogger.info('获取财务记录患者医生信息失败: $e');
      return null;
    }
  }

  /// 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange() async {
    try {
      final provider = Provider.of<FinancialProvider>(context, listen: false);

      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await provider.getFinancialItemsByRecordId(
        _recordId,
      );
      final totalQuantity = items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      // 更新财务记录
      final updatedRecord = widget.record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );

      await provider.updateFinancialRecord(updatedRecord);
      AppLogger.info('✅ 财务记录更新成功：总数量 = $totalQuantity');
    } catch (e) {
      AppLogger.info('❌ 更新财务记录失败: $e');
    }
  }

  /// 编辑记录（仅备注）
  void _editRecord(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => FinancialRecordDialog(
            record: widget.record,
            isEditingNotesOnly: true, // 传递一个标志，表示只编辑备注
          ),
    ).then((result) {
      if (result == true) {
        _loadData(); // 刷新数据以显示更新后的备注
        // 通知父页面有修改
        if (context.mounted) {
          Navigator.of(context).pop(true);
        }
      }
    });
  }

  /// 删除整个财务记录
  void _deleteRecord(BuildContext context) async {
    final patientName =
        (_patient?.name ?? widget.record.patientName ?? '').trim();
    final financialInfo =
        patientName.isNotEmpty ? '患者"$patientName"的整条财务记录' : '该患者的整条财务记录';

    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: financialInfo,
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      try {
        final provider = Provider.of<FinancialProvider>(context, listen: false);
        // 注意：这里我们假设有一个 `deleteFinancialRecordByPatientId` 方法
        // 但从 `financial_management_screen.dart` 来看，更可能是按 `record.id` 删除
        await provider.deleteFinancialRecord(_recordId);

        if (context.mounted) {
          DeleteSuccessToastManager.show(context, message: '财务记录删除成功');
          Navigator.of(context).pop(true); // 返回并通知列表刷新
        }
      } catch (e) {
        if (context.mounted) {
          SuccessToastManager.showError(context, message: '删除失败: $e');
        }
      }
    }
  }

  /// 添加收费项目
  void _addItem() {
    showDialog(
      context: context,
      builder:
          (context) => FinancialItemAddDialog(
            financialRecordId: _recordId,
            onSave: (newItem) async {
              try {
                final provider = Provider.of<FinancialProvider>(
                  context,
                  listen: false,
                );
                await provider.addFinancialItem(newItem);

                // 更新财务记录的收费项数量和更新时间
                await _updateFinancialRecordAfterItemChange();

                if (context.mounted) {
                  SuccessToastManager.show(context, message: '收费项目添加成功');
                  Navigator.of(context).pop(); // 关闭添加对话框
                  _loadData(); // 重新加载数据
                }
              } catch (e) {
                if (context.mounted) {
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
      builder:
          (context) => FinancialItemEditDialog(
            item: item,
            onSave: (updatedItem) async {
              try {
                final provider = Provider.of<FinancialProvider>(
                  context,
                  listen: false,
                );
                await provider.updateFinancialItem(updatedItem);

                // 更新财务记录的收费项数量和更新时间
                await _updateFinancialRecordAfterItemChange();

                if (context.mounted) {
                  SuccessToastManager.show(context, message: '收费项目更新成功');
                  Navigator.of(context).pop(); // 关闭编辑对话框
                  _loadData(); // 重新加载数据
                }
              } catch (e) {
                if (context.mounted) {
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
    final financialInfo = [
      '收费项目"${item.itemName}"',
      '应收费 ¥${item.itemPrice.toStringAsFixed(2)}',
      '已收费 ¥${item.totalPrice.toStringAsFixed(2)}',
      '加工费 ¥${item.processingFee.toStringAsFixed(2)}',
    ].join('\n');

    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: financialInfo,
    );

    if (confirmed == true) {
      await _confirmDeleteItem(item);
    }
  }

  /// 确认删除收费项目
  Future<void> _confirmDeleteItem(FinancialItem item) async {
    final itemId = item.id;
    if (itemId == null) {
      if (mounted) {
        SuccessToastManager.showError(context, message: '收费项目ID无效，无法删除');
      }
      return;
    }
    try {
      final provider = Provider.of<FinancialProvider>(context, listen: false);
      await provider.deleteFinancialItem(itemId);

      // 更新财务记录的收费项数量和更新时间
      await _updateFinancialRecordAfterItemChange();

      if (mounted) {
        // 使用公共组件的删除成功提示
        DeleteSuccessToastManager.show(context, message: '收费项目删除成功');
        _loadData(); // 重新加载数据
      }
    } catch (e) {
      if (mounted) {
        // 使用公共组件的错误提示
        SuccessToastManager.showError(context, message: '删除失败: $e');
      }
    }
  }
}
