import 'package:flutter/material.dart';
import '../models/medical_template.dart';
import '../services/medical_template_service.dart';
import '../widgets/dental_icons.dart';
import 'success_toast.dart';

/// 医疗模板编辑对话框
/// 用于添加和编辑治疗方案模板和医嘱模板
class MedicalTemplateEditDialog extends StatefulWidget {
  final String templateType;
  final MedicalTemplate? template;
  final Function(MedicalTemplate)? onSaved;

  const MedicalTemplateEditDialog({
    Key? key,
    required this.templateType,
    this.template,
    this.onSaved,
  }) : super(key: key);

  @override
  State<MedicalTemplateEditDialog> createState() => _MedicalTemplateEditDialogState();
}

class _MedicalTemplateEditDialogState extends State<MedicalTemplateEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.template != null) {
      // 编辑模式
      final template = widget.template!;
      _titleController.text = template.title;
      _contentController.text = template.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
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
                  widget.template == null ? '添加模板' : '编辑模板',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  MedicalTemplateType.getTypeName(widget.templateType),
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
            // 模板标题
            _buildInputField(
              controller: _titleController,
              label: '模板标题',
              hint: '请输入模板标题',
              icon: Icons.title_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入模板标题';
                }
                if (value.trim().length < 2) {
                  return '标题至少需要2个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 模板内容
            _buildInputField(
              controller: _contentController,
              label: '模板内容',
              hint: '请输入模板内容，每行一个步骤或要点',
              icon: Icons.description_rounded,
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入模板内容';
                }
                if (value.trim().length < 5) {
                  return '内容至少需要5个字符';
                }
                return null;
              },
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
                      widget.templateType == MedicalTemplateType.treatment
                          ? '治疗方案模板用于快速填入治疗计划，建议按步骤编写'
                          : '医嘱模板用于快速填入注意事项，建议分条列出要点',
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

    setState(() {
      _isLoading = true;
    });

    try {
      final template = MedicalTemplate(
        id: widget.template?.id ?? MedicalTemplateService.generateTemplateId(widget.templateType),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        type: widget.templateType,
        sortOrder: widget.template?.sortOrder ?? 999, // 新模板放在最后
      );

      if (widget.template == null) {
        // 新建
        await MedicalTemplateService.addTemplate(template);
        SuccessToastManager.show(
          context,
          message: '模板添加成功',
          duration: const Duration(seconds: 2),
        );
      } else {
        // 编辑
        await MedicalTemplateService.updateTemplate(template);
        SuccessToastManager.show(
          context,
          message: '模板更新成功',
          duration: const Duration(seconds: 2),
        );
      }

      // 调用回调
      if (widget.onSaved != null) {
        widget.onSaved!(template);
      }

      // 关闭对话框
      if (mounted) {
        Navigator.of(context).pop(template);
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
}