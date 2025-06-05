import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../providers/database_provider.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class PatientExportDialog extends StatefulWidget {
  final String? searchQuery;
  final String? sortField;
  final bool sortAscending;
  final DateTime? startDate;
  final DateTime? endDate;
  final String dateFilterType;

  const PatientExportDialog({
    Key? key,
    this.searchQuery,
    this.sortField,
    this.sortAscending = false,
    this.startDate,
    this.endDate,
    this.dateFilterType = 'first_visit_date',
  }) : super(key: key);

  @override
  State<PatientExportDialog> createState() => _PatientExportDialogState();
}

class _PatientExportDialogState extends State<PatientExportDialog> {
  bool _isExporting = false;
  String _exportPath = '';
  String _statusMessage = '';
  bool _includeAllPatients = true;
  bool _includeInactivePatients = false;
  bool _includeDentalCondition = true;
  bool _exportSuccess = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    final textColor = isPurpleTheme ? AppTheme.purplePrimaryText : null;

    final secondaryTextColor = isPurpleTheme
        ? AppTheme.purpleSecondaryText
        : isDarkMode
            ? Colors.grey[400]
            : Colors.grey[700];

    final accentColor =
        isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor;

    return AlertDialog(
      title: Text('导出患者数据到Excel', style: TextStyle(color: textColor)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择导出选项：', style: TextStyle(color: textColor)),
            const SizedBox(height: 16),

            // 导出选项
            CheckboxListTile(
              title: Text('导出所有患者数据', style: TextStyle(color: textColor)),
              subtitle: Text(
                '勾选后将导出全部患者，不勾选将仅导出当前筛选和搜索结果',
                style: TextStyle(color: secondaryTextColor),
              ),
              value: _includeAllPatients,
              onChanged: _isExporting
                  ? null
                  : (value) {
                      setState(() {
                        _includeAllPatients = value ?? true;
                      });
                    },
              activeColor: accentColor,
            ),

            CheckboxListTile(
              title: Text('包含牙齿状况图表', style: TextStyle(color: textColor)),
              subtitle: Text(
                '勾选后将添加牙齿状况图表为文本格式',
                style: TextStyle(color: secondaryTextColor),
              ),
              value: _includeDentalCondition,
              onChanged: _isExporting
                  ? null
                  : (value) {
                      setState(() {
                        _includeDentalCondition = value ?? true;
                      });
                    },
              activeColor: accentColor,
            ),

            const SizedBox(height: 16),
            Divider(
              color: isPurpleTheme
                  ? AppTheme.purpleDividerColor
                  : isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey[300],
            ),

            // 导出状态显示
            if (_isExporting || _statusMessage.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '导出状态: $_statusMessage',
                    style: TextStyle(
                      color: _hasError ? Colors.red : textColor,
                      fontWeight:
                          _exportSuccess || _hasError ? FontWeight.bold : null,
                    ),
                  ),
                  if (_exportSuccess && _exportPath.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '文件已保存至: $_exportPath',
                        style: TextStyle(color: textColor),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
          ),
          child: const Text('关闭'),
        ),
        if (!_exportSuccess)
          ElevatedButton(
            onPressed: _isExporting ? null : _exportPatientData,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              disabledBackgroundColor: accentColor.withOpacity(0.5),
            ),
            child: _isExporting ? const Text('导出中...') : const Text('开始导出'),
          ),
      ],
    );
  }

  // 导出患者数据到Excel
  Future<void> _exportPatientData() async {
    setState(() {
      _isExporting = true;
      _statusMessage = '准备导出数据...';
      _exportSuccess = false;
      _hasError = false;
      _exportPath = '';
    });

    try {
      // 1. 选择保存位置
      setState(() {
        _statusMessage = '请选择保存位置...';
      });

      // 让用户选择保存位置
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存Excel文件的位置',
      );

      if (selectedDirectory == null) {
        setState(() {
          _isExporting = false;
          _statusMessage = '导出已取消';
        });
        return;
      }

      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 2. 获取要导出的患者数据
      setState(() {
        _statusMessage = '正在获取患者数据...';
      });

      List<Patient> patients;
      if (_includeAllPatients) {
        patients = await dbProvider.getAllPatients();
        print('获取到所有患者数据: ${patients.length}条记录');
      } else {
        // 使用搜索条件获取筛选后的患者数据
        if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          // 有搜索词时使用搜索功能
          patients = await dbProvider.searchPatients(
            widget.searchQuery!,
            sortField: widget.sortField,
            sortAscending: widget.sortAscending,
            startDate: widget.startDate,
            endDate: widget.endDate,
            dateFilterType: widget.dateFilterType,
          );
          print('使用搜索条件获取患者数据: ${patients.length}条记录');
        } else {
          // 无搜索词但有日期或排序筛选
          var result = await dbProvider.getPatientsPage(
            page: 1,
            pageSize: 5000, // 使用大数值以获取所有结果
            sortField: widget.sortField,
            sortAscending: widget.sortAscending,
            startDate: widget.startDate,
            endDate: widget.endDate,
            dateFilterType: widget.dateFilterType,
          );
          patients = result['patients'] as List<Patient>;
          print('使用分页条件获取患者数据: ${patients.length}条记录');
        }
      }

      // 打印第一个患者信息进行调试
      if (patients.isNotEmpty) {
        print('第一个患者信息: ${patients[0].name}, ID: ${patients[0].id}');
      } else {
        print('警告：未获取到任何患者数据');
      }

      // 3. 创建Excel工作簿
      setState(() {
        _statusMessage = '创建Excel文件...';
      });

      final excel = Excel.createExcel();
      final sheet = excel['患者信息'];

      // 添加表头
      _addExcelHeader(sheet);

      // 4. 填充数据
      setState(() {
        _statusMessage = '填充患者数据 (0/${patients.length})...';
      });

      for (var i = 0; i < patients.length; i++) {
        await _addPatientToExcel(sheet, patients[i], i + 2); // 行号从2开始（1是表头）

        // 调试每个患者数据
        print('正在导出患者: ${patients[i].name}, ID: ${patients[i].id}');

        // 更新状态
        if (i % 10 == 0 || i == patients.length - 1) {
          setState(() {
            _statusMessage = '填充患者数据 (${i + 1}/${patients.length})...';
          });
        }
      }

      // 5. 保存Excel文件
      setState(() {
        _statusMessage = '保存Excel文件...';
      });

      // 创建文件名
      final now = DateTime.now();
      final fileName =
          '患者数据导出_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';
      final filePath = '$selectedDirectory${Platform.pathSeparator}$fileName';

      // 保存文件
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        setState(() {
          _isExporting = false;
          _exportSuccess = true;
          _statusMessage = '导出完成！共导出${patients.length}条患者记录';
          _exportPath = filePath;
        });

        print('成功保存文件: $filePath，包含${patients.length}条记录');
      } else {
        throw Exception('无法生成Excel文件');
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _hasError = true;
        _statusMessage = '导出失败: $e';
      });
      print('患者数据导出错误: $e');
    }
  }

  // 添加Excel表头
  void _addExcelHeader(Sheet sheet) {
    final headers = [
      '病历号',
      '姓名',
      '性别',
      '年龄',
      '电话',
      '备用电话',
      '地址',
      '身份证号',
      '主治医生',
      '首诊日期',
      '总费用',
      '治疗项目',
      '牙齿状况',
      '牙齿状况JSON'
    ];

    // 添加标题行
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
    }

    // 设置表头样式
    for (var i = 0; i < headers.length; i++) {
      var cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
  }

  // 将患者数据添加到Excel
  Future<void> _addPatientToExcel(
      Sheet sheet, Patient patient, int rowIndex) async {
    // 设置基本患者信息
    var columnIndex = 0;

    // 病历号 (放到第一列)
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.medical_record_number?.toString() ?? '');

    // 基本信息
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.name);
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.gender);
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = IntCellValue(patient.age);

    // 分开处理主电话和备用电话
    List<String> phones = patient.phoneList;

    // 电话号码 - 完全不添加任何特殊字符
    String mainPhone = phones.isNotEmpty ? phones[0] : "";
    // 移除可能的换行符
    mainPhone = mainPhone.replaceAll('\n', '').replaceAll('\r', '');

    // 使用StringCellValue明确指示为字符串类型
    var mainPhoneCell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: columnIndex++, rowIndex: rowIndex));
    // 确保是TextCellValue类型，而不是其他类型
    mainPhoneCell.value = TextCellValue(mainPhone);
    // 设置居中显示
    mainPhoneCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
    );

    // 备用电话号码 - 同样不添加任何特殊字符
    String backupPhone = phones.length > 1 ? phones[1] : "";
    // 移除可能的换行符
    backupPhone = backupPhone.replaceAll('\n', '').replaceAll('\r', '');

    // 使用StringCellValue明确指示为字符串类型
    var backupCell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: columnIndex++, rowIndex: rowIndex));
    // 确保是TextCellValue类型，而不是其他类型
    backupCell.value = TextCellValue(backupPhone);
    // 设置居中显示
    backupCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
    );

    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.address?.toString() ?? '');
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.identification_number?.toString() ?? '');
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.doctor?.toString() ?? '');

    // 日期格式化
    sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: columnIndex++, rowIndex: rowIndex))
            .value =
        TextCellValue(
            DateFormat('yyyy-MM-dd').format(patient.first_visit_date));

    // 金额格式化
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = DoubleCellValue(patient.total_cost ?? 0.0);

    // 治疗项目
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.treatment_items?.toString() ?? '');

    // 牙齿状况 - 格式化为易读的文本
    if (patient.dental_condition != null &&
        patient.dental_condition!.isNotEmpty &&
        _includeDentalCondition) {
      // 解析牙齿状况JSON并格式化为文本
      String formattedDentalCondition =
          _formatDentalCondition(patient.dentalCharts);

      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: columnIndex++, rowIndex: rowIndex))
          .value = TextCellValue(formattedDentalCondition);
    } else {
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: columnIndex++, rowIndex: rowIndex))
          .value = TextCellValue('无牙齿状况记录');
    }

    // 添加原始牙齿状况JSON数据
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = TextCellValue(patient.dental_condition ?? '');
  }

  // 将牙齿状况的JSON格式化为易读的文本格式
  String _formatDentalCondition(Map<String, dynamic> dentalCharts) {
    if (dentalCharts.isEmpty) {
      return '无牙齿状况记录';
    }

    // 找出有多少行数据
    int rowCount = 0;
    for (String key in dentalCharts.keys) {
      if (key.startsWith('date-')) {
        int index = int.tryParse(key.split('-').last) ?? 0;
        rowCount = rowCount > index ? rowCount : index + 1;
      }
    }

    StringBuffer result = StringBuffer();

    for (int i = 0; i < rowCount; i++) {
      // 添加日期
      String dateValue = dentalCharts['date-$i'] ?? '未知日期';
      result.writeln('日期-$i: $dateValue');

      // 图表1数据
      String topLeft1 =
          _getTranslatedDentalText(dentalCharts['chart1-top-left-$i']);
      String topRight1 =
          _getTranslatedDentalText(dentalCharts['chart1-top-right-$i']);
      String bottomLeft1 =
          _getTranslatedDentalText(dentalCharts['chart1-bottom-left-$i']);
      String bottomRight1 =
          _getTranslatedDentalText(dentalCharts['chart1-bottom-right-$i']);

      result.writeln('左上-$i: $topLeft1');
      result.writeln('右上-$i: $topRight1');
      result.writeln('左下-$i: $bottomLeft1');
      result.writeln('右下-$i: $bottomRight1');

      // 图表2数据
      String topLeft2 =
          _getTranslatedDentalText(dentalCharts['chart2-top-left-$i']);
      String topRight2 =
          _getTranslatedDentalText(dentalCharts['chart2-top-right-$i']);
      String bottomLeft2 =
          _getTranslatedDentalText(dentalCharts['chart2-bottom-left-$i']);
      String bottomRight2 =
          _getTranslatedDentalText(dentalCharts['chart2-bottom-right-$i']);

      if (i < rowCount - 1) {
        result.writeln();
      }
    }

    return result.toString();
  }

  // 获取并翻译牙齿状况文本
  String _getTranslatedDentalText(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '无';
    }
    return _translateDentalCondition(value.toString());
  }

  // 将牙齿状况英文术语转换为中文
  String _translateDentalCondition(String dentalCondition) {
    // 牙齿治疗编号对应的中文名称
    Map<String, String> treatmentTranslations = {
      '1': '引导式组织再生术',
      '2': '牙体缺损',
      '3': '牙体缺失',
      '4': '牙龈炎',
      '5': '牙周炎',
      '6': '根尖周炎',
      '7': '乳牙',
      '8': '拔除',
      '9': '种植体',
      '10': '固定义齿',
      '11': '可摘局部义齿',
      '12': '治疗',
      '13': '根管治疗',
      '14': '充填治疗',
      '15': '拆除',
      '16': '软组织手术',
      '17': '牙周手术',
      '18': '全口义齿',
      '19': '磨牙',
      '20': '缺失',
    };

    // 特殊情况处理
    if (dentalCondition.contains('-')) {
      List<String> parts = dentalCondition.split('-');
      List<String> translatedParts = [];

      for (String part in parts) {
        String trimmedPart = part.trim();
        if (treatmentTranslations.containsKey(trimmedPart)) {
          translatedParts.add(treatmentTranslations[trimmedPart]!);
        } else {
          translatedParts.add(trimmedPart);
        }
      }

      return translatedParts.join('-');
    }

    // 直接翻译单个数字
    if (treatmentTranslations.containsKey(dentalCondition.trim())) {
      return treatmentTranslations[dentalCondition.trim()]!;
    }

    return dentalCondition;
  }
}
