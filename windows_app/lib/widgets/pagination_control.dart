import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 通用分页控件
///
/// 与具体业务领域无关，接收 currentPage / pageSize / totalRecords，
/// 并通过 [onPageChanged] 回调将页码变更交给调用方处理。
class PaginationControl extends StatelessWidget {
  const PaginationControl({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalRecords,
    required this.onPageChanged,
  });

  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final ValueChanged<int> onPageChanged;

  int get totalPages => totalRecords > 0 ? (totalRecords / pageSize).ceil() : 1;

  void _goToPage(int page) {
    final target = page.clamp(1, totalPages);
    if (target != currentPage) {
      onPageChanged(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectivePage = currentPage.clamp(1, totalPages);

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
          _PaginationIconButton(
            icon: Icons.keyboard_arrow_left,
            onPressed:
                effectivePage > 1 ? () => _goToPage(effectivePage - 1) : null,
          ),
          const SizedBox(width: 8),
          ...List.generate(
            totalPages > 5 ? 5 : totalPages,
            (index) {
              int pageNumber;
              if (totalPages <= 5) {
                pageNumber = index + 1;
              } else if (effectivePage <= 3) {
                pageNumber = index + 1;
              } else if (effectivePage >= totalPages - 2) {
                pageNumber = totalPages - 4 + index;
              } else {
                pageNumber = effectivePage - 2 + index;
              }
              return _PaginationNumberButton(
                pageNumber: pageNumber,
                isActive: effectivePage == pageNumber,
                onPressed: () => _goToPage(pageNumber),
              );
            },
          ),
          const SizedBox(width: 8),
          _PaginationIconButton(
            icon: Icons.keyboard_arrow_right,
            onPressed: effectivePage < totalPages
                ? () => _goToPage(effectivePage + 1)
                : null,
          ),
          const SizedBox(width: 16),
          _PaginationIconButton(
            icon: Icons.home,
            onPressed:
                effectivePage != 1 ? () => _goToPage(1) : null,
          ),
          const SizedBox(width: 16),
          _PageInfo(
            pageSize: pageSize,
            totalRecords: totalRecords,
            totalPages: totalPages,
          ),
          const SizedBox(width: 16),
          _PageJumper(
            totalPages: totalPages,
            onPageChanged: onPageChanged,
          ),
        ],
      ),
    );
  }
}

class _PaginationIconButton extends StatelessWidget {
  const _PaginationIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onPressed != null;

    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      splashRadius: 20,
      color: enabled ? tokens.primaryAccent : tokens.disabledText,
      disabledColor: tokens.disabledText,
    );
  }
}

class _PaginationNumberButton extends StatelessWidget {
  const _PaginationNumberButton({
    required this.pageNumber,
    required this.isActive,
    required this.onPressed,
  });

  final int pageNumber;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? tokens.primaryAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? tokens.primaryAccent : tokens.border,
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

class _PageInfo extends StatelessWidget {
  const _PageInfo({
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
  });

  final int pageSize;
  final int totalRecords;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
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
          Icon(
            Icons.info_outline,
            size: 16,
            color: tokens.primaryAccent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            '每页 $pageSize 条 · 共 $totalRecords 条 / $totalPages 页',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageJumper extends StatefulWidget {
  const _PageJumper({
    required this.totalPages,
    required this.onPageChanged,
  });

  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  State<_PageJumper> createState() => _PageJumperState();
}

class _PageJumperState extends State<_PageJumper> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jump() {
    final text = _controller.text.trim();
    final page = int.tryParse(text);
    if (page == null) return;

    final target = page.clamp(1, widget.totalPages);
    if (target.toString() != text) {
      _controller.text = '$target';
    }
    widget.onPageChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: tokens.selectedBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.focusRing),
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
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '页码',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) => _jump(),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              onTap: _jump,
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
                child: Text(
                  '确定',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
