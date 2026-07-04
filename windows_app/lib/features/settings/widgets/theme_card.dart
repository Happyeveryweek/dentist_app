import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';

/// 主题卡片组件（历史兼容）
///
/// 当前只保留标准主题，此组件仅用于显示当前主题状态。
/// 未来新增主题时，在此处恢复主题选择功能即可。
class ThemeCard extends StatelessWidget {
  final ExtendedThemeMode mode;
  final String title;
  final IconData icon;
  final bool isSelected;

  const ThemeCard({
    Key? key,
    required this.mode,
    required this.title,
    required this.icon,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final tokens = context.tokens;

    return GestureDetector(
      onTap: () {
        settingsProvider.setExtendedThemeMode(mode);
      },
      child: Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tokens.primaryAccent : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected ? tokens.elevatedShadow : tokens.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? tokens.primaryAccent : tokens.iconMuted,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
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
                    color: tokens.primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 10,
                      color: tokens.primaryAccent,
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
