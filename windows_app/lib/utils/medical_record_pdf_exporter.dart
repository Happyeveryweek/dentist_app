import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/patient_medical_record.dart';

import 'dental_condition_integration.dart';
import '../utils/log_manager.dart';

/// 病历PDF导出器
/// 负责将患者病历数据导出为标准化的PDF格式
class MedicalRecordPdfExporter {
  static bool _fontInitialized = false;
  static pw.Font? _chineseFont;
  static pw.Font? _chineseBoldFont;

  /// 初始化中文字体 - 必须成功加载，否则抛出异常
  static Future<void> _initializeFonts() async {
    if (_fontInitialized) return;

    try {
      // 加载 Noto Sans SC 中文字体 (TTF格式)
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');

      // 验证字体数据
      if (fontData.lengthInBytes == 0) {
        throw Exception('中文字体文件为空或损坏');
      }

      // 尝试创建字体对象
      _chineseFont = pw.Font.ttf(fontData);
      _chineseBoldFont = pw.Font.ttf(fontData);

      // 验证字体是否正确创建
      if (_chineseFont == null || _chineseBoldFont == null) {
        throw Exception('中文字体创建失败');
      }

      _fontInitialized = true;
    } catch (e) {
      // 字体加载失败，抛出异常而不是降级
      _fontInitialized = false;
      _chineseFont = null;
      _chineseBoldFont = null;
      throw Exception('中文字体加载失败，无法生成PDF: $e');
    }
  }

  /// 获取中文文本样式 - 必须使用中文字体
  static pw.TextStyle _getTextStyle({
    double fontSize = 12,
    bool isBold = false,
    PdfColor? color,
  }) {
    // 确保中文字体已加载
    if (_chineseFont == null || _chineseBoldFont == null) {
      throw Exception('中文字体未正确加载，无法生成PDF');
    }

    return pw.TextStyle(
      font: isBold ? _chineseBoldFont : _chineseFont,
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? PdfColors.black,
    );
  }

  /// 处理文本内容 - 确保中文字体可用
  static String _processText(String text) {
    // 确保中文字体已加载
    if (_chineseFont == null) {
      throw Exception('中文字体未加载，无法处理中文文本');
    }

    // 直接返回原文，因为我们确保有中文字体支持
    return text;
  }

  /// 验证中文字体是否正确加载
  static void _validateChineseFont() {
    if (_chineseFont == null || _chineseBoldFont == null) {
      throw Exception('中文字体未正确加载，无法生成包含中文的PDF');
    }
  }

  /// 生成病历PDF - 必须正确显示中文
  static Future<Uint8List> generatePdf(
    Patient patient,
    PatientMedicalRecord record, {
    String? clinicName,
    String? clinicLogo,
  }) async {
    try {
      // 初始化字体 - 如果失败会抛出异常
      await _initializeFonts();

      // 验证中文字体是否正确加载
      _validateChineseFont();

      final pdf = pw.Document();

      // 构建PDF内容
      final widgets = <pw.Widget>[
        _buildHeader(),
        pw.SizedBox(height: 15),
        _buildCombinedPatientAndMedicalInfo(patient, record),
        pw.SizedBox(height: 15),
        _buildMedicalRecordDetails(patient, record),
        pw.SizedBox(height: 20),
        _buildSignature(
          doctorName: record.doctorName,
        ),
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => widgets,
        ),
      );

      return pdf.save();
    } catch (e) {
      // 重新抛出异常，确保调用方知道PDF生成失败
      throw Exception('PDF生成失败: $e');
    }
  }

  /// 构建PDF头部
  static pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Text(
          _processText('患者就诊病历'),
          style: _getTextStyle(
            fontSize: 24,
            isBold: true,
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// 构建合并的患者信息和病历基本信息
  static pw.Widget _buildCombinedPatientAndMedicalInfo(
      Patient patient, PatientMedicalRecord record) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 标题单独占一行
          pw.Text(
            _processText('患者基本信息'),
            style: _getTextStyle(
              fontSize: 16,
              isBold: true,
            ),
          ),
          pw.SizedBox(height: 12),

          // 患者基本信息 - 参考底部病历日期/医生/创建时间行，直接按整句文本排版
          _buildInlineInfoRow(
            [
              '姓名: ${patient.name}',
              '年龄: ${patient.age}岁',
              '病例编号: ${record.recordNumber}',
            ],
            columnFlexes: const [2, 1, 4],
            leftPaddings: const [0, 0, 28],
          ),
          pw.SizedBox(height: 8),
          _buildInlineInfoRow(
            [
              '病历号: ${patient.medicalRecordNumber?.toString() ?? "无"}',
              '性别: ${patient.gender}',
              '首诊日期: ${DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)}',
            ],
            columnFlexes: const [2, 1, 4],
            leftPaddings: const [0, 0, 28],
          ),
          pw.SizedBox(height: 8),
          _buildInlineInfoRow(
            [
              '电话: ${patient.displayPhone()}',
              '身份证号: ${patient.identificationNumber ?? "无"}',
            ],
            columnFlexes: const [2, 4],
            leftPaddings: const [0, 28],
          ),
          pw.SizedBox(height: 8),
          _buildInlineInfoRow(
            [
              '住址: ${patient.address ?? "无"}',
            ],
            columnFlexes: const [1],
          ),

          // 分隔线
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 12),
            child: pw.Divider(color: PdfColors.grey300),
          ),

          // 病历基本信息
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  _processText(
                      '病历日期: ${DateFormat('yyyy-MM-dd').format(record.recordDate)}'),
                  style: _getTextStyle(),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  _processText('医生: ${record.doctorName}'),
                  style: _getTextStyle(),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  _processText(
                      '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                  style: _getTextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建病历详细内容 - 简化版本，无边框
  static pw.Widget _buildMedicalRecordDetails(
    Patient patient,
    PatientMedicalRecord record,
  ) {
    final List<pw.Widget> contentWidgets = [];

    // 标题
    contentWidgets.add(
      pw.Text(
        '病历详细信息',
        style: _getTextStyle(fontSize: 16, isBold: true),
      ),
    );
    contentWidgets.add(pw.SizedBox(height: 12));

    // 主诉
    if (record.chiefComplaint.isNotEmpty) {
      contentWidgets.add(
          pw.Text('主诉:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(
          pw.Text(record.chiefComplaint, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 现病史
    if (record.presentIllness.isNotEmpty) {
      contentWidgets.add(
          pw.Text('现病史:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(
          pw.Text(record.presentIllness, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 既往史
    if (record.pastMedicalHistory.isNotEmpty) {
      contentWidgets.add(pw.Text('全身疾病既往史:',
          style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(pw.Text(record.pastMedicalHistory,
          style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    if (record.pastDentalHistory.isNotEmpty) {
      contentWidgets.add(pw.Text('口腔疾病既往史:',
          style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(pw.Text(record.pastDentalHistory,
          style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 过敏史
    if (record.allergyHistory.isNotEmpty) {
      contentWidgets.add(
          pw.Text('过敏史:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(
          pw.Text(record.allergyHistory, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 口腔检查
    if (record.oralExamination.isNotEmpty) {
      contentWidgets.add(
          pw.Text('口腔检查:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(
          pw.Text(record.oralExamination, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 关联牙齿状况
    final conditionDate = record.selectedDentalConditionDate;
    if (conditionDate != null && conditionDate.isNotEmpty) {
      contentWidgets.add(_buildMultipleDentalConditionSection(
          patient, conditionDate));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 诊断
    if (record.diagnosis.isNotEmpty) {
      contentWidgets.add(
          pw.Text('诊断:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets
          .add(pw.Text(record.diagnosis, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 治疗方案
    if (record.treatmentPlan.isNotEmpty) {
      contentWidgets.add(
          pw.Text('治疗方案:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 2));
      contentWidgets.add(
          pw.Text(record.treatmentPlan, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    // 注意事项
    if (record.notes.isNotEmpty) {
      contentWidgets.add(
          pw.Text('注意事项:', style: _getTextStyle(fontSize: 13, isBold: true)));
      contentWidgets.add(pw.SizedBox(height: 2));
      contentWidgets
          .add(pw.Text(record.notes, style: _getTextStyle(fontSize: 11)));
      contentWidgets.add(pw.SizedBox(height: 12));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  static pw.Widget _buildInlineInfoRow(
    List<String> texts, {
    required List<int> columnFlexes,
    List<double>? leftPaddings,
  }) {
    final resolvedLeftPaddings =
        leftPaddings ?? List<double>.filled(texts.length, 0);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < texts.length; i++) ...[
          pw.Expanded(
            flex: columnFlexes[i],
            child: pw.Padding(
              padding: pw.EdgeInsets.only(left: resolvedLeftPaddings[i]),
              child: pw.Text(
                _processText(texts[i]),
                style: _getTextStyle(),
              ),
            ),
          ),
          if (i < texts.length - 1) pw.SizedBox(width: 20),
        ],
      ],
    );
  }

  /// 构建签名区域
  static pw.Widget _buildSignature({
    required String doctorName,
  }) {
    return pw.Column(
      children: [
        // 分隔线
        pw.Divider(
          color: PdfColors.grey400,
          thickness: 1,
        ),
        pw.SizedBox(height: 12),

        // 患者签名
        pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            _processText('患者签名: ________________'),
            style: _getTextStyle(fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 12),

        // 医生签名和日期在同一水平线
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              _processText('医生签名: ________________'),
              style: _getTextStyle(fontSize: 11),
            ),
            pw.Text(
              _processText('日期: ________________'),
              style: _getTextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建多个牙齿状况区块
  static pw.Widget _buildMultipleDentalConditionSection(
      Patient patient, String selectedDatesJson) {
    // 解析多选的牙齿状况日期
    List<String> selectedDates = [];
    try {
      // 尝试解析为JSON数组
      final List<dynamic> dates = jsonDecode(selectedDatesJson);
      selectedDates = dates.map((date) => date.toString()).toList();
    } catch (e) {
      // 如果解析失败，可能是旧的单选格式，直接使用
      selectedDates = [selectedDatesJson];
    }

    if (selectedDates.isEmpty) {
      return pw.SizedBox.shrink();
    }

    // 解析患者的牙齿状况数据
    Map<String, dynamic> dentalData = {};
    final condition = patient.dentalCondition;
    if (condition != null && condition.isNotEmpty) {
      try {
        dentalData = DentalConditionIntegration.parseDentalCondition(condition);
      } catch (e) {
        LogManager.e('MedicalRecordPdfExporter', 'PDF导出: 解析牙齿状况数据失败', error: e);
      }
    }

    List<pw.Widget> dentalWidgets = [];

    // 添加标题
    dentalWidgets.add(
      pw.Text(
        '关联牙齿状况:',
        style: _getTextStyle(fontSize: 13, isBold: true),
      ),
    );
    dentalWidgets.add(pw.SizedBox(height: 4));

    // 为每个选中的日期构建牙齿状况
    for (int i = 0; i < selectedDates.length; i++) {
      final selectedDate = selectedDates[i];
      final dentalRecord = DentalConditionIntegration.getDentalConditionByDate(
          dentalData, selectedDate);

      if (dentalRecord.isNotEmpty) {
        // 添加日期标题
        dentalWidgets.add(
          pw.Text(
            '${i + 1}. 关联日期: ${DentalConditionIntegration.formatDateForDisplay(selectedDate)}',
            style: _getTextStyle(fontSize: 11, isBold: true),
          ),
        );
        dentalWidgets.add(pw.SizedBox(height: 6));

        // 添加牙齿状况图表
        dentalWidgets.add(
          pw.Row(
            children: [
              // 第一个牙齿图表
              pw.Expanded(
                child: _buildPdfCrossChart(
                  '图表1',
                  dentalRecord['chart1-top-left'] ?? '',
                  dentalRecord['chart1-top-right'] ?? '',
                  dentalRecord['chart1-bottom-left'] ?? '',
                  dentalRecord['chart1-bottom-right'] ?? '',
                  dentalRecord['chart1-note'] ?? '',
                ),
              ),
              pw.SizedBox(width: 8),
              // 第二个牙齿图表
              pw.Expanded(
                child: _buildPdfCrossChart(
                  '图表2',
                  dentalRecord['chart2-top-left'] ?? '',
                  dentalRecord['chart2-top-right'] ?? '',
                  dentalRecord['chart2-bottom-left'] ?? '',
                  dentalRecord['chart2-bottom-right'] ?? '',
                  dentalRecord['chart2-note'] ?? '',
                ),
              ),
              pw.SizedBox(width: 8),
              // 第三个牙齿图表
              pw.Expanded(
                child: _buildPdfCrossChart(
                  '图表3',
                  dentalRecord['chart3-top-left'] ?? '',
                  dentalRecord['chart3-top-right'] ?? '',
                  dentalRecord['chart3-bottom-left'] ?? '',
                  dentalRecord['chart3-bottom-right'] ?? '',
                  dentalRecord['chart3-note'] ?? '',
                ),
              ),
            ],
          ),
        );

        // 如果不是最后一个，添加间距
        if (i < selectedDates.length - 1) {
          dentalWidgets.add(pw.SizedBox(height: 12));
        }
      } else {
        // 数据不可用的情况
        dentalWidgets.add(
          pw.Text(
            '${i + 1}. 关联日期: $selectedDate（数据不可用）',
            style: _getTextStyle(fontSize: 11),
          ),
        );
        if (i < selectedDates.length - 1) {
          dentalWidgets.add(pw.SizedBox(height: 8));
        }
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: dentalWidgets,
    );
  }

  /// 构建PDF中的十字图表
  static pw.Widget _buildPdfCrossChart(
    String title,
    String topLeft,
    String topRight,
    String bottomLeft,
    String bottomRight,
    String note,
  ) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        // 图表标题
        pw.Container(
          height: 15,
          alignment: pw.Alignment.center,
          child: pw.Text(
            _processText(title),
            style: _getTextStyle(
              fontSize: 9,
              isBold: true,
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // 十字图表 - 固定尺寸确保对齐
        pw.Container(
          height: 50,
          width: double.infinity,
          child: pw.Stack(
            children: [
              // 十字线 - 横线 (居中)
              pw.Positioned(
                top: 24,
                left: 10,
                right: 10,
                child: pw.Container(
                  height: 1,
                  color: PdfColors.grey600,
                ),
              ),
              // 十字线 - 竖线 (居中)
              pw.Positioned(
                left: 0,
                right: 0,
                top: 5,
                bottom: 5,
                child: pw.Center(
                  child: pw.Container(
                    width: 1,
                    height: 40,
                    color: PdfColors.grey600,
                  ),
                ),
              ),

              // 四个象限的文本显示
              pw.Positioned.fill(
                child: pw.Column(
                  children: [
                    // 上排 - 左上和右上
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          // 左上象限
                          pw.Expanded(
                            child: pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding:
                                  const pw.EdgeInsets.only(right: 3, top: 5),
                              child: pw.Text(
                                _processText(topLeft),
                                textAlign: pw.TextAlign.right,
                                style: _getTextStyle(fontSize: 8),
                              ),
                            ),
                          ),
                          // 右上象限
                          pw.Expanded(
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding:
                                  const pw.EdgeInsets.only(left: 3, top: 5),
                              child: pw.Text(
                                _processText(topRight),
                                textAlign: pw.TextAlign.left,
                                style: _getTextStyle(fontSize: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 下排 - 左下和右下
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          // 左下象限
                          pw.Expanded(
                            child: pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding:
                                  const pw.EdgeInsets.only(right: 3, bottom: 5),
                              child: pw.Text(
                                _processText(bottomLeft),
                                textAlign: pw.TextAlign.right,
                                style: _getTextStyle(fontSize: 8),
                              ),
                            ),
                          ),
                          // 右下象限
                          pw.Expanded(
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding:
                                  const pw.EdgeInsets.only(left: 3, bottom: 5),
                              child: pw.Text(
                                _processText(bottomRight),
                                textAlign: pw.TextAlign.left,
                                style: _getTextStyle(fontSize: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 备注显示区域 - 固定高度确保对齐
        pw.Container(
          height: 15,
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10.0),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              if (note.isNotEmpty)
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _processText(note),
                      textAlign: pw.TextAlign.center,
                      style: _getTextStyle(fontSize: 7),
                      maxLines: 1,
                    ),
                  ),
                ),
              // 底部横线 - 统一对齐
              pw.Container(
                height: 0.5,
                width: double.infinity,
                color: PdfColors.grey600,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
