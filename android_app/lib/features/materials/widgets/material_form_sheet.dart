import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/material.dart';
import '../../../providers/material_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/toast_manager.dart';
import '../services/material_catalog.dart';
import 'material_sheet_header.dart';
import 'material_type_filter_menu.dart';

class MaterialFormPage extends StatefulWidget {
  const MaterialFormPage({super.key, this.material});

  final DentalMaterial? material;

  @override
  State<MaterialFormPage> createState() => _MaterialFormPageState();
}

class _MaterialFormPageState extends State<MaterialFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _supplierController;
  late final TextEditingController _descriptionController;
  late String _selectedType;
  late String _selectedUnit;
  late final List<String> _typeItems;
  late final List<String> _unitItems;
  bool _saving = false;

  bool get _isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _nameController = TextEditingController(text: material?.materialName ?? '');
    _codeController = TextEditingController(
      text: material?.materialCode ?? 'M001',
    );
    _quantityController = TextEditingController(
      text: material?.stockQuantity.toString() ?? '1',
    );
    _priceController = TextEditingController(
      text: material?.defaultPrice.toString() ?? '0.0',
    );
    _supplierController = TextEditingController(text: material?.supplier ?? '');
    _descriptionController = TextEditingController(
      text: fixMaybeDecoded(material?.description),
    );
    _selectedType = material?.materialType ?? '其他';
    _selectedUnit = material?.unit ?? '个';
    _typeItems = [
      for (final type in materialTypeOptions)
        if (type != '全部') type,
    ];
    if (!_typeItems.contains(_selectedType)) {
      _typeItems.add(_selectedType);
    }
    _unitItems = List<String>.from(materialUnitOptions);
    if (!_unitItems.contains(_selectedUnit)) {
      _unitItems.add(_selectedUnit);
    }
    if (material == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNextCode();
      });
    }
  }

  Future<void> _loadNextCode() async {
    if (!mounted) return;
    try {
      final next = await context.read<MaterialProvider>().getNextMaterialCode();
      if (!mounted || _codeController.text != 'M001') return;
      _codeController.text = next;
    } catch (_) {
      if (!mounted || _codeController.text.trim().isNotEmpty) return;
      _codeController.text = 'M001';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickValue({
    required String title,
    required String current,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.7;
        return SafeArea(
          child: SizedBox(
            height: height > 520 ? 520 : height,
            child: MaterialTypeFilterMenu(
              title: title,
              value: current,
              items: items,
              onSelected: (value) => Navigator.of(context).pop(value),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!isMaterialNameValid(_nameController.text)) {
      SuccessToastManager.showError(context, message: '请输入材料名称');
      return;
    }

    setState(() => _saving = true);
    try {
      var code = _codeController.text;
      if (!_isEditing && code.trim().isEmpty) {
        try {
          code = await context.read<MaterialProvider>().getNextMaterialCode();
        } catch (_) {
          code = 'M001';
        }
      }
      if (!mounted) return;

      final draft = buildMaterialDraft(
        existing: widget.material,
        name: _nameController.text,
        code: code,
        type: _selectedType,
        unit: _selectedUnit,
        priceText: _priceController.text,
        quantityText: _quantityController.text,
        supplier: _supplierController.text,
        description: _descriptionController.text,
      );
      final provider = context.read<MaterialProvider>();
      final success =
          _isEditing
              ? await provider.updateMaterial(draft) > 0
              : await provider.addMaterial(draft) > 0;
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        return;
      }
      SuccessToastManager.showError(context, message: '操作失败');
    } catch (error) {
      if (!mounted) return;
      SuccessToastManager.showError(context, message: '操作失败: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? '编辑材料' : '添加材料'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          MaterialSectionCard(
            title: '基本信息',
            child: Column(
              children: [
                _field(
                  controller: _nameController,
                  label: '材料名称',
                  hint: '请输入材料名称',
                  icon: Icons.inventory_rounded,
                  requiredField: true,
                ),
                _field(
                  controller: _codeController,
                  label: '材料编码',
                  hint: '例如: M001',
                  icon: Icons.qr_code_rounded,
                ),
                MaterialChoiceTile(
                  icon: Icons.category_rounded,
                  label: '材料类型',
                  value: _selectedType,
                  onTap: () {
                    _pickValue(
                      title: '材料类型',
                      current: _selectedType,
                      items: _typeItems,
                      onSelected: (value) {
                        setState(() => _selectedType = value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MaterialSectionCard(
            title: '数量与价格',
            child: Column(
              children: [
                _field(
                  controller: _quantityController,
                  label: '数量',
                  hint: '例如: 1',
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                ),
                MaterialChoiceTile(
                  icon: Icons.straighten_rounded,
                  label: '单位',
                  value: _selectedUnit,
                  onTap: () {
                    _pickValue(
                      title: '单位',
                      current: _selectedUnit,
                      items: _unitItems,
                      onSelected: (value) {
                        setState(() => _selectedUnit = value);
                      },
                    );
                  },
                ),
                _field(
                  controller: _priceController,
                  label: '默认价格',
                  hint: '0.00',
                  icon: Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefix: '¥',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MaterialSectionCard(
            title: '补充说明',
            child: Column(
              children: [
                _field(
                  controller: _supplierController,
                  label: '供应商',
                  hint: '请输入供应商名称',
                  icon: Icons.business_rounded,
                ),
                _field(
                  controller: _descriptionController,
                  label: '描述',
                  hint: '请输入材料描述信息',
                  icon: Icons.description_rounded,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child:
                      _saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(_isEditing ? '更新' : '添加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool requiredField = false,
    TextInputType? keyboardType,
    String? prefix,
    int maxLines = 1,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          prefixText: prefix,
          filled: true,
          fillColor: AppTheme.backgroundColor,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
