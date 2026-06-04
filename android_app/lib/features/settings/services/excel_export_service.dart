import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import 'dart:convert';

/// Excel 导出服务
/// 负责导出患者信息到 Excel 文件
class ExcelExportService {

  /// 导出患者信息到Excel文件
  /// 
  /// [filePath] - 导出文件路径
  /// [patients] - 患者数据列表
  /// 
  /// 返回导出文件的完整路径
  static Future<String> exportPatientsToExcel(String filePath, List<Map<String, dynamic>> patients) async {
    try {
      print('开始导出患者数据到Excel');

      if (patients.isEmpty) {
        throw Exception('没有患者数据可导出');
      }

      // 创建Excel文件
      final excel = Excel.createExcel();
      final sheet = excel['患者信息'];

      // 设置表头
      final headers = [
        '姓名',
        '性别',
        '年龄',
        '主电话号',
        '备用电话号',
        '地址',
        '身份证号',
        '病历号',
        '医生',
        '初诊日期',
        '总费用',
        '牙齿状况',
      ];

      // 设置表头样式
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // 填充数据
      for (var i = 0; i < patients.length; i++) {
        final patient = patients[i];
        final rowIndex = i + 1;

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['name'] ?? '');
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['gender'] ?? '');
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = IntCellValue(patient['age'] ?? 0);

        // 处理电话号码 - 分为主电话号和备用电话号两列
        String mainPhone = '';
        String backupPhone = '';

        try {
          final phone = patient['phone'] ?? '';
          if (phone.contains(",")) {
            // 可能是JSON格式，尝试解析
            if (phone.startsWith('[') && phone.endsWith(']')) {
              List<dynamic> phones = jsonDecode(phone);
              if (phones.isNotEmpty) {
                mainPhone = phones[0].toString();
                if (phones.length > 1) {
                  backupPhone = phones[1].toString();
                }
              }
            } else {
              // 可能是逗号分隔的格式
              List<String> phones = phone.split(',');
              if (phones.isNotEmpty) {
                mainPhone = phones[0].trim();
                if (phones.length > 1) {
                  backupPhone = phones[1].trim();
                }
              }
            }
          } else {
            // 单个电话号码
            mainPhone = phone;
          }
        } catch (e) {
          print('解析电话号码失败: $e, 使用原始值');
          mainPhone = patient['phone'] ?? '';
        }

        // 主电话号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(mainPhone);

        // 备用电话号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = TextCellValue(backupPhone);

        // 地址
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['address'] ?? '');

        // 身份证号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['identification_number'] ?? '');

        // 病历号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = patient['medical_record_number'] != null
                ? IntCellValue(patient['medical_record_number'])
                : TextCellValue('');

        // 医生
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['doctor'] ?? '');

        // 初诊日期
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          DateFormat('yyyy-MM-dd').format(DateTimeFormatter.fromDbString(patient['first_visit_date'] ?? DateTimeFormatter.nowDbString())),
        );

        // 总费用
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(patient['total_cost'] ?? 0.0);

        // 牙齿状况
        String dentalData = '';
        if (patient['dental_condition'] != null &&
            patient['dental_condition'].isNotEmpty) {
          try {
            if (patient['dental_condition'].startsWith('{') ||
                patient['dental_condition'].startsWith('[')) {
              // 尝试解析JSON格式
              Map<String, dynamic> dentalJson = jsonDecode(
                patient['dental_condition'],
              );
              dentalData = _convertDentalJsonToText(dentalJson);
            } else {
              // 使用普通格式化
              dentalData = _formatDentalCondition(patient['dental_condition']);
            }
          } catch (e) {
            print('处理牙齿状况失败: $e, 使用原始数据');
            dentalData = patient['dental_condition'];
          }
        }

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex),
            )
            .value = TextCellValue(dentalData);
      }

      // 自动调整列宽
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
      }

      // 保存Excel文件
      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Excel文件已保存到: $filePath');
        return filePath;
      } else {
        throw Exception('Excel编码失败');
      }
    } catch (e) {
      print('导出Excel文件错误: $e');
      throw Exception('导出Excel文件错误: $e');
    }
  }

  /// 将牙齿状况JSON转换为易读文本
  static String _convertDentalJsonToText(Map<String, dynamic> jsonData) {
    StringBuffer buffer = StringBuffer();

    // 处理日期
    if (jsonData.containsKey('date-0')) {
      buffer.writeln('检查日期: ${jsonData['date-0']}');
    }

    // 处理图表1
    buffer.writeln('\n图表1');
    if (jsonData.containsKey('chart1-top-left-0')) {
      buffer.writeln('左上: ${jsonData['chart1-top-left-0']}');
    }
    if (jsonData.containsKey('chart1-top-right-0')) {
      buffer.writeln('右上: ${jsonData['chart1-top-right-0']}');
    }
    if (jsonData.containsKey('chart1-bottom-left-0')) {
      buffer.writeln('左下: ${jsonData['chart1-bottom-left-0']}');
    }
    if (jsonData.containsKey('chart1-bottom-right-0')) {
      buffer.writeln('右下: ${jsonData['chart1-bottom-right-0']}');
    }

    // 处理图表2
    buffer.writeln('\n图表2');
    if (jsonData.containsKey('chart2-top-left-0')) {
      buffer.writeln('左上: ${jsonData['chart2-top-left-0']}');
    }
    if (jsonData.containsKey('chart2-top-right-0')) {
      buffer.writeln('右上: ${jsonData['chart2-top-right-0']}');
    }
    if (jsonData.containsKey('chart2-bottom-left-0')) {
      buffer.writeln('左下: ${jsonData['chart2-bottom-left-0']}');
    }
    if (jsonData.containsKey('chart2-bottom-right-0')) {
      buffer.writeln('右下: ${jsonData['chart2-bottom-right-0']}');
    }

    return buffer.toString();
  }

  /// 格式化牙齿状况信息，使其更易读
  static String _formatDentalCondition(String dentalCondition) {
    if (dentalCondition.isEmpty) return '';

    try {
      // 分行处理
      List<String> lines = dentalCondition.split('\n');
      List<String> formattedLines = [];

      // 日期行处理
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();

        // 提取日期
        if (line.startsWith('日期:')) {
          String date = line.substring(3).trim();
          formattedLines.add('检查日期: $date');
          continue;
        }

        // 处理图表行
        if (line.startsWith('图表')) {
          String chartName = line.substring(0, line.length - 1); // 去掉末尾冒号
          formattedLines.add('\n$chartName');

          // 收集该图表下的所有数据
          List<String> chartData = [];
          int j = i + 1;
          while (j < lines.length &&
              lines[j].trim().isNotEmpty &&
              !lines[j].trim().startsWith('图表')) {
            String dataLine = lines[j].trim();

            // 格式化每个位置的数据
            if (dataLine.startsWith('左上:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('左上: $value');
            } else if (dataLine.startsWith('右上:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('右上: $value');
            } else if (dataLine.startsWith('左下:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('左下: $value');
            } else if (dataLine.startsWith('右下:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('右下: $value');
            } else {
              chartData.add(dataLine);
            }
            j++;
          }

          // 将图表数据添加到格式化行中
          formattedLines.addAll(chartData);
          i = j - 1; // 更新循环索引
        } else if (line.isNotEmpty) {
          // 其他内容直接添加
          formattedLines.add(line);
        }
      }

      // 合并所有行
      return formattedLines.join('\n');
    } catch (e) {
      print('格式化牙齿状况失败: $e');
      return dentalCondition; // 如果格式化失败，返回原始字符串
    }
  }
}
