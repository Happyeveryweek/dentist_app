import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../theme/app_theme.dart';

class PatientFilterBar extends StatelessWidget {
  final String searchQuery;
  final String sortField;
  final bool sortAscending;
  final int totalPatients;
  final bool showDateFilter;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onDateFilterToggled;

  const PatientFilterBar({
    Key? key,
    required this.searchQuery,
    required this.sortField,
    required this.sortAscending,
    required this.totalPatients,
    required this.showDateFilter,
    required this.onSortChanged,
    required this.onDateFilterToggled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPurpleTheme ? AppTheme.purpleCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isPurpleTheme
            ? Border.all(
                color: AppTheme.purpleLightColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
        boxShadow: isPurpleTheme
            ? [
                BoxShadow(
                  color: AppTheme.purpleColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SortOptions(
            sortField: sortField,
            sortAscending: sortAscending,
            totalPatients: totalPatients,
            onSortChanged: onSortChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onDateFilterToggled,
                icon:
                    Icon(showDateFilter ? Icons.date_range : Icons.filter_alt),
                label: Text(
                  showDateFilter
                      ? '隐藏时间筛选'
                      : '时间筛选${searchQuery.isNotEmpty ? " (搜索结果)" : ""}',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: isPurpleTheme
                      ? AppTheme.purpleColor
                      : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PatientDateFilterChip extends StatelessWidget {
  final String searchQuery;
  final String dateFilterType;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<String> onFilterTypeChanged;
  final VoidCallback onSelectDateRange;
  final VoidCallback onClearFilters;

  const PatientDateFilterChip({
    Key? key,
    required this.searchQuery,
    required this.dateFilterType,
    required this.startDate,
    required this.endDate,
    required this.onFilterTypeChanged,
    required this.onSelectDateRange,
    required this.onClearFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            searchQuery.isEmpty ? '筛选类型' : '结果筛选',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          _FilterTypeChip(
            label: '首诊时间',
            value: 'first_visit_date',
            activeValue: dateFilterType,
            onChanged: onFilterTypeChanged,
          ),
          const SizedBox(width: 6),
          _FilterTypeChip(
            label: '更新时间',
            value: 'updated_at',
            activeValue: dateFilterType,
            onChanged: onFilterTypeChanged,
          ),
          const Spacer(),
          InkWell(
            onTap: onSelectDateRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.tokens.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    () {
                      final start = startDate;
                      final end = endDate;
                      if (start != null && end != null) {
                        return '${DateFormat('yyyy-MM-dd').format(start)} 至 ${DateFormat('yyyy-MM-dd').format(end)}';
                      }
                      return '选择日期范围';
                    }(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (startDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon:
                  const Icon(Icons.clear, size: 18, color: AppTheme.errorColor),
              onPressed: onClearFilters,
              tooltip: '清除筛选',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortOptions extends StatelessWidget {
  final String sortField;
  final bool sortAscending;
  final int totalPatients;
  final ValueChanged<String> onSortChanged;

  const _SortOptions({
    required this.sortField,
    required this.sortAscending,
    required this.totalPatients,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('排序方式：', style: TextStyle(color: AppTheme.secondaryText)),
        const SizedBox(width: 8),
        _SortButton(
          label: '更新时间',
          field: 'updated_at',
          sortField: sortField,
          sortAscending: sortAscending,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(width: 6),
        _SortButton(
          label: '姓名',
          field: 'name',
          sortField: sortField,
          sortAscending: sortAscending,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(width: 6),
        _SortButton(
          label: '年龄',
          field: 'age',
          sortField: sortField,
          sortAscending: sortAscending,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(width: 6),
        _SortButton(
          label: '病历号',
          field: 'medical_record_number',
          sortField: sortField,
          sortAscending: sortAscending,
          onSortChanged: onSortChanged,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                '总患者数: $totalPatients',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final String field;
  final String sortField;
  final bool sortAscending;
  final ValueChanged<String> onSortChanged;

  const _SortButton({
    required this.label,
    required this.field,
    required this.sortField,
    required this.sortAscending,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = sortField == field;

    return InkWell(
      onTap: () => onSortChanged(field),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color:
                    isActive ? AppTheme.primaryColor : AppTheme.secondaryText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterTypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String activeValue;
  final ValueChanged<String> onChanged;

  const _FilterTypeChip({
    required this.label,
    required this.value,
    required this.activeValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = activeValue == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 'first_visit_date' ? Icons.event_note : Icons.update,
              size: 14,
              color: active ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
