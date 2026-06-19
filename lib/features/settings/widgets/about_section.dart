import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/dental_icons.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/setting_item.dart';
import '../widgets/reset_data_item.dart';
import '../../../screens/app_info_screen.dart';

class AboutSection extends StatelessWidget {
  final VoidCallback onEditAppName;
  final VoidCallback onOpenDataStorageLocation;
  final VoidCallback onResetAppData;
  final String Function(SettingsProvider) getDataStorageLocation;

  const AboutSection({
    Key? key,
    required this.onEditAppName,
    required this.onOpenDataStorageLocation,
    required this.onResetAppData,
    required this.getDataStorageLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Column(
      children: [
        SettingsSectionHeader(
          title: '关于',
          icon: Icons.info_outline,
          color: AppTheme.accentColor,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 应用名称配置
                SettingItem(
                  icon: Icons.edit,
                  title: '应用名称',
                  subtitle: settingsProvider.appName,
                  trailing: DentalGradientButton(
                    text: '修改',
                    icon: Icons.edit,
                    onPressed: onEditAppName,
                    isOutlined: true,
                  ),
                ),
                const Divider(height: 20),
                SettingItem(
                  icon: Icons.info_outline,
                  title: '应用版本',
                  subtitle: 'v1.0.0',
                  trailing: DentalGradientButton(
                    text: '详细信息',
                    icon: Icons.info,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AppInfoScreen(),
                        ),
                      );
                    },
                    isOutlined: true,
                  ),
                ),
                const Divider(height: 20),
                SettingItem(
                  icon: Icons.code,
                  title: '开发者',
                  subtitle: 'Dr. Dentist Software 牙医软件团队',
                ),
                const Divider(height: 20),
                SettingItem(
                  icon: Icons.copyright,
                  title: '版权信息',
                  subtitle: '© ${DateTime.now().year} 牙科诊所管理系统 版权所有',
                ),
                const Divider(height: 20),
                SettingItem(
                  icon: Icons.folder_open,
                  title: '数据存储位置',
                  subtitle: getDataStorageLocation(settingsProvider),
                  trailing: DentalGradientButton(
                    text: '打开',
                    icon: Icons.folder_open,
                    onPressed: onOpenDataStorageLocation,
                    isOutlined: true,
                  ),
                ),
                const Divider(height: 20),
                SettingItem(
                  icon: Icons.refresh,
                  title: '重置应用配置',
                  subtitle: '将所有配置恢复到初始状态（不删除数据）',
                  trailing: DentalGradientButton(
                    text: '重置',
                    icon: Icons.refresh,
                    onPressed: onResetAppData,
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
