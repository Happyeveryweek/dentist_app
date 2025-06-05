import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

class DentalChartCard extends StatefulWidget {
  final Map<String, dynamic> chartData;
  final String title;
  final Function(String position, String value) onValueChanged;
  final Function(String note) onNoteChanged;

  const DentalChartCard({
    Key? key,
    required this.chartData,
    required this.title,
    required this.onValueChanged,
    required this.onNoteChanged,
  }) : super(key: key);

  @override
  State<DentalChartCard> createState() => _DentalChartCardState();
}

class _DentalChartCardState extends State<DentalChartCard> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.chartData['note'] ?? '',
    );
    print('${widget.title} 备注初始值: "${_noteController.text}"');
  }

  @override
  void didUpdateWidget(DentalChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartData['note'] != widget.chartData['note']) {
      _noteController.text = widget.chartData['note'] ?? '';
      print('${widget.title} 备注更新值: "${_noteController.text}"');
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('构建 ${widget.title} 图表组件，备注: "${widget.chartData['note'] ?? ''}"');
    print('图表数据: ${widget.chartData}');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDentalChartGrid(),
            const SizedBox(height: 16),
            _buildNoteField(),
          ],
        ),
      ),
    );
  }

  Widget _buildDentalChartGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                '左上',
                widget.chartData['top-left'] ?? '',
                (value) => widget.onValueChanged('top-left', value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                '右上',
                widget.chartData['top-right'] ?? '',
                (value) => widget.onValueChanged('top-right', value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                '左下',
                widget.chartData['bottom-left'] ?? '',
                (value) => widget.onValueChanged('bottom-left', value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                '右下',
                widget.chartData['bottom-right'] ?? '',
                (value) => widget.onValueChanged('bottom-right', value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    print(
      '构建备注字段，当前值: "${_noteController.text}", 类型: ${_noteController.text.runtimeType}',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '备注:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: '请在此输入${widget.title}的备注',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            maxLines: 2,
            onChanged: (value) {
              print('备注已更改为: "$value"');
              widget.onNoteChanged(value);
            },
            onTap: () {
              if (_noteController.text.startsWith('请在此输入') &&
                  _noteController.text.endsWith('的备注')) {
                _noteController.clear();
                widget.onNoteChanged('');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue.isEmpty ? null : currentValue,
              hint: const Text('选择状态'),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: _buildDropdownItems(),
              onChanged: (value) => onChanged(value ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    return [
      const DropdownMenuItem(value: '', child: Text('无')),
      const DropdownMenuItem(value: '蛀牙', child: Text('蛀牙')),
      const DropdownMenuItem(value: '缺失', child: Text('缺失')),
      const DropdownMenuItem(value: '矫正', child: Text('矫正')),
      const DropdownMenuItem(value: '填充', child: Text('填充')),
    ];
  }
}
