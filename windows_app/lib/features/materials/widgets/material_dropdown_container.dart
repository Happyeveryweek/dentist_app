import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';

class MaterialDropdownContainer extends StatelessWidget {
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final String? hintText;
  final double? width;

  const MaterialDropdownContainer({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = width ??
            (constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 260.0);
        final displayText = value.trim().isEmpty ? (hintText ?? '请选择') : value;
        final displayColor =
            value.trim().isEmpty ? Colors.grey.shade500 : Colors.black87;

        return SizedBox(
          width: resolvedWidth,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: PopupMenuButton<String>(
              initialValue: value,
              onSelected: onChanged,
              constraints: const BoxConstraints(maxHeight: 300, minWidth: 200),
              offset: const Offset(0, 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              itemBuilder: (context) => [
                // 标题栏
                PopupMenuItem<String>(
                  enabled: false,
                  height: 40,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DentalColors.primary.withValues(alpha: 0.1),
                          DentalColors.primary.withValues(alpha: 0.05)
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.list_rounded,
                            size: 16, color: DentalColors.primary),
                        SizedBox(width: 8),
                        Text(
                          '选择选项',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DentalColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 分割线
                const PopupMenuDivider(height: 1),
                // 选项列表
                ...items.map((item) {
                  final isSelected = item == value;
                  return PopupMenuItem<String>(
                    value: item,
                    height: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DentalColors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? DentalColors.primary
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                              color: isSelected
                                  ? DentalColors.primary
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 10, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? DentalColors.primary
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 14,
                          color: displayColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: value.trim().isEmpty
                          ? Colors.grey.shade500
                          : DentalColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
