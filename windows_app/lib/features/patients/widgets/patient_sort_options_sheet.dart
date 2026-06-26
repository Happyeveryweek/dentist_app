import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PatientSortOptionsSheet extends StatelessWidget {
  final String sortField;
  final bool sortAscending;
  final ValueChanged<String> onSortSelected;

  const PatientSortOptionsSheet({
    Key? key,
    required this.sortField,
    required this.sortAscending,
    required this.onSortSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '排序选项',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            _PatientSortOption(
              title: '按修改日期排序',
              icon: Icons.update,
              isSelected: sortField == 'updated_at',
              isAscending: sortAscending,
              onTap: () => _selectSort(context, 'updated_at'),
            ),
            const Divider(height: 1),
            _PatientSortOption(
              title: '按姓名排序',
              icon: Icons.person,
              isSelected: sortField == 'name',
              isAscending: sortAscending,
              onTap: () => _selectSort(context, 'name'),
            ),
            const Divider(height: 1),
            _PatientSortOption(
              title: '按年龄排序',
              icon: Icons.sort,
              isSelected: sortField == 'age',
              isAscending: sortAscending,
              onTap: () => _selectSort(context, 'age'),
            ),
            const Divider(height: 1),
            _PatientSortOption(
              title: '按首诊日期排序',
              icon: Icons.date_range,
              isSelected: sortField == 'first_visit_date',
              isAscending: sortAscending,
              onTap: () => _selectSort(context, 'first_visit_date'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSort(BuildContext context, String field) {
    onSortSelected(field);
    Navigator.pop(context);
  }
}

class _PatientSortOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isAscending;
  final VoidCallback onTap;

  const _PatientSortOption({
    Key? key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.isAscending,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.secondaryText,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
