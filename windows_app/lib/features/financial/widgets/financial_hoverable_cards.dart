import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';

/// 可悬浮的财务列表卡片组件（患者模式）
class HoverableFinancialListCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const HoverableFinancialListCard({
    Key? key,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  State<HoverableFinancialListCard> createState() =>
      _HoverableFinancialListCardState();
}

class _HoverableFinancialListCardState
    extends State<HoverableFinancialListCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? tokens.primaryAccent.withValues(alpha: 0.1)
                : tokens.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 可悬浮的财务记录卡片组件（表格模式）
class HoverableFinancialCard extends StatefulWidget {
  final FinancialRecord record;
  final Patient patient;
  final List<FinancialItem> items;
  final VoidCallback onTap;
  final VoidCallback onViewPatient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const HoverableFinancialCard({
    Key? key,
    required this.record,
    required this.patient,
    required this.items,
    required this.onTap,
    required this.onViewPatient,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  }) : super(key: key);

  @override
  State<HoverableFinancialCard> createState() => _HoverableFinancialCardState();
}

class _HoverableFinancialCardState extends State<HoverableFinancialCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovered
              ? tokens.primaryAccent.withValues(alpha: 0.1)
              : tokens.cardBackground,
          borderRadius: BorderRadius.circular(8),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: tokens.primaryAccent.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: tokens.shadow.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
