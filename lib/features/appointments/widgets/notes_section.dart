import 'package:flutter/material.dart';

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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildNotesField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.note,
          color: const Color(0xFF9C27B0),
          size: 18,
        ),
        const SizedBox(width: 8),
        const Text(
          '备注信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9C27B0),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: notesController,
      decoration: InputDecoration(
        labelText: '备注',
        hintText: '其他备注信息(可选)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      maxLines: 3,
    );
  }
}
