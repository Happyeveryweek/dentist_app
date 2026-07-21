import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/theme_context_extensions.dart';

class PatientFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final int maxLines;
  final TextAlignVertical? textAlignVertical;
  final bool enabled;

  const PatientFormTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.onTap,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.textAlignVertical,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      maxLines: maxLines,
      textAlignVertical: textAlignVertical ?? TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(
          icon,
          color: enabled ? tokens.primaryAccent : tokens.iconMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.divider.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.divider.withValues(alpha: 0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.error),
        ),
        filled: true,
        fillColor: enabled
            ? tokens.cardBackground.withValues(alpha: 0.8)
            : tokens.disabledBackground,
        contentPadding: maxLines > 1
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: TextStyle(
          color: enabled ? colors.onSurfaceVariant : tokens.disabledText,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: enabled
              ? colors.onSurfaceVariant.withValues(alpha: 0.6)
              : tokens.disabledText.withValues(alpha: 0.6),
        ),
        alignLabelWithHint: true,
      ),
      style: TextStyle(
        color: enabled ? colors.onSurface : tokens.disabledText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }
}

class PatientFormDropdown extends StatelessWidget {
  final String value;
  final String labelText;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const PatientFormDropdown({
    Key? key,
    required this.value,
    required this.labelText,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return DropdownButtonFormField<String>(
      mouseCursor: SystemMouseCursors.click,
      dropdownMenuItemMouseCursor: SystemMouseCursors.click,
      initialValue: value,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(
          icon,
          color: enabled ? tokens.primaryAccent : tokens.iconMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.divider.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.divider.withValues(alpha: 0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.primaryAccent, width: 2),
        ),
        filled: true,
        fillColor: enabled
            ? tokens.cardBackground.withValues(alpha: 0.8)
            : tokens.disabledBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: TextStyle(
          color: enabled ? colors.onSurfaceVariant : tokens.disabledText,
          fontWeight: FontWeight.w500,
        ),
      ),
      items: enabled ? items : null,
      onChanged: enabled ? onChanged : null,
      style: TextStyle(
        color: colors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: tokens.cardBackground,
      icon: Icon(Icons.arrow_drop_down, color: tokens.primaryAccent),
    );
  }
}

class PatientFormDateField extends StatelessWidget {
  final String labelText;
  final DateTime date;
  final VoidCallback onTap;
  final bool enabled;

  const PatientFormDateField({
    Key? key,
    required this.labelText,
    required this.date,
    required this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(
            Icons.calendar_today,
            color: enabled ? tokens.primaryAccent : tokens.iconMuted,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: tokens.divider.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: tokens.divider.withValues(alpha: 0.5)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: tokens.border),
          ),
          filled: true,
          fillColor: enabled
              ? tokens.cardBackground.withValues(alpha: 0.8)
              : tokens.disabledBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          labelStyle: TextStyle(
            color: enabled ? colors.onSurfaceVariant : tokens.disabledText,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(date),
          style: TextStyle(
            color: enabled ? colors.onSurface : tokens.disabledText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class ExistingPatientInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const ExistingPatientInfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
