import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../utils/app_logger.dart';

/// 患者牙齿状况显示组件
/// 职责：显示患者牙齿状况的十字图表和备注
class PatientDentalConditionDisplay extends StatelessWidget {
  final String dentalConditionJson;

  const PatientDentalConditionDisplay({
    super.key,
    required this.dentalConditionJson,
  });

  @override
  Widget build(BuildContext context) {
    try {
      AppLogger.info('准备解析牙齿数据: $dentalConditionJson');

      Map<String, dynamic> dentalData = Map<String, dynamic>.from(
        jsonDecode(dentalConditionJson),
      );

      // 收集所有记录并按日期排序
      Map<String, Map<String, String>> groupedData = {};
      Set<String> allIndexes = {};

      // 首先获取所有的索引
      for (final key in dentalData.keys) {
        if (key.startsWith('date-')) {
          String index = key.split('-').last;
          allIndexes.add(index);
        } else if (key.contains('-')) {
          List<String> parts = key.split('-');
          if (parts.length >= 2) {
            String dataIndex = parts.last;
            allIndexes.add(dataIndex);
          }
        }
      }

      AppLogger.info('找到的索引列表: $allIndexes');

      // 初始化所有组的数据
      for (String index in allIndexes) {
        groupedData[index] = {'date': ''};
      }

      // 处理所有数据
      for (final entry in dentalData.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key.startsWith('date-')) {
          String index = key.split('-').last;
          final group = groupedData[index];
          if (group != null) {
            group['date'] = value?.toString() ?? '';
          }
        } else if (key.contains('-')) {
          List<String> parts = key.split('-');
          if (parts.length >= 2) {
            String dataIndex = parts.last;
            final group = groupedData[dataIndex];
            if (group == null) continue;

            // 处理带有note的字段
            if (key.contains('note')) {
              String chartPrefix = parts[0]; // 例如 chart1
              group['$chartPrefix-note'] = value?.toString() ?? '';
            }
            // 处理位置字段
            else if (parts.length >= 3) {
              String chartPrefix = parts[0]; // 例如 chart1
              String position = parts[1];
              if (parts.length > 3) {
                position = '${parts[1]}-${parts[2]}'; // 例如 top-left
              }
              group['$chartPrefix-$position'] = value?.toString() ?? '';
            }
          }
        }
      }

      AppLogger.info('分组后的牙齿数据: $groupedData');

      // 过滤出有内容的日期记录，并按日期倒序排序（最新的在前）
      List<Widget> dateRecords = [];

      // 将记录转换为列表并按日期排序
      List<MapEntry<String, Map<String, String>>> sortedEntries =
          groupedData.entries.toList();
      sortedEntries.sort((a, b) {
        String dateA = a.value['date'] ?? '';
        String dateB = b.value['date'] ?? '';
        // 倒序排序，最新日期在前
        return dateB.compareTo(dateA);
      });

      for (var entry in sortedEntries) {
        Map<String, String> data = entry.value;

        // 检查该日期是否有任何图表内容
        bool hasAnyContent = false;
        for (int i = 1; i <= 3; i++) {
          if (_hasChartContent('图表$i', data)) {
            hasAnyContent = true;
            break;
          }
        }

        // 只有当该日期有内容时才添加到显示列表
        if (hasAnyContent) {
          if (dateRecords.isNotEmpty) {
            dateRecords.add(const SizedBox(height: 16)); // 日期记录之间的间距
          }

          dateRecords.add(_buildDateRecordCard(data));
        }
      }

      // 如果没有任何日期有内容，显示提示信息
      if (dateRecords.isEmpty) {
        dateRecords.add(
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  color: Colors.grey.shade400,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无牙齿状况记录',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请在编辑患者信息时添加牙齿状况',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dateRecords,
      );
    } catch (e) {
      AppLogger.info('解析牙齿状况数据错误: $e');
      return Center(child: Text('牙齿状况数据格式错误: $e'));
    }
  }

  // 构建日期记录卡片
  Widget _buildDateRecordCard(Map<String, String> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
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
                      data['date'] ?? '未设置',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 图表内容 - 只显示有内容的图表
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildNonEmptyDentalCharts(data),
            ),
          ),
        ],
      ),
    );
  }

  // 构建非空的牙齿图表列表
  List<Widget> _buildNonEmptyDentalCharts(Map<String, String> data) {
    List<Widget> charts = [];

    // 检查并添加有内容的图表
    for (int i = 1; i <= 3; i++) {
      String title = '图表$i';
      if (_hasChartContent(title, data)) {
        if (charts.isNotEmpty) {
          charts.add(const SizedBox(height: 16)); // 添加间距
        }
        charts.add(_buildDentalChartInfo(title, data));
      }
    }

    // 如果没有任何图表有内容，显示提示信息
    if (charts.isEmpty) {
      charts.add(
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '该日期暂无牙齿状况记录',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return charts;
  }

  // 检查图表是否有内容（包括四个象限和备注）
  bool _hasChartContent(String title, Map<String, String> data) {
    final chartPrefix = "chart${title.substring(2, 3)}"; // 从"图表1"提取为"chart1"

    // 检查四个象限是否有内容
    final topLeft = data['$chartPrefix-top-left'] ?? '';
    final topRight = data['$chartPrefix-top-right'] ?? '';
    final bottomLeft = data['$chartPrefix-bottom-left'] ?? '';
    final bottomRight = data['$chartPrefix-bottom-right'] ?? '';

    // 检查备注是否有有效内容
    String noteValue = data['$chartPrefix-note'] ?? '';
    // 过滤掉默认提示文本
    if (noteValue.startsWith('请在此输入') && noteValue.endsWith('的备注')) {
      noteValue = '';
    }

    // 只要有任何一个字段有内容就显示该图表
    return topLeft.trim().isNotEmpty ||
        topRight.trim().isNotEmpty ||
        bottomLeft.trim().isNotEmpty ||
        bottomRight.trim().isNotEmpty ||
        noteValue.trim().isNotEmpty;
  }

  // 辅助方法：构建单个牙齿图表的信息显示 - 十字图表版本
  Widget _buildDentalChartInfo(String title, Map<String, String> data) {
    final chartPrefix = "chart${title.substring(2, 3)}"; // 从"图表1"提取为"chart1"

    // 检查备注内容是否存在
    String noteValue = data['$chartPrefix-note'] ?? '';
    // 检查备注是否为提示文本，避免显示
    if (noteValue.startsWith('请在此输入') && noteValue.endsWith('的备注')) {
      noteValue = '';
    }

    // 检查四个象限是否有内容
    final topLeft = data['$chartPrefix-top-left'] ?? '';
    final topRight = data['$chartPrefix-top-right'] ?? '';
    final bottomLeft = data['$chartPrefix-bottom-left'] ?? '';
    final bottomRight = data['$chartPrefix-bottom-right'] ?? '';

    final hasChartData =
        topLeft.trim().isNotEmpty ||
        topRight.trim().isNotEmpty ||
        bottomLeft.trim().isNotEmpty ||
        bottomRight.trim().isNotEmpty;

    // 如果只有备注没有图表数据，使用紧凑显示
    if (!hasChartData && noteValue.trim().isNotEmpty) {
      return _buildCompactNoteOnlyChart(title, noteValue);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getChartIcon(title), size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 十字图表显示 - 只读版本
          Container(
            height: 100, // 适合移动端的高度
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                // 十字线 - 横线
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 2,
                    color: Colors.blue.shade300,
                  ),
                ),
                // 十字线 - 竖线
                Center(
                  child: Container(
                    width: 2,
                    height: 60,
                    color: Colors.blue.shade300,
                  ),
                ),

                // 四个象限的文本显示
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
                              padding: const EdgeInsets.only(right: 6, top: 12),
                              child: _buildQuadrantText(
                                data['$chartPrefix-top-left'] ?? '',
                              ),
                            ),
                          ),
                          // 右上象限 (患者左上)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 6, top: 12),
                              child: _buildQuadrantText(
                                data['$chartPrefix-top-right'] ?? '',
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
                              padding: const EdgeInsets.only(
                                right: 6,
                                bottom: 12,
                              ),
                              child: _buildQuadrantText(
                                data['$chartPrefix-bottom-left'] ?? '',
                              ),
                            ),
                          ),
                          // 右下象限 (患者左下)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(
                                left: 6,
                                bottom: 12,
                              ),
                              child: _buildQuadrantText(
                                data['$chartPrefix-bottom-right'] ?? '',
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

          // 备注显示区域 - 位于十字图下方
          if (noteValue.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note_alt,
                        size: 14,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '备注',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(noteValue, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建象限文本，空内容时显示占位符
  Widget _buildQuadrantText(String text) {
    if (text.trim().isEmpty) {
      return Text(
        '·', // 使用小点作为空内容占位符
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade300,
          fontWeight: FontWeight.w300,
        ),
      );
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  // 构建仅有备注的紧凑图表显示
  Widget _buildCompactNoteOnlyChart(String title, String noteValue) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.amber.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getChartIcon(title),
              color: Colors.amber.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  noteValue,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
          Icon(Icons.note_alt, size: 16, color: Colors.amber.shade600),
        ],
      ),
    );
  }

  // 为图表获取相应的图标
  IconData _getChartIcon(String title) {
    switch (title) {
      case '图表1':
        return Icons.healing;
      case '图表2':
        return Icons.health_and_safety;
      case '图表3':
        return Icons.medical_information;
      default:
        return Icons.medical_services;
    }
  }
}
