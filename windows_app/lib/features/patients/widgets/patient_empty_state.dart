import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PatientEmptyState extends StatelessWidget {
  final bool hasSearchQuery;
  final VoidCallback onAddPatient;

  const PatientEmptyState({
    Key? key,
    required this.hasSearchQuery,
    required this.onAddPatient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 64,
            color: AppTheme.lightText,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearchQuery ? '未找到匹配的搜索结果' : '暂无患者记录',
            style: const TextStyle(
              fontSize: 18,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onAddPatient,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                '添加患者',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
