import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';
import 'material_dropdown_container.dart';

class MaterialDropdownField extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final List<String> items;
  final Function(String?) onChanged;

  const MaterialDropdownField({
    Key? key,
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
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
          ],
        ),
        const SizedBox(height: 8),
        MaterialDropdownContainer(
          value: value,
          items: items,
          onChanged: onChanged,
          hintText: '请选择$label',
        ),
      ],
    );
  }
}
