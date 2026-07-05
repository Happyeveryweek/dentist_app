import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class PatientPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final int patientsPerPage;
  final int totalPatients;
  final String searchQuery;
  final bool hasDateFilter;
  final ValueChanged<int> onPageChanged;

  const PatientPagination({
    Key? key,
    required this.totalPages,
    required this.currentPage,
    required this.patientsPerPage,
    required this.totalPatients,
    required this.searchQuery,
    required this.hasDateFilter,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final String resultText =
        '每页 $patientsPerPage 条 · 共 $totalPatients 条 / $totalPages 页';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: tokens.elevatedShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PaginationButton(
            icon: Icons.keyboard_arrow_left,
            onPressed:
                currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            isActive: currentPage > 1,
          ),
          const SizedBox(width: 8),
          ...List.generate(totalPages > 5 ? 5 : totalPages, (index) {
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

            final bool isCurrentPage = pageNumber == currentPage;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                elevation: 0,
                child: InkWell(
                  onTap: isCurrentPage ? null : () => onPageChanged(pageNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: isCurrentPage
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                tokens.primaryAccent,
                                tokens.primaryAccent.withValues(alpha: 0.8),
                              ],
                            )
                          : null,
                      color: isCurrentPage ? null : tokens.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrentPage
                          ? null
                          : Border.all(
                              color:
                                  tokens.border,
                              width: 1.5,
                            ),
                      boxShadow: isCurrentPage
                          ? [
                              BoxShadow(
                                color:
                                    tokens.primaryAccent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: tokens.shadow,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Text(
                      '$pageNumber',
                      style: TextStyle(
                        color:
                            isCurrentPage
                                ? tokens.cardBackground
                                : context.colors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          _PaginationButton(
            icon: Icons.keyboard_arrow_right,
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            isActive: currentPage < totalPages,
          ),
          const SizedBox(width: 16),
          _HomePageButton(onPressed: () => onPageChanged(1)),
          Container(
            margin: const EdgeInsets.only(left: 32),
            child: Row(
              children: [
                _PageInfo(resultText: resultText),
                if (totalPages > 5)
                  _PageJumper(
                    totalPages: totalPages,
                    onPageChanged: onPageChanged,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isActive;

  const _PaginationButton({
    required this.icon,
    required this.onPressed,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.tokens.primaryAccent,
                      context.tokens.primaryAccent.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: isActive ? null : context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? context.tokens.primaryAccent.withValues(alpha: 0.3)
                  : context.tokens.border,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: context.tokens.primaryAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: context.tokens.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(
            icon,
            color: isActive
                ? context.tokens.cardBackground
                : context.tokens.primaryAccent.withValues(alpha: 0.7),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _HomePageButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HomePageButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.tokens.primaryAccent.withValues(alpha: 0.8),
            context.tokens.primaryAccent.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.tokens.primaryAccent.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.home,
                color: context.tokens.cardBackground, size: 20),
          ),
        ),
      ),
    );
  }
}

class _PageInfo extends StatelessWidget {
  final String resultText;

  const _PageInfo({required this.resultText});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: context.tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.tokens.shadow.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.tokens.primaryAccent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Icon(
            Icons.info_outline,
            size: 16,
            color: context.tokens.primaryAccent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            resultText,
            style: TextStyle(
              color: context.colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageJumper extends StatelessWidget {
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PageJumper({required this.totalPages, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    final jumpController = TextEditingController();

    void jumpToPage() {
      if (jumpController.text.isEmpty) {
        return;
      }

      try {
        final targetPage = int.parse(jumpController.text);
        if (targetPage > 0 && targetPage <= totalPages) {
          onPageChanged(targetPage);
        } else {
          _showInvalidPageMessage(context, '请输入1到$totalPages之间的页码');
        }
      } catch (e) {
        _showInvalidPageMessage(context, '请输入有效的页码');
      }
    }

    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.border,
          width: 1.5,
        ),
        color: context.tokens.cardBackground,
        boxShadow: context.tokens.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.tokens.inputBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
            child: const Text(
              '转到',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 72,
            height: 42,
            color: context.tokens.inputBackground,
            child: TextField(
              controller: jumpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '页码',
                hintStyle: TextStyle(
                color: context.tokens.textMuted.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              onSubmitted: (_) => jumpToPage(),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: jumpToPage,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.tokens.primaryAccent,
                      context.tokens.primaryAccent.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Text(
                  '确定',
                  style: TextStyle(
                    color: context.tokens.cardBackground,
                    fontSize: 14,
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

  void _showInvalidPageMessage(BuildContext context, String message) {
    final tokens = context.tokens;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: tokens.cardBackground,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: tokens.cardBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: tokens.warningAccent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
