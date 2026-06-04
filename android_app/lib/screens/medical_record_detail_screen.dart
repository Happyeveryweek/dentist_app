import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../models/database_models.dart';
import '../models/patient_medical_record.dart';
import '../providers/medical_record_provider.dart';
import '../features/medical_records/utils/medical_record_pdf_exporter.dart';
import '../features/medical_records/utils/dental_condition_integration.dart';
import '../utils/toast_util.dart';
import '../widgets/app_card.dart';

// 定义颜色常量
class _AppColors {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryTextColor = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);
}

class MedicalRecordDetailScreen extends StatefulWidget {
  final Patient patient;
  final PatientMedicalRecord record;

  const MedicalRecordDetailScreen({
    super.key,
    required this.patient,
    required this.record,
  });

  @override
  State<MedicalRecordDetailScreen> createState() => _MedicalRecordDetailScreenState();
}

class _MedicalRecordDetailScreenState extends State<MedicalRecordDetailScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          '病历详情',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isExporting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf, color: _AppColors.primaryColor),
            onPressed: _isExporting ? null : _exportToPdf,
            tooltip: '导出PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 患者基本信息卡片
            _buildPatientInfoCard(),
            const SizedBox(height: 16),
            
            // 病历基本信息卡片
            _buildRecordInfoCard(),
            const SizedBox(height: 16),
            
            // 病历详细内容
            _buildRecordDetailsCard(),
          ],
        ),
      ),
    );
  }

  // 患者基本信息卡片
  Widget _buildPatientInfoCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: _AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('姓名', widget.patient.name),
              ),
              Expanded(
                child: _buildInfoItem('年龄', '${widget.patient.age ?? 0}岁'),
              ),
              Expanded(
                child: _buildInfoItem('性别', widget.patient.gender),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('电话', widget.patient.phone ?? '未设置'),
              ),
              Expanded(
                child: _buildInfoItem('病历号', widget.patient.medicalRecordNumber?.toString() ?? '无'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 病历基本信息卡片
  Widget _buildRecordInfoCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_information,
                color: _AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '病历信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('病历编号', widget.record.recordNumber),
              ),
              Expanded(
                child: _buildInfoItem('病历日期', DateFormat('yyyy年MM月dd日').format(widget.record.recordDate)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('医生', widget.record.doctorName.isNotEmpty ? widget.record.doctorName : '未知'),
              ),
              Expanded(
                child: _buildInfoItem('创建时间', DateFormat('yyyy-MM-dd HH:mm').format(widget.record.createdAt)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 病历详细内容卡片
  Widget _buildRecordDetailsCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description,
                color: _AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '病历详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          
          // 主诉
          if (widget.record.chiefComplaint.isNotEmpty)
            _buildDetailSection('主诉', widget.record.chiefComplaint),
          
          // 现病史
          if (widget.record.presentIllness.isNotEmpty)
            _buildDetailSection('现病史', widget.record.presentIllness),
          
          // 全身疾病既往史
          if (widget.record.pastMedicalHistory.isNotEmpty)
            _buildDetailSection('全身疾病既往史', widget.record.pastMedicalHistory),
          
          // 口腔疾病既往史
          if (widget.record.pastDentalHistory.isNotEmpty)
            _buildDetailSection('口腔疾病既往史', widget.record.pastDentalHistory),
          
          // 过敏史
          if (widget.record.allergyHistory.isNotEmpty)
            _buildDetailSection('过敏史', widget.record.allergyHistory),
          
          // 口腔检查
          if (widget.record.oralExamination.isNotEmpty)
            _buildDetailSection('口腔检查', widget.record.oralExamination),
          
          // 关联牙齿状况
          if (widget.record.selectedDentalConditionDate != null && 
              widget.record.selectedDentalConditionDate!.isNotEmpty)
            _buildDentalConditionSection(),
          
          // 诊断
          if (widget.record.diagnosis.isNotEmpty)
            _buildDetailSection('诊断', widget.record.diagnosis),
          
          // 治疗方案
          if (widget.record.treatmentPlan.isNotEmpty)
            _buildDetailSection('治疗方案', widget.record.treatmentPlan),
          
          // 注意事项
          if (widget.record.notes.isNotEmpty)
            _buildDetailSection('注意事项', widget.record.notes),
        ],
      ),
    );
  }

  // 信息项构建器
  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 详细内容区块构建器
  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 牙齿状况区块
  Widget _buildDentalConditionSection() {
    if (widget.patient.dentalCondition == null || 
        widget.patient.dentalCondition!.isEmpty) {
      return _buildDetailSection('关联牙齿状况', '无牙齿状况数据');
    }

    try {
      final dentalData = DentalConditionIntegration.parseDentalCondition(
        widget.patient.dentalCondition!
      );
      
      if (dentalData.isEmpty) {
        return _buildDetailSection('关联牙齿状况', '牙齿状况数据解析失败');
      }

      // 解析选中的日期
      List<String> selectedDates = [];
      try {
        final List<dynamic> dates = jsonDecode(widget.record.selectedDentalConditionDate!);
        selectedDates = dates.map((date) => date.toString()).toList();
      } catch (e) {
        selectedDates = [widget.record.selectedDentalConditionDate!];
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关联牙齿状况',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          
          for (int i = 0; i < selectedDates.length; i++) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. 关联日期: ${DentalConditionIntegration.formatDateForDisplay(selectedDates[i])}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDentalChartInfo(dentalData, selectedDates[i]),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
        ],
      );
    } catch (e) {
      return _buildDetailSection('关联牙齿状况', '牙齿状况数据解析错误: $e');
    }
  }

  // 牙齿图表信息
  Widget _buildDentalChartInfo(Map<String, dynamic> dentalData, String selectedDate) {
    final dentalRecord = DentalConditionIntegration.getDentalConditionByDate(
      dentalData, 
      selectedDate
    );
    
    if (dentalRecord.isEmpty) {
      return const Text(
        '该日期无牙齿状况数据',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      );
    }

    // 构建非空的牙齿图表列表
    List<Widget> charts = [];
    
    // 检查并添加有内容的图表
    for (int i = 1; i <= 3; i++) {
      String title = '图表$i';
      String chartPrefix = 'chart$i';
      
      if (_hasChartContent(title, dentalRecord, chartPrefix)) {
        if (charts.isNotEmpty) {
          charts.add(const SizedBox(height: 12)); // 添加间距
        }
        charts.add(_buildSingleChart(title, dentalRecord, chartPrefix));
      }
    }
    
    // 如果没有任何图表有内容，显示提示信息
    if (charts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '该日期暂无牙齿状况记录',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: charts,
    );
  }

  // 检查图表是否有内容（包括四个象限和备注）
  bool _hasChartContent(String title, Map<String, String> data, String chartPrefix) {
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

  // 单个图表显示 - 使用十字图表样式
  Widget _buildSingleChart(String title, Map<String, String> dentalRecord, String chartPrefix) {
    final topLeft = dentalRecord['$chartPrefix-top-left'] ?? '';
    final topRight = dentalRecord['$chartPrefix-top-right'] ?? '';
    final bottomLeft = dentalRecord['$chartPrefix-bottom-left'] ?? '';
    final bottomRight = dentalRecord['$chartPrefix-bottom-right'] ?? '';
    final note = dentalRecord['$chartPrefix-note'] ?? '';

    // 检查备注内容是否存在且不是默认提示文本
    String noteValue = note;
    if (noteValue.startsWith('请在此输入') && noteValue.endsWith('的备注')) {
      noteValue = '';
    }

    // 检查四个象限是否有内容
    final hasChartData = topLeft.trim().isNotEmpty || 
                        topRight.trim().isNotEmpty || 
                        bottomLeft.trim().isNotEmpty || 
                        bottomRight.trim().isNotEmpty;

    // 如果只有备注没有图表数据，使用紧凑显示
    if (!hasChartData && noteValue.trim().isNotEmpty) {
      return _buildCompactNoteOnlyChart(title, noteValue);
    }

    // 如果没有任何内容，不显示该图表
    if (!hasChartData && noteValue.trim().isEmpty) {
      return const SizedBox.shrink();
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
                              child: _buildQuadrantText(topLeft),
                            ),
                          ),
                          // 右上象限 (患者左上)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 6, top: 12),
                              child: _buildQuadrantText(topRight),
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
                              padding: const EdgeInsets.only(right: 6, bottom: 12),
                              child: _buildQuadrantText(bottomLeft),
                            ),
                          ),
                          // 右下象限 (患者左下)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 6, bottom: 12),
                              child: _buildQuadrantText(bottomRight),
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
                      Icon(Icons.note_alt, size: 14, color: Colors.amber.shade700),
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
                  Text(
                    noteValue,
                    style: const TextStyle(fontSize: 13),
                  ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.note_alt,
            size: 16,
            color: Colors.amber.shade600,
          ),
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

  // PDF导出功能
  Future<void> _exportToPdf() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // 检查和请求存储权限
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        return;
      }

      // 生成PDF
      final pdfBytes = await MedicalRecordPdfExporter.generatePdf(
        widget.patient,
        widget.record,
      );

      // 获取文件名
      final fileName = '病历_${widget.patient.name}_${widget.record.recordNumber}_${DateFormat('yyyyMMdd').format(widget.record.recordDate)}.pdf';

      // 使用SAF保存文件
      final params = SaveFileDialogParams(
        data: pdfBytes,
        fileName: fileName,
        mimeTypesFilter: ['application/pdf'],
      );

      final filePath = await FlutterFileDialog.saveFile(params: params);

      if (filePath != null && mounted) {
        ToastUtil.showSuccess(context, 'PDF已保存成功');
      } else if (mounted) {
        ToastUtil.showInfo(context, '用户取消了保存操作');
      }
    } catch (e) {
      print('PDF导出失败: $e');
      if (mounted) {
        ToastUtil.showError(context, 'PDF导出失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    try {
      // 现代Android版本使用SAF，尝试直接进行而不检查传统存储权限
      // 如果SAF可用，就不需要存储权限
      
      // 首先尝试检查存储权限状态
      var status = await Permission.storage.status;
      
      if (status.isGranted) {
        return true;
      }

      // 如果权限被永久拒绝，引导用户到设置页面
      if (status.isPermanentlyDenied) {
        return await _showPermissionDialog();
      }

      // 请求权限
      status = await Permission.storage.request();
      
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        return await _showPermissionDialog();
      } else if (status.isDenied) {
        // 权限被拒绝，但可能是因为使用了SAF，尝试继续
        if (mounted) {
          ToastUtil.showInfo(context, '将使用系统文件选择器保存PDF');
        }
        return true; // 让SAF处理文件保存
      } else {
        if (mounted) {
          ToastUtil.showError(context, '需要存储权限才能导出PDF');
        }
        return false;
      }
    } catch (e) {
      print('权限检查失败: $e');
      // 权限检查失败，但仍然尝试使用SAF
      if (mounted) {
        ToastUtil.showInfo(context, '将使用系统文件选择器保存PDF');
      }
      return true;
    }
  }

  // 显示权限对话框
  Future<bool> _showPermissionDialog() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('需要存储权限'),
          content: const Text(
            '为了保存PDF文件，需要访问设备存储权限。请在设置中允许此权限。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // 打开应用设置页面
      await openAppSettings();
      
      // 等待用户返回后重新检查权限
      await Future.delayed(const Duration(seconds: 1));
      final status = await Permission.storage.status;
      return status.isGranted;
    }

    return false;
  }
}