import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/theme_card.dart';

/// 主题设置区块
///
/// 提供五套 Windows 主题变体选择：
/// 医疗蓝、灰蓝专业、紫粉灰、绿色清新、粉杏柔和。
class ThemeSection extends StatelessWidget {
  const ThemeSection({Key? key}) : super(key: key);

  static const _variants = [
    WindowsThemeVariant.medicalBlue,
    WindowsThemeVariant.slateBlue,
    WindowsThemeVariant.purplePinkGray,
    WindowsThemeVariant.freshGreen,
    WindowsThemeVariant.peachPink,
  ];

  static const _titles = {
    WindowsThemeVariant.medicalBlue: '医疗蓝',
    WindowsThemeVariant.slateBlue: '灰蓝专业',
    WindowsThemeVariant.purplePinkGray: '紫粉灰',
    WindowsThemeVariant.freshGreen: '绿色清新',
    WindowsThemeVariant.peachPink: '粉杏柔和',
  };

  static const _subtitles = {
    WindowsThemeVariant.medicalBlue: '默认推荐',
    WindowsThemeVariant.slateBlue: '长时间办公',
    WindowsThemeVariant.purplePinkGray: '个性化',
    WindowsThemeVariant.freshGreen: '保留当前风格',
    WindowsThemeVariant.peachPink: '前台 / 亲和',
  };

  static const _icons = {
    WindowsThemeVariant.medicalBlue: Icons.medical_services_outlined,
    WindowsThemeVariant.slateBlue: Icons.business_center_outlined,
    WindowsThemeVariant.purplePinkGray: Icons.color_lens_outlined,
    WindowsThemeVariant.freshGreen: Icons.eco_outlined,
    WindowsThemeVariant.peachPink: Icons.spa_outlined,
  };

  static const _swatches = {
    WindowsThemeVariant.medicalBlue: [
      Color(0xFF2E7DB8),
      Color(0xFF5BA8D6),
      Color(0xFFF4F7FA),
    ],
    WindowsThemeVariant.slateBlue: [
      Color(0xFF4F7CAC),
      Color(0xFF6A9A8B),
      Color(0xFFF3F5F7),
    ],
    WindowsThemeVariant.purplePinkGray: [
      Color(0xFF9A78A8),
      Color(0xFFC99AAD),
      Color(0xFFF8F5F9),
    ],
    WindowsThemeVariant.freshGreen: [
      Color(0xFF2F8F72),
      Color(0xFF2E7DB8),
      Color(0xFFF5F8F6),
    ],
    WindowsThemeVariant.peachPink: [
      Color(0xFFC97888),
      Color(0xFF8FA7A0),
      Color(0xFFF9F6F4),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentVariant =
        Provider.of<SettingsProvider>(context).windowsThemeVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: tokens.elevatedShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionHeader(
              title: '外观主题',
              icon: Icons.palette,
              color: tokens.primaryAccent,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _variants.map((variant) {
                return ThemeCard(
                  variant: variant,
                  title: _titles[variant]!,
                  subtitle: _subtitles[variant]!,
                  icon: _icons[variant]!,
                  swatches: _swatches[variant]!,
                  isSelected: variant == currentVariant,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
