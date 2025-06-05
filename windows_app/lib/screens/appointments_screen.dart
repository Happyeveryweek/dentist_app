import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:convert';
import 'dart:collection';

import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../models/dental_treatment.dart';
import '../providers/database_provider.dart';
import '../providers/app_state.dart';
import './appointment_details_screen.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
  // 保留旧键名的映射以兼容旧数据
  'upperLeft': '右上',
  'upperRight': '左上',
  'lowerLeft': '右下',
  'lowerRight': '左下',
};

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _endDate;
  List<Appointment> _appointments = [];
  List<Appointment> _filteredAppointments = [];
  bool _isLoading = true;
  bool _showAllAppointments = true;
  bool _isFiltering = false;
  bool _isDateRangeFiltering = false;
  bool _patientDropdownOpen = false;
  final TextEditingController _patientSearchController =
      TextEditingController();
  List<Patient> _filteredPatients = [];
  List<Patient> _patients = [];
  bool _isLoadingPatients = true;

  // 治疗类型选项
  List<String> _treatmentTypes = [];
  List<String> _selectedTreatments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    if (dbProvider.appointmentsNeedRefresh) {
      _loadAppointments();
      dbProvider.resetAppointmentsRefreshFlag();
    }
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 获取当前用户信息
      final currentUser = await dbProvider.getCurrentUser();
      final isAdmin = currentUser?.role == 'admin';
      final doctorName = currentUser?.doctor;

      List<Appointment> appointments = [];

      // 根据用户角色过滤预约
      if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
        // 医生只能看到自己的预约
        appointments = await dbProvider.getAppointmentsByDoctor(doctorName);
      } else {
        // 管理员可以看到所有预约
        appointments = await dbProvider.getAllAppointments();
      }

      appointments.sort((a, b) {
        final now = DateTime.now();
        final diffA = a.appointment_date.difference(now).inMinutes.abs();
        final diffB = b.appointment_date.difference(now).inMinutes.abs();

        if (a.appointment_date.isAfter(now) &&
            b.appointment_date.isBefore(now)) {
          return -1;
        }
        if (a.appointment_date.isBefore(now) &&
            b.appointment_date.isAfter(now)) {
          return 1;
        }

        return diffA.compareTo(diffB);
      });

      setState(() {
        _appointments = appointments;
        _filterAppointmentsByDate();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载预约数据失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterAppointmentsByDate() {
    if (!_isFiltering) {
      // 不筛选，显示全部
      _filteredAppointments = List.from(_appointments);
    } else if (_isDateRangeFiltering && _endDate != null) {
      // 按日期范围筛选
      _filteredAppointments = _appointments.where((appointment) {
        final appointmentDate = appointment.appointment_date;
        // 从选择的开始日期的0点到结束日期的23:59:59
        final startDateTime = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        final endDateTime = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        return appointmentDate
                .isAfter(startDateTime.subtract(const Duration(seconds: 1))) &&
            appointmentDate
                .isBefore(endDateTime.add(const Duration(seconds: 1)));
      }).toList();
    } else {
      // 按单一日期筛选
      _filteredAppointments = _appointments.where((appointment) {
        final appointmentDate = appointment.appointment_date;
        return appointmentDate.year == _selectedDate.year &&
            appointmentDate.month == _selectedDate.month &&
            appointmentDate.day == _selectedDate.day;
      }).toList();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _endDate = null; // 清除结束日期
        _isFiltering = true;
        _isDateRangeFiltering = false; // 设置为单日筛选
        _filterAppointmentsByDate();
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = _endDate != null
        ? DateTimeRange(start: _selectedDate, end: _endDate!)
        : DateTimeRange(
            start: _selectedDate,
            end: _selectedDate.add(const Duration(days: 7)),
          );

    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Container(
          width: 350, // 保持宽度
          height: 380, // 减小高度以避免溢出
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '选择日期范围',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  // 添加滚动视图，避免内容溢出
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开始日期:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppTheme.primaryColor,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null && context.mounted) {
                            setState(() {
                              _selectedDate = date;
                              // 确保结束日期不早于开始日期
                              if (_endDate != null &&
                                  _endDate!.isBefore(_selectedDate)) {
                                _endDate = _selectedDate;
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 18, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('yyyy年MM月dd日').format(_selectedDate),
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), // 减小间距
                      Text('结束日期:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ??
                                _selectedDate.add(const Duration(days: 7)),
                            firstDate: _selectedDate, // 确保结束日期不早于开始日期
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppTheme.primaryColor,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null && context.mounted) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 18, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                _endDate != null
                                    ? DateFormat('yyyy年MM月dd日')
                                        .format(_endDate!)
                                    : DateFormat('yyyy年MM月dd日').format(
                                        _selectedDate
                                            .add(const Duration(days: 7))),
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), // 减小间距
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '选择的范围将包含开始日期和结束日期',
                                style: TextStyle(color: Colors.blue.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        DateTimeRange(
                          start: _selectedDate,
                          end: _endDate ??
                              _selectedDate.add(const Duration(days: 7)),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDate = result.start;
        _endDate = result.end;
        _isFiltering = true;
        _isDateRangeFiltering = true;
      });
      _filterAppointmentsByDate();
    }
  }

  void _toggleFiltering() {
    setState(() {
      _isFiltering = !_isFiltering;
      if (!_isFiltering) {
        _isDateRangeFiltering = false;
        _endDate = null;
      } else {
        // 切换到筛选状态时，自动打开日期范围选择器
        _selectDateRange(context);
      }
      _filterAppointmentsByDate();
    });
  }

  String _formatAppointmentTime(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  Future<void> _showAddEditAppointmentDialog([Appointment? appointment]) async {
    final bool isEditing = appointment != null;

    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: _selectedDate,
        appointment: appointment,
      ),
    );

    if (result != null) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      try {
        if (isEditing) {
          await appState.showLoading(
            dbProvider.updateAppointment(result),
            message: '正在更新预约...',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('预约已更新'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          await appState.showLoading(
            dbProvider.addAppointment(result),
            message: '正在添加预约...',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('预约已添加'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadAppointments();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isEditing ? "更新" : "添加"}预约失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除${appointment.patient?.name ?? "未知患者"}的预约吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      try {
        await appState.showLoading(
          dbProvider.deleteAppointment(appointment.id!),
          message: '正在删除预约...',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('预约已删除'), backgroundColor: Colors.green),
        );

        _loadAppointments();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除预约失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 在_AppointmentsScreenState类中添加方法，用于格式化显示治疗类型和牙位信息
  String _formatTreatmentTypeForDisplay(String? treatmentTypeStr) {
    if (treatmentTypeStr == null || treatmentTypeStr.isEmpty) {
      return '';
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

      return displayParts.join(' ');
    } catch (e) {
      // 如果不是JSON格式，直接返回原始字符串
      return treatmentTypeStr;
    }
  }

  // 构建今日预约以及预约列表的显示格式
  Widget _buildAppointmentCard(Appointment appointment) {
    // 获取状态颜色
    Color statusColor = Color(
      int.parse(appointment.statusColor.replaceAll('#', '0xff')),
    );

    // 根据性别决定头像背景颜色
    final gender = appointment.patient?.gender ?? '';
    final Color avatarBackground =
        gender == '女' ? Colors.pink.shade100 : Colors.blue.shade100;

    final Color avatarIconColor =
        gender == '女' ? Colors.pink.shade400 : Colors.blue.shade400;

    // 获取日期和时间
    String appointmentDate =
        _formatAppointmentDate(appointment.appointment_date);
    String appointmentTime =
        _formatAppointmentTime(appointment.appointment_date);

    // 处理治疗项目显示
    String treatmentDisplay = '常规复诊';
    if (appointment.treatment_type != null &&
        appointment.treatment_type!.isNotEmpty) {
      try {
        // 尝试解析JSON格式的treatment_type
        treatmentDisplay =
            _formatTreatmentTypeForDisplay(appointment.treatment_type);
      } catch (e) {
        // 如果解析失败，使用原始字符串
        treatmentDisplay = appointment.treatment_type!;

        // 如果治疗类型包含多个项目（用顿号分隔），保持原样
        if (!treatmentDisplay.contains('{')) {
          treatmentDisplay = treatmentDisplay;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (appointment.id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailsScreen(
                  appointmentId: appointment.id!,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: avatarBackground,
                    child: Icon(gender == '女' ? Icons.female : Icons.male,
                        color: avatarIconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patient?.name ?? "未知患者",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$appointmentDate $appointmentTime',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      appointment.statusDisplay,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '治疗项目: $treatmentDisplay',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    if (appointment.cost != null) ...[
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${appointment.cost!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddEditAppointmentDialog(appointment),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text(
                      '编辑',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteAppointment(appointment),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: const Text(
                      '删除',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 计算筛选文本
    String filterText = '';
    if (_isFiltering && _endDate != null) {
      filterText =
          '显示 ${DateFormat('yyyy年MM月dd日').format(_selectedDate)} 至 ${DateFormat('yyyy年MM月dd日').format(_endDate!)} 的预约';
    } else {
      filterText = '显示所有预约，按与当前时间接近程度排序';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('预约管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditAppointmentDialog(),
            tooltip: '添加预约',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 顶部操作栏 - 改进设计
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_note,
                                color: AppTheme.primaryColor,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '共 ${_filteredAppointments.length} 个预约',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // 简化为单个按钮，直接打开日期范围选择
                              _isFiltering && _endDate != null
                                  ? OutlinedButton.icon(
                                      onPressed: _toggleFiltering,
                                      icon: const Icon(Icons.list, size: 18),
                                      label: const Text('显示全部'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: () =>
                                          _selectDateRange(context),
                                      icon: const Icon(Icons.date_range,
                                          size: 18),
                                      label: const Text('按日期筛选'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                              if (_isFiltering && _endDate != null) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    '${DateFormat('MM/dd').format(_selectedDate)} - ${DateFormat('MM/dd').format(_endDate!)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: _toggleFiltering,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (_filteredAppointments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            filterText,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 预约列表
                Expanded(
                  child: _filteredAppointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _isFiltering && _endDate != null
                                    ? '${DateFormat('MM月dd日').format(_selectedDate)} 至 ${DateFormat('MM月dd日').format(_endDate!)} 没有预约'
                                    : '暂无预约记录',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showAddEditAppointmentDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('添加预约'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredAppointments.length,
                          itemBuilder: (context, index) {
                            return _buildAppointmentCard(
                                _filteredAppointments[index]);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditAppointmentDialog(),
        tooltip: '添加预约',
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AppointmentFormDialog extends StatefulWidget {
  final DateTime initialDate;
  final Appointment? appointment;

  const AppointmentFormDialog({
    Key? key,
    required this.initialDate,
    this.appointment,
  }) : super(key: key);

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TimeOfDay _time;
  String _status = '已预约';
  Patient? _selectedPatient;
  final TextEditingController _treatmentTypeController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _patientSearchController =
      TextEditingController();
  List<Patient> _filteredPatients = [];
  List<Patient> _patients = [];
  bool _isLoadingPatients = true;

  // 牙齿情况数据
  List<Map<String, String>> _teethData = [
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
  ];

  // 治疗项目
  List<String> _selectedTreatments = [];

  @override
  void initState() {
    super.initState();

    if (widget.appointment != null) {
      final appointmentDate = widget.appointment!.appointment_date;
      _date = DateTime(
          appointmentDate.year, appointmentDate.month, appointmentDate.day);
      _time =
          TimeOfDay(hour: appointmentDate.hour, minute: appointmentDate.minute);
      _status = widget.appointment!.status;

      // 解析 treatment_type 字段
      if (widget.appointment!.treatment_type != null) {
        _parseTreatmentTypeData(widget.appointment!.treatment_type!);
      }

      _notesController.text = widget.appointment!.notes ?? '';
      _costController.text = widget.appointment!.cost?.toString() ?? '';
    } else {
      _date = widget.initialDate;
      _time = TimeOfDay.now();
      if (_time.minute > 30) {
        _time = TimeOfDay(hour: (_time.hour + 1) % 24, minute: 0);
      } else if (_time.minute > 0) {
        _time = TimeOfDay(hour: _time.hour, minute: 30);
      }
    }

    _loadPatients();
  }

  // 解析 treatment_type 字段中的数据
  void _parseTreatmentTypeData(String treatmentTypeStr) {
    try {
      // 尝试解析为JSON
      Map<String, dynamic> data = json.decode(treatmentTypeStr);

      // 提取牙齿情况数据
      if (data.containsKey('teethData')) {
        var teethJsonData = data['teethData'];
        _teethData = List<Map<String, String>>.from(
            teethJsonData.map((item) => Map<String, String>.from(item)));
      }

      // 提取治疗项目数据
      if (data.containsKey('treatments')) {
        _selectedTreatments = List<String>.from(data['treatments']);
        _updateTreatmentTypeController();
      }
    } catch (e) {
      // 如果解析失败，可能是旧数据格式，直接设为治疗项目
      print('解析treatment_type失败: $e');
      _treatmentTypeController.text = treatmentTypeStr;

      // 如果治疗类型包含多个项目（用顿号分隔），则解析为多选项目
      if (treatmentTypeStr.contains('、')) {
        _selectedTreatments = treatmentTypeStr.split('、');
      } else if (treatmentTypeStr.isNotEmpty) {
        _selectedTreatments = [treatmentTypeStr];
      }
    }
  }

  // 更新治疗项目控制器
  void _updateTreatmentTypeController() {
    if (_selectedTreatments.isEmpty) {
      _treatmentTypeController.text = '';
    } else {
      _treatmentTypeController.text = _selectedTreatments.join('、');
    }
  }

  // 准备 treatment_type 数据，将牙齿情况和治疗项目合并为一个 JSON 字符串
  String _buildTreatmentTypeData() {
    Map<String, dynamic> data = {
      'teethData': _teethData,
      'treatments': _selectedTreatments,
    };
    return json.encode(data);
  }

  @override
  void dispose() {
    _treatmentTypeController.dispose();
    _notesController.dispose();
    _costController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoadingPatients = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final patients = await dbProvider.getAllPatients();

      // 按最近更新时间倒序排序
      patients.sort((a, b) => b.updated_at.compareTo(a.updated_at));

      setState(() {
        _patients = patients;
        _filteredPatients = patients;
        _isLoadingPatients = false;

        if (widget.appointment != null &&
            widget.appointment!.patientId != null) {
          try {
            _selectedPatient = _patients.firstWhere(
              (p) => p.id == widget.appointment!.patientId,
            );
            // 选中后设置搜索框文本
            if (_selectedPatient != null) {
              _patientSearchController.text = _selectedPatient!.name;
            }
          } catch (e) {
            _selectedPatient = null;
          }
        }
      });
    } catch (e) {
      setState(() => _isLoadingPatients = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载患者数据失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 显示治疗项目选择对话框
  void _showTreatmentSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TreatmentSelectionDialog(
          selectedTreatments: _selectedTreatments,
          onConfirm: (selectedItems) {
            setState(() {
              _selectedTreatments = selectedItems;
              _updateTreatmentTypeController();
            });
          },
        );
      },
    );
  }

  // 显示患者搜索对话框
  void _showPatientSearchDialog(BuildContext context) {
    _patientSearchController.clear();
    _filteredPatients = _patients;

    // 获取主题颜色
    final accentColor = AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white.withOpacity(0.85), // 增加透明度
              elevation: 0,
              child: Container(
                width: 500, // 固定宽度，与添加预约对话框保持一致
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height *
                      0.45, // 增加高度以显示至少三行数据
                  minHeight: 300,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题和搜索框
                    Text(
                      '选择患者',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 搜索框
                    TextField(
                      controller: _patientSearchController,
                      decoration: InputDecoration(
                        hintText: '搜索患者 (姓名/电话)',
                        prefixIcon: Icon(Icons.search, color: accentColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        // 搜索过滤患者
                        setState(() {
                          if (value.isEmpty) {
                            _filteredPatients = _patients;
                          } else {
                            _filteredPatients = _patients.where((patient) {
                              // 姓名搜索
                              final nameMatch = patient.name
                                  .toLowerCase()
                                  .contains(value.toLowerCase());

                              // 电话搜索
                              bool phoneMatch = false;
                              if (patient.mainPhone.isNotEmpty) {
                                phoneMatch = patient.mainPhone.contains(value);
                              }

                              // 拼音搜索
                              bool pinyinMatch = false;
                              if (patient.name_pinyin != null) {
                                pinyinMatch = patient.name_pinyin!
                                    .toLowerCase()
                                    .contains(value.toLowerCase());

                                // 处理无空格搜索
                                if (!pinyinMatch &&
                                    patient.name_pinyin!.contains(" ")) {
                                  String noSpacePinyin =
                                      patient.name_pinyin!.replaceAll(" ", "");
                                  pinyinMatch = noSpacePinyin
                                      .toLowerCase()
                                      .contains(value.toLowerCase());
                                }
                              }

                              // 拼音首字母搜索
                              bool initialsMatch = false;
                              if (patient.name_initials != null) {
                                initialsMatch = patient.name_initials!
                                    .toLowerCase()
                                    .contains(value.toLowerCase());
                              }

                              return nameMatch ||
                                  phoneMatch ||
                                  pinyinMatch ||
                                  initialsMatch;
                            }).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 患者列表 - 表格形式显示
                    Expanded(
                      child: _isLoadingPatients
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _filteredPatients.isEmpty
                              ? Center(
                                  child: Text(
                                    '没有找到匹配的患者',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Column(
                                      children: [
                                        // 表头
                                        Container(
                                          color: Colors.grey.shade100,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '姓名',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: accentColor,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  '电话',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: accentColor,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  '最近就诊',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: accentColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 表格内容
                                        Expanded(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _filteredPatients.length,
                                            itemBuilder: (context, index) {
                                              final patient =
                                                  _filteredPatients[index];
                                              final lastVisitDate = DateFormat(
                                                      'yyyy-MM-dd')
                                                  .format(patient.updated_at);

                                              // 交替背景色
                                              final backgroundColor =
                                                  index % 2 == 0
                                                      ? Colors.white
                                                      : Colors.grey.shade50;

                                              return InkWell(
                                                onTap: () {
                                                  // 选择患者并关闭对话框
                                                  this.setState(() {
                                                    _selectedPatient = patient;
                                                  });
                                                  Navigator.of(context).pop();
                                                },
                                                child: Container(
                                                  color: backgroundColor,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          patient.name,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                            patient.mainPhone),
                                                      ),
                                                      Expanded(
                                                        flex: 3,
                                                        child:
                                                            Text(lastVisitDate),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                    ),
                    const SizedBox(height: 16),
                    // 底部按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            '取消',
                            style: TextStyle(color: accentColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 选择时间
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _time) {
      setState(() => _time = picked);
    }
  }

  // 选择日期
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加预约'),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _isLoadingPatients
                    ? const Center(child: CircularProgressIndicator())
                    : InkWell(
                        onTap: () => _showPatientSearchDialog(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '选择患者*',
                            hintText: _selectedPatient == null ? '点击选择患者' : '',
                            border: const OutlineInputBorder(),
                            suffixIcon: Icon(Icons.search,
                                color: AppTheme.primaryColor),
                          ),
                          child: _selectedPatient != null
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_selectedPatient!.name} (${_selectedPatient!.mainPhone})',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Text(
                                        '最近就诊: ${DateFormat('yyyy-MM-dd').format(_selectedPatient!.updated_at)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '预约日期*',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(_date),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '预约时间*',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            _time.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 预约详情 - 牙齿情况
                _buildTeethCondition(),

                const SizedBox(height: 16),

                // 预约详情 - 治疗项目
                _buildTreatmentSection(),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                    labelText: '费用估计',
                    hintText: '预估费用(可选)',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '预约状态',
                    border: OutlineInputBorder(),
                  ),
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: '已预约', child: Text('已预约')),
                    DropdownMenuItem(value: '已完成', child: Text('已完成')),
                    DropdownMenuItem(value: '已取消', child: Text('已取消')),
                    DropdownMenuItem(value: '未到诊', child: Text('未到诊')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '其他备注信息(可选)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedPatient != null) {
              final appointmentDateTime = DateTime(
                _date.year,
                _date.month,
                _date.day,
                _time.hour,
                _time.minute,
              );

              // 合并牙齿情况和治疗项目数据
              final String treatmentTypeData = _buildTreatmentTypeData();

              final appointment = Appointment(
                id: widget.appointment?.id,
                patient_id: _selectedPatient!.id,
                patient: _selectedPatient,
                appointment_date: appointmentDateTime,
                status: _status,
                treatment_type: treatmentTypeData,
                notes: _notesController.text.isEmpty
                    ? null
                    : _notesController.text,
                cost: _costController.text.isEmpty
                    ? null
                    : double.tryParse(_costController.text),
              );

              Navigator.of(context).pop(appointment);
            } else if (_selectedPatient == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请选择患者')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: Text(widget.appointment == null ? '添加' : '更新'),
        ),
      ],
    );
  }

  // 构建牙齿情况区域
  Widget _buildTeethCondition() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '牙齿情况',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '从医生视角看患者：左上框=患者左上牙位，右上框=患者右上牙位，左下框=患者左下牙位，右下框=患者右下牙位',
              child:
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '填写规则：输入框位置对应患者牙位，如左上输入框对应患者左上牙齿',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 第一个十字
            Expanded(child: _buildCrossWidget(0)),
            const SizedBox(width: 5), // 减小间距
            // 第二个十字
            Expanded(child: _buildCrossWidget(1)),
          ],
        ),
      ],
    );
  }

  // 构建单个十字图
  Widget _buildCrossWidget(int crossIndex) {
    return Container(
      width: 180, // 确保宽度合适
      height: 120, // 保持适当高度
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        // 获取十字图实际宽高
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // 计算十字线中心位置
        final centerY = height / 2;
        final centerX = width / 2;

        return Stack(
          children: [
            // 十字线
            Positioned.fill(
              child: CustomPaint(
                painter: _CrossPainter(),
              ),
            ),

            // 左上象限 - 避免光标错位
            Positioned(
              top: centerY - 26.0,
              left: 5.0,
              width: centerX - 8.0,
              height: 22.0,
              child: TextField(
                textAlign: TextAlign.right,
                textAlignVertical: TextAlignVertical.center, // 确保文本垂直居中
                cursorHeight: 14.0, // 设置光标高度
                cursorWidth: 1.0, // 设置光标宽度
                decoration: InputDecoration(
                  isCollapsed: true, // 折叠为最小高度
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0, horizontal: 5.0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(fontSize: 12),
                controller: TextEditingController(
                    text: _teethData[crossIndex]['topLeft']),
                onChanged: (value) {
                  setState(() {
                    _teethData[crossIndex]['topLeft'] = value;
                  });
                },
              ),
            ),

            // 右上象限 - 避免光标错位
            Positioned(
              top: centerY - 26.0,
              left: centerX + 3.0,
              width: centerX - 8.0,
              height: 22.0,
              child: TextField(
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.center, // 确保文本垂直居中
                cursorHeight: 14.0, // 设置光标高度
                cursorWidth: 1.0, // 设置光标宽度
                decoration: InputDecoration(
                  isCollapsed: true, // 折叠为最小高度
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0, horizontal: 5.0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(fontSize: 12),
                controller: TextEditingController(
                    text: _teethData[crossIndex]['topRight']),
                onChanged: (value) {
                  setState(() {
                    _teethData[crossIndex]['topRight'] = value;
                  });
                },
              ),
            ),

            // 左下象限 - 避免光标错位
            Positioned(
              top: centerY + 4.0,
              left: 5.0,
              width: centerX - 8.0,
              height: 22.0,
              child: TextField(
                textAlign: TextAlign.right,
                textAlignVertical: TextAlignVertical.center, // 确保文本垂直居中
                cursorHeight: 14.0, // 设置光标高度
                cursorWidth: 1.0, // 设置光标宽度
                decoration: InputDecoration(
                  isCollapsed: true, // 折叠为最小高度
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0, horizontal: 5.0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(fontSize: 12),
                controller: TextEditingController(
                    text: _teethData[crossIndex]['bottomLeft']),
                onChanged: (value) {
                  setState(() {
                    _teethData[crossIndex]['bottomLeft'] = value;
                  });
                },
              ),
            ),

            // 右下象限 - 避免光标错位
            Positioned(
              top: centerY + 4.0,
              left: centerX + 3.0,
              width: centerX - 8.0,
              height: 22.0,
              child: TextField(
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.center, // 确保文本垂直居中
                cursorHeight: 14.0, // 设置光标高度
                cursorWidth: 1.0, // 设置光标宽度
                decoration: InputDecoration(
                  isCollapsed: true, // 折叠为最小高度
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0, horizontal: 5.0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(fontSize: 12),
                controller: TextEditingController(
                    text: _teethData[crossIndex]['bottomRight']),
                onChanged: (value) {
                  setState(() {
                    _teethData[crossIndex]['bottomRight'] = value;
                  });
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // 构建治疗项目区域
  Widget _buildTreatmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '治疗项目',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            // 添加可点击的下拉按钮，用于选择预配置的治疗项目
            TextButton.icon(
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              label: const Text(
                '选择',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () => _showTreatmentSelectionDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 治疗项目输入框和添加按钮
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _treatmentTypeController,
                decoration: InputDecoration(
                  hintText: '输入治疗项目',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  // 当用户直接编辑文本框时，内容直接更新到控制器
                  // 但不更新已选项目列表，用户按回车或点击添加按钮时才会添加
                },
                onSubmitted: (value) {
                  _addCustomTreatment(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _addCustomTreatment(_treatmentTypeController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('添加'),
            ),
          ],
        ),

        // 已选治疗项目显示
        if (_selectedTreatments.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选治疗项目:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedTreatments
                      .map((treatment) => Chip(
                            label: Text(
                              treatment,
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedTreatments.remove(treatment);
                                _updateTreatmentTypeController();
                              });
                            },
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 添加自定义治疗项目
  void _addCustomTreatment(String treatment) {
    String trimmedTreatment = treatment.trim();
    if (trimmedTreatment.isEmpty) return;

    setState(() {
      // 如果没有重复，则添加到已选列表
      if (!_selectedTreatments.contains(trimmedTreatment)) {
        _selectedTreatments.add(trimmedTreatment);
      }
      // 清空输入框
      _treatmentTypeController.clear();
      // 更新控制器文本
      _updateTreatmentTypeController();
    });
  }
}

// 十字画笔
class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5;

    // 绘制水平线 - 明显长于竖线（占据整个宽度）
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // 绘制垂直线 - 高度约为三个字符高度
    double verticalHeight = 40; // 减小至约等于三个字符高度
    double startY = size.height / 2 - verticalHeight / 2;
    double endY = size.height / 2 + verticalHeight / 2;

    canvas.drawLine(
      Offset(size.width / 2, startY),
      Offset(size.width / 2, endY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
