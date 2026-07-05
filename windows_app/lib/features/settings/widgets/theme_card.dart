import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';

/// 主题卡片组件
///
/// 用于展示一套 Windows 主题变体，点击后切换主题。
/// 卡片只负责选择 [WindowsThemeVariant]，不传递具体颜色到业务页面。
class ThemeCard extends StatelessWidget {
  final WindowsThemeVariant variant;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> swatches;
  final bool isSelected;

  const ThemeCard({
    Key? key,
    required this.variant,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.swatches,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final tokens = context.tokens;

    return GestureDetector(
      onTap: () {
        settingsProvider.setWindowsThemeVariant(variant);
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tokens.primaryAccent : tokens.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? tokens.elevatedShadow : tokens.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? tokens.primaryAccent : tokens.iconMuted,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: tokens.primaryAccent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: swatches
                  .map(
                    (color) => Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: tokens.divider,
                          width: 1,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
