import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/dental_icons.dart';

class HoverablePatientCard extends StatefulWidget {
  final bool isPurpleTheme;
  final VoidCallback onTap;
  final Widget child;

  const HoverablePatientCard({
    Key? key,
    required this.isPurpleTheme,
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
              ? DentalColors.primary.withValues(alpha: 0.1)
              : (widget.isPurpleTheme
                  ? AppTheme.purpleCardBackground
                  : AppTheme.cardBackground),
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: DentalColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                ]
              : widget.isPurpleTheme
                  ? [
                      BoxShadow(
                        color: AppTheme.purpleColor.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : AppTheme.cardShadow,
          border: Border.all(
            color: _isHovered
                ? DentalColors.primary
                : (widget.isPurpleTheme
                    ? AppTheme.purpleLightColor.withValues(alpha: 0.3)
                    : Colors.transparent),
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
