import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../utils/app_logger.dart';

/// 电话号码管理组件
/// 职责：管理电话号码的输入和管理
class PatientPhoneWidget extends StatefulWidget {
  final String? initialPhone;
  final Function(String) onPhoneChanged;

  const PatientPhoneWidget({
    Key? key,
    this.initialPhone,
    required this.onPhoneChanged,
  }) : super(key: key);

  @override
  PatientPhoneWidgetState createState() => PatientPhoneWidgetState();
}

class PatientPhoneWidgetState extends State<PatientPhoneWidget> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _additionalPhoneControllers = [];

  @override
  void initState() {
    super.initState();
    _processPhoneNumbers(widget.initialPhone ?? '');
  }

  @override
  void didUpdateWidget(PatientPhoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPhone != widget.initialPhone) {
      _processPhoneNumbers(widget.initialPhone ?? '');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _additionalPhoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // 专门处理电话号码的辅助方法
  void _processPhoneNumbers(String phoneStr) {
    AppLogger.info('处理电话号码: $phoneStr');
    AppLogger.info('电话号码类型: ${phoneStr.runtimeType}');
    AppLogger.info('电话号码长度: ${phoneStr.length}');

    // 原始格式判断
    if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
      AppLogger.info('电话号码原始格式: JSON数组格式');
    } else if (phoneStr.contains(',')) {
      AppLogger.info('电话号码原始格式: 逗号分隔格式');
    } else {
      AppLogger.info('电话号码原始格式: 单个电话号码');
    }

    if (phoneStr.isEmpty) {
      _phoneController.text = '';
      return;
    }

    // 特殊情况处理：删除JSON字符串中可能存在的转义字符
    String cleanPhoneStr = phoneStr;
    if (phoneStr.contains('\\')) {
      cleanPhoneStr = phoneStr.replaceAll('\\', '');
      AppLogger.info('移除转义字符后: $cleanPhoneStr');
    }

    // 尝试直接解析多个电话号码
    List<String> phoneNumbers = [];

    // 检查是否为JSON格式
    if (cleanPhoneStr.startsWith('[') && cleanPhoneStr.endsWith(']')) {
      AppLogger.info('检测到JSON格式电话号码: $cleanPhoneStr');

      try {
        // 尝试标准JSON解析
        final parsed = jsonDecode(cleanPhoneStr);
        AppLogger.info('JSON解析结果类型: ${parsed.runtimeType}');

        if (parsed is List) {
          AppLogger.info('成功解析为JSON数组: $parsed');
          if (parsed.isNotEmpty) {
            phoneNumbers = parsed.map((p) => p.toString()).toList();
            AppLogger.info('从JSON提取的电话号码列表: $phoneNumbers');
          }
        } else if (parsed is String) {
          // 处理嵌套JSON字符串的情况
          AppLogger.info('JSON解析结果是字符串，尝试再次解析');
          try {
            final nestedParsed = jsonDecode(parsed);
            if (nestedParsed is List) {
              phoneNumbers = nestedParsed.map((p) => p.toString()).toList();
              AppLogger.info('从嵌套JSON提取的电话号码列表: $phoneNumbers');
            } else {
              // 单个电话号码
              phoneNumbers = [parsed];
            }
          } catch (e) {
            AppLogger.info('嵌套JSON解析失败: $e，当作单个电话号码处理');
            phoneNumbers = [parsed];
          }
        }
      } catch (e) {
        AppLogger.info('标准JSON解析失败: $e，类型: ${e.runtimeType}');

        // 使用正则表达式提取电话号码
        final RegExp regex = RegExp(r'"([^"]*)"');
        final matches = regex.allMatches(cleanPhoneStr);

        if (matches.isNotEmpty) {
          for (final match in matches) {
            final phone = match.group(1);
            if (phone != null && phone.isNotEmpty) {
              phoneNumbers.add(phone);
            }
          }
          AppLogger.info('通过正则表达式提取的电话: $phoneNumbers');
        }

        // 如果正则表达式没有匹配到，尝试直接分割字符串
        if (phoneNumbers.isEmpty) {
          // 去除方括号
          String content = cleanPhoneStr.substring(1, cleanPhoneStr.length - 1);
          // 分割字符串
          List<String> parts = content.split(',');
          for (var part in parts) {
            String clean = part.trim();
            // 去除可能的引号
            if (clean.startsWith('"') && clean.endsWith('"')) {
              clean = clean.substring(1, clean.length - 1);
            }
            if (clean.isNotEmpty) {
              phoneNumbers.add(clean);
            }
          }
          AppLogger.info('通过分割字符串提取的电话: $phoneNumbers');
        }
      }
    } else if (cleanPhoneStr.contains(',')) {
      // 处理逗号分隔的电话号码
      AppLogger.info('处理逗号分隔的电话号码: $cleanPhoneStr');
      phoneNumbers =
          cleanPhoneStr
              .split(',')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
      AppLogger.info('通过逗号分割提取的电话: $phoneNumbers');
    } else {
      // 单个电话号码
      phoneNumbers = [cleanPhoneStr];
      AppLogger.info('单个电话号码: $cleanPhoneStr');
    }

    // 设置电话号码到输入框
    if (phoneNumbers.isNotEmpty) {
      _phoneController.text = phoneNumbers[0];
      AppLogger.info('设置主电话: ${phoneNumbers[0]}');

      // 清理之前的额外电话控制器
      if (_additionalPhoneControllers.isNotEmpty) {
        AppLogger.info('清理之前的额外电话控制器: ${_additionalPhoneControllers.length}个');
        for (var controller in _additionalPhoneControllers) {
          controller.dispose();
        }
        _additionalPhoneControllers.clear();
      }

      // 添加额外电话
      for (int i = 1; i < phoneNumbers.length; i++) {
        AppLogger.info('添加备用电话 $i: ${phoneNumbers[i]}');
        _additionalPhoneControllers.add(
          TextEditingController(text: phoneNumbers[i]),
        );
      }

      AppLogger.info(
        '设置了${phoneNumbers.length}个电话号码，主电话:${_phoneController.text}，额外电话:${_additionalPhoneControllers.length}个',
      );
    } else {
      // 无法解析，使用原始字符串
      _phoneController.text = phoneStr;
      AppLogger.info('无法解析电话号码，使用原始字符串: $phoneStr');
    }
  }

  // 添加额外电话号码字段
  void _addAdditionalPhone() {
    setState(() {
      _additionalPhoneControllers.add(TextEditingController());
    });
    _notifyChange();
  }

  // 移除额外电话号码字段
  void _removeAdditionalPhone(int index) {
    setState(() {
      _additionalPhoneControllers[index].dispose();
      _additionalPhoneControllers.removeAt(index);
    });
    _notifyChange();
  }

  void _notifyChange() {
    List<String> allPhones = [_phoneController.text];
    for (var controller in _additionalPhoneControllers) {
      if (controller.text.trim().isNotEmpty) {
        allPhones.add(controller.text.trim());
      }
    }
    widget.onPhoneChanged(jsonEncode(allPhones));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoField(
                icon: Icons.phone,
                iconColor: Colors.green,
                label: '主要电话',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
            ),
            // 添加按钮
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: IconButton(
                onPressed: _addAdditionalPhone,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                tooltip: '添加备用电话',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
        // 额外的电话号码输入框
        ..._additionalPhoneControllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoField(
                    icon: Icons.phone_forwarded,
                    iconColor: Colors.blue,
                    label: '备用电话',
                    controller: controller,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                // 删除按钮
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 8.0),
                  child: IconButton(
                    onPressed: () => _removeAdditionalPhone(index),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                    ),
                    tooltip: '删除备用电话',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(
            icon,
            color: iconColor.withValues(alpha: 0.8),
            size: 22,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          _notifyChange();
        },
      ),
    );
  }
}
