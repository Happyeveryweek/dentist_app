import 'package:flutter/material.dart';

class MaterialUnitDropdown extends StatelessWidget {
  final TextEditingController controller;
  final List<String> options;
  final Function(String) onSelected;

  const MaterialUnitDropdown({
    Key? key,
    required this.controller,
    required this.options,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 输入框部分
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '例如: 个',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // 下拉按钮部分
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Colors.grey[600],
              ),
            ),
            constraints: const BoxConstraints(maxHeight: 240, minWidth: 180),
            offset: const Offset(0, 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            onSelected: onSelected,
            itemBuilder: (context) => [
              // 标题栏
              PopupMenuItem<String>(
                enabled: false,
                height: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        '常用单位',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${options.length}个',
                          style: const TextStyle(
                            fontSize: 10,
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
              ...options.map((unit) {
                final isSelected = controller.text == unit;
                
                return PopupMenuItem<String>(
                  value: unit,
                  height: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Colors.blue.shade300, width: 1) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.blue : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 10, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? Colors.blue.shade700 : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }
}
