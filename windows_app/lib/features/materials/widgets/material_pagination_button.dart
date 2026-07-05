import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class MaterialPaginationButton extends StatelessWidget {
  final IconData? icon;
  final int? pageNumber;
  final VoidCallback? onPressed;
  final bool isActive;

  const MaterialPaginationButton({
    Key? key,
    this.icon,
    this.pageNumber,
    required this.onPressed,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? tokens.primaryAccent : tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? tokens.primaryAccent : tokens.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
                  )
                : Text(
                    pageNumber.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
