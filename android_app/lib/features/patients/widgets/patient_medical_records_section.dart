import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/medical_record_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/models/patient_medical_record.dart';
import 'package:dentist_app/widgets/app_card.dart';
import 'package:dentist_app/screens/medical_record_detail_screen.dart';

/// 患者病历记录显示组件
/// 职责：显示患者的病历记录列表
class PatientMedicalRecordsSection extends StatefulWidget {
  final Patient patient;

  const PatientMedicalRecordsSection({
    super.key,
    required this.patient,
  });

  @override
  State<PatientMedicalRecordsSection> createState() => _PatientMedicalRecordsSectionState();
}

class _PatientMedicalRecordsSectionState extends State<PatientMedicalRecordsSection> {
  List<PatientMedicalRecord>? _cachedMedicalRecords;
  bool _medicalRecordsLoaded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.patient.id == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medical_information,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '病历记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _cachedMedicalRecords = null;
                    _medicalRecordsLoaded = false;
                  });
                },
                tooltip: '刷新病历记录',
              ),
            ],
          ),
          const Divider(height: 24),
          _buildMedicalRecordsDisplay(),
        ],
      ),
    );
  }

  // 异步加载病历记录
  void _loadMedicalRecordsAsync() async {
    if (widget.patient.id == null || !mounted) return;

    try {
      // 先设置加载状态
      if (mounted) {
        setState(() {
          _medicalRecordsLoaded = true; // 标记为已尝试加载
        });
      }

      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 确保数据库已初始化
      if (!dbProvider.isInitialized) {
        print('数据库未初始化，无法加载病历记录');
        return;
      }
      
      // 确保provider已初始化
      if (!medicalRecordProvider.initialized) {
        await medicalRecordProvider.initializeFromDatabase(dbProvider);
      }
      
      // 像患者提供者一样，直接调用简单的查询方法
      final records = await medicalRecordProvider.getPatientMedicalRecordsSimple(widget.patient.id!);
      
      if (mounted) {
        setState(() {
          _cachedMedicalRecords = records;
        });
      }
    } catch (e) {
      print('加载病历记录失败: $e');
      // 错误状态已经通过_medicalRecordsLoaded = true设置
    }
  }

  // 显示病历记录
  Widget _buildMedicalRecordsDisplay() {
    // 如果还没有加载过，触发加载
    if (!_medicalRecordsLoaded) {
      // 使用addPostFrameCallback避免在build过程中调用setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMedicalRecordsAsync();
      });
      
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                '正在加载病历记录...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final records = _cachedMedicalRecords;

    // 如果加载完成但records为null，说明加载失败
    if (records == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '加载病历记录失败',
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cachedMedicalRecords = null;
                    _medicalRecordsLoaded = false;
                  });
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 如果记录为空
    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.description_outlined,
                color: Colors.grey[400],
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '暂无病历记录',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '该患者还没有创建病历记录',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: records.map((record) => _buildMedicalRecordCard(record)).toList(),
    );
  }

  // 病历记录卡片
  Widget _buildMedicalRecordCard(PatientMedicalRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _viewMedicalRecordDetails(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      record.recordNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MM-dd').format(record.recordDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (record.chiefComplaint.isNotEmpty) ...[
                Text(
                  '主诉: ${record.chiefComplaint}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              if (record.diagnosis.isNotEmpty) ...[
                Text(
                  '诊断: ${record.diagnosis}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '医生: ${record.doctorName.isNotEmpty ? record.doctorName : '未知'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '查看详情',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 查看病历详情
  void _viewMedicalRecordDetails(PatientMedicalRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordDetailScreen(
          patient: widget.patient,
          record: record,
        ),
      ),
    );
  }
}
