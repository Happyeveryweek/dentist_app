import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dental_icons.dart';

class UnifiedSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool showClearButton;
  final String? searchQuery;

  const UnifiedSearchField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.onClear,
    this.onChanged,
    this.onSubmitted,
    this.showClearButton = true,
    this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted?.call(),
        style: TextStyle(
          fontSize: 15,
          color: DentalColors.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: DentalColors.primary.withOpacity(0.5), width: 1.2),
          ),
          // 不使用浮动标签，保持占位提示样式一致
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: hintText,
          hintStyle: TextStyle(
            color: DentalColors.onSurfaceVariant.withOpacity(0.6),
            fontSize: 15,
          ),
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(prefixIcon!, color: DentalColors.primary, size: 20),
                )
              : const SizedBox(width: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          suffixIcon: showClearButton && (controller.text.isNotEmpty || (searchQuery?.isNotEmpty ?? false))
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    icon: Icon(Icons.clear_rounded, color: DentalColors.error, size: 20),
                    onPressed: () { controller.clear(); onClear?.call(); },
                    tooltip: '清空',
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
