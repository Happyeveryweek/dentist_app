import 'package:flutter/material.dart';

import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../theme/app_theme.dart';

class HoverablePatientCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const HoverablePatientCard({
    Key? key,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  State<HoverablePatientCard> createState() => _HoverablePatientCardState();
}

class _HoverablePatientCardState extends State<HoverablePatientCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? context.tokens.primaryAccent.withValues(alpha: 0.1)
              : context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: context.tokens.primaryAccent.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                ]
              : context.tokens.cardShadow,
          border: Border.all(
            color: _isHovered
                ? context.tokens.primaryAccent
                : Colors.transparent,
            width: _isHovered ? 3 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
