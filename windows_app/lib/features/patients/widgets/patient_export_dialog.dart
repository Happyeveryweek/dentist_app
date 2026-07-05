import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../providers/patient_provider.dart';
import '../../../models/patient.dart';
import '../../../utils/log_manager.dart';

class PatientExportDialog extends StatefulWidget {
  final String? searchQuery;
  final Map<String, String>? advancedCriteria;
  final String? sortField;
  final bool sortAscending;
  final DateTime? startDate;
  final DateTime? endDate;
  final String dateFilterType;

  const PatientExportDialog({
    Key? key,
    this.searchQuery,
    this.advancedCriteria,
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
  bool _includeDentalCondition = true;
  bool _exportSuccess = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final textColor = colors.onSurface;
    final secondaryTextColor = tokens.textMuted;
    final accentColor = tokens.primaryAccent;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accentColor.withValues(alpha: 0.9),
                      accentColor.withValues(alpha: 0.7)
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: accentColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Icon(Icons.file_download_outlined,
                      color: context.tokens.cardBackground, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('导出患者数据到Excel',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints()),
              ],
            ),
            const SizedBox(height: 4),
            Divider(color: tokens.shadow.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            Text('选择导出选项',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                  color: context.tokens.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: tokens.shadow.withValues(alpha: 0.06))),
              child: Column(children: [
                SwitchListTile.adaptive(
                  title: const Text('导出所有患者数据'),
                  subtitle: Text('勾选后导出全部患者；不勾选仅导出当前筛选/搜索结果',
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 12)),
                  value: _includeAllPatients,
                  onChanged: _isExporting
                      ? null
                      : (v) => setState(() => _includeAllPatients = v),
                  activeThumbColor: accentColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Divider(height: 1, color: tokens.shadow.withValues(alpha: 0.06)),
                SwitchListTile.adaptive(
                  title: const Text('包含牙齿状况图表'),
                  subtitle: Text('以文本格式附加牙齿状况信息',
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 12)),
                  value: _includeDentalCondition,
                  onChanged: _isExporting
                      ? null
                      : (v) => setState(() => _includeDentalCondition = v),
                  activeThumbColor: accentColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (_isExporting || _statusMessage.isNotEmpty) ...[
              Row(children: [
                Icon(_hasError ? Icons.error_outline : Icons.info_outline,
                    size: 18, color: _hasError ? tokens.error : accentColor),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_statusMessage,
                        style: TextStyle(
                            color: _hasError ? tokens.error : textColor))),
              ]),
              if (_exportSuccess && _exportPath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text('文件已保存至: $_exportPath',
                      style: TextStyle(color: secondaryTextColor)),
                ),
            ],
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭')),
              const SizedBox(width: 8),
              if (!_exportSuccess)
                ElevatedButton(
                  onPressed: _isExporting ? null : _exportPatientData,
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  child: Text(_isExporting ? '导出中...' : '开始导出'),
                ),
            ]),
          ],
        ),
      ),
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

      // 2. 获取要导出的患者数据
      setState(() {
        _statusMessage = '正在获取患者数据...';
      });

      if (!mounted) return;
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final advancedCriteria = widget.advancedCriteria;
      final searchQuery = widget.searchQuery;

      List<Patient> patients;
      if (_includeAllPatients) {
        patients = await patientProvider.getAllPatients();
      } else {
        // 使用高级搜索条件或普通搜索条件获取筛选后的患者数据
        if (advancedCriteria != null && advancedCriteria.isNotEmpty) {
          patients = await patientProvider.searchPatients(
            '',
            sortField: widget.sortField,
            sortAscending: widget.sortAscending,
            startDate: widget.startDate,
            endDate: widget.endDate,
            dateFilterType: widget.dateFilterType,
            advancedCriteria: advancedCriteria,
          );
        } else if (searchQuery != null && searchQuery.isNotEmpty) {
          // 有搜索词时使用搜索功能
          patients = await patientProvider.searchPatients(
            searchQuery,
            sortField: widget.sortField,
            sortAscending: widget.sortAscending,
            startDate: widget.startDate,
            endDate: widget.endDate,
            dateFilterType: widget.dateFilterType,
          );
        } else {
          // 无搜索词但有日期或排序筛选
          var result = await patientProvider.getPatientsPage(
            page: 1,
            pageSize: 5000, // 使用大数值以获取所有结果
            sortField: widget.sortField,
            sortAscending: widget.sortAscending,
            startDate: widget.startDate,
            endDate: widget.endDate,
            dateFilterType: widget.dateFilterType,
          );
          patients = result['patients'] as List<Patient>;
        }
      }

      // 打印第一个患者信息进行调试
      if (patients.isNotEmpty) {
      } else {}

      // 3. 创建Excel工作簿
      setState(() {
        _statusMessage = '创建Excel文件...';
      });

      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['患者信息'];

      // 添加表头
      _addExcelHeader(sheet);

      // 4. 填充数据
      setState(() {
        _statusMessage = '填充患者数据 (0/${patients.length})...';
      });

      for (var i = 0; i < patients.length; i++) {
        await _addPatientToExcel(sheet, patients[i], i + 2); // 行号从2开始（1是表头）

        // 调试每个患者数据

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
      final fileBytes = excelFile.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        setState(() {
          _isExporting = false;
          _exportSuccess = true;
          _statusMessage = '导出完成！共导出${patients.length}条患者记录';
          _exportPath = filePath;
        });
      } else {
        throw Exception('无法生成Excel文件');
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _hasError = true;
        _statusMessage = '导出失败: $e';
      });
      LogManager.e('PatientExportDialog', '患者数据导出错误', error: e);
    }
  }

  // 添加Excel表头
  void _addExcelHeader(excel.Sheet sheet) {
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
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = excel.TextCellValue(headers[i]);
    }

    // 设置表头样式
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
  }

  // 将患者数据添加到Excel
  Future<void> _addPatientToExcel(
      excel.Sheet sheet, Patient patient, int rowIndex) async {
    // 设置基本患者信息
    var columnIndex = 0;

    // 病历号 (放到第一列)
    sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: columnIndex++, rowIndex: rowIndex))
            .value =
        excel.TextCellValue(patient.medicalRecordNumber?.toString() ?? '');

    // 基本信息
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.TextCellValue(patient.name);
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.TextCellValue(patient.gender);
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.IntCellValue(patient.age);

    // 分开处理主电话和备用电话
    List<String> phones = patient.phoneList;

    // 电话号码 - 完全不添加任何特殊字符
    String mainPhone = phones.isNotEmpty ? phones[0] : "";
    // 移除可能的换行符
    mainPhone = mainPhone.replaceAll('\n', '').replaceAll('\r', '');

    // 使用StringCellValue明确指示为字符串类型
    var mainPhoneCell = sheet.cell(excel.CellIndex.indexByColumnRow(
        columnIndex: columnIndex++, rowIndex: rowIndex));
    // 确保是TextCellValue类型，而不是其他类型
    mainPhoneCell.value = excel.TextCellValue(mainPhone);
    // 设置居中显示
    mainPhoneCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
    );

    // 备用电话号码 - 同样不添加任何特殊字符
    String backupPhone = phones.length > 1 ? phones[1] : "";
    // 移除可能的换行符
    backupPhone = backupPhone.replaceAll('\n', '').replaceAll('\r', '');

    // 使用StringCellValue明确指示为字符串类型
    var backupCell = sheet.cell(excel.CellIndex.indexByColumnRow(
        columnIndex: columnIndex++, rowIndex: rowIndex));
    // 确保是TextCellValue类型，而不是其他类型
    backupCell.value = excel.TextCellValue(backupPhone);
    // 设置居中显示
    backupCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
    );

    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.TextCellValue(patient.address?.toString() ?? '');
    sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: columnIndex++, rowIndex: rowIndex))
            .value =
        excel.TextCellValue(patient.identificationNumber?.toString() ?? '');
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.TextCellValue(patient.doctor?.toString() ?? '');

    // 日期格式化
    sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: columnIndex++, rowIndex: rowIndex))
            .value =
        excel.TextCellValue(
            DateFormat('yyyy-MM-dd').format(patient.firstVisitDate));

    // 金额格式化
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.DoubleCellValue(patient.totalCost);

    // 治疗项目
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.TextCellValue(patient.treatmentItems?.toString() ?? '');

    // 牙齿状况 - 格式化为易读的文本
    final dentalCondition = patient.dentalCondition;
    if (dentalCondition != null &&
        dentalCondition.isNotEmpty &&
        _includeDentalCondition) {
      // 解析牙齿状况JSON并格式化为文本
      String formattedDentalCondition =
          _formatDentalCondition(patient.dentalCharts);

      sheet
          .cell(excel.CellIndex.indexByColumnRow(
              columnIndex: columnIndex++, rowIndex: rowIndex))
          .value = excel.TextCellValue(formattedDentalCondition);
    } else {
      sheet
          .cell(excel.CellIndex.indexByColumnRow(
              columnIndex: columnIndex++, rowIndex: rowIndex))
          .value = excel.TextCellValue('无牙齿状况记录');
    }

    // 添加原始牙齿状况JSON数据
    sheet
        .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: columnIndex++, rowIndex: rowIndex))
        .value = excel.TextCellValue(patient.dentalCondition ?? '');
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
        translatedParts.add(
          treatmentTranslations.containsKey(trimmedPart)
              ? (treatmentTranslations[trimmedPart] ?? trimmedPart)
              : trimmedPart,
        );
      }

      return translatedParts.join('-');
    }

    // 直接翻译单个数字
    final trimmedDentalCondition = dentalCondition.trim();
    if (treatmentTranslations.containsKey(trimmedDentalCondition)) {
      return treatmentTranslations[trimmedDentalCondition] ??
          trimmedDentalCondition;
    }

    return dentalCondition;
  }
}
