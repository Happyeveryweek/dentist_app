import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

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
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
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
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
