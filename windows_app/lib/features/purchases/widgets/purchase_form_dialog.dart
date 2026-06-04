import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../providers/purchase_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/modern_date_picker.dart';
import '../../../widgets/success_toast.dart';
import '../widgets/material_selection_dialog.dart';
import 'purchase_form_basic_info_section.dart';
import 'purchase_form_item_list_section.dart';
import 'purchase_form_actions_section.dart';

/// 采购记录表单对话框
/// 用于新增或编辑采购记录
class PurchaseFormDialog extends StatefulWidget {
  final PurchaseRecord? record;
  final VoidCallback? onSaved;

  const PurchaseFormDialog({
    super.key,
    this.record,
    this.onSaved,
  });

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  late TextEditingController _dateController;
  late TextEditingController _supplierController;
  late TextEditingController _doctorController;
  late TextEditingController _notesController;

  List<Map<String, dynamic>> _purchaseItems = [];
  List<TextEditingController> _materialNameControllers = [];
  List<TextEditingController> _quantityControllers = [];
  List<TextEditingController> _unitPriceControllers = [];
  List<TextEditingController> _unitControllers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.record != null;

    _dateController = TextEditingController(
      text: isEditing
          ? DateFormat('yyyy-MM-dd').format(widget.record!.purchaseDate)
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _supplierController = TextEditingController(text: widget.record?.supplier ?? '');

    // 设置医生字段的初始值
    String initialDoctorName = '';
    if (isEditing) {
      initialDoctorName = widget.record?.doctor ?? '';
    } else {
      // 新增模式：通过UserProvider获取当前用户信息作为默认值
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = userProvider.currentUser;

        if (currentUser != null && currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
          initialDoctorName = currentUser.doctor!;
        } else if (currentUser != null && currentUser.role == 'doctor') {
          initialDoctorName = currentUser.username;
        }
      } catch (e) {
        print('通过UserProvider获取当前用户信息失败: $e');
      }
    }

    _doctorController = TextEditingController(text: initialDoctorName);
    _notesController = TextEditingController(text: widget.record?.notes ?? '');

    if (isEditing) {
      _loadExistingItems();
    }
  }

  Future<void> _loadExistingItems() async {
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      final items = await purchaseProvider.getPurchaseItemsByRecordId(widget.record!.id!);
      print('编辑模式：成功加载采购项目 ${items.length} 项');
      for (final item in items) {
        _purchaseItems.add({
          'materialId': item.materialId,
          'materialName': item.materialName,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'totalPrice': item.totalPrice,
          'unit': item.unit ?? '个',
        });
        _materialNameControllers.add(TextEditingController(text: item.materialName));
        _quantityControllers.add(TextEditingController(text: item.quantity.toString()));
        _unitPriceControllers.add(TextEditingController(text: item.unitPrice == 0.0 ? '' : item.unitPrice.toString()));
        _unitControllers.add(TextEditingController(text: item.unit ?? '个'));
      }
      setState(() {});
    } catch (e) {
      print('加载采购项目失败: $e');
      _purchaseItems.add({
        'materialId': null,
        'materialName': '加载失败，请重新添加',
        'quantity': 1,
        'unitPrice': 0.0,
        'totalPrice': 0.0,
        'unit': '个',
      });
      _materialNameControllers.add(TextEditingController(text: '加载失败，请重新添加'));
      _quantityControllers.add(TextEditingController(text: '1'));
      _unitPriceControllers.add(TextEditingController(text: ''));
      _unitControllers.add(TextEditingController(text: '个'));
      setState(() {});
    }
  }

  void _addItem(int index) {
    setState(() {
      _purchaseItems.insert(index, {
        'materialId': null,
        'materialName': '',
        'quantity': 1,
        'unitPrice': 0.0,
        'totalPrice': 0.0,
        'unit': '个',
      });
      _materialNameControllers.insert(index, TextEditingController(text: ''));
      _quantityControllers.insert(index, TextEditingController(text: '1'));
      _unitPriceControllers.insert(index, TextEditingController(text: ''));
      _unitControllers.insert(index, TextEditingController(text: '个'));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
      _materialNameControllers[index].dispose();
      _quantityControllers[index].dispose();
      _unitPriceControllers[index].dispose();
      _unitControllers[index].dispose();
      _materialNameControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _unitPriceControllers.removeAt(index);
      _unitControllers.removeAt(index);
    });
  }

  void _onMaterialNameChanged(int index, String value) {
    setState(() {
      _purchaseItems[index]['materialName'] = value;
    });
  }

  void _onQuantityChanged(int index, int quantity) {
    setState(() {
      _purchaseItems[index]['quantity'] = quantity;
      _purchaseItems[index]['totalPrice'] = quantity * (_purchaseItems[index]['unitPrice'] as double);
    });
  }

  void _onUnitChanged(int index, String value) {
    setState(() {
      _purchaseItems[index]['unit'] = value;
    });
  }

  void _onUnitPriceChanged(int index, double unitPrice) {
    setState(() {
      _purchaseItems[index]['unitPrice'] = unitPrice;
      _purchaseItems[index]['totalPrice'] = (_purchaseItems[index]['quantity'] as int) * unitPrice;
    });
  }

  Future<void> _onMaterialSelect(int index) async {
    final selectedMaterial = await MaterialSelectionDialog.show(context);
    if (selectedMaterial != null) {
      setState(() {
        _purchaseItems[index]['materialId'] = selectedMaterial.id;
        _purchaseItems[index]['materialName'] = selectedMaterial.materialName;
        _purchaseItems[index]['unit'] = selectedMaterial.unit;
        if (selectedMaterial.defaultPrice > 0) {
          _purchaseItems[index]['unitPrice'] = selectedMaterial.defaultPrice;
          _purchaseItems[index]['totalPrice'] = (_purchaseItems[index]['quantity'] as int) * selectedMaterial.defaultPrice;
        }
        _materialNameControllers[index].text = selectedMaterial.materialName;
        _unitControllers[index].text = selectedMaterial.unit ?? '个';
        if (selectedMaterial.defaultPrice > 0) {
          _unitPriceControllers[index].text = selectedMaterial.defaultPrice.toString();
        }
      });
    }
  }

  Future<void> _onSave() async {
    // 验证基本信息
    if (_dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('采购日期不能为空'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 验证采购项目
    for (int i = 0; i < _purchaseItems.length; i++) {
      final item = _purchaseItems[i];
      final materialName = _materialNameControllers[i].text.trim();
      final quantity = int.tryParse(_quantityControllers[i].text) ?? 0;
      final unitPrice = double.tryParse(_unitPriceControllers[i].text) ?? 0.0;
      final unit = _unitControllers[i].text.trim();

      if (materialName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('第${i + 1}个项目的材料名称不能为空'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('第${i + 1}个项目的数量必须大于0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (unitPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('第${i + 1}个项目的单价不能为负数'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      item['materialName'] = materialName;
      item['quantity'] = quantity;
      item['unitPrice'] = unitPrice;
      item['unit'] = unit;
      item['totalPrice'] = quantity * unitPrice;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);

      final totalQuantity = _purchaseItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
      final totalAmount = _purchaseItems.fold<double>(0.0, (sum, item) => sum + (item['totalPrice'] as double));

      final purchaseRecord = PurchaseRecord(
        id: widget.record?.id,
        purchaseDate: DateFormat('yyyy-MM-dd').parse(_dateController.text),
        totalQuantity: totalQuantity,
        totalAmount: totalAmount,
        supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
        doctor: _doctorController.text.trim().isEmpty ? null : _doctorController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      bool success;
      int? recordId;

      if (widget.record != null) {
        success = await purchaseProvider.updatePurchaseRecord(purchaseRecord);
        recordId = widget.record?.id;
      } else {
        recordId = await purchaseProvider.addPurchaseRecord(purchaseRecord);
        success = recordId != null && recordId > 0;
      }

      if (success && recordId != null) {
        List<PurchaseItem> oldItems = [];
        if (widget.record != null) {
          oldItems = await purchaseProvider.getPurchaseItemsByRecordId(recordId!);
        }

        List<Map<String, dynamic>> itemsToAdd = [];
        List<PurchaseItem> itemsToUpdate = [];
        List<PurchaseItem> itemsToDelete = [];

        for (final newItem in _purchaseItems) {
          if (newItem['materialName'].toString().contains('请重新添加') ||
              newItem['materialName'].toString().contains('加载失败')) {
            continue;
          }

          bool foundMatch = false;
          for (final oldItem in oldItems) {
            if (oldItem.materialName == newItem['materialName'].toString().trim()) {
              bool hasChanges = oldItem.quantity != newItem['quantity'] ||
                              oldItem.unitPrice != newItem['unitPrice'] ||
                              oldItem.unit != newItem['unit'] ||
                              oldItem.materialId != newItem['materialId'];

              if (hasChanges) {
                final updatedItem = PurchaseItem(
                  id: oldItem.id,
                  purchaseRecordId: recordId!,
                  materialId: newItem['materialId'] as int?,
                  materialName: newItem['materialName'].toString().trim(),
                  quantity: newItem['quantity'] as int,
                  unitPrice: newItem['unitPrice'] as double,
                  totalPrice: newItem['totalPrice'] as double,
                  unit: newItem['unit'] as String?,
                  createdAt: oldItem.createdAt,
                  updatedAt: DateTime.now(),
                );
                itemsToUpdate.add(updatedItem);
              }

              oldItems.remove(oldItem);
              foundMatch = true;
              break;
            }
          }

          if (!foundMatch) {
            itemsToAdd.add(newItem);
          }
        }

        itemsToDelete.addAll(oldItems);

        for (final itemToDelete in itemsToDelete) {
          await purchaseProvider.deletePurchaseItem(itemToDelete.id!);
        }

        for (final itemToUpdate in itemsToUpdate) {
          await purchaseProvider.updatePurchaseItem(itemToUpdate);
        }

        for (final itemToAdd in itemsToAdd) {
          final purchaseItem = PurchaseItem(
            purchaseRecordId: recordId!,
            materialId: itemToAdd['materialId'] as int?,
            materialName: itemToAdd['materialName'].toString().trim(),
            quantity: itemToAdd['quantity'] as int,
            unitPrice: itemToAdd['unitPrice'] as double,
            totalPrice: itemToAdd['totalPrice'] as double,
            unit: itemToAdd['unit'] as String?,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await purchaseProvider.addPurchaseItem(purchaseItem);
        }

        Navigator.of(context).pop(true);
        AppToastManager.showSuccess(context, message: widget.record != null ? '采购记录更新成功' : '采购记录添加成功');
        widget.onSaved?.call();
      } else {
        Navigator.of(context).pop();
        AppToastManager.showError(context, message: '保存失败');
      }
    } catch (e) {
      Navigator.of(context).pop();
      AppToastManager.showError(context, message: '保存失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _supplierController.dispose();
    _doctorController.dispose();
    _notesController.dispose();
    for (var controller in _materialNameControllers) {
      controller.dispose();
    }
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    for (var controller in _unitPriceControllers) {
      controller.dispose();
    }
    for (var controller in _unitControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 560,
          maxWidth: 736,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Material(
          color: Theme.of(context).dialogBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(DentalIcons.shoppingCart, color: Theme.of(context).primaryColor, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isEditing ? '编辑采购记录' : '新增采购记录',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: '关闭',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PurchaseFormBasicInfoSection(
                  dateController: _dateController,
                  supplierController: _supplierController,
                  doctorController: _doctorController,
                  notesController: _notesController,
                  isEditing: isEditing,
                  initialDate: widget.record?.purchaseDate,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PurchaseFormItemListSection(
                    purchaseItems: _purchaseItems,
                    materialNameControllers: _materialNameControllers,
                    quantityControllers: _quantityControllers,
                    unitPriceControllers: _unitPriceControllers,
                    unitControllers: _unitControllers,
                    onAddItem: _addItem,
                    onRemoveItem: _removeItem,
                    onMaterialNameChanged: _onMaterialNameChanged,
                    onQuantityChanged: _onQuantityChanged,
                    onUnitChanged: _onUnitChanged,
                    onUnitPriceChanged: _onUnitPriceChanged,
                    onMaterialSelect: _onMaterialSelect,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: PurchaseFormActionsSection(
                    isEditing: isEditing,
                    isLoading: _isLoading,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: _onSave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示采购记录表单对话框
Future<bool?> showPurchaseFormDialog({
  required BuildContext context,
  PurchaseRecord? record,
  VoidCallback? onSaved,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => PurchaseFormDialog(
      record: record,
      onSaved: onSaved,
    ),
  );
}
