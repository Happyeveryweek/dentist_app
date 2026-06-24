import 'package:flutter/material.dart';
import 'section_title.dart';

class NotesSection extends StatelessWidget {
  final TextEditingController notesController;

  const NotesSection({super.key, required this.notesController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '备注信息', icon: Icons.note, color: Colors.orange),
        const SizedBox(height: 8),

        TextFormField(
          controller: notesController,
          decoration: InputDecoration(
            labelText: '备注',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            hintText: '请输入备注信息（可选）',
          ),
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
