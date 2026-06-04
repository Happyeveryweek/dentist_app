import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';

class MaterialTypeDropdown extends StatefulWidget {
  final String value;
  final List<String> items;
  final Function(String) onChanged;

  const MaterialTypeDropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<MaterialTypeDropdown> createState() => _MaterialTypeDropdownState();
}

class _MaterialTypeDropdownState extends State<MaterialTypeDropdown> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHover = true),
      onExit: (_) => setState(() => _isHover = false),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (widget.value != '全部' || _isHover) 
                ? DentalColors.primary.withOpacity(0.6) 
                : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: [
            if (_isHover)
              BoxShadow(
                color: DentalColors.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: PopupMenuButton<String>(
          initialValue: widget.value,
          onSelected: widget.onChanged,
          constraints: const BoxConstraints(maxHeight: 320, minWidth: 240),
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
          itemBuilder: (context) => [
            // 标题栏
            PopupMenuItem<String>(
              enabled: false,
              height: 44,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: DentalColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text(
                      '材料类型',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.items.length}项',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 分割线
            const PopupMenuDivider(height: 1),
            // 选项列表
            ...widget.items.map((type) {
              final isSelected = type == widget.value;
              return PopupMenuItem<String>(
                value: type,
                height: 38,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? DentalColors.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected ? DentalColors.primaryGradient : null,
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? DentalColors.primary : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DentalColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '已选',
                            style: TextStyle(
                              fontSize: 10,
                              color: DentalColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: (widget.value != '全部' || _isHover) 
                      ? DentalColors.primary 
                      : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: (widget.value != '全部' || _isHover) 
                        ? DentalColors.primary 
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: (widget.value != '全部' || _isHover) 
                      ? DentalColors.primary 
                      : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
