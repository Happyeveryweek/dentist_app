import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/features/patients/widgets/patient_info_row.dart';
import '../../../utils/app_logger.dart';

List<String> parsePatientPhoneNumbers(String phoneData) {
  final trimmed = phoneData.trim();
  if (trimmed.isEmpty) {
    return ['未设置'];
  }

  try {
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is List) {
        final phones =
            decoded
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList();
        return phones.isEmpty ? ['未设置'] : phones;
      }
    }
  } catch (_) {}

  final phones =
      trimmed
          .split(RegExp(r'[,，]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

  if (phones.isNotEmpty) {
    return phones;
  }

  return [trimmed];
}

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
        return const PatientInfoRow(
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
          onPhoneCall:
              phoneNumbers[0] != '未设置'
                  ? () => onPhoneCall?.call(phoneNumbers[0])
                  : null,
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
                        color:
                            i == 0
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : AppTheme.secondaryColor.withValues(
                                  alpha: 0.1,
                                ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        i == 0 ? '主要' : '备用',
                        style: TextStyle(
                          color:
                              i == 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          phoneNumbers[i] == '未设置'
                              ? Text(
                                phoneNumbers[i],
                                style: const TextStyle(
                                  color: AppTheme.textColor,
                                  fontSize: 14,
                                ),
                              )
                              : InkWell(
                                onTap: () => onPhoneCall?.call(phoneNumbers[i]),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    phoneNumbers[i],
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }
    } catch (e) {
      AppLogger.info('构建电话号码部分错误: $e');
      return const PatientInfoRow(
        icon: CupertinoIcons.phone,
        label: '联系电话',
        value: '未设置',
      );
    }
  }
}
