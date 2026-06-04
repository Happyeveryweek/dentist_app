import 'package:flutter/material.dart';

/// 病历模板初始化进度对话框
class MedicalTemplateInitializeProgressDialog extends StatelessWidget {
  const MedicalTemplateInitializeProgressDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(40),
              ),
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
              ),
            ),
            const SizedBox(height: 24),
            
            // 标题
            Text(
              '正在初始化病历模板数据...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // 描述
            Text(
              '请稍候，系统正在创建数据库表并初始化预设的疾病类型数据。\n此过程可能需要几秒钟时间。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
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
