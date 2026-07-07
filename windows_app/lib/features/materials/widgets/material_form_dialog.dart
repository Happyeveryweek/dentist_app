import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/material.dart' as material_models;
import '../../../providers/material_provider.dart';
import '../../../widgets/success_toast.dart';
import 'material_form_field.dart';
import 'material_dropdown_field.dart';
import 'material_unit_dropdown.dart';
import '../../../utils/log_manager.dart';

/// 材料表单对话框
///
/// 用于添加或编辑材料信息
class MaterialFormDialog extends StatefulWidget {
  final material_models.MaterialInfo? material;
  final List<String> materialTypes;
  final VoidCallback onSuccess;
  final String Function(String?) fixMaybeDecoded;

  const MaterialFormDialog({
    Key? key,
    this.material,
    required this.materialTypes,
    required this.onSuccess,
    required this.fixMaybeDecoded,
  }) : super(key: key);

  @override
  State<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<MaterialFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _priceController;
  late TextEditingController _supplierController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;

  late String _selectedType;
  late String _selectedUnit;

  final List<String> _unitOptions = [
    '个',
    '瓶',
    '把',
    '盒',
    '包',
    '支',
    '片',
    '克',
    '毫升',
    '米',
    '厘米',
    '箱',
    '卷',
    '袋',
    '套',
    '件',
    '条',
    '块',
    '粒',
    '颗',
    '根',
    '张',
    '台',
    '架',
    '组',
    '对',
    '双',
    '副',
    '只',
    '枚',
    '筒',
    '罐',
    '桶'
  ];

  bool get isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.material?.materialName ?? '');
    _priceController = TextEditingController(
        text: widget.material?.defaultPrice.toString() ?? '0.0');
    _supplierController =
        TextEditingController(text: widget.material?.supplier ?? '');
    _descriptionController = TextEditingController(
        text: widget.fixMaybeDecoded(widget.material?.description ?? ''));
    _quantityController = TextEditingController(
        text: widget.material?.stockQuantity.toString() ?? '1');

    _selectedType = widget.material?.materialType ?? '其他';
    _selectedUnit = widget.material?.unit ?? '个';
    _unitController = TextEditingController(text: _selectedUnit);

    // Initialize _codeController immediately to avoid LateInitializationError
    if (isEditing) {
      _codeController =
          TextEditingController(text: widget.material?.materialCode ?? '');
    } else {
      _codeController = TextEditingController(text: 'M001'); // Default value
      _initializeNextCode(); // Update asynchronously
    }
  }

  Future<void> _initializeNextCode() async {
    try {
      final materialProvider =
          Provider.of<MaterialProvider>(context, listen: false);
      final nextCode = await materialProvider.getNextMaterialCode();
      setState(() {
        _codeController = TextEditingController(text: nextCode);
      });
    } catch (e) {
      setState(() {
        _codeController = TextEditingController(text: 'M001');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入材料名称'),
          backgroundColor: context.tokens.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final price = double.tryParse(_priceController.text) ?? 0.0;

      String? materialCode;
      if (isEditing) {
        materialCode = _codeController.text.trim().isEmpty
            ? null
            : _codeController.text.trim();
      } else {
        if (_codeController.text.trim().isEmpty) {
          final materialProvider =
              Provider.of<MaterialProvider>(context, listen: false);
          try {
            materialCode = await materialProvider.getNextMaterialCode();
          } catch (e) {
            LogManager.e('MaterialFormDialog', '自动生成材料编码失败', error: e);
            materialCode = 'M001';
          }
        } else {
          materialCode = _codeController.text.trim();
        }
      }

      final newMaterial = material_models.MaterialInfo(
        id: widget.material?.id,
        materialName: _nameController.text.trim(),
        materialCode: materialCode,
        materialType: _selectedType,
        unit: _unitController.text,
        defaultPrice: price,
        stockQuantity: int.tryParse(_quantityController.text.trim()) ?? 0,
        supplier: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (!mounted) return;
      final materialProvider =
          Provider.of<MaterialProvider>(context, listen: false);
      bool success;

      if (isEditing) {
        success = await materialProvider.updateMaterial(newMaterial);
      } else {
        final newId = await materialProvider.addMaterial(newMaterial);
        success = newId > 0;
      }

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        widget.onSuccess();
        AppToastManager.showSuccess(context,
            message: isEditing ? '材料更新成功' : '材料添加成功');
      } else {
        if (!mounted) return;
        AppToastManager.showError(context, message: '操作失败');
      }
    } catch (e) {
      if (!mounted) return;
      AppToastManager.showError(context, message: '操作失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: context.tokens.cardBackground,
          boxShadow: context.tokens.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildForm(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: context.tokens.primaryHeaderGradient,
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
              color: context.colors.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.add_rounded,
              color: context.colors.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isEditing ? '编辑材料' : '添加材料',
              style: TextStyle(
                color: context.colors.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: Icon(Icons.close_rounded, color: context.colors.onPrimary),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MaterialFormField(
              controller: _nameController,
              label: '材料名称',
              hint: '请输入材料名称',
              icon: Icons.inventory_rounded,
              isRequired: true,
            ),
            const SizedBox(height: 20),
            MaterialFormField(
              controller: _codeController,
              label: '材料编码',
              hint: '例如: M001',
              icon: Icons.qr_code_rounded,
            ),
            const SizedBox(height: 20),
            MaterialDropdownField(
              value: _selectedType,
              label: '材料类型',
              icon: Icons.category_rounded,
              items:
                  widget.materialTypes.where((type) => type != '全部').toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MaterialFormField(
                    controller: _quantityController,
                    label: '数量',
                    hint: '例如: 1',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten_rounded,
                              size: 20, color: context.tokens.primaryAccent),
                          const SizedBox(width: 8),
                          Text(
                            '单位',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MaterialUnitDropdown(
                        controller: _unitController,
                        options: _unitOptions,
                        onSelected: (value) {
                          setState(() {
                            _unitController.text = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MaterialFormField(
              controller: _priceController,
              label: '默认价格',
              hint: '0.00',
              icon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
              prefix: '¥',
            ),
            const SizedBox(height: 20),
            MaterialFormField(
              controller: _supplierController,
              label: '供应商',
              hint: '请输入供应商名称',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 20),
            MaterialFormField(
              controller: _descriptionController,
              label: '描述',
              hint: '请输入材料描述信息',
              icon: Icons.description_rounded,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tokens.mutedBackground,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.tokens.textMuted),
              ),
            ),
            child: const Text(
              '取消',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.tokens.primaryAccent,
              foregroundColor: context.tokens.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              isEditing ? '更新' : '添加',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
