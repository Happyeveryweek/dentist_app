import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:collection';
import 'dart:convert';
import '../../../models/appointment.dart';
import '../../../models/patient.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/patient_provider.dart';
import './appointment_time_picker.dart' hide CrossPainter;
import '../../../widgets/modern_date_picker.dart';
import './teeth_condition_widget.dart';
import './appointment_treatment_section.dart';
import './appointment_patient_selection_section.dart';
import './appointment_date_time_section.dart';
import './appointment_cost_status_section.dart';
import './appointment_notes_section.dart';
import './appointment_patient_search_dialog.dart';

class AppointmentFormDialog extends StatefulWidget {
  final DateTime initialDate;
  final Appointment? appointment;
  final Patient? preselectedPatient;

  const AppointmentFormDialog({
    Key? key,
    required this.initialDate,
    this.appointment,
    this.preselectedPatient,
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
  List<Patient> _patients = [];
  bool _isLoadingPatients = true;

  // 牙齿情况数据
  List<Map<String, String>> _teethData = [
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
    {'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': ''},
  ];

  // 治疗项目
  List<String> _selectedTreatments = [];
  List<String> _treatmentSuggestions = [];

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

    // 如果有预选患者，直接设置
    if (widget.preselectedPatient != null) {
      _selectedPatient = widget.preselectedPatient;
    }

    _loadPatients();
    _loadTreatmentSuggestions();
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
        _selectedTreatments = _normalizeTreatmentItems(
          List<String>.from(data['treatments']),
        );
        _updateTreatmentTypeController();
      }
    } catch (e) {
      // 如果解析失败，可能是旧数据格式，直接设为治疗项目
      print('解析treatment_type失败: $e');
      _selectedTreatments = _extractTreatmentItems(treatmentTypeStr);
      _updateTreatmentTypeController();
    }
  }

  // 更新治疗项目控制器
  void _updateTreatmentTypeController() {
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

  Future<void> _loadTreatmentSuggestions() async {
    try {
      final appointmentProvider = Provider.of<AppointmentProvider>(
        context,
        listen: false,
      );
      final appointments = await appointmentProvider.getAllAppointments();
      final suggestions = LinkedHashSet<String>();

      for (final appointment in appointments) {
        for (final item in _extractTreatmentItems(appointment.treatment_type)) {
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
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final patients = await patientProvider.getAllPatients();

      // 按最近更新时间倒序排序
      patients.sort((a, b) => b.updated_at.compareTo(a.updated_at));

      setState(() {
        _patients = patients;
        _isLoadingPatients = false;

        if (widget.appointment != null &&
            widget.appointment!.patient_id != null) {
          try {
            _selectedPatient = _patients.firstWhere(
              (p) => p.id == widget.appointment!.patient_id,
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
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingPatients = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载患者数据失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 显示治疗项目选择对话框

  // 显示患者搜索对话框

  // 显示添加患者对话框

  // 显示患者表单对话框

  // 选择时间
  Future<void> _selectTime(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ModernTimePickerDialog(
          initialTime: _time,
          onTimeSelected: (TimeOfDay time) {
            setState(() => _time = time);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // 选择日期
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
      },
    );

    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
             child: Container(
         width: MediaQuery.of(context).size.width * 0.4, // 从0.3增加到0.4，增加三分之一
         height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF667eea).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行 - 带渐变背景
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.appointment != null ? Icons.edit : Icons.add_circle_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.appointment != null ? '编辑预约' : '添加预约',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 16,
                        tooltip: '关闭',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ),
                  ],
                ),
              ),
            
                             // 表单内容
               Expanded(
                 child: SingleChildScrollView(
                   padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                 // 患者选择区域
                         AppointmentPatientSelectionSection(
                           selectedPatient: _selectedPatient,
                           hasPreselectedPatient: widget.preselectedPatient != null,
                           isLoadingPatients: _isLoadingPatients,
                           onSelectPatient: () => _showPatientSearchDialog(context),
                         ),
                          
                         const SizedBox(height: 12),
                          
                         // 时间选择区域
                         AppointmentDateTimeSection(
                           date: _date,
                           time: _time,
                           onSelectDate: () => _selectDate(context),
                           onSelectTime: () => _selectTime(context),
                         ),
                          
                         const SizedBox(height: 12),
                          
                         // 牙齿情况区域 - 使用新的独立组件
                         TeethConditionWidget(
                           teethData: _teethData,
                           onChanged: (newTeethData) {
                             setState(() {
                               _teethData = newTeethData;
                             });
                           },
                         ),
                          
                         const SizedBox(height: 12),
                          
                         // 治疗项目区域 - 使用新的独立组件
                         TreatmentSectionWidget(
                           selectedTreatments: _selectedTreatments,
                           treatmentTypeController: _treatmentTypeController,
                           suggestions: _treatmentSuggestions,
                           onTreatmentsChanged: (treatments) {
                             setState(() {
                               _selectedTreatments =
                                   _normalizeTreatmentItems(treatments);
                             });
                           },
                         ),
                          
                         const SizedBox(height: 12),
                          
                         // 费用和状态区域
                         AppointmentCostStatusSection(
                           costController: _costController,
                           status: _status,
                           onStatusChanged: (value) {
                             if (value != null) {
                               setState(() {
                                 _status = value;
                               });
                             }
                           },
                         ),
                          
                         const SizedBox(height: 12),
                          
                         // 备注区域
                         AppointmentNotesSection(
                           notesController: _notesController,
                         ),
                      ],
                    ),
                  ),
                ),
              ),
              
                             // 底部操作按钮
               Container(
                 padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate() && _selectedPatient != null) {
                          _ensurePendingTreatmentInputIncluded();
                          final appointmentDateTime = DateTime(
                            _date.year,
                            _date.month,
                            _date.day,
                            _time.hour,
                            _time.minute,
                          );
                           
                          // 构建预约对象
                          final appointment = Appointment(
                            id: widget.appointment?.id,
                            patient_id: _selectedPatient!.id,
                            patient: _selectedPatient,
                            appointment_date: appointmentDateTime,
                            status: _status,
                            treatment_type: _buildTreatmentTypeData(),
                            notes: _notesController.text.isEmpty ? null : _notesController.text,
                            cost: _costController.text.isEmpty ? null : double.tryParse(_costController.text),
                            created_at: widget.appointment?.created_at ?? DateTime.now(),
                            updated_at: DateTime.now(),
                          );

                          Navigator.of(context).pop(appointment);
                        } else if (_selectedPatient == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请选择患者')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.appointment == null ? '添加' : '更新',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AppointmentPatientSearchDialog(
          patients: _patients,
          selectedPatient: _selectedPatient,
          isLoading: _isLoadingPatients,
          onPatientSelected: (patient) {
            setState(() {
              _selectedPatient = patient;
              _patientSearchController.text = patient.name;
            });
          },
        );
      },
    );
  }
}
