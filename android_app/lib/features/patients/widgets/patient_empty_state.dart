import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/utils/permission_utils.dart';

/// 患者空状态组件
/// 职责：显示患者列表为空时的状态
class PatientEmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onClearSearch;
  final VoidCallback onAddPatient;

  const PatientEmptyState({
    super.key,
    required this.searchQuery,
    required this.onClearSearch,
    required this.onAddPatient,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.lightText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? '暂无患者数据' : '未找到符合"$searchQuery"的患者',
            style: const TextStyle(fontSize: 16, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          if (searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.clear),
              label: const Text('清除搜索'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            )
          else
            PermissionWrapper(
              module: 'patients',
              action: 'create',
              hideWhenDenied: true,
              child: ElevatedButton.icon(
                onPressed: onAddPatient,
                icon: const Icon(Icons.add),
                label: const Text('添加首位患者'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
