import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'material_pagination_button.dart';

class MaterialPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int materialsPerPage;
  final int totalMaterials;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final Function(int) onPageSelected;
  final VoidCallback onGoToFirstPage;

  const MaterialPagination({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.materialsPerPage,
    required this.totalMaterials,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSelected,
    required this.onGoToFirstPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
          MaterialPaginationButton(
            icon: Icons.keyboard_arrow_left,
            onPressed: currentPage > 1 ? onPreviousPage : null,
            isActive: currentPage > 1,
          ),

          const SizedBox(width: 8),

          // 页码
          ...List.generate(
            totalPages > 5 ? 5 : totalPages,
            (index) {
              int pageNumber;
              if (totalPages <= 5) {
                pageNumber = index + 1;
              } else {
                if (currentPage <= 3) {
                  pageNumber = index + 1;
                } else if (currentPage >= totalPages - 2) {
                  pageNumber = totalPages - 4 + index;
                } else {
                  pageNumber = currentPage - 2 + index;
                }
              }

              return MaterialPaginationButton(
                icon: null,
                pageNumber: pageNumber,
                onPressed: () => onPageSelected(pageNumber),
                isActive: currentPage == pageNumber,
              );
            },
          ),

          const SizedBox(width: 8),

          // 右箭头
          MaterialPaginationButton(
            icon: Icons.keyboard_arrow_right,
            onPressed: currentPage < totalPages ? onNextPage : null,
            isActive: currentPage < totalPages,
          ),

          const SizedBox(width: 16),

          // 首页按钮
          MaterialPaginationButton(
            icon: Icons.home,
            onPressed: currentPage != 1 ? onGoToFirstPage : null,
            isActive: currentPage != 1,
          ),

          const SizedBox(width: 16),

          // 分页信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.tokens.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.tokens.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '每页 $materialsPerPage 条 · 共 $totalMaterials 条 / $totalPages 页',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.tokens.iconMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
