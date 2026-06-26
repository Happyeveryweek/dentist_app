import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';

class ThemeCard extends StatelessWidget {
  final ExtendedThemeMode mode;
  final String title;
  final IconData icon;
  final bool isSelected;
  final Color? cardColor;
  final Color? textColor;
  final Color? iconColor;

  const ThemeCard({
    Key? key,
    required this.mode,
    required this.title,
    required this.icon,
    required this.isSelected,
    this.cardColor,
    this.textColor,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color defaultCardColor;
    Color defaultTextColor;

    switch (mode) {
      case ExtendedThemeMode.light:
        defaultCardColor = Colors.white;
        defaultTextColor = Colors.black87;
        break;
      case ExtendedThemeMode.grey:
        defaultCardColor = const Color(0xFFEEEEEE);
        defaultTextColor = Colors.black87;
        break;
      case ExtendedThemeMode.purple:
        defaultCardColor = AppTheme.purpleCardBackground;
        defaultTextColor = AppTheme.purplePrimaryText;
        break;
    }

    return GestureDetector(
      onTap: () {
        settingsProvider.setExtendedThemeMode(mode);
      },
      child: Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: cardColor ?? defaultCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: iconColor ??
                  (isDarkMode ? Colors.white : Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor ?? defaultTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
