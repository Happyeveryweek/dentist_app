import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 病历模板初始化进度对话框
class MedicalTemplateInitializeProgressDialog extends StatelessWidget {
  const MedicalTemplateInitializeProgressDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 加载动画
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tokens.warningContainer,
                borderRadius: BorderRadius.circular(40),
              ),
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.warning),
              ),
            ),
            const SizedBox(height: 24),

            // 标题
            Text(
              '正在初始化病历模板数据...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: tokens.warning,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 描述
            Text(
              '请稍候，系统正在创建数据库表并初始化预设的疾病类型数据。\n此过程可能需要几秒钟时间。',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
