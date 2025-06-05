import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currentMode = settingsProvider.extendedThemeMode;

    return PopupMenuButton<ExtendedThemeMode>(
      tooltip: '切换主题',
      icon: Icon(
        _getIconForMode(currentMode),
        color: currentMode == ExtendedThemeMode.purple
            ? AppTheme.purplePrimaryText
            : null,
      ),
      onSelected: (ExtendedThemeMode mode) {
        settingsProvider.setExtendedThemeMode(mode);
      },
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<ExtendedThemeMode>>[
        _buildThemeMenuItem(context, ExtendedThemeMode.light, '浅色模式',
            Icons.brightness_5, currentMode),
        _buildThemeMenuItem(context, ExtendedThemeMode.grey, '灰色模式',
            Icons.brightness_4, currentMode),
        _buildThemeMenuItem(context, ExtendedThemeMode.purple, '紫色模式',
            Icons.color_lens, currentMode,
            iconColor: AppTheme.purpleColor),
      ],
    );
  }

  IconData _getIconForMode(ExtendedThemeMode mode) {
    switch (mode) {
      case ExtendedThemeMode.light:
        return Icons.brightness_5;
      case ExtendedThemeMode.grey:
        return Icons.brightness_4;
      case ExtendedThemeMode.purple:
        return Icons.color_lens;
      default:
        return Icons.brightness_5;
    }
  }

  PopupMenuItem<ExtendedThemeMode> _buildThemeMenuItem(
    BuildContext context,
    ExtendedThemeMode mode,
    String title,
    IconData icon,
    ExtendedThemeMode currentMode, {
    Color? iconColor,
  }) {
    final isSelected = mode == currentMode;
    final selectedColor = mode == ExtendedThemeMode.purple
        ? AppTheme.purpleColor
        : Theme.of(context).colorScheme.primary;

    return PopupMenuItem<ExtendedThemeMode>(
      value: mode,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minLeadingWidth: 24,
        leading: Icon(
          icon,
          color: isSelected
              ? selectedColor
              : iconColor ?? Theme.of(context).iconTheme.color,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? selectedColor : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check,
                color: selectedColor,
                size: 16,
              )
            : null,
      ),
    );
  }
}
