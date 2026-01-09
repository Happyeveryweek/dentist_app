import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';
import 'package:dentist_app/widgets/patient_form_sheet.dart';
import 'package:dentist_app/utils/pinyin_util.dart';
import 'package:dentist_app/widgets/stateful_text_field.dart';

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
  String _treatmentType = '';
  String _notes = '';
  double _cost = 0.0;

  // 牙齿情况数据
  List<Map<String, String>> _teethData = [
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
  ];

  // 治疗项目
  List<String> _selectedTreatments = [];

  // 患者相关
  List<Patient> _patients = [];
  bool _isLoading = true;
  String _selectedPatientName = '';
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _treatmentTypeController = TextEditingController();
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
    // 不再自动加载患者数据，只在需要时加载

    // 如果是编辑模式，初始化表单数据
    if (widget.appointment != null) {
      final appointment = widget.appointment!;
      _selectedDate = appointment.appointmentDate;
      _selectedTime = TimeOfDay.fromDateTime(appointment.appointmentDate);
      _selectedPatientId = appointment.patientId;
      // 将数据库中的状态值映射到表单值
      _status = _statusMapping[appointment.status] ?? 'scheduled';
      _treatmentType = appointment.treatmentType ?? '';
      _notes = appointment.notes ?? '';
      _cost = appointment.cost;
      
      // 解析 treatment_type 字段
      if (appointment.treatmentType != null && appointment.treatmentType!.isNotEmpty) {
        _parseTreatmentTypeData(appointment.treatmentType!);
      }
      
      // 设置控制器值
      _costController.text = _cost.toString();
      _notesController.text = _notes;
      
      // 编辑模式下需要立即加载患者数据来显示当前选中的患者
      _loadPatients();
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

  // 根据患者ID设置患者姓名
  void _setPatientNameFromId(int? patientId) {
    if (patientId != null) {
      final patient = _patients.firstWhere(
        (p) => p.id == patientId,
        orElse: () => Patient(
          id: 0, 
          name: '', 
          age: 0,
          gender: '男',
          phone: '', 
          createdAt: DateTime.now(), 
          updatedAt: DateTime.now()
        ),
      );
      if (patient.id != 0) {
        _selectedPatientName = patient.name;
        _patientNameController.text = patient.name;
      }
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final patients = await Provider.of<PatientProvider>(context, listen: false).getAllPatients();

      // 按 updated_at 降序排序
      patients.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      setState(() {
        _patients = patients;
        _isLoading = false;
      });
      
      // 加载患者数据后，如果是编辑模式，设置患者姓名
      if (widget.appointment != null && _selectedPatientId != null) {
        _setPatientNameFromId(_selectedPatientId);
      }
    } catch (e) {
      print('加载患者数据错误: $e');
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
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

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

      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      
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
    // 当前选择的小时和分钟
    int hour = _selectedTime.hour;
    int minute = _selectedTime.minute;

    // 用于手动输入的控制器
    final hourController = TextEditingController(
      text: hour.toString().padLeft(2, '0'),
    );
    final minuteController = TextEditingController(
      text: minute.toString().padLeft(2, '0'),
    );

    // 显示自定义24小时制时间选择对话框
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '选择时间',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 内容区域
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      // 更新文本框的值
                      void updateTextFieldsFromValues() {
                        hourController.text = hour.toString().padLeft(2, '0');
                        minuteController.text = minute.toString().padLeft(2, '0');
                      }

                      // 从文本框更新值
                      void updateValuesFromTextFields() {
                        final h = int.tryParse(hourController.text);
                        final m = int.tryParse(minuteController.text);

                        if (h != null && h >= 0 && h < 24) {
                          hour = h;
                        }
                        if (m != null && m >= 0 && m < 60) {
                          minute = m;
                        }
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 手动输入时间
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 小时输入
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: hourController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue, width: 2),
                                      ),
                                      hintText: '时',
                                      hintStyle: TextStyle(color: Colors.grey.shade400),
                                      filled: true,
                                      fillColor: Colors.blue.shade50,
                                    ),
                                    onChanged: (value) {
                                      final h = int.tryParse(value);
                                      if (h != null && h >= 0 && h < 24) {
                                        setState(() {
                                          hour = h;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    ':',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                // 分钟输入
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: minuteController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue, width: 2),
                                      ),
                                      hintText: '分',
                                      hintStyle: TextStyle(color: Colors.grey.shade400),
                                      filled: true,
                                      fillColor: Colors.blue.shade50,
                                    ),
                                    onChanged: (value) {
                                      final m = int.tryParse(value);
                                      if (m != null && m >= 0 && m < 60) {
                                        setState(() {
                                          minute = m;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 小时选择器
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time, color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '小时',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 120,
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 6,
                                        childAspectRatio: 1.2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                      ),
                                  itemCount: 24,
                                  padding: const EdgeInsets.all(8),
                                  itemBuilder: (context, index) {
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          hour = index;
                                          updateTextFieldsFromValues();
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              hour == index
                                                  ? Colors.blue.shade400
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: hour == index
                                                ? Colors.blue.shade400
                                                : Colors.grey.shade300,
                                            width: hour == index ? 2 : 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            color:
                                                hour == index
                                                    ? Colors.white
                                                    : Colors.blue.shade700,
                                            fontWeight:
                                                hour == index
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // 分钟选择器
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timer, color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '分钟',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 120,
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 6,
                                        childAspectRatio: 1.2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                      ),
                                  itemCount: 12,
                                  padding: const EdgeInsets.all(8),
                                  itemBuilder: (context, index) {
                                    final m = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55][index];
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          minute = m;
                                          updateTextFieldsFromValues();
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              minute == m
                                                  ? Colors.blue.shade400
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: minute == m
                                                ? Colors.blue.shade400
                                                : Colors.grey.shade300,
                                            width: minute == m ? 2 : 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          m.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            color:
                                                minute == m
                                                    ? Colors.white
                                                    : Colors.blue.shade700,
                                            fontWeight:
                                                minute == m
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                // 操作按钮
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '确定',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      if (value == true) {
        final newTime = TimeOfDay(hour: hour, minute: minute);
        if (newTime != _selectedTime) {
          setState(() {
            _selectedTime = newTime;
          });
        }
      }
    });
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
                child: _buildTeethConditionSection(),
              ),
              const SizedBox(height: 20),

              // 治疗信息区域
              _buildModernSection(
                title: '治疗项目',
                icon: Icons.healing_outlined,
                child: _buildTreatmentInfo(),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
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
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedPatientId != null 
                ? AppTheme.primaryColor.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_rounded,
                color: _selectedPatientId != null 
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
                    color: _selectedPatientName.isNotEmpty 
                      ? AppTheme.primaryText 
                      : AppTheme.secondaryText,
                    fontWeight: _selectedPatientName.isNotEmpty 
                      ? FontWeight.w500 
                      : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showPatientSelectionDialog(),
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text('选择患者'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // 日期时间选择区域
  Widget _buildDateTimeSelection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateTimeCard(
                title: '日期',
                value: DateFormat('yyyy-MM-dd').format(_selectedDate),
                icon: Icons.calendar_today_rounded,
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateTimeCard(
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

  // 日期时间卡片
  Widget _buildDateTimeCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryText,
              ),
            ),
          ],
        ),
      ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: [
          _buildModernDropdownItem('scheduled', '已预约', Icons.schedule_rounded, AppTheme.infoColor),
          _buildModernDropdownItem('completed', '已完成', Icons.check_circle_rounded, AppTheme.successColor),
          _buildModernDropdownItem('cancelled', '已取消', Icons.cancel_rounded, AppTheme.errorColor),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 牙位情况区域
  Widget _buildTeethConditionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '从医生视角看患者',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: '显示的是患者的实际牙位（右上、左上、右下、左下）',
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTeethCrossInput(0)),
            const SizedBox(width: 12),
            Expanded(child: _buildTeethCrossInput(1)),
          ],
        ),
      ],
    );
  }

  // 构建单个十字图输入组件
  Widget _buildTeethCrossInput(int crossIndex) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '牙位 ${crossIndex + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final centerX = width / 2;
                final centerY = height / 2;
                
                return CustomPaint(
                  painter: _TeethCrossPainter(),
                  child: Stack(
                    children: [
                      // 右上象限
                      Positioned(
                        top: 0,
                        left: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2, bottom: 1),
                            child: _buildTeethInput(crossIndex, 'topLeft', TextAlign.right),
                          ),
                        ),
                      ),
                      // 左上象限
                      Positioned(
                        top: 0,
                        right: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, bottom: 1),
                            child: _buildTeethInput(crossIndex, 'topRight', TextAlign.left),
                          ),
                        ),
                      ),
                      // 右下象限
                      Positioned(
                        bottom: 0,
                        left: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2, top: 1),
                            child: _buildTeethInput(crossIndex, 'bottomLeft', TextAlign.right),
                          ),
                        ),
                      ),
                      // 左下象限
                      Positioned(
                        bottom: 0,
                        right: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, top: 1),
                            child: _buildTeethInput(crossIndex, 'bottomRight', TextAlign.left),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建单个牙位输入框 - 使用有状态组件彻底解决删除问题
  Widget _buildTeethInput(int crossIndex, String position, TextAlign textAlign) {
    final value = _teethData[crossIndex][position] ?? '';
    return StatefulTextField(
      initialValue: value,
      onChanged: (newValue) {
        setState(() {
          _teethData[crossIndex][position] = newValue;
        });
      },
      textAlign: textAlign,
      style: const TextStyle(fontSize: 11),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.all(2),
        isDense: true,
        filled: false,
      ),
      maxLines: 1,
    );
  }

  // 治疗项目区域
  Widget _buildTreatmentInfo() {
    return Column(
      children: [
        // 治疗项目输入和选择
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _treatmentTypeController,
                hint: '输入治疗项目',
                icon: Icons.healing_rounded,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                // 添加治疗项目
                if (_treatmentTypeController.text.isNotEmpty) {
                  setState(() {
                    if (!_selectedTreatments.contains(_treatmentTypeController.text)) {
                      _selectedTreatments.add(_treatmentTypeController.text);
                    }
                    _treatmentTypeController.clear();
                    _updateTreatmentTypeController();
                  });
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primaryColor,
            ),
          ],
        ),
        if (_selectedTreatments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTreatments.map((treatment) {
              return Chip(
                label: Text(treatment),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    _selectedTreatments.remove(treatment);
                    _updateTreatmentTypeController();
                  });
                },
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                labelStyle: const TextStyle(color: AppTheme.primaryText),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // 现代化文本输入框
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.secondaryText),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppTheme.primaryText,
        ),
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
            child: Icon(Icons.note_alt_rounded, color: AppTheme.primaryColor, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        maxLines: 3,
        style: const TextStyle(
          fontSize: 16,
          color: AppTheme.primaryText,
        ),
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
            child: _isLoading
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  // 显示患者选择对话框
  Future<void> _showPatientSelectionDialog() async {
    // 在显示患者选择对话框时才加载患者数据
    if (_patients.isEmpty) {
      await _loadPatients();
    }
    
    final selectedPatient = await showDialog<Patient>(
      context: context,
      builder: (context) => _PatientSelectionDialog(
        patients: _patients,
        onPatientAdded: () {
          _loadPatients();
        },
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

// 新增：患者选择对话框
class _PatientSelectionDialog extends StatefulWidget {
  final List<Patient> patients;
  final VoidCallback? onPatientAdded; // 新增：患者添加成功回调

  const _PatientSelectionDialog({
    required this.patients,
    this.onPatientAdded,
  });

  @override
  State<_PatientSelectionDialog> createState() => _PatientSelectionDialogState();
}

class _PatientSelectionDialogState extends State<_PatientSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    // 如果患者列表为空，显示加载状态
    if (widget.patients.isEmpty) {
      _filteredPatients = [];
    } else {
      _filteredPatients = List.from(widget.patients);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPatients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = List.from(widget.patients);
      } else {
        _filteredPatients = widget.patients.where((patient) {
          final queryLower = query.toLowerCase();
          
          // 姓名搜索
          final nameMatch = patient.name.toLowerCase().contains(queryLower);
          
          // 电话号码搜索
          final phoneMatch = patient.phone.toLowerCase().contains(queryLower);
          
          // 拼音搜索支持
          bool pinyinMatch = false;
          bool initialsMatch = false;
          
          if (patient.name.isNotEmpty) {
            try {
              // 获取完整拼音（无空格）
              final pinyin = PinyinUtil.toPinyin(patient.name, separator: '').toLowerCase();
              // 获取拼音首字母
              final initials = PinyinUtil.getInitials(patient.name).toLowerCase();
              
              pinyinMatch = pinyin.contains(queryLower);
              initialsMatch = initials.contains(queryLower);
            } catch (e) {
              print('拼音搜索错误: $e');
            }
          }
          
          return nameMatch || phoneMatch || pinyinMatch || initialsMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_search,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '选择患者',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索患者 (姓名/拼音/首字母)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _filterPatients,
              ),
            ),
            
            // 患者列表标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '患者列表 (${_filteredPatients.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 患者列表
            Expanded(
              child: _filteredPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.patients.isEmpty)
                            // 显示加载状态
                            Column(
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '正在加载患者数据...',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          else
                            // 显示空状态或搜索结果
                            Column(
                              children: [
                                Icon(
                                  _searchController.text.isEmpty ? Icons.people_outline : Icons.search_off,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty ? '暂无患者数据' : '未找到匹配的患者',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patient = _filteredPatients[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                patient.name.isNotEmpty ? patient.name[0] : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              patient.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '电话: ${_getDisplayPhone(patient.phone)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop(patient);
                            },
                          ),
                        );
                      },
                    ),
            ),
            
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 从JSON格式中获取显示电话号码
  String _getDisplayPhone(String phone) {
    if (phone.startsWith('[') && phone.endsWith(']')) {
      try {
        List<dynamic> phones = jsonDecode(phone);
        if (phones.isNotEmpty) {
          return phones[0].toString();
        }
      } catch (e) {
        print('解析电话号码JSON失败: $e');
      }
    }
    return phone;
  }

  // 添加新患者
  Future<void> _addNewPatient() async {
    // 关闭当前对话框
    Navigator.of(context).pop();
    
    // 延迟一下，确保对话框完全关闭
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 显示患者添加表单
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PatientFormSheet(
        onSaved: (isSuccess, message) {
          // 处理患者保存结果
          if (isSuccess) {
            // 通过回调函数刷新患者列表
            widget.onPatientAdded?.call();
          }
          return isSuccess;
        },
      ),
    );
    
    // 如果添加成功，显示成功提示
    if (result == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('患者添加成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}


// 十字画笔 - 用于绘制牙位十字图
class _TeethCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制水平线 - 占据整个宽度
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );

    // 绘制垂直线 - 长度为横线的二分之一
    final verticalLineLength = size.width / 2;
    final verticalStartY = centerY - verticalLineLength / 2;
    final verticalEndY = centerY + verticalLineLength / 2;
    
    canvas.drawLine(
      Offset(centerX, verticalStartY),
      Offset(centerX, verticalEndY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
