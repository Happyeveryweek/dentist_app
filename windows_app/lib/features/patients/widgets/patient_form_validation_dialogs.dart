import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/patient.dart';

class DuplicateMedicalRecordDialog extends StatelessWidget {
  const DuplicateMedicalRecordDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      title: const Text(
        '重复的病历号',
        style: TextStyle(fontSize: 16),
      ),
      content: const Text('此病历号已被使用，请重新输入'),
      backgroundColor: tokens.cardBackground.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.error, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '确定',
            style: TextStyle(color: tokens.error),
          ),
        ),
      ],
    );
  }
}

class ExistingPatientChoiceDialog extends StatelessWidget {
  final Patient patient;

  const ExistingPatientChoiceDialog({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      title: const Text(
        '发现同名患者',
        style: TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('系统中已存在同名患者：'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.infoContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.info),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '姓名: ${patient.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('年龄: ${patient.age}岁'),
                Text('性别: ${patient.gender}'),
                Text('电话: ${patient.mainPhone}'),
                Text(
                  '首诊日期: ${DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('请选择：'),
        ],
      ),
      backgroundColor: tokens.cardBackground.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.warning, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            '继续添加新患者',
            style: TextStyle(color: tokens.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.warning,
            foregroundColor: tokens.cardBackground,
          ),
          child: const Text('编辑已存在患者'),
        ),
      ],
    );
  }
}
