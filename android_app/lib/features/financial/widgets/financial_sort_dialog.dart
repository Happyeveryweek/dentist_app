import 'package:flutter/material.dart';

/// 财务排序对话框内容组件
/// 职责：显示财务记录排序选项对话框内容
class FinancialSortDialogContent extends StatelessWidget {
  final String currentSort;
  final bool isAscending;
  final Function(String) onSortChanged;

  const FinancialSortDialogContent({
    super.key,
    required this.currentSort,
    required this.isAscending,
    required this.onSortChanged,
  });

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
              title: '按更新时间排序',
              icon: Icons.update,
              isSelected: currentSort == 'updated_time',
              isAscending: isAscending,
              onTap: () {
                onSortChanged('updated_time');
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            _buildSortOption(
              title: '按已收金额排序',
              icon: Icons.payment,
              isSelected: currentSort == 'collected_amount',
              isAscending: isAscending,
              onTap: () {
                onSortChanged('collected_amount');
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            _buildSortOption(
              title: '按欠费金额排序',
              icon: Icons.money_off,
              isSelected: currentSort == 'outstanding_amount',
              isAscending: isAscending,
              onTap: () {
                onSortChanged('outstanding_amount');
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
        color: isSelected ? Colors.purple[600] : Colors.grey[600],
      ),
      title: Text(title),
      trailing:
          isSelected
              ? Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.purple[600],
                size: 18,
              )
              : null,
      onTap: onTap,
      selected: isSelected,
      selectedColor: Colors.purple[600],
    );
  }
}
