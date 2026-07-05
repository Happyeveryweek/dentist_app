import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 财务管理分页控件
class FinancialPagination extends StatelessWidget {
  const FinancialPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.recordsPerPage,
    required this.pageJumpController,
    required this.onGoToPage,
    required this.onGoToPreviousPage,
    required this.onGoToNextPage,
  });

  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int recordsPerPage;
  final TextEditingController pageJumpController;
  final void Function(int page) onGoToPage;
  final VoidCallback onGoToPreviousPage;
  final VoidCallback onGoToNextPage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: tokens.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
          _buildPaginationButton(
            context: context,
            icon: Icons.keyboard_arrow_left,
            onPressed: currentPage > 1 ? onGoToPreviousPage : null,
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
              return _buildPaginationButton(
                context: context,
                pageNumber: pageNumber,
                onPressed: () => onGoToPage(pageNumber),
                isActive: currentPage == pageNumber,
              );
            },
          ),
          const SizedBox(width: 8),
          // 右箭头
          _buildPaginationButton(
            context: context,
            icon: Icons.keyboard_arrow_right,
            onPressed: currentPage < totalPages ? onGoToNextPage : null,
            isActive: currentPage < totalPages,
          ),
          const SizedBox(width: 16),
          // 首页按钮
          _buildPaginationButton(
            context: context,
            icon: Icons.home,
            onPressed: currentPage != 1 ? () => onGoToPage(1) : null,
            isActive: currentPage != 1,
          ),
          const SizedBox(width: 16),
          // 分页信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
              boxShadow: tokens.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Icon(Icons.info_outline,
                    size: 16,
                    color:
                        tokens.primaryAccent.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Text(
                  '每页 $recordsPerPage 条 · 共 $totalRecords 条 / $totalPages 页',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 页面跳转
          Container(
            decoration: BoxDecoration(
              color: tokens.selectedBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: tokens.focusRing),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 36,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: tokens.cardBackground,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    '转到',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  height: 36,
                  width: 72,
                  color: tokens.cardBackground,
                  child: TextField(
                    controller: pageJumpController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '页码',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (value) {
                      final page = int.tryParse(value);
                      if (page != null) onGoToPage(page);
                    },
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    onTap: () {
                      final text = pageJumpController.text.trim();
                      final page = int.tryParse(text);
                      if (page != null) onGoToPage(page);
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        gradient: tokens.primaryHeaderGradient,
                      ),
                      child: Text('确定',
                          style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required BuildContext context,
    IconData? icon,
    int? pageNumber,
    VoidCallback? onPressed,
    required bool isActive,
  }) {
    final tokens = context.tokens;
    final colors = context.colors;

    if (icon != null) {
      return IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
        color: isActive ? tokens.primaryAccent : tokens.disabledText,
        disabledColor: tokens.disabledText,
      );
    } else {
      return Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isActive
                    ? tokens.primaryAccent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? tokens.primaryAccent
                      : tokens.border,
                ),
              ),
              child: Center(
                child: Text(
                  '$pageNumber',
                  style: TextStyle(
                    color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
