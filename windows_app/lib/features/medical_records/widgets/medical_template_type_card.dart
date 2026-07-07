import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/medical_record_template.dart';
import '../helpers/medical_template_category_style_helper.dart';
import 'medical_template_sub_type_tile.dart';

/// 病历模板类型卡片
/// 显示主类型及其子类型
class MedicalTemplateTypeCard extends StatefulWidget {
  final MedicalRecordTemplate mainType;
  final List<MedicalRecordTemplate> children;
  final String category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddSubType;
  final Function(MedicalRecordTemplate) onSubTypeEdit;
  final Function(MedicalRecordTemplate) onSubTypeDelete;

  const MedicalTemplateTypeCard({
    Key? key,
    required this.mainType,
    required this.children,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubType,
    required this.onSubTypeEdit,
    required this.onSubTypeDelete,
  }) : super(key: key);

  @override
  State<MedicalTemplateTypeCard> createState() =>
      _MedicalTemplateTypeCardState();
}

class _MedicalTemplateTypeCardState extends State<MedicalTemplateTypeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final categoryColor = MedicalTemplateCategoryStyleHelper.getCategoryColor(
      widget.category,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        widget.mainType.name.substring(0, 1),
                        style: TextStyle(
                          color: tokens.cardBackground,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mainType.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                        ),
                        if (widget.mainType.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.mainType.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.iconMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.children.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 11,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.children.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: tokens.primaryAccent,
                    tooltip: '编辑',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: tokens.error,
                    tooltip: '删除',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: tokens.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 4),
            if (widget.children.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      tokens.divider,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...widget.children.map(
                (child) => MedicalTemplateSubTypeTile(
                  subType: child,
                  category: widget.category,
                  onEdit: () => widget.onSubTypeEdit(child),
                  onDelete: () => widget.onSubTypeDelete(child),
                ),
              ),
            ],
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: InkWell(
                onTap: widget.onAddSubType,
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.primaryAccent.withValues(alpha: 0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.primaryAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add,
                          color: tokens.primaryAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '添加子类型',
                        style: TextStyle(
                          color: tokens.primaryAccent,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
