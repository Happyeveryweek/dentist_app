import 'package:flutter/material.dart';

/// 分页控件组件
/// 用于显示分页导航，支持上一页、下一页和页码选择
class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int recordsPerPage;
  final int totalRecords;
  final ValueChanged<int> onPageChanged;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.recordsPerPage,
    required this.totalRecords,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTotalPages = totalPages > 0 ? totalPages : 1;
    final String infoText =
        '每页 $recordsPerPage 条 · 共 $totalRecords 条 / $effectiveTotalPages 页';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
          _PageIconButton(
            icon: Icons.keyboard_arrow_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 8),
          // 页码窗口（最多5个）
          ...List.generate(effectiveTotalPages < 5 ? effectiveTotalPages : 5,
              (i) {
            int pageNum;
            if (effectiveTotalPages <= 5) {
              pageNum = i + 1;
            } else if (currentPage <= 3) {
              pageNum = i + 1;
            } else if (currentPage >= effectiveTotalPages - 2) {
              pageNum = effectiveTotalPages - 4 + i;
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
                        active ? Theme.of(context).primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text('$pageNum',
                      style: TextStyle(
                          color: active ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // 下一页
          _PageIconButton(
            icon: Icons.keyboard_arrow_right,
            enabled: currentPage < effectiveTotalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
          const SizedBox(width: 16),
          // 信息块
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.black54),
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

/// 分页按钮组件
class _PageIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
          color: enabled ? Colors.white : Colors.grey.shade100,
        ),
        child:
            Icon(icon, size: 20, color: enabled ? Colors.black87 : Colors.grey),
      ),
    );
  }
}
