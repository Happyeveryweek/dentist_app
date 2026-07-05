import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 采购记录的分页组件
/// 用于显示分页控件和分页信息
class PurchasePagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int recordsPerPage;
  final Function(int) onPageChanged;
  final Widget Function(IconData icon,
      {required bool enabled,
      required VoidCallback onTap}) pageIconButtonBuilder;

  const PurchasePagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.recordsPerPage,
    required this.onPageChanged,
    required this.pageIconButtonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final actualTotalPages = totalPages > 0 ? totalPages : 1;
    final String infoText =
        '每页 $recordsPerPage 条 · 共 $totalRecords 条 / $actualTotalPages 页';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        boxShadow: [
          BoxShadow(
              color: tokens.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -2))
        ],
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页
          pageIconButtonBuilder(
            Icons.keyboard_arrow_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 8),
          // 页码窗口（最多5个）
          ...List.generate(actualTotalPages < 5 ? actualTotalPages : 5, (i) {
            int pageNum;
            if (actualTotalPages <= 5) {
              pageNum = i + 1;
            } else if (currentPage <= 3) {
              pageNum = i + 1;
            } else if (currentPage >= actualTotalPages - 2) {
              pageNum = actualTotalPages - 4 + i;
            } else {
              pageNum = currentPage - 2 + i;
            }
            final bool active = pageNum == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: active ? null : () => onPageChanged(pageNum),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        active ? tokens.primaryAccent : tokens.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: tokens.border.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: tokens.shadow,
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text('$pageNum',
                      style: TextStyle(
                          color: active ? tokens.cardBackground : colors.onSurface,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // 下一页
          pageIconButtonBuilder(
            Icons.keyboard_arrow_right,
            enabled: currentPage < actualTotalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
          const SizedBox(width: 16),
          // 信息块
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.border.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: tokens.shadow.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: colors.onSurface.withValues(alpha: 0.54)),
              const SizedBox(width: 6),
              Text(infoText,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}
