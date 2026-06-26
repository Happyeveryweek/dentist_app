import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/theme_card.dart';

class ThemeSection extends StatelessWidget {
  const ThemeSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(
              title: '主题设置',
              icon: Icons.palette,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ThemeCard(
                  mode: ExtendedThemeMode.light,
                  title: '浅色模式',
                  icon: Icons.brightness_5,
                  isSelected: settingsProvider.extendedThemeMode ==
                      ExtendedThemeMode.light,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
