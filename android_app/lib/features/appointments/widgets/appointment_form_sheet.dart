import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';
import 'package:dentist_app/features/patients/widgets/patient_selection_dialog.dart';
import 'package:dentist_app/features/appointments/widgets/time_picker_dialog.dart'
    as custom;
import 'package:dentist_app/features/appointments/widgets/teeth_condition_input.dart';
import 'package:dentist_app/features/appointments/widgets/treatment_items_input.dart';
import 'package:dentist_app/widgets/date_time_card.dart';

class AppointmentFormSheet extends StatefulWidget {
  final Appointment? appointment;
  final Function(bool isSuccess, String message) onSaved;
  final DateTime? initialDate;

  const AppointmentFormSheet({
    super.key,
    this.appointment,
    required this.onSaved,
    this.initialDate,
  });

  @override
  State<AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<AppointmentFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // 表单数据
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int? _selectedPatientId;
  String _status = 'scheduled';
  String _notes = '';
  double _cost = 0.0;

  // 牙齿情况数据
  List<Map<String, String>> _teethData = [
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
  ];

  // 治疗项目
  List<String> _selectedTreatments = [];
  List<String> _treatmentSuggestions = [];

  // 患者相关
  bool _isLoading = true;
  String _selectedPatientName = '';
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _treatmentTypeController =
      TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // 状态映射
  final Map<String, String> _statusMapping = {
    '已预约': 'scheduled',
    '已完成': 'completed',
    '已取消': 'cancelled',
    'scheduled': 'scheduled',
    'completed': 'completed',
    'cancelled': 'cancelled',
  };

  // 反向状态映射
  final Map<String, String> _reverseStatusMapping = {
    'scheduled': '已预约',
    'completed': '已完成',
    'cancelled': '已取消',
  };

  @override
  void initState() {
    super.initState();
    _loadTreatmentSuggestions();
    // 不再自动加载患者数据，只在需要时加载

    // 如果是编辑模式，初始化表单数据
    if (widget.appointment != null) {
      final appointment = widget.appointment!;
      _selectedDate = appointment.appointmentDate;
      _selectedTime = TimeOfDay.fromDateTime(appointment.appointmentDate);
      _selectedPatientId = appointment.patientId;
      // 将数据库中的状态值映射到表单值
      _status = _statusMapping[appointment.status] ?? 'scheduled';
      _notes = appointment.notes ?? '';
      _cost = appointment.cost;

      // 解析 treatment_type 字段
      if (appointment.treatmentType != null &&
          appointment.treatmentType!.isNotEmpty) {
        _parseTreatmentTypeData(appointment.treatmentType!);
      }

      // 设置控制器值
      _costController.text = _cost.toString();
      _notesController.text = _notes;

      // 编辑模式下只加载当前患者姓名，避免打开表单时全量拉取患者列表
      _loadSelectedPatientName();
    } else {
      // 新建预约模式，不预加载患者数据
      // 设置加载状态为false，因为不需要加载患者数据
      _isLoading = false;

      // 如果有初始日期参数，使用它
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
        _selectedTime = const TimeOfDay(hour: 9, minute: 0);
      } else {
        // 新建预约，默认为当前时间后一小时，向上取整到30分钟
        final now = DateTime.now();
        final minutes = now.minute;
        final roundedMinutes = (minutes / 30).ceil() * 30;
        _selectedDate = now;
        _selectedTime = TimeOfDay(
          hour: (now.hour + (roundedMinutes >= 60 ? 1 : 0)) % 24,
          minute: roundedMinutes % 60,
        );
      }
    }
  }

  Future<void> _loadTreatmentSuggestions() async {
    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(
        context,
        listen: false,
      );
      final appointments = await appointmentsProvider.getAllAppointments();
      final suggestions = LinkedHashSet<String>();

      for (final appointment in appointments) {
        for (final item in _extractTreatmentItems(appointment.treatmentType)) {
          suggestions.add(item);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _treatmentSuggestions = suggestions.toList();
      });
    } catch (e) {
      print('加载治疗项目下拉数据失败: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _treatmentSuggestions = [];
      });
    }
  }

  Future<void> _loadSelectedPatientName() async {
    if (_selectedPatientId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final patient = await Provider.of<PatientProvider>(
        context,
        listen: false,
      ).getPatientById(_selectedPatientId!);
      setState(() {
        if (patient != null) {
          _selectedPatientName = patient.name;
          _patientNameController.text = patient.name;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('加载当前患者数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
          teethJsonData.map((item) => Map<String, String>.from(item)),
        );
      }

      // 提取治疗项目数据
      if (data.containsKey('treatments')) {
        _selectedTreatments = _normalizeTreatmentItems(
          List<String>.from(data['treatments']),
        );
        _updateTreatmentTypeController();
      }
    } catch (e) {
      // 如果解析失败，可能是旧数据格式，直接设为治疗项目
      print('解析treatment_type失败: $e');
      _selectedTreatments = _extractTreatmentItems(treatmentTypeStr);
    }
  }

  // 更新治疗项目控制器
  void _updateTreatmentTypeController() {
    _treatmentTypeController.clear();
  }

  List<String> _normalizeTreatmentItems(List<String> items) {
    return LinkedHashSet<String>.from(
      items.map((item) => item.trim()).where((item) => item.isNotEmpty),
    ).toList();
  }

  List<String> _extractTreatmentItems(String? source) {
    if (source == null || source.trim().isEmpty) {
      return [];
    }

    final trimmed = source.trim();

    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic> && decoded['treatments'] is List) {
        return _normalizeTreatmentItems(
          List<String>.from(decoded['treatments']),
        );
      }
    } catch (_) {}

    return _normalizeTreatmentItems(trimmed.split(RegExp(r'[、,，\n]')));
  }

  void _ensurePendingTreatmentInputIncluded() {
    final pending = _treatmentTypeController.text.trim();
    if (pending.isEmpty) {
      return;
    }

    _selectedTreatments = _normalizeTreatmentItems([
      ..._selectedTreatments,
      pending,
    ]);
    _treatmentTypeController.clear();
  }

  // 准备 treatment_type 数据，将牙齿情况和治疗项目合并为一个 JSON 字符串
  String _buildTreatmentTypeData() {
    Map<String, dynamic> data = {
      'teethData': _teethData,
      'treatments': _selectedTreatments,
    };
    return json.encode(data);
  }

  Future<void> _saveAppointment() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择患者'), duration: Duration(seconds: 2)),
      );
      return;
    }

    // 设置加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      _ensurePendingTreatmentInputIncluded();

      // 合并日期和时间
      final appointmentDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final appointment = Appointment(
        id: widget.appointment?.id,
        patientId: _selectedPatientId!,
        appointmentDate: appointmentDate,
        // 将表单状态值映射回数据库状态值
        status: _reverseStatusMapping[_status] ?? _status,
        treatmentType: _buildTreatmentTypeData(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        cost: double.tryParse(_costController.text) ?? 0.0,
      );

      final appointmentsProvider = Provider.of<AppointmentsProvider>(
        context,
        listen: false,
      );

      if (widget.appointment == null) {
        // 新建预约
        await appointmentsProvider.addAppointment(appointment);
      } else {
        // 更新预约
        await appointmentsProvider.updateAppointment(appointment);
      }

      // 重置加载状态
      setState(() {
        _isLoading = false;
      });

      // 先关闭表单
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // 通知父组件刷新并显示成功消息
      widget.onSaved(true, widget.appointment == null ? '预约创建成功' : '预约更新成功');
    } catch (e) {
      // 重置加载状态
      setState(() {
        _isLoading = false;
      });

      // 通知父组件显示错误消息
      widget.onSaved(false, '保存失败: $e');
      print('保存预约错误: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          title: '选择预约日期',
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final newTime = await showDialog<TimeOfDay>(
      context: context,
      builder:
          (context) =>
              custom.CustomTimePickerDialog(initialTime: _selectedTime),
    );

    if (newTime != null && newTime != _selectedTime) {
      setState(() {
        _selectedTime = newTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointment == null ? '新建预约' : '编辑预约'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          top: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 患者选择区域
              _buildModernSection(
                title: '患者信息',
                icon: Icons.person_outline_rounded,
                child: _buildPatientSelection(),
              ),
              const SizedBox(height: 20),

              // 预约时间区域
              _buildModernSection(
                title: '预约时间',
                icon: Icons.access_time_rounded,
                child: _buildDateTimeSelection(),
              ),
              const SizedBox(height: 20),

              // 状态区域
              _buildModernSection(
                title: '预约状态',
                icon: Icons.flag_outlined,
                child: _buildStatusSelection(),
              ),
              const SizedBox(height: 20),

              // 牙位情况区域
              _buildModernSection(
                title: '牙位情况',
                icon: Icons.medical_services_outlined,
                child: TeethConditionInput(
                  teethData: _teethData,
                  onChanged: (newData) {
                    setState(() {
                      _teethData = newData;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 治疗信息区域
              _buildModernSection(
                title: '治疗项目',
                icon: Icons.healing_outlined,
                child: TreatmentItemsInput(
                  controller: _treatmentTypeController,
                  selectedTreatments: _selectedTreatments,
                  suggestions: _treatmentSuggestions,
                  onChanged: (newTreatments) {
                    setState(() {
                      _selectedTreatments =
                          _normalizeTreatmentItems(newTreatments);
                      _updateTreatmentTypeController();
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 备注区域
              _buildModernSection(
                title: '备注',
                icon: Icons.notes_outlined,
                child: _buildNotesSection(),
              ),
              const SizedBox(height: 24),

              // 底部操作按钮
              _buildModernActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // 现代化标题栏
  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.appointment == null
                  ? Icons.add_circle_outline_rounded
                  : Icons.edit_calendar_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appointment == null ? '新建预约' : '编辑预约',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请填写预约信息',
                  style: TextStyle(fontSize: 14, color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.1),
              foregroundColor: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // 现代化区域包装器
  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // 患者选择区域
  Widget _buildPatientSelection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return InkWell(
      onTap: _showPatientSelectionDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _selectedPatientId != null
                    ? AppTheme.primaryColor.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_rounded,
              color:
                  _selectedPatientId != null
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryText,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedPatientName.isNotEmpty
                    ? _selectedPatientName
                    : '请选择患者',
                style: TextStyle(
                  fontSize: 16,
                  color:
                      _selectedPatientName.isNotEmpty
                          ? AppTheme.primaryText
                          : AppTheme.secondaryText,
                  fontWeight:
                      _selectedPatientName.isNotEmpty
                          ? FontWeight.w500
                          : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.person_search_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // 日期时间选择区域
  Widget _buildDateTimeSelection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DateTimeCard(
                title: '日期',
                value: DateFormat('yyyy-MM-dd').format(_selectedDate),
                icon: Icons.calendar_today_rounded,
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DateTimeCard(
                title: '时间',
                value: _selectedTime.format(context),
                icon: Icons.access_time_rounded,
                onTap: () => _selectTime(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 状态选择区域
  Widget _buildStatusSelection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonFormField<String>(
        value: _status,
        decoration: InputDecoration(
          hintText: '选择状态',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: AppTheme.backgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        items: [
          _buildModernDropdownItem(
            'scheduled',
            '已预约',
            Icons.schedule_rounded,
            AppTheme.infoColor,
          ),
          _buildModernDropdownItem(
            'completed',
            '已完成',
            Icons.check_circle_rounded,
            AppTheme.successColor,
          ),
          _buildModernDropdownItem(
            'cancelled',
            '已取消',
            Icons.cancel_rounded,
            AppTheme.errorColor,
          ),
        ],
        onChanged: (value) {
          setState(() {
            _status = value!;
          });
        },
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }

  // 现代化下拉菜单项
  DropdownMenuItem<String> _buildModernDropdownItem(
    String value,
    String text,
    IconData icon,
    Color color,
  ) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // 备注信息区域
  Widget _buildNotesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: _notesController,
        decoration: InputDecoration(
          hintText: '输入备注信息',
          hintStyle: TextStyle(color: AppTheme.secondaryText),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.note_alt_rounded,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        maxLines: 3,
        style: const TextStyle(fontSize: 16, color: AppTheme.primaryText),
      ),
    );
  }

  // 现代化操作按钮
  Widget _buildModernActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.secondaryText,
              side: BorderSide(color: AppTheme.secondaryText.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '取消',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      widget.appointment == null ? '创建预约' : '更新预约',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  // 显示患者选择对话框
  Future<void> _showPatientSelectionDialog() async {
    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );

    final selectedPatient = await showDialog<Patient>(
      context: context,
      builder:
          (context) => PatientSelectionDialog(
            patients: const [],
            onLoadPatients:
                () => patientProvider.getPatientsPage(
                  1,
                  50,
                  sortField: 'updated',
                  ascending: false,
                ),
            onSearchPatients: patientProvider.searchPatients,
          ),
    );

    if (selectedPatient != null) {
      setState(() {
        _selectedPatientId = selectedPatient.id;
        _selectedPatientName = selectedPatient.name;
        _patientNameController.text = _selectedPatientName;
      });
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _treatmentTypeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
