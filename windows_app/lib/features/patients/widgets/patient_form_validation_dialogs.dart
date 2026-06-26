import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/patient.dart';

class DuplicateMedicalRecordDialog extends StatelessWidget {
  const DuplicateMedicalRecordDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '重复的病历号',
        style: TextStyle(fontSize: 16),
      ),
      content: const Text('此病历号已被使用，请重新输入'),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.red, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '确定',
            style: TextStyle(color: Colors.red),
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
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
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
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.orange, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            '继续添加新患者',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('编辑已存在患者'),
        ),
      ],
    );
  }
}
