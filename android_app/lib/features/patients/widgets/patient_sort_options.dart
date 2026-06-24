import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

/// 患者排序选项组件
/// 职责：显示排序选项对话框
class PatientSortOptions extends StatelessWidget {
  final String currentSort;
  final bool ascending;
  final Function(String) onSortChange;

  const PatientSortOptions({
    super.key,
    required this.currentSort,
    required this.ascending,
    required this.onSortChange,
  });

  static void show(
    BuildContext context, {
    required String currentSort,
    required bool ascending,
    required Function(String) onSortChange,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return PatientSortOptions(
          currentSort: currentSort,
          ascending: ascending,
          onSortChange: onSortChange,
        );
      },
    );
  }

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
            _buildSortOption(
              title: '按修改时间排序',
              icon: Icons.update,
              isSelected: currentSort == 'updated',
              isAscending: ascending,
              onTap: () {
                onSortChange('updated');
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            _buildSortOption(
              title: '按年龄排序',
              icon: Icons.sort,
              isSelected: currentSort == 'age',
              isAscending: ascending,
              onTap: () {
                onSortChange('age');
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            _buildSortOption(
              title: '按病历号排序',
              icon: Icons.format_list_numbered,
              isSelected: currentSort == 'medical_record',
              isAscending: ascending,
              onTap: () {
                onSortChange('medical_record');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isAscending,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryText,
      ),
      title: Text(title),
      trailing:
          isSelected
              ? Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppTheme.primaryColor,
                size: 18,
              )
              : null,
      onTap: onTap,
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
    );
  }
}
