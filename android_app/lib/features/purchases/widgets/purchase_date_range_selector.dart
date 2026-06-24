import 'package:flutter/material.dart';

import '../services/purchase_date_range_service.dart';

/// 采购统计时间范围选择器组件
class PurchaseDateRangeSelector extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime earliestDate;
  final Function(String) onPresetApplied;
  final VoidCallback onCustomDatePicker;

  const PurchaseDateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.earliestDate,
    required this.onPresetApplied,
    required this.onCustomDatePicker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前时间范围显示
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  PurchaseDateRangeService.formatDateRangeDisplay(
                    startDate,
                    endDate,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCustomDatePicker,
                child: const Text('自定义'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 预设时间范围按钮
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  PurchaseDateRangeService.presets.map((preset) {
                    final isActive = PurchaseDateRangeService.isPresetActive(
                      preset['key'],
                      startDate,
                      endDate,
                      earliestDate,
                    );
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          preset['label'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isActive,
                        onSelected: (_) => onPresetApplied(preset['key']),
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green.shade600,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color:
                              isActive
                                  ? Colors.green.shade600
                                  : Colors.grey.shade700,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
