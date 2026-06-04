import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/features/patients/widgets/patient_info_row.dart';

/// 患者电话号码显示组件
/// 职责：显示患者电话号码列表，支持拨号功能
class PatientPhoneDisplay extends StatelessWidget {
  final List<String> phoneNumbers;
  final Function(String)? onPhoneCall;

  const PatientPhoneDisplay({
    super.key,
    required this.phoneNumbers,
    this.onPhoneCall,
  });

  @override
  Widget build(BuildContext context) {
    try {
      if (phoneNumbers.isEmpty) {
        return PatientInfoRow(
          icon: CupertinoIcons.phone,
          label: '联系电话',
          value: '未设置',
        );
      }

      if (phoneNumbers.length == 1) {
        // 单个电话号码时，使用isPhone参数启用拨号功能
        return PatientInfoRow(
          icon: CupertinoIcons.phone,
          label: '联系电话',
          value: phoneNumbers[0],
          isPhone: phoneNumbers[0] != '未设置',
          onPhoneCall: phoneNumbers[0] != '未设置' ? () => onPhoneCall?.call(phoneNumbers[0]) : null,
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  CupertinoIcons.phone,
                  size: 18,
                  color: AppTheme.secondaryTextColor,
                ),
                SizedBox(width: 8),
                Text(
                  '联系电话',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < phoneNumbers.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        i == 0 ? '主要' : '备用',
                        style: TextStyle(
                          color: i == 0
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phoneNumbers[i],
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontSize: 14,
                          decoration: phoneNumbers[i] != '未设置'
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    if (phoneNumbers[i] != '未设置')
                      IconButton(
                        icon: const Icon(
                          Icons.phone,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () => onPhoneCall?.call(phoneNumbers[i]),
                        tooltip: '拨打此号码',
                      ),
                  ],
                ),
              ),
          ],
        );
      }
    } catch (e) {
      print('构建电话号码部分错误: $e');
      return PatientInfoRow(
        icon: CupertinoIcons.phone,
        label: '联系电话',
        value: '未设置',
      );
    }
  }
}
