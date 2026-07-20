import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

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
  final bool readOnly;

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
    this.readOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prefixIconData = prefixIcon;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted?.call(),
        style: TextStyle(
          fontSize: 15,
          color: context.colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.tokens.inputBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: context.tokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: context.tokens.primaryAccent.withValues(alpha: 0.5),
                width: 1.2),
          ),
          // 不使用浮动标签，保持占位提示样式一致
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: hintText,
          hintStyle: TextStyle(
            color: context.tokens.textMuted.withValues(alpha: 0.6),
            fontSize: 15,
          ),
          prefixIcon: prefixIconData != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(prefixIconData,
                      color: context.tokens.primaryAccent, size: 20),
                )
              : const SizedBox(width: 12),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          suffixIcon: showClearButton &&
                  (controller.text.isNotEmpty ||
                      (searchQuery?.isNotEmpty ?? false))
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: context.tokens.error, size: 20),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                    tooltip: '清空',
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
