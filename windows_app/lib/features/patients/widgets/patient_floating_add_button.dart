import 'package:flutter/material.dart';

import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class PatientFloatingAddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PatientFloatingAddButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.tokens.primaryAccent,
              context.tokens.primaryAccent.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.tokens.primaryAccent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          heroTag: 'patients_add_button',
          elevation: 0,
          child: Icon(Icons.add, size: 28, color: context.colors.onPrimary),
        ),
      ),
    );
  }
}
