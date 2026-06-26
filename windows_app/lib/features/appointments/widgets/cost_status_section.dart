import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFields(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(
          Icons.attach_money,
          color: Color(0xFF4CAF50),
          size: 18,
        ),
        SizedBox(width: 8),
        Text(
          '费用与状态',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildFields() {
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
              fillColor: Colors.white,
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
              fillColor: Colors.white,
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
