import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 费用与状态区域
///
/// 显示费用输入框和预约状态下拉框
class CostStatusSection extends StatelessWidget {
  final TextEditingController costController;
  final String status;
  final Function(String) onStatusChanged;

  const CostStatusSection({
    Key? key,
    required this.costController,
    required this.status,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tokens),
          const SizedBox(height: 16),
          _buildFields(context, tokens),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeTokens tokens) {
    return Row(
      children: [
        Icon(
          Icons.attach_money,
          color: tokens.success,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '费用与状态',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.success,
          ),
        ),
      ],
    );
  }

  Widget _buildFields(BuildContext context, AppThemeTokens tokens) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: costController,
            decoration: InputDecoration(
              labelText: '费用估计',
              hintText: '预估费用(可选)',
              prefixText: '¥ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: tokens.cardBackground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: '预约状态',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: tokens.cardBackground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            initialValue: status,
            items: const [
              DropdownMenuItem(value: '已预约', child: Text('已预约')),
              DropdownMenuItem(value: '已完成', child: Text('已完成')),
              DropdownMenuItem(value: '已取消', child: Text('已取消')),
              DropdownMenuItem(value: '未到诊', child: Text('未到诊')),
            ],
            onChanged: (value) {
              if (value != null) {
                onStatusChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }
}
