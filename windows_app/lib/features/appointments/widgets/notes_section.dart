import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 备注信息区域
///
/// 显示备注输入框
class NotesSection extends StatelessWidget {
  final TextEditingController notesController;

  const NotesSection({
    Key? key,
    required this.notesController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildNotesField(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.note,
          color: context.tokens.primaryAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '备注信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.tokens.primaryAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    return TextFormField(
      controller: notesController,
      decoration: InputDecoration(
        labelText: '备注',
        hintText: '其他备注信息(可选)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: context.tokens.cardBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      maxLines: 3,
    );
  }
}
