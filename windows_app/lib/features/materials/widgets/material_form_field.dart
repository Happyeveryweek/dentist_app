import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';

class MaterialFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isRequired;
  final bool isReadOnly;
  final TextInputType? keyboardType;
  final String? prefix;
  final int maxLines;

  const MaterialFormField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isRequired = false,
    this.isReadOnly = false,
    this.keyboardType,
    this.prefix,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.tokens.primaryAccent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: context.tokens.error,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.tokens.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: context.tokens.primaryAccent, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.tokens.divider),
            ),
            filled: true,
            fillColor: isReadOnly ? context.tokens.pageBackground : context.tokens.cardBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
