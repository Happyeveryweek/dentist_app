import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class PatientFilterBar extends StatelessWidget {
  final String sortField;
  final bool sortAscending;
  final int totalPatients;
  final ValueChanged<String> onSortChanged;

  const PatientFilterBar({
    Key? key,
    required this.sortField,
    required this.sortAscending,
    required this.totalPatients,
    required this.onSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _SortOptions(
        sortField: sortField,
        sortAscending: sortAscending,
        totalPatients: totalPatients,
        onSortChanged: onSortChanged,
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
        Text('排序方式：', style: TextStyle(color: context.tokens.textMuted)),
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
            color: context.tokens.primaryAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.tokens.primaryAccent.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: 16, color: context.tokens.primaryAccent),
              const SizedBox(width: 8),
              Text(
                '总患者数: $totalPatients',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.primaryAccent,
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
    final tokens = context.tokens;
    final colors = context.colors;
    final bool isActive = sortField == field;

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: () => onSortChanged(field),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? tokens.primaryAccent.withValues(alpha: 0.1)
              : tokens.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? tokens.primaryAccent : tokens.divider,
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
                    isActive ? tokens.primaryAccent : colors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: tokens.primaryAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
