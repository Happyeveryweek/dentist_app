import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/dental_icons.dart';

class UserListErrorState extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const UserListErrorState({
    Key? key,
    required this.errorMessage,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DentalGradientButton(
              text: '重试',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
