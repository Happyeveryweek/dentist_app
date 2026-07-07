import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';

class BackupPathInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onBrowse;

  const BackupPathInput({
    Key? key,
    required this.controller,
    required this.label,
    required this.onBrowse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder, color: context.tokens.secondaryAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.tokens.secondaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '请输入备份目录或留空',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.tokens.divider),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('浏览'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.tokens.secondaryAccent,
                foregroundColor: context.tokens.cardBackground,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
