import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medical_record_template.dart';
import '../providers/medical_record_provider.dart';
import '../widgets/dental_icons.dart';
import 'success_toast.dart';

/// 疾病类型编辑对话框
/// 用于添加和编辑病历模板中的疾病类型
class DiseaseTypeEditDialog extends StatefulWidget {
  final String? category;
  final String? parentName;
  final MedicalRecordTemplate? template;
  final Function(MedicalRecordTemplate)? onSaved;

  const DiseaseTypeEditDialog({
    Key? key,
    this.category,
    this.parentName,
    this.template,
    this.onSaved,
  }) : super(key: key);

  @override
  State<DiseaseTypeEditDialog> createState() => _DiseaseTypeEditDialogState();
}

class _DiseaseTypeEditDialogState extends State<DiseaseTypeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedParentName;
  bool _isLoading = false;
  List<String> _availableParentTypes = [];
  bool _isMainType = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadAvailableParentTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.template != null) {
      // 编辑模式
      final template = widget.template!;
      _nameController.text = template.name;
      _descriptionController.text = template.description;
      _selectedCategory = template.category;
      _selectedParentName = template.parentName;
      _isMainType = template.isMainType;
    } else {
      // 新建模式
      _selectedCategory = widget.category;
      _selectedParentName = widget.parentName;
      _isMainType = widget.parentName == null;
    }
  }

  Future<void> _loadAvailableParentTypes() async {
    if (_selectedCategory == null) return;
    
    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      final templates = await provider.getTemplatesByCategory(_selectedCategory!, forceRefresh: true);
      
      setState(() {
        _availableParentTypes = templates
            .where((t) => t.isMainType)
            .map((t) => t.name)
            .toList();
      });
    } catch (e) {
      print('加载父类型失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: DentalColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DentalColors.primaryGradient,
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.template == null ? Icons.add_rounded : Icons.edit_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.template == null ? '添加疾病类型' : '编辑疾病类型',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getCategoryDisplayName(_selectedCategory ?? ''),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类别选择
            _buildCategorySelector(),
            const SizedBox(height: 20),

            // 类型选择（主类型/子类型）
            _buildTypeSelector(),
            const SizedBox(height: 20),

            // 父类型选择（仅子类型时显示）
            if (!_isMainType) ...[
              _buildParentTypeSelector(),
              const SizedBox(height: 20),
            ],

            // 名称输入
            _buildInputField(
              controller: _nameController,
              label: '名称',
              hint: '请输入疾病类型名称',
              icon: Icons.label_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入名称';
                }
                if (value.trim().length < 2) {
                  return '名称至少需要2个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 描述输入
            _buildInputField(
              controller: _descriptionController,
              label: '描述',
              hint: '请输入疾病类型的详细描述（可选）',
              icon: Icons.description_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DentalColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DentalColors.info.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: DentalColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isMainType 
                          ? '主类型用于分类管理，可以包含多个子类型'
                          : '子类型属于某个主类型，用于更详细的分类',
                      style: TextStyle(
                        color: DentalColors.info,
                        fontSize: 14,
                      ),
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

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_rounded,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '类别',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: DentalColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.divider,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              hint: const Text('请选择类别'),
              items: [
                DropdownMenuItem(
                  value: MedicalRecordTemplateCategory.dentalDisease,
                  child: Row(
                    children: [
                      Icon(Icons.medical_services, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('牙科疾病'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: MedicalRecordTemplateCategory.systemicDisease,
                  child: Row(
                    children: [
                      Icon(Icons.health_and_safety, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('全身疾病'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: MedicalRecordTemplateCategory.allergy,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('过敏类型'),
                    ],
                  ),
                ),
              ],
              onChanged: widget.template == null ? (value) {
                setState(() {
                  _selectedCategory = value;
                  _selectedParentName = null;
                  _availableParentTypes.clear();
                });
                if (value != null) {
                  _loadAvailableParentTypes();
                }
              } : null,
              style: const TextStyle(
                fontSize: 16,
                color: DentalColors.onSurface,
              ),
              dropdownColor: DentalColors.surface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_rounded,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '类型',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('主类型'),
                subtitle: const Text('顶级分类'),
                value: true,
                groupValue: _isMainType,
                onChanged: widget.template == null ? (value) {
                  setState(() {
                    _isMainType = value ?? true;
                    if (_isMainType) {
                      _selectedParentName = null;
                    }
                  });
                } : null,
                activeColor: DentalColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('子类型'),
                subtitle: const Text('从属分类'),
                value: false,
                groupValue: _isMainType,
                onChanged: widget.template == null ? (value) {
                  setState(() {
                    _isMainType = value ?? true;
                  });
                } : null,
                activeColor: DentalColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParentTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.folder_rounded,
              size: 18,
              color: DentalColors.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              '父类型',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: DentalColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.divider,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedParentName,
              isExpanded: true,
              hint: const Text('请选择父类型'),
              items: _availableParentTypes.map((parentType) {
                return DropdownMenuItem(
                  value: parentType,
                  child: Text(parentType),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedParentName = value;
                });
              },
              style: const TextStyle(
                fontSize: 16,
                color: DentalColors.onSurface,
              ),
              dropdownColor: DentalColors.surface,
            ),
          ),
        ),
        if (_availableParentTypes.isEmpty && _selectedCategory != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DentalColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DentalColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '该类别下暂无主类型，请先创建主类型',
                    style: TextStyle(
                      color: DentalColors.warning,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: DentalColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.divider,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: DentalColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DentalColors.surface,
        border: Border(
          top: BorderSide(
            color: DentalColors.divider,
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: DentalColors.primary),
                foregroundColor: DentalColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: DentalColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.template == null ? '添加' : '保存',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 验证必填字段
    if (_selectedCategory == null) {
      SuccessToastManager.showError(
        context,
        message: '请选择类别',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_isMainType && (_selectedParentName == null || _selectedParentName!.isEmpty)) {
      SuccessToastManager.showError(
        context,
        message: '子类型必须选择父类型',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      final template = MedicalRecordTemplate(
        id: widget.template?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        parentName: _isMainType ? null : _selectedParentName,
      );

      if (widget.template == null) {
        // 新建
        final templateId = await provider.createTemplate(template);
        final savedTemplate = template.copyWith(id: templateId);
        
        SuccessToastManager.show(
          context,
          message: '疾病类型添加成功',
          duration: const Duration(seconds: 2),
        );
        
        // 调用回调
        if (widget.onSaved != null) {
          widget.onSaved!(savedTemplate);
        }

        // 关闭对话框
        if (mounted) {
          Navigator.of(context).pop(savedTemplate);
        }
      } else {
        // 编辑
        final success = await provider.updateTemplate(template);
        if (success) {
          SuccessToastManager.show(
            context,
            message: '疾病类型更新成功',
            duration: const Duration(seconds: 2),
          );
          
          // 调用回调
          if (widget.onSaved != null) {
            widget.onSaved!(template);
          }

          // 关闭对话框
          if (mounted) {
            Navigator.of(context).pop(template);
          }
        } else {
          throw Exception('更新失败');
        }
      }
    } catch (e) {
      SuccessToastManager.showError(
        context,
        message: '保存失败: $e',
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryDisplayName(String category) {
    return MedicalRecordTemplateCategory.getCategoryName(category);
  }
}