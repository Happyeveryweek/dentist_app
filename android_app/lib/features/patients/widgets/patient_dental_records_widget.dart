import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';
import 'package:dentist_app/widgets/stateful_text_field.dart';

/// 牙齿状况记录管理组件
/// 职责：管理牙齿状况记录的 UI 和逻辑
class PatientDentalRecordsWidget extends StatefulWidget {
  final String? initialDentalCondition;
  final Function(String) onDentalConditionChanged;

  const PatientDentalRecordsWidget({
    Key? key,
    this.initialDentalCondition,
    required this.onDentalConditionChanged,
  }) : super(key: key);

  @override
  _PatientDentalRecordsWidgetState createState() =>
      _PatientDentalRecordsWidgetState();
}

class _PatientDentalRecordsWidgetState extends State<PatientDentalRecordsWidget> {
  // 牙齿状况相关状态
  List<Map<String, dynamic>> _dentalRecords = [];
  int _currentDentalRecordIndex = 0;
  Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _loadDentalCondition(widget.initialDentalCondition);
  }

  @override
  void didUpdateWidget(PatientDentalRecordsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDentalCondition != widget.initialDentalCondition) {
      _loadDentalCondition(widget.initialDentalCondition);
    }
  }

  // 从患者数据中加载牙齿状况数据
  void _loadDentalCondition(String? dentalCondition) {
    print('开始加载牙齿状况数据: $dentalCondition');

    if (dentalCondition == null || dentalCondition.isEmpty) {
      print('牙齿状况数据为空，创建默认记录');
      _dentalRecords = [_createEmptyDentalRecord()];
      return;
    }

    try {
      print('尝试解析牙齿状况数据: $dentalCondition');
      Map<String, dynamic> condition = json.decode(dentalCondition);
      print('原始牙齿状况数据: $condition');

      // 找出所有索引
      Set<int> indices = {};
      condition.keys.forEach((key) {
        if (key.contains('-')) {
          final parts = key.split('-');
          if (parts.length > 1 && parts.last.isNotEmpty) {
            try {
              final index = int.parse(parts.last);
              indices.add(index);
            } catch (e) {
              print('解析索引失败: $key');
            }
          }
        }
      });

      print('找到的索引列表: $indices');
      if (indices.isEmpty) {
        print('未找到有效的索引，创建默认记录');
        _dentalRecords = [_createEmptyDentalRecord()];
        return;
      }

      // 根据索引构建记录，并收集日期信息用于排序
      List<Map<String, dynamic>> tempRecords = [];
      for (int i in indices) {
        Map<String, dynamic> record = {
          'date':
              condition['date-$i'] ??
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
        };

        // 提取每个图表的数据
        for (int chartNum = 1; chartNum <= 3; chartNum++) {
          String chartPrefix = 'chart$chartNum';
          record['$chartPrefix-top-left'] =
              condition['$chartPrefix-top-left-$i'] ?? '';
          record['$chartPrefix-top-right'] =
              condition['$chartPrefix-top-right-$i'] ?? '';
          record['$chartPrefix-bottom-left'] =
              condition['$chartPrefix-bottom-left-$i'] ?? '';
          record['$chartPrefix-bottom-right'] =
              condition['$chartPrefix-bottom-right-$i'] ?? '';

          // 处理备注字段：如果是默认提示文本，转换为空字符串
          String noteValue = condition['$chartPrefix-note-$i'] ?? '';
          String defaultText = '请在此输入图表$chartNum的备注';
          if (noteValue == defaultText) {
            noteValue = '';
          }
          record['$chartPrefix-note'] = noteValue;
        }

        print('构建的记录 $i: $record');
        tempRecords.add(record);
      }

      // 按日期倒序排序（最新的在前）
      tempRecords.sort((a, b) {
        String dateA = a['date'] ?? '';
        String dateB = b['date'] ?? '';
        return dateB.compareTo(dateA);
      });

      _dentalRecords = tempRecords;
      print('最终设置的牙齿记录（已按日期倒序排序）: $_dentalRecords');
    } catch (e) {
      print('解析牙齿状况数据失败: $e');
      _dentalRecords = [_createEmptyDentalRecord()];
    }

    print('记录数量: ${_dentalRecords.length}');
  }

  // 创建一个新的空记录
  Map<String, dynamic> _createEmptyDentalRecord() {
    Map<String, dynamic> record = {
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };

    // 为每个图表创建空字段
    for (int i = 1; i <= 3; i++) {
      String chartPrefix = 'chart$i';
      record['$chartPrefix-top-left'] = '';
      record['$chartPrefix-top-right'] = '';
      record['$chartPrefix-bottom-left'] = '';
      record['$chartPrefix-bottom-right'] = '';
      record['$chartPrefix-note'] = '';
    }

    return record;
  }

  void _addNewDentalRecord() {
    print('添加新的牙齿记录...');
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    setState(() {
      // 在列表开头插入新记录（最新的在前）
      _dentalRecords.insert(0, {
        'date': currentDate,
        'chart1-top-left': '',
        'chart1-top-right': '',
        'chart1-bottom-left': '',
        'chart1-bottom-right': '',
        'chart1-note': '',
        'chart2-top-left': '',
        'chart2-top-right': '',
        'chart2-bottom-left': '',
        'chart2-bottom-right': '',
        'chart2-note': '',
        'chart3-top-left': '',
        'chart3-top-right': '',
        'chart3-bottom-left': '',
        'chart3-bottom-right': '',
        'chart3-note': '',
      });

      // 切换到新添加的记录（索引0）
      _currentDentalRecordIndex = 0;

      print('新记录已添加到列表开头:');
      print('当前记录总数: ${_dentalRecords.length}');
      print('新记录数据:');
      print('  日期: ${_dentalRecords.first['date']}');
      print('  图表1-备注: ${_dentalRecords.first['chart1-note']}');
      print('  图表2-备注: ${_dentalRecords.first['chart2-note']}');
      print('  图表3-备注: ${_dentalRecords.first['chart3-note']}');
    });

    _notifyChange();
  }

  void _removeDentalRecord(int index) {
    setState(() {
      if (_dentalRecords.length > 1) {
        _dentalRecords.removeAt(index);
        if (_currentDentalRecordIndex >= _dentalRecords.length) {
          _currentDentalRecordIndex = _dentalRecords.length - 1;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('至少需要保留一条牙齿状况记录')),
        );
      }
    });

    _notifyChange();
  }

  // 将牙齿状况数据转换为保存格式
  String _dentalConditionToJson() {
    print('开始转换牙齿状况数据为JSON');
    print('当前记录数: ${_dentalRecords.length}');

    final Map<String, dynamic> result = {};

    for (int i = 0; i < _dentalRecords.length; i++) {
      final record = _dentalRecords[i];
      print('处理记录 #$i: $record');

      // 保存日期
      result['date-$i'] = record['date'];

      // 保存图表1数据
      result['chart1-top-left-$i'] = record['chart1-top-left'] ?? '';
      result['chart1-top-right-$i'] = record['chart1-top-right'] ?? '';
      result['chart1-bottom-left-$i'] = record['chart1-bottom-left'] ?? '';
      result['chart1-bottom-right-$i'] = record['chart1-bottom-right'] ?? '';
      result['chart1-note-$i'] = record['chart1-note'] ?? '';

      // 保存图表2数据
      result['chart2-top-left-$i'] = record['chart2-top-left'] ?? '';
      result['chart2-top-right-$i'] = record['chart2-top-right'] ?? '';
      result['chart2-bottom-left-$i'] = record['chart2-bottom-left'] ?? '';
      result['chart2-bottom-right-$i'] = record['chart2-bottom-right'] ?? '';
      result['chart2-note-$i'] = record['chart2-note'] ?? '';

      // 保存图表3数据
      result['chart3-top-left-$i'] = record['chart3-top-left'] ?? '';
      result['chart3-top-right-$i'] = record['chart3-top-right'] ?? '';
      result['chart3-bottom-left-$i'] = record['chart3-bottom-left'] ?? '';
      result['chart3-bottom-right-$i'] = record['chart3-bottom-right'] ?? '';
      result['chart3-note-$i'] = record['chart3-note'] ?? '';
    }

    final jsonString = jsonEncode(result);
    print('转换后的JSON字符串: $jsonString');
    return jsonString;
  }

  void _notifyChange() {
    widget.onDentalConditionChanged(_dentalConditionToJson());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 牙齿状况标题
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 0, 16),
          child: Text(
            '牙齿状况',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // 牙齿记录列表
        if (_dentalRecords.isNotEmpty)
          _buildDentalRecordSimplified(
            _dentalRecords[_currentDentalRecordIndex],
            _currentDentalRecordIndex,
          ),

        // 记录切换导航
        if (_dentalRecords.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentDentalRecordIndex > 0
                      ? () {
                          setState(() {
                            _currentDentalRecordIndex--;
                            print('切换到上一条记录: $_currentDentalRecordIndex');
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  label: const Text('上一条'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_currentDentalRecordIndex + 1}/${_dentalRecords.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _currentDentalRecordIndex < _dentalRecords.length - 1
                      ? () {
                          setState(() {
                            _currentDentalRecordIndex++;
                            print('切换到下一条记录: $_currentDentalRecordIndex');
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  label: const Text('下一条'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Center(
          child: TextButton.icon(
            onPressed: _addNewDentalRecord,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('添加牙齿记录'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 修复牙齿状况记录切换功能 - 将旧的底部导航栏方法替换
  Widget _buildDentalRecordSimplified(Map<String, dynamic> record, int index) {
    print('构建牙齿记录卡片: $index, 数据: $record');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_note,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '就诊日期',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record['date'] ??
                              DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                      ),
                      onPressed: () async {
                        final pickedDate = await showDialog<DateTime>(
                          context: context,
                          builder: (BuildContext context) {
                            return ModernDatePickerDialog(
                              initialDate:
                                  DateTime.tryParse(record['date']) ??
                                  DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                          },
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dentalRecords[index]['date'] = DateFormat(
                              'yyyy-MM-dd',
                            ).format(pickedDate);
                          });
                          _notifyChange();
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '选择日期',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                      ),
                      onPressed: () => _removeDentalRecord(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '删除记录',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 图表内容
          _buildDentalChartSimplified('图表1', record, index),
          _buildDentalChartSimplified('图表2', record, index),
          _buildDentalChartSimplified('图表3', record, index),
        ],
      ),
    );
  }

  // 简化版的牙齿图表 - 减小备注高度
  // 移动端十字图表 - 基于Windows端设计，适配移动端屏幕
  Widget _buildDentalChartSimplified(
    String title,
    Map<String, dynamic> record,
    int recordIndex,
  ) {
    final actualPrefix = "chart${title.substring(2, 3)}"; // 从"图表1"提取为"chart1"

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getChartIcon(title),
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),

          // 十字图表区域 - 适配移动端
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 十字图表
                Container(
                  height: 120, // 适合移动端的高度
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(
                    children: [
                      // 十字线 - 横线
                      Center(
                        child: Container(
                          width: double.infinity,
                          height: 2,
                          color: Colors.blue.shade400,
                        ),
                      ),
                      // 十字线 - 竖线
                      Center(
                        child: Container(
                          width: 2,
                          height: 80,
                          color: Colors.blue.shade400,
                        ),
                      ),

                      // 四个象限的输入框
                      Column(
                        children: [
                          // 上排 - 左上和右上
                          Expanded(
                            child: Row(
                              children: [
                                // 左上象限 (患者右上)
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 6, top: 15),
                                    child: _buildCrossInputField(
                                      record['$actualPrefix-top-left'] ?? '',
                                      (value) {
                                        setState(() {
                                          _dentalRecords[recordIndex]['$actualPrefix-top-left'] = value;
                                        });
                                        _notifyChange();
                                      },
                                      TextAlign.right,
                                      'cross-$recordIndex-$actualPrefix-top-left',
                                    ),
                                  ),
                                ),
                                // 右上象限 (患者左上)
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 6, top: 15),
                                    child: _buildCrossInputField(
                                      record['$actualPrefix-top-right'] ?? '',
                                      (value) {
                                        setState(() {
                                          _dentalRecords[recordIndex]['$actualPrefix-top-right'] = value;
                                        });
                                        _notifyChange();
                                      },
                                      TextAlign.left,
                                      'cross-$recordIndex-$actualPrefix-top-right',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 下排 - 左下和右下
                          Expanded(
                            child: Row(
                              children: [
                                // 左下象限 (患者右下)
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 6, bottom: 15),
                                    child: _buildCrossInputField(
                                      record['$actualPrefix-bottom-left'] ?? '',
                                      (value) {
                                        setState(() {
                                          _dentalRecords[recordIndex]['$actualPrefix-bottom-left'] = value;
                                        });
                                        _notifyChange();
                                      },
                                      TextAlign.right,
                                      'cross-$recordIndex-$actualPrefix-bottom-left',
                                    ),
                                  ),
                                ),
                                // 右下象限 (患者左下)
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 6, bottom: 15),
                                    child: _buildCrossInputField(
                                      record['$actualPrefix-bottom-right'] ?? '',
                                      (value) {
                                        setState(() {
                                          _dentalRecords[recordIndex]['$actualPrefix-bottom-right'] = value;
                                        });
                                        _notifyChange();
                                      },
                                      TextAlign.left,
                                      'cross-$recordIndex-$actualPrefix-bottom-right',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 备注输入框 - 位于十字图下方
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: StatefulTextField(
                    key: ValueKey('note-$recordIndex-$actualPrefix'),
                    initialValue: record['$actualPrefix-note'] ?? '',
                    onChanged: (value) {
                      setState(() {
                        _dentalRecords[recordIndex]['$actualPrefix-note'] = value;
                      });
                      _notifyChange();
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '备注',
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.note, color: Colors.blue.shade300, size: 20),
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
                        borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 根据图表编号返回对应图标
  IconData _getChartIcon(String title) {
    switch (title) {
      case '图表1':
        return Icons.filter_1;
      case '图表2':
        return Icons.filter_2;
      case '图表3':
        return Icons.filter_3;
      default:
        return Icons.sticky_note_2;
    }
  }

  // 构建十字图表输入框 - 使用有状态组件彻底解决删除问题
  Widget _buildCrossInputField(
    String value,
    Function(String) onChanged,
    TextAlign textAlign,
    String keyString,
  ) {
    return SizedBox(
      width: 120, // 增加宽度以容纳更多文字
      child: StatefulTextField(
        key: ValueKey(keyString),
        initialValue: value,
        onChanged: onChanged,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.all(2),
          isDense: true,
          filled: false,
        ),
        maxLines: 1,
      ),
    );
  }
}
