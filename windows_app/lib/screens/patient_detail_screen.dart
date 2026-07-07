import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient_medical_record.dart';
import '../providers/database_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/medical_record_provider.dart';
import '../providers/user_provider.dart';
import '../utils/permission_utils.dart';
import '../widgets/success_toast.dart';
import '../features/patients/widgets/patient_form_dialog.dart';
import '../features/appointments/widgets/appointment_form_dialog.dart';
import './appointment_details_screen.dart';
import '../features/financial/widgets/financial_form_dialog.dart';
import './financial_detail_screen.dart';
import '../features/medical_records/widgets/medical_record_form_dialog.dart';
import '../features/patients/services/patient_detail_loader_service.dart';
import '../features/patients/widgets/patient_detail_components.dart';
import '../utils/log_manager.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Patient? _patient;
  Patient? _appointmentContextPatient;
  Patient? _financialContextPatient;
  List<Appointment> _appointments = [];
  // 移除_patientMaterials变量 - 材料管理已迁移到MaterialDetailManager
  List<FinancialRecord> _financialRecords = [];
  List<FinancialItem> _financialItems = [];
  List<PatientMedicalRecord> _medicalRecords = [];
  late TabController _tabController;

  // 标记数据是否已更改，用于通知父页面是否需要刷新
  bool _dataChanged = false;
  bool _dataLoaded = false;
  // 患者数据同步状态
  PatientSyncStatus _syncStatus = PatientSyncStatus.checking;
  bool _isSyncing = false;
  // 牙齿状况区域的滚动控制器，必须共享给 Scrollbar 和 SingleChildScrollView
  final ScrollController _dentalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _loadPatientData();
      _dataLoaded = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dentalScrollController.dispose(); // 释放牙齿状况滚动控制器
    super.dispose();
  }

  Future<void> _loadPatientData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await PatientDetailLoaderService.load(
        context: context,
        patient: widget.patient,
        canViewFinancialRecords: _canViewPatientFinancialRecords(),
      );

      if (mounted) {
        setState(() {
          _patient = data.patient;
          _appointmentContextPatient = data.appointmentContextPatient;
          _financialContextPatient = data.financialContextPatient;
          _appointments = data.appointments;
          _financialRecords = data.financialRecords;
          _financialItems = data.financialItems;
          _medicalRecords = data.medicalRecords;
          _isLoading = false;
        });
        // 加载完成后检查同步状态
        _checkSyncStatus();
      }
    } catch (e) {
      LogManager.e('PatientDetailScreen', '加载患者数据错误', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('加载数据错误: $e')),
            );
          }
        });
      }
    }
  }

  Future<void> _reloadPatientData(
      {bool markChanged = true, bool showLoading = true}) async {
    await _loadPatientData(showLoading: showLoading);
    if (markChanged) {
      _dataChanged = true;
    }
  }

  Future<void> _runWithLoadingState(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // 系统返回按钮也要传递数据更改标志
        Navigator.of(context).pop(_dataChanged);
      },
      child: PatientDetailScaffold(
        patientName: _patient?.name ?? '患者详情',
        isLoading: _isLoading,
        tabController: _tabController,
        onBack: () {
          // 返回时传递数据更改标志
          Navigator.of(context).pop(_dataChanged);
        },
        onEditPatient: _isLoading ? null : _editPatient,
        syncStatus: _syncStatus,
        isSyncing: _isSyncing,
        onSync: _isLoading ? null : _syncPatient,
        tabViews: _isLoading
            ? const []
            : [
                _buildPatientInfoTab(),
                _buildMedicalRecordsTab(),
                PatientMaterialsTab(
                  patient: _patient,
                  onMaterialsChanged: () {
                    // 材料变化时标记数据已更改
                    _dataChanged = true;
                    // 可以选择性地重新加载患者数据
                    // _loadPatientData();
                  },
                ),
                _buildAppointmentsTab(),
                _buildFinancialRecordsTab(),
              ],
      ),
    );
  }

  Widget _buildPatientInfoTab() {
    final patient = _patient;
    if (patient == null) {
      return const Center(child: Text('无法加载患者信息'));
    }

    final dentalCondition = patient.dentalCondition;
    final treatmentItems = patient.treatmentItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PatientDetailOverviewCard(patient: patient),

          // 用分区标签分割内容
          PatientDetailSectionHeader(
              title: '个人信息', icon: Icons.person, color: context.tokens.success),
          PatientPersonalInfoCard(patient: patient),

          // 牙齿状况和治疗分区
          PatientDetailSectionHeader(
              title: '诊疗信息',
              icon: Icons.medical_information,
              color: context.tokens.error),
          PatientClinicalInfoCard(
            dentalCondition: _buildDentalCondition(patient),
            treatmentItems: treatmentItems,
            showDivider: dentalCondition != null &&
                dentalCondition.isNotEmpty &&
                treatmentItems != null &&
                treatmentItems.isNotEmpty,
            showEmptyState: dentalCondition == null && treatmentItems == null,
          ),
        ],
      ),
    );
  }

  Widget _buildDentalCondition(Patient patient) {
    final dentalCondition = patient.dentalCondition;
    if (dentalCondition == null || dentalCondition.isEmpty) {
      return const PatientDentalConditionEmptyState();
    }

    try {
      // 为MySQL和SQLite数据来源处理不同的数据类型
      Map<String, dynamic> dentalCharts;

      if (Provider.of<DatabaseProvider>(context, listen: false)
              .dataSourceType ==
          'mysql') {
        // MySQL数据源

        // 处理dental_condition字段的数据
        final dynamic rawData = dentalCondition;
        String jsonStr = '';

        try {
          // 根据实际类型进行处理
          if (rawData is List<int>) {
            // 已经是List<int>类型，直接解码
            jsonStr = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is Uint8List) {
            // 是Uint8List类型，直接解码
            jsonStr = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is String) {
            // 是String类型，直接使用
            jsonStr = rawData;
          } else {
            // 其他类型，尝试toString()
            jsonStr = rawData.toString();
          }
        } catch (e) {
          LogManager.e('PatientDetailScreen', '转换dental_condition错误', error: e);
          // 转换失败，使用toString作为后备方案
          jsonStr = rawData != null ? rawData.toString() : '{}';
        }

        // 尝试解析JSON字符串
        try {
          final decodedData = jsonDecode(jsonStr);
          if (decodedData is Map) {
            dentalCharts = Map<String, dynamic>.from(decodedData);

            // 额外处理可能存在的编码问题
            if (Provider.of<DatabaseProvider>(context, listen: false)
                    .dataSourceType ==
                'mysql') {
              _fixChineseEncodingInMap(dentalCharts);
            }
          } else {
            throw FormatException('期望Map类型，实际为: ${decodedData.runtimeType}');
          }
        } catch (e) {
          LogManager.e('PatientDetailScreen', 'JSON解析错误，尝试修复格式问题', error: e);

          // 尝试清理JSON字符串中可能存在的问题字符
          final cleanedJson =
              jsonStr.replaceAll(RegExp(r'[\u0000-\u001F]'), '');

          try {
            final decodedData = jsonDecode(cleanedJson);
            if (decodedData is Map) {
              dentalCharts = Map<String, dynamic>.from(decodedData);

              // 额外处理可能存在的编码问题
              if (Provider.of<DatabaseProvider>(context, listen: false)
                      .dataSourceType ==
                  'mysql') {
                _fixChineseEncodingInMap(dentalCharts);
              }
            } else {
              throw FormatException(
                  '清理后期望Map类型，实际为: ${decodedData.runtimeType}');
            }
          } catch (e2) {
            LogManager.e('PatientDetailScreen', '清理后JSON解析仍然失败2', error: e);
            // 尝试最后的修复方法
            try {
              // 对于MySQL，尝试手动处理JSON字符串中的编码问题
              if (Provider.of<DatabaseProvider>(context, listen: false)
                      .dataSourceType ==
                  'mysql') {
                String fixedJson = _fixJsonEncoding(jsonStr);
                final decodedData = jsonDecode(fixedJson);
                if (decodedData is Map) {
                  dentalCharts = Map<String, dynamic>.from(decodedData);
                  _fixChineseEncodingInMap(dentalCharts);
                } else {
                  throw FormatException(
                      '修复后期望Map类型，实际为: ${decodedData.runtimeType}');
                }
              } else {
                // 解析失败，使用空Map
                dentalCharts = {};
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('牙齿状况数据格式错误: $e2'),
                );
              }
            } catch (e3) {
              LogManager.e('PatientDetailScreen', '所有修复尝试均失败3', error: e);
              // 解析失败，使用空Map
              dentalCharts = {};
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('牙齿状况数据格式错误: $e3'),
              );
            }
          }
        }
      } else {
        // SQLite数据源
        dentalCharts = patient.dentalCharts;
      }

      if (dentalCharts.isEmpty) {
        return const PatientDentalConditionEmptyState();
      }

      // 找出有多少行数据
      int rowCount = 0;
      for (String key in dentalCharts.keys) {
        if (key.startsWith('date-')) {
          int index = int.tryParse(key.split('-').last) ?? 0;
          rowCount = rowCount > index ? rowCount : index + 1;
        }
      }

      // 创建包含日期和索引的列表用于排序
      List<Map<String, dynamic>> rowsWithDate = [];
      for (int i = 0; i < rowCount; i++) {
        // 获取日期
        String rawDateStr = dentalCharts['date-$i'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        // 确保日期字符串只包含年月日，去掉时分秒
        DateTime date;
        String dateStr;
        try {
          // 尝试解析日期字符串，然后重新格式化为年月日
          if (rawDateStr.contains('-')) {
            // 尝试解析包含"-"的日期格式
            date = DateTime.parse(rawDateStr.split(' ')[0]); // 只取日期部分
          } else if (rawDateStr.contains('/')) {
            // 尝试解析包含"/"的日期格式
            date = DateFormat('yyyy/MM/dd')
                .parse(rawDateStr.split(' ')[0]); // 只取日期部分
          } else {
            // 其他格式
            date = DateTime.parse(rawDateStr);
          }
          // 统一格式化为年-月-日
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          // 解析失败时使用原始字符串和当前日期
          LogManager.e('PatientDetailScreen', '日期解析错误，使用原始日期字符串', error: e);
          dateStr = rawDateStr;
          date = DateTime.now(); // 使用当前日期作为fallback
        }

        rowsWithDate.add({
          'index': i,
          'date': date,
          'dateStr': dateStr,
        });
      }

      // 按日期排序，最新的在前面
      rowsWithDate.sort((a, b) => b['date'].compareTo(a['date']));

      List<Widget> chartRows = [];
      for (var rowData in rowsWithDate) {
        int i = rowData['index'];
        String dateStr = rowData['dateStr'];

        // 获取创建者医生信息
        String createdByDoctor =
            _ensureString(dentalCharts['created_by_doctor-$i']);

        // 获取各位置数据并确保是字符串类型
        // 第一个图表
        String chart1TopLeft =
            _ensureString(dentalCharts['chart1-top-left-$i']);
        String chart1TopRight =
            _ensureString(dentalCharts['chart1-top-right-$i']);
        String chart1BottomLeft =
            _ensureString(dentalCharts['chart1-bottom-left-$i']);
        String chart1BottomRight =
            _ensureString(dentalCharts['chart1-bottom-right-$i']);
        String chart1Note = _ensureString(dentalCharts['chart1-note-$i']);

        // 第二个图表
        String chart2TopLeft =
            _ensureString(dentalCharts['chart2-top-left-$i']);
        String chart2TopRight =
            _ensureString(dentalCharts['chart2-top-right-$i']);
        String chart2BottomLeft =
            _ensureString(dentalCharts['chart2-bottom-left-$i']);
        String chart2BottomRight =
            _ensureString(dentalCharts['chart2-bottom-right-$i']);
        String chart2Note = _ensureString(dentalCharts['chart2-note-$i']);

        // 第三个图表
        String chart3TopLeft =
            _ensureString(dentalCharts['chart3-top-left-$i']);
        String chart3TopRight =
            _ensureString(dentalCharts['chart3-top-right-$i']);
        String chart3BottomLeft =
            _ensureString(dentalCharts['chart3-bottom-left-$i']);
        String chart3BottomRight =
            _ensureString(dentalCharts['chart3-bottom-right-$i']);
        String chart3Note = _ensureString(dentalCharts['chart3-note-$i']);

        chartRows.add(
          PatientDentalChartCard(
            dateStr: dateStr,
            createdByDoctor: createdByDoctor,
            chart1TopLeft: chart1TopLeft,
            chart1TopRight: chart1TopRight,
            chart1BottomLeft: chart1BottomLeft,
            chart1BottomRight: chart1BottomRight,
            chart1Note: chart1Note,
            chart2TopLeft: chart2TopLeft,
            chart2TopRight: chart2TopRight,
            chart2BottomLeft: chart2BottomLeft,
            chart2BottomRight: chart2BottomRight,
            chart2Note: chart2Note,
            chart3TopLeft: chart3TopLeft,
            chart3TopRight: chart3TopRight,
            chart3BottomLeft: chart3BottomLeft,
            chart3BottomRight: chart3BottomRight,
            chart3Note: chart3Note,
          ),
        );
      }

      return PatientDentalConditionList(
        chartRows: chartRows,
        scrollController: _dentalScrollController,
        maxHeight: _calculateOptimalChartHeight(chartRows.length),
      );
    } catch (e) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('解析牙齿状况数据出错: $e'),
      );
    }
  }

  // 计算牙齿状况图表的最佳高度（最多显示 5 行）
  double _calculateOptimalChartHeight(int chartCount) {
    // 每个图表卡片的基础高度 (优化后更紧凑)
    // 包含：创建者信息(15px) + 日期和图表行(75px) + 卡片间距(8px) + 内边距(12px) = 约110px
    const double baseChartHeight = 110.0;
    // 标题和间距的额外高度
    const double headerHeight = 40.0;
    // 底部间距
    const double bottomPadding = 16.0;

    // 最多显示 3 行，超过则滚动
    const int maxVisibleRows = 3;
    final int displayCount = chartCount.clamp(1, maxVisibleRows);

    // 计算总高度
    double totalHeight =
        headerHeight + (displayCount * baseChartHeight) + bottomPadding;

    // 设置合理的最小高度
    const double minHeight = 180.0;

    return totalHeight.clamp(minHeight, double.infinity);
  }

  // 确保值为字符串类型的辅助方法
  String _ensureString(dynamic value) {
    if (value == null) return '';

    try {
      if (value is List<int>) {
        // 二进制数据转换为字符串，尝试多种编码方式
        try {
          final utf8Result = utf8.decode(value, allowMalformed: true);
          if (_containsChinese(utf8Result)) {
            return utf8Result;
          }

          // 尝试其他编码
          if (Provider.of<DatabaseProvider>(context, listen: false)
                  .dataSourceType ==
              'mysql') {
            // MySQL默认通常是latin1或utf8
            try {
              // 尝试转换为latin1编码字符串再转回utf8
              final latin1Result = String.fromCharCodes(value);
              if (_containsChinese(latin1Result)) {
                return latin1Result;
              }
            } catch (e) {
              LogManager.e('PatientDetailScreen', 'latin1转换失败', error: e);
            }
          }

          return utf8Result;
        } catch (e) {
          LogManager.e('PatientDetailScreen', '二进制数据转换为字符串失败', error: e);
          // 尝试直接从字符码转换
          return String.fromCharCodes(value);
        }
      } else if (value is Uint8List) {
        // Uint8List转换为字符串，尝试多种编码方式
        try {
          final utf8Result = utf8.decode(value, allowMalformed: true);
          if (_containsChinese(utf8Result)) {
            return utf8Result;
          }

          // 尝试其他编码
          if (Provider.of<DatabaseProvider>(context, listen: false)
                  .dataSourceType ==
              'mysql') {
            // 尝试转换为latin1编码字符串
            try {
              final latin1Result = String.fromCharCodes(value);
              if (_containsChinese(latin1Result)) {
                return latin1Result;
              }
            } catch (e) {
              LogManager.e('PatientDetailScreen', 'latin1转换失败', error: e);
            }
          }

          return utf8Result;
        } catch (e) {
          LogManager.e('PatientDetailScreen', 'Uint8List转换为字符串失败', error: e);
          // 尝试直接从字符码转换
          return String.fromCharCodes(value);
        }
      } else if (value is String) {
        // 对已经是字符串的值检查是否需要重新解码
        if (Provider.of<DatabaseProvider>(context, listen: false)
                    .dataSourceType ==
                'mysql' &&
            !_containsChinese(value) &&
            _containsEncodedBytes(value)) {
          try {
            // 检测到可能是编码问题的字符串，尝试重新解码
            List<int> bytes = value.codeUnits;
            final decodedString = utf8.decode(bytes, allowMalformed: true);
            if (_containsChinese(decodedString)) {
              return decodedString;
            }
          } catch (e) {
            LogManager.e('PatientDetailScreen', '字符串重新解码失败', error: e);
          }
        }
        return value;
      }
    } catch (e) {
      LogManager.e('PatientDetailScreen', '字符串处理异常', error: e);
    }

    // 默认返回toString结果
    return value.toString();
  }

  // 检测字符串是否包含中文字符
  bool _containsChinese(String text) {
    // 中文Unicode范围大致为\u4e00-\u9fff
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  // 检测字符串是否可能包含编码问题的字节
  bool _containsEncodedBytes(String text) {
    // 检查是否包含常见的非ASCII字符但又不是中文
    return RegExp(r'[\u0080-\u00ff]').hasMatch(text);
  }

  void _fixChineseEncodingInMap(Map<String, dynamic> map) {
    // 遍历Map，尝试修复所有字符串值的编码问题
    map.forEach((key, value) {
      if (value is String &&
          !_containsChinese(value) &&
          _containsEncodedBytes(value)) {
        try {
          // 尝试修复编码问题
          List<int> bytes = value.codeUnits;

          // 尝试不同的解码方式
          String? fixedValue;

          // 尝试UTF-8解码
          try {
            final utf8Decoded = utf8.decode(bytes, allowMalformed: true);
            if (_containsChinese(utf8Decoded)) {
              fixedValue = utf8Decoded;
            }
          } catch (e) {
            LogManager.e('PatientDetailScreen', 'UTF-8解码失败', error: e);
          }

          // 尝试直接使用String.fromCharCodes
          if (fixedValue == null) {
            try {
              final directDecoded = String.fromCharCodes(bytes);
              if (_containsChinese(directDecoded)) {
                fixedValue = directDecoded;
              }
            } catch (e) {
              LogManager.e('PatientDetailScreen', '直接解码失败', error: e);
            }
          }

          // 如果找到修复的值，更新Map
          if (fixedValue != null && fixedValue != value) {
            map[key] = fixedValue;
          }
        } catch (e) {
          LogManager.e('PatientDetailScreen', '修复编码过程中出错', error: e);
        }
      }
    });
  }

  String _fixJsonEncoding(String jsonStr) {
    // 修复JSON字符串中的编码问题

    // 步骤1: 处理常见的MySQL编码问题
    // 尝试不同的编码组合
    String fixedJson = jsonStr;

    // 尝试处理可能的转义序列问题
    fixedJson =
        fixedJson.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      try {
        final group = match.group(1);
        if (group == null) return match.group(0) ?? '';
        final codePoint = int.parse(group, radix: 16);
        return String.fromCharCode(codePoint);
      } catch (e) {
        return match.group(0) ?? '';
      }
    });

    // 如果看起来是双重编码的问题，尝试解决
    if (fixedJson.contains(r'\u') && !_containsChinese(fixedJson)) {
      try {
        // 尝试解码一次
        final decoded = jsonDecode(fixedJson);
        if (decoded is String) {
          return decoded;
        } else if (decoded is Map) {
          return jsonEncode(decoded);
        }
      } catch (e) {
        LogManager.e('PatientDetailScreen', '尝试解决双重编码问题失败', error: e);
      }
    }

    // 对于包含特殊字符序列但不包含中文的字符串，尝试特殊处理
    if (!_containsChinese(fixedJson) && _containsEncodedBytes(fixedJson)) {
      try {
        List<int> bytes = fixedJson.codeUnits;
        String decodedStr = utf8.decode(bytes, allowMalformed: true);
        if (_containsChinese(decodedStr)) {
          return decodedStr;
        }
      } catch (e) {
        LogManager.e('PatientDetailScreen', '尝试特殊处理编码失败', error: e);
      }
    }

    return fixedJson;
  }

  Widget _buildMedicalRecordsTab() {
    if (_medicalRecords.isEmpty) {
      return PatientMedicalRecordsEmptyState(onAdd: _addMedicalRecord);
    }

    // 按创建时间倒序排序，最新的排在前面
    final sortedRecords = List<PatientMedicalRecord>.from(_medicalRecords);
    sortedRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PatientMedicalRecordsListSection(
      recordCount: _medicalRecords.length,
      recordCards: sortedRecords.map(_buildMedicalRecordCard).toList(),
      onRefresh: _refreshMedicalRecords,
      onAdd: _addMedicalRecord,
    );
  }

  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return PatientAppointmentsEmptyState(onAdd: _addAppointment);
    }

    // 按日期排序，最近的排在前面
    _appointments
        .sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return PatientAppointmentCard(
          appointment: appointment,
          treatmentTypeText:
              _formatTreatmentTypeForDisplay(appointment.treatmentType),
          canEdit: PermissionUtils.canEditDoctor(
              context, appointment.patient?.doctor),
          canDelete: PermissionUtils.canDeleteDoctor(
            context,
            appointment.patient?.doctor,
          ),
          onView: () => _viewAppointmentDetails(appointment),
          onEdit: () => _editAppointment(appointment),
          onDelete: () => _deleteAppointment(appointment),
          onEditDenied: () => AppToastManager.showError(
            context,
            message: '您只能编辑自己医生患者的预约',
          ),
          onDeleteDenied: () => AppToastManager.showError(
            context,
            message: '您只能删除自己医生患者的预约',
          ),
        );
      },
    );
  }

  void _editPatient() async {
    final patient = _patient;
    if (patient == null) return;

    // 所有医生都可以编辑任何患者，但编辑权限在表单内部控制

    final patientProvider =
        Provider.of<PatientProvider>(context, listen: false);

    // 从数据库获取最新的患者信息，确保包含完整的牙齿状况数据
    Patient? freshPatient;
    try {
      final patientId = patient.id;
      if (patientId != null) {
        freshPatient = await patientProvider.getPatient(patientId);
        if (freshPatient == null) {
          LogManager.e('PatientDetailScreen', '无法获取最新患者数据，使用当前患者数据');
          freshPatient = patient;
        }
      } else {
        freshPatient = patient;
      }
    } catch (e) {
      LogManager.e('PatientDetailScreen', '获取最新患者数据失败，使用当前患者数据', error: e);
      freshPatient = _patient;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => PatientFormDialog(
        patient: freshPatient,
        onSave: _savePatient,
      ),
    );
  }

  // 移除添加患者材料的方法 - 功能已迁移到MaterialDetailManager
  // void _addPatientMaterial() async { ... }

  void _savePatient(Patient updatedPatient) async {
    try {
      // 患者已经在PatientFormDialog中保存过了，这里只需要刷新数据

      // 重新加载数据（_loadPatientData内部会管理_isLoading状态）
      await _reloadPatientData();

      if (mounted) {
        // 使用公用成功提示组件
        AppToastManager.showSuccess(context, message: '患者信息已更新');
      }

      // 保存后同步到 MySQL 并刷新同步状态
      await _syncAndCheckStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  /// 检查患者数据在 SQLite 与 MySQL 之间的同步状态
  Future<void> _checkSyncStatus() async {
    final patient = _patient;
    if (patient == null) return;
    final patientId = patient.id;
    if (patientId == null) return;

    if (mounted) {
      setState(() {
        _syncStatus = PatientSyncStatus.checking;
      });
    }

    try {
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final result =
          await patientProvider.comparePatientSyncStatus(patientId);

      if (!mounted) return;
      setState(() {
        switch (result) {
          case true:
            _syncStatus = PatientSyncStatus.synced;
            break;
          case false:
            _syncStatus = PatientSyncStatus.notSynced;
            break;
          case null:
            _syncStatus = PatientSyncStatus.unavailable;
            break;
        }
      });
    } catch (e) {
      LogManager.e('PatientDetailScreen', '检查同步状态失败', error: e);
      if (mounted) {
        setState(() {
          _syncStatus = PatientSyncStatus.unavailable;
        });
      }
    }
  }

  /// 手动同步当前患者到 MySQL
  Future<void> _syncPatient() async {
    final patient = _patient;
    if (patient == null) return;
    final patientId = patient.id;
    if (patientId == null) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final success =
          await patientProvider.syncSinglePatientToMySQL(patientId);

      if (!mounted) return;

      if (success) {
        AppToastManager.showSuccess(context, message: '患者数据已同步到 MySQL');
      } else {
        AppToastManager.showError(context, message: '同步失败，请检查 MySQL 连接');
      }

      await _checkSyncStatus();
    } catch (e) {
      LogManager.e('PatientDetailScreen', '手动同步患者失败', error: e);
      if (mounted) {
        AppToastManager.showError(context, message: '同步失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  /// 保存后同步到 MySQL 并刷新同步状态
  Future<void> _syncAndCheckStatus() async {
    final patient = _patient;
    if (patient == null) return;
    final patientId = patient.id;
    if (patientId == null) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.syncSinglePatientToMySQL(patientId);
    } catch (e) {
      LogManager.e('PatientDetailScreen', '保存后同步失败', error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }

    await _checkSyncStatus();
  }

  void _addAppointment() async {
    // 实现添加预约功能
    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: DateTime.now(),
        preselectedPatient: _appointmentContextPatient ?? widget.patient,
      ),
    );

    if (result != null) {
      try {
        if (!mounted) return;
        final appointmentProvider =
            Provider.of<AppointmentProvider>(context, listen: false);
        await appointmentProvider.addAppointment(result);

        // 重新加载数据
        await _reloadPatientData();

        if (!mounted) return;
        // 使用公用成功提示组件
        AppToastManager.showSuccess(context, message: '预约已添加');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加预约失败: $e')),
        );
      }
    }
  }

  void _viewAppointmentDetails(Appointment appointment) {
    // 跳转到预约详情页面
    final appointmentId = appointment.id;
    if (appointmentId == null) {
      LogManager.w('PatientDetailScreen', '无法查看无 ID 的预约详情');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailsScreen(
          appointmentId: appointmentId,
        ),
      ),
    );
  }

  void _editAppointment(Appointment appointment) async {
    // 检查编辑权限
    if (!PermissionUtils.canEditDoctor(context, appointment.patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }

    // 实现编辑预约功能
    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: DateTime.now(),
        preselectedPatient: _appointmentContextPatient ?? widget.patient,
        appointment: appointment,
      ),
    );

    if (result != null) {
      try {
        if (!mounted) return;
        final appointmentProvider =
            Provider.of<AppointmentProvider>(context, listen: false);
        await appointmentProvider.updateAppointment(result);

        // 重新加载数据
        await _reloadPatientData();

        if (!mounted) return;
        // 使用公用成功提示组件
        AppToastManager.showSuccess(context, message: '预约已更新');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新预约失败: $e')),
        );
      }
    }
  }

  void _deleteAppointment(Appointment appointment) async {
    // 检查删除权限
    if (!PermissionUtils.canDeleteDoctor(
        context, appointment.patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能删除自己医生患者的预约',
      );
      return;
    }

    // 实现删除预约功能
    final confirm = await DeleteConfirmDialogManager.showAppointmentDelete(
      context,
      appointmentInfo: '这个预约',
    );

    if (confirm == true) {
      try {
        final appointmentId = appointment.id;
        if (appointmentId == null) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '无法删除无 ID 的预约');
          return;
        }
        if (!mounted) return;
        final appointmentProvider =
            Provider.of<AppointmentProvider>(context, listen: false);
        await appointmentProvider.deleteAppointment(appointmentId);

        // 重新加载数据
        await _reloadPatientData();

        if (!mounted) return;
        // 使用公用删除成功提示组件
        AppToastManager.showDelete(context, message: '预约已删除');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除预约失败: $e')),
        );
      }
    }
  }

  // 格式化显示治疗类型和牙位信息
  String _formatTreatmentTypeForDisplay(String? treatmentTypeStr) {
    if (treatmentTypeStr == null || treatmentTypeStr.isEmpty) {
      return '常规复诊';
    }

    try {
      // 尝试解析JSON数据
      Map<String, dynamic> data = json.decode(treatmentTypeStr);
      List<String> displayParts = [];

      // 处理牙位信息
      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        List teethData = data['teethData'];

        for (int i = 0; i < teethData.length; i++) {
          List<String> positions = [];
          Map<String, dynamic> tooth = Map<String, dynamic>.from(teethData[i]);

          // 检查所有可能的字段名称
          final fieldMapping = {
            'topLeft': '右上',
            'topRight': '左上',
            'bottomLeft': '右下',
            'bottomRight': '左下',
            'upperLeft': '右上',
            'upperRight': '左上',
            'lowerLeft': '右下',
            'lowerRight': '左下',
          };

          fieldMapping.forEach((field, label) {
            if (tooth.containsKey(field) &&
                tooth[field] != null &&
                tooth[field].toString().isNotEmpty) {
              positions.add('$label ${tooth[field]}');
            }
          });

          if (positions.isNotEmpty) {
            displayParts.add('牙位${i + 1}: ${positions.join('，')}');
          }
        }
      }

      // 处理治疗项目
      if (data.containsKey('treatments') && data['treatments'] is List) {
        List<String> treatments = List<String>.from(data['treatments']);
        if (treatments.isNotEmpty) {
          if (displayParts.isNotEmpty) {
            displayParts.add('- ${treatments.join("、")}');
          } else {
            displayParts.add(treatments.join("、"));
          }
        }
      }

      return displayParts.isNotEmpty ? displayParts.join(' ') : '常规复诊';
    } catch (e) {
      // 如果不是JSON格式，直接返回原始字符串
      return treatmentTypeStr;
    }
  }

  // 移除旧的_buildMaterialsTab方法 - 已被MaterialDetailManager替代

  // 移除旧的_buildMaterialCard和_showImageDetail方法 - 已被MaterialDetailManager替代

  Widget _buildFinancialRecordsTab() {
    // 检查当前用户是否有权限查看该患者的财务记录
    if (!_canViewPatientFinancialRecords()) {
      return const PatientFinancialPermissionDeniedState();
    }

    if (_financialRecords.isEmpty) {
      return PatientFinancialRecordsEmptyState(
        onAddFinancialRecord: _addFinancialRecord,
      );
    }

    // 按创建时间排序，最近的排在前面
    _financialRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PatientFinancialRecordsList(
      records: _financialRecords,
      financialItems: _financialItems,
      patient: _financialContextPatient ?? widget.patient,
      patientTotalReceivable: _calculatePatientTotalReceivable(),
      canViewRecords: _canViewPatientFinancialRecords(),
      onViewRecord: _viewFinancialRecordDetails,
      onEditRecord: _editFinancialRecord,
      onDeleteRecord: _deleteFinancialRecord,
      onPermissionDenied: () => PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能操作自己医生的患者的财务记录。',
      ),
    );
  }

  double _calculatePatientTotalReceivable() {
    double patientTotalReceivable = 0.0;
    if (_financialRecords.isNotEmpty && _financialItems.isNotEmpty) {
      try {
        for (final r in _financialRecords) {
          if (r.id != null) {
            for (final item in _financialItems) {
              if (item.financialRecordId == r.id) {
                patientTotalReceivable += (item.itemPrice * item.quantity);
              }
            }
          }
        }
      } catch (e) {
        LogManager.e('PatientDetailScreen', '计算患者应收费总额时出错', error: e);
        patientTotalReceivable = 0.0;
      }
    }

    return patientTotalReceivable;
  }

  void _addFinancialRecord() async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能为自己医生的患者添加收费记录。',
      );
      return;
    }

    Patient? financialContextPatient = _financialContextPatient;
    if (financialContextPatient == null) {
      final patient = _patient ?? widget.patient;
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);

      financialContextPatient = await patientProvider.ensurePatientInDataSource(
        patient,
        targetDataSourceType: financialProvider.dataSourceType,
      );

      if (financialContextPatient == null) {
        if (!mounted) return;
        AppToastManager.showError(
          context,
          message: '当前患者写入财务数据源失败，无法新增收费记录',
        );
        return;
      }

      if (mounted) {
        setState(() {
          _financialContextPatient = financialContextPatient;
        });
      }
    }

    if (!mounted) return;

    // 实现添加收费记录功能
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FinancialFormDialog(
        contextPatient: financialContextPatient,
        onResult: (success) {
          if (success) {
            // 保存成功后重新加载数据但不关闭页面
            _reloadPatientData();
            if (mounted) {
              // 使用公用成功提示组件
              AppToastManager.showSuccess(context, message: '收费记录已添加');
            }
          }
        },
      ),
    );
  }

  void _viewFinancialRecordDetails(FinancialRecord record) async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能查看自己医生的患者的财务记录。',
      );
      return;
    }

    final financialContextPatient = _financialContextPatient;
    if (financialContextPatient == null) {
      AppToastManager.showError(
        context,
        message: '当前患者未在财务数据源中匹配到对应档案，请先同步患者数据',
      );
      return;
    }

    // 跳转到收费记录详情页面，并等待返回结果
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialDetailScreen(
          patient: financialContextPatient,
          initialRecordId: record.id,
        ),
      ),
    );

    // 如果财务详情页有数据变动，重新加载患者数据
    if (result == true) {
      await _reloadPatientData();
    }
  }

  void _editFinancialRecord(FinancialRecord record) async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能编辑自己医生的患者的财务记录。',
      );
      return;
    }

    final financialContextPatient = _financialContextPatient;
    if (financialContextPatient == null) {
      AppToastManager.showError(
        context,
        message: '当前患者未在财务数据源中匹配到对应档案，请先同步患者数据',
      );
      return;
    }

    final result =
        await PatientDetailDialogActions.showEditFinancialRecordDialog(
      context: context,
      patient: financialContextPatient,
      record: record,
    );
    if (result) {
      await _reloadPatientData();
    }
  }

  void _deleteFinancialRecord(FinancialRecord record) async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能删除自己医生的患者的财务记录。',
      );
      return;
    }

    final confirm =
        await PatientDetailDialogActions.showDeleteFinancialRecordConfirm(
      context: context,
    );

    if (confirm) {
      try {
        final recordId = record.id;
        if (recordId == null) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '无法删除无 ID 的财务记录');
          return;
        }
        if (!mounted) return;
        final financialProvider =
            Provider.of<FinancialProvider>(context, listen: false);
        await financialProvider.deleteFinancialRecord(recordId);

        // 重新加载数据
        await _reloadPatientData();

        if (!mounted) return;
        AppToastManager.showSuccess(context, message: '收费记录已删除');
      } catch (e) {
        if (!mounted) return;
        AppToastManager.showError(context, message: '删除收费记录失败: $e');
      }
    }
  }

  // 病历相关方法
  Widget _buildMedicalRecordCard(PatientMedicalRecord record) {
    return PatientMedicalRecordCard(
      record: record,
      canEdit: _canEditMedicalRecord(record),
      onView: () => _viewMedicalRecordDetails(record),
      onEdit: () => _editMedicalRecord(record),
      onExport: () => _exportMedicalRecordToPdf(record),
    );
  }

  /// 检查当前用户是否可以编辑指定的病历记录
  bool _canEditMedicalRecord(PatientMedicalRecord record) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        return false;
      }

      // 管理员拥有所有权限
      if (currentUser.role == 'admin') {
        return true;
      }

      // 非管理员用户只能编辑自己创建的病历记录
      final currentDoctor = currentUser.doctor;
      if (currentDoctor != null && currentDoctor.isNotEmpty) {
        final createdByDoctor = record.createdByDoctor ?? record.doctorName;
        return createdByDoctor == currentDoctor;
      }

      return false;
    } catch (e) {
      LogManager.e('PatientDetailScreen', '检查病历编辑权限时出错', error: e);
      return false;
    }
  }

  /// 检查当前用户是否可以删除指定的病历记录
  bool _canDeleteMedicalRecord(PatientMedicalRecord record) {
    // 删除权限与编辑权限相同
    return _canEditMedicalRecord(record);
  }

  void _addMedicalRecord() async {
    final patient = _patient;
    if (patient == null) {
      return;
    }

    try {
      final result = await showDialog<PatientMedicalRecord>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MedicalRecordFormDialog(
          patient: patient,
          onSave: (record) async {
            try {
              // 调用MedicalRecordProvider保存病历
              final medicalRecordProvider =
                  Provider.of<MedicalRecordProvider>(context, listen: false);
              final recordId =
                  await medicalRecordProvider.createMedicalRecord(record);

              if (recordId > 0) {
                if (!context.mounted) return;
                // 保存成功，返回带ID的记录
                final savedRecord = record.copyWith(id: recordId);
                Navigator.of(context).pop(savedRecord);
              } else {
                throw Exception('保存病历失败');
              }
            } catch (e) {
              if (!context.mounted) return;
              // 显示错误信息
              final tokens = context.tokens;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('保存病历失败: $e'),
                  backgroundColor: tokens.error,
                ),
              );
              // 不关闭对话框，让用户可以重试
            }
          },
        ),
      );

      if (result != null) {
        // 重新加载病历数据
        await _reloadPatientData(showLoading: false);

        if (mounted) {
          AppToastManager.showSuccess(context, message: '病历记录已创建');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建病历失败: $e')),
        );
      }
    }
  }

  void _viewMedicalRecordDetails(PatientMedicalRecord record) {
    final patient = _patient;
    if (patient == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PatientMedicalRecordDetailDialog(
        patient: patient,
        record: record,
        canEdit: _canEditMedicalRecord(record),
        canDelete: _canDeleteMedicalRecord(record),
        onExport: () => _exportMedicalRecordToPdf(record),
        onEdit: () {
          Navigator.of(context).pop();
          _editMedicalRecord(record);
        },
        onDelete: () async {
          // 不关闭病历详情页，直接执行删除操作
          await _deleteMedicalRecord(record);
        },
      ),
    );
  }

  void _editMedicalRecord(PatientMedicalRecord record) async {
    final patient = _patient;
    if (patient == null) return;

    // 检查编辑权限
    if (!_canEditMedicalRecord(record)) {
      final tokens = context.tokens;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('权限不足：只能编辑自己创建的病历记录'),
          backgroundColor: tokens.error,
        ),
      );
      return;
    }

    try {
      final result = await showDialog<PatientMedicalRecord>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MedicalRecordFormDialog(
          patient: patient,
          medicalRecord: record,
          onSave: (updatedRecord) async {
            try {
              // 调用MedicalRecordProvider更新病历
              final medicalRecordProvider =
                  Provider.of<MedicalRecordProvider>(context, listen: false);
              final success = await medicalRecordProvider
                  .updateMedicalRecord(updatedRecord);

              if (success) {
                if (!context.mounted) return;
                Navigator.of(context).pop(updatedRecord);
              } else {
                throw Exception('更新病历失败');
              }
            } catch (e) {
              if (!context.mounted) return;
              // 显示错误信息
              final tokens = context.tokens;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('更新病历失败: $e'),
                  backgroundColor: tokens.error,
                ),
              );
              // 不关闭对话框，让用户可以重试
            }
          },
        ),
      );

      if (result != null) {
        // 重新加载病历数据
        await _reloadPatientData(showLoading: false);

        if (mounted) {
          AppToastManager.showSuccess(context, message: '病历记录已更新');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('编辑病历失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteMedicalRecord(PatientMedicalRecord record) async {
    final patient = _patient;
    if (patient == null) return;

    // 检查删除权限
    if (!_canDeleteMedicalRecord(record)) {
      final tokens = context.tokens;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('权限不足：只能删除自己创建的病历记录'),
          backgroundColor: tokens.error,
        ),
      );
      return;
    }

    // 使用公共删除确认框组件
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除病历记录 "${record.recordNumber}" 吗？此操作不可撤销。',
    );

    if (confirmed) {
      try {
        final recordId = record.id;
        if (recordId == null) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '无法删除无 ID 的病历记录');
          return;
        }
        if (!mounted) return;
        final medicalRecordProvider =
            Provider.of<MedicalRecordProvider>(context, listen: false);
        await medicalRecordProvider.deleteMedicalRecord(recordId);

        // 重新加载病历数据
        await _reloadPatientData(showLoading: false);

        if (!mounted) return;
        AppToastManager.showDelete(context, message: '病历记录已删除');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除病历失败: $e')),
        );
      }
    }
  }

  void _exportMedicalRecordToPdf(PatientMedicalRecord record) {
    final patient = _patient;
    if (patient == null) return;
    PatientDetailDialogActions.exportMedicalRecordToPdf(
      context: context,
      patient: patient,
      record: record,
    );
  }

  /// 刷新病历记录数据
  Future<void> _refreshMedicalRecords() async {
    final patient = _patient;
    if (patient == null) return;

    final patientId = patient.id;
    if (patientId == null) {
      AppToastManager.showError(context, message: '无法刷新无 ID 患者的病历数据');
      return;
    }

    try {
      await _runWithLoadingState(() async {
        final medicalRecords =
            await PatientDetailLoaderService.loadMedicalRecords(
          context: context,
          patientId: patientId,
        );

        if (mounted) {
          setState(() {
            _medicalRecords = medicalRecords;
            _isLoading = false;
          });

          AppToastManager.showSuccess(
            context,
            message: '病历数据已刷新',
            duration: const Duration(seconds: 2),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        AppToastManager.showError(
          context,
          message: '刷新病历数据失败: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// 检查当前用户是否可以查看该患者的财务记录
  bool _canViewPatientFinancialRecords() {
    // 使用 widget.patient 而不是 _patient，因为在数据加载时 _patient 可能还是 null
    final patient = _patient ?? widget.patient;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        return false;
      }

      // 管理员拥有所有权限
      if (currentUser.isAdmin) {
        return true;
      }

      // 非管理员用户只能查看自己医生的患者的财务记录
      // 如果患者没有指定医生，或者当前用户的医生与患者的医生匹配，则允许查看
      final patientDoctor = patient.doctor;
      if (patientDoctor == null || patientDoctor.isEmpty) {
        // 如果患者没有指定医生，所有用户都可以查看

        return true;
      }

      // 检查当前用户的医生是否与患者的医生匹配
      final hasPermission =
          currentUser.doctor != null && currentUser.doctor == patientDoctor;

      return hasPermission;
    } catch (e) {
      LogManager.e('PatientDetailScreen', '检查财务记录查看权限时出错', error: e);
      return false;
    }
  }
}
