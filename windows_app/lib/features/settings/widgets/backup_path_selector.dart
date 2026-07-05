import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../widgets/dental_icons.dart';

class BackupPathSelector extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onSelectPath;

  const BackupPathSelector({
    Key? key,
    required this.controller,
    required this.label,
    required this.onSelectPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: '请选择备份目录',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DentalGradientButton(
                text: '浏览',
                icon: Icons.folder_open,
                onPressed: onSelectPath,
                isOutlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
