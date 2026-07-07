import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../providers/settings_provider.dart';

class EditAppNameDialog extends StatelessWidget {
  const EditAppNameDialog({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const EditAppNameDialog(),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final TextEditingController controller =
        TextEditingController(text: settingsProvider.appName);
    final tokens = context.tokens;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: context.tokens.primaryAccent),
          const SizedBox(width: 12),
          const Text('修改应用名称'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '请输入新的应用名称：',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '例如：牙科诊所管理系统',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: context.tokens.primaryAccent, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLength: 50,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.infoContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.info),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: tokens.primaryAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '应用名称将显示在侧边栏顶部',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.primaryAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final newName = controller.text.trim();
            if (newName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('应用名称不能为空'),
                  backgroundColor: tokens.error,
                ),
              );
              return;
            }
            Navigator.of(context).pop(newName);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.tokens.primaryAccent,
            foregroundColor: context.tokens.cardBackground,
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
