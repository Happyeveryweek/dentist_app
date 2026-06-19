import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/dental_icons.dart';

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
          color: enabled ? DentalColors.primary : Colors.grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.error),
        ),
        filled: true,
        fillColor:
            enabled ? Colors.white.withOpacity(0.8) : Colors.grey.withOpacity(0.1),
        contentPadding: maxLines > 1
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: TextStyle(
          color: enabled ? DentalColors.onSurfaceVariant : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: enabled
              ? DentalColors.onSurfaceVariant.withOpacity(0.6)
              : Colors.grey.withOpacity(0.6),
        ),
        alignLabelWithHint: true,
      ),
      style: TextStyle(
        color: enabled ? DentalColors.onSurface : Colors.grey,
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
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(
          icon,
          color: enabled ? DentalColors.primary : Colors.grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.primary, width: 2),
        ),
        filled: true,
        fillColor:
            enabled ? Colors.white.withOpacity(0.8) : Colors.grey.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: TextStyle(
          color: enabled ? DentalColors.onSurfaceVariant : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      items: enabled ? items : null,
      onChanged: enabled ? onChanged : null,
      style: TextStyle(
        color: DentalColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: DentalColors.primary),
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
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(
            Icons.calendar_today,
            color: enabled ? DentalColors.primary : Colors.grey,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          filled: true,
          fillColor:
              enabled ? Colors.white.withOpacity(0.8) : Colors.grey.withOpacity(0.1),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          labelStyle: TextStyle(
            color: enabled ? DentalColors.onSurfaceVariant : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(date),
          style: TextStyle(
            color: enabled ? DentalColors.onSurface : Colors.grey,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
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
