import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/appointment.dart';
import '../models/dental_treatment.dart';
import '../models/patient.dart';
import '../providers/database_provider.dart';
import '../providers/patient_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_date_picker.dart';

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

    // 如果有预选患者，直接设置
    if (widget.preselectedPatient != null) {
      _selectedPatient = widget.preselectedPatient;
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
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final patients = await patientProvider.getAllPatients();

      // 按最近更新时间倒序排序
      patients.sort((a, b) => b.updated_at.compareTo(a.updated_at));

      setState(() {
        _patients = patients;
        _filteredPatients = patients;
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
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 500,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  minHeight: 300,
                ),
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
                      color: const Color(0xFF667eea).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
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
                      // 标题栏 - 带渐变背景
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.person_search,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '选择患者',
                                  style: TextStyle(
                                    fontSize: 20,
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
                            // 已移除：顶部中间的“添加”按钮按需去掉，避免未完善的添加流程
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
                      
                      // 内容区域
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 搜索框
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _patientSearchController,
                                  decoration: InputDecoration(
                                    hintText: '搜索患者 (姓名/拼音)',
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF667eea).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.search, color: accentColor, size: 20),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: accentColor, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // 患者列表标题
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: accentColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '患者列表 (${_filteredPatients.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 患者列表
                              Expanded(
                                child: _isLoadingPatients
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              '正在加载患者数据...',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : _filteredPatients.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.search_off,
                                                  size: 48,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  '没有找到匹配的患者',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '请尝试其他搜索关键词',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.grey.shade200),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey.withOpacity(0.1),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: Column(
                                                children: [
                                                  // 表头
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          accentColor.withOpacity(0.1),
                                                          accentColor.withOpacity(0.05),
                                                        ],
                                                      ),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(16),
                                                        topRight: Radius.circular(16),
                                                      ),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 2,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.person,
                                                                size: 16,
                                                                color: accentColor,
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                '姓名',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  color: accentColor,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.phone,
                                                                size: 16,
                                                                color: accentColor,
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                '电话',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  color: accentColor,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.calendar_today,
                                                                size: 16,
                                                                color: accentColor,
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                '最近就诊',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  color: accentColor,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ],
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
                                                        final patient = _filteredPatients[index];
                                                        final lastVisitDate = DateFormat('yyyy-MM-dd')
                                                            .format(patient.updated_at);

                                                        return Container(
                                                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: Colors.transparent,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Material(
                                                            color: Colors.transparent,
                                                            child: InkWell(
                                                              borderRadius: BorderRadius.circular(12),
                                                              onTap: () {
                                                                // 选择患者并关闭对话框
                                                                this.setState(() {
                                                                  _selectedPatient = patient;
                                                                });
                                                                Navigator.of(context).pop();
                                                              },
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      flex: 2,
                                                                      child: Row(
                                                                        children: [
                                                                          Container(
                                                                            width: 32,
                                                                            height: 32,
                                                                            decoration: BoxDecoration(
                                                                              color: accentColor.withOpacity(0.1),
                                                                              borderRadius: BorderRadius.circular(16),
                                                                            ),
                                                                            child: Icon(
                                                                              Icons.person,
                                                                              size: 18,
                                                                              color: accentColor,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(width: 12),
                                                                          Text(
                                                                            patient.name,
                                                                            style: const TextStyle(
                                                                              fontWeight: FontWeight.w600,
                                                                              fontSize: 14,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      flex: 3,
                                                                      child: Text(
                                                                        patient.mainPhone.isEmpty ? '暂无电话' : patient.mainPhone,
                                                                        style: TextStyle(
                                                                          color: patient.mainPhone.isEmpty ? Colors.grey.shade500 : Colors.black87,
                                                                          fontSize: 14,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      flex: 3,
                                                                      child: Row(
                                                                        children: [
                                                                          Icon(
                                                                            Icons.access_time,
                                                                            size: 14,
                                                                            color: Colors.grey.shade600,
                                                                          ),
                                                                          const SizedBox(width: 6),
                                                                          Text(
                                                                            lastVisitDate,
                                                                            style: TextStyle(
                                                                              color: Colors.grey.shade700,
                                                                              fontSize: 14,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
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
                            ],
                          ),
                        ),
                      ),
                      
                      // 底部按钮区域
                      Container(
                        padding: const EdgeInsets.all(24),
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
                                  borderRadius: BorderRadius.circular(12),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 显示添加患者对话框
  void _showAddPatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('添加新患者'),
            ],
          ),
          content: const Text('是否要添加新患者？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 这里可以导航到添加患者页面
                // 或者显示添加患者的表单对话框
                _showPatientFormDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 显示患者表单对话框
  void _showPatientFormDialog(BuildContext context) {
    // 这里可以导入并使用现有的PatientFormDialog
    // 或者创建一个简化的患者添加表单
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加新患者'),
          content: const Text('患者添加功能需要导入PatientFormDialog组件。\n\n请先完成患者添加功能后再进行预约创建。'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 选择时间
  Future<void> _selectTime(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _ModernTimePickerDialog(
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
                         _buildPatientSelectionSection(),
                          
                         const SizedBox(height: 12),
                          
                         // 时间选择区域
                         _buildDateTimeSection(),
                          
                         const SizedBox(height: 12),
                          
                         // 牙齿情况区域
                         _buildTeethCondition(),
                          
                         const SizedBox(height: 12),
                          
                         // 治疗项目区域
                         _buildTreatmentSection(),
                          
                         const SizedBox(height: 12),
                          
                         // 费用和状态区域
                         _buildCostAndStatusSection(),
                          
                         const SizedBox(height: 12),
                          
                         // 备注区域
                         _buildNotesSection(),
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

     // 构建牙齿情况区域
   Widget _buildTeethCondition() {
     return Container(
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services,
                color: const Color(0xFF2196F3),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '牙齿情况',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
                           // 第一个十字
               Expanded(child: _buildCrossWidget(0)),
               const SizedBox(width: 4),
               // 第二个十字
               Expanded(child: _buildCrossWidget(1)),
            ],
          ),
        ],
      ),
    );
  }

          // 构建单个十字图
   Widget _buildCrossWidget(int crossIndex) {
     return Container(
       width: 140, // 调整为更小的大小
       height: 100, // 调整为更小的高度
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16), // 使用更大的圆角
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 牙位标题
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '牙位 ${crossIndex + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          // 十字图
          Expanded(
            child: _buildCross(crossIndex),
          ),
        ],
      ),
    );
   }

   // 构建十字图的核心部分
   Widget _buildCross(int crossIndex) {
     // 使用固定尺寸，避免布局计算问题
     final double width = 120.0; // 调整为更小的尺寸
     final double height = 65.0; // 调整为更小的高度
     final double centerX = width / 2;
     final double centerY = height / 2;

     return Stack(
       alignment: Alignment.center,
       children: [
         // 自定义画笔绘制十字
         CustomPaint(
           size: Size(width, height),
           painter: _CrossPainter(),
         ),

         // 左上象限
         Positioned(
           top: centerY - 20,
           left: 10,
           width: centerX - 12,
           height: 18,
           child: TextField(
             textAlign: TextAlign.right,
             textAlignVertical: TextAlignVertical.center,
             cursorHeight: 14,
             cursorWidth: 1.5,
             decoration: InputDecoration(
               isCollapsed: true,
               contentPadding: const EdgeInsets.only(right: 4),
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

         // 右上象限
         Positioned(
           top: centerY - 20,
           right: 10,
           width: centerX - 12,
           height: 18,
           child: TextField(
             textAlign: TextAlign.left,
             textAlignVertical: TextAlignVertical.center,
             cursorHeight: 14,
             cursorWidth: 1.5,
             decoration: InputDecoration(
               isCollapsed: true,
               contentPadding: const EdgeInsets.only(left: 4),
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

         // 左下象限
         Positioned(
           top: centerY + 3,
           left: 10,
           width: centerX - 12,
           height: 18,
           child: TextField(
             textAlign: TextAlign.right,
             textAlignVertical: TextAlignVertical.center,
             cursorHeight: 14,
             cursorWidth: 1.5,
             decoration: InputDecoration(
               isCollapsed: true,
               contentPadding: const EdgeInsets.only(right: 4),
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

         // 右下象限
         Positioned(
           top: centerY + 3,
           right: 10,
           width: centerX - 12,
           height: 18,
           child: TextField(
             textAlign: TextAlign.left,
             textAlignVertical: TextAlignVertical.center,
             cursorHeight: 14,
             cursorWidth: 1.5,
             decoration: InputDecoration(
               isCollapsed: true,
               contentPadding: const EdgeInsets.only(left: 4),
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
   }

     // 构建治疗项目区域
   Widget _buildTreatmentSection() {
     return Container(
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.healing,
                color: const Color(0xFFFF9800),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '治疗项目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF9800),
                ),
              ),
              const Spacer(),
              // 添加可点击的下拉按钮，用于选择预配置的治疗项目
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF9800),
                      const Color(0xFFFFB74D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    '选择',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => _showTreatmentSelectionDialog(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 治疗项目输入框和添加按钮
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _treatmentTypeController,
                  decoration: InputDecoration(
                    hintText: '输入治疗项目',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: const Color(0xFFFF9800)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF9800),
                      const Color(0xFFFFB74D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _addCustomTreatment(_treatmentTypeController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    '添加',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 已选治疗项目显示
          if (_selectedTreatments.isNotEmpty)
                         Container(
               margin: const EdgeInsets.only(top: 12),
               padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFFFF9800),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '已选治疗项目:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedTreatments
                        .map((treatment) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF9800).withOpacity(0.1),
                                    const Color(0xFFFFB74D).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFF9800).withOpacity(0.3),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setState(() {
                                      _selectedTreatments.remove(treatment);
                                      _updateTreatmentTypeController();
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          treatment,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFFF9800),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.close,
                                          size: 12,
                                          color: const Color(0xFFFF9800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
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

     // 构建患者选择区域
   Widget _buildPatientSelectionSection() {
     return Container(
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: const Color(0xFF667eea),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667eea),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.preselectedPatient == null)
            _isLoadingPatients
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _selectedPatient == null
                                    ? Text(
                                        '患者姓名',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedPatient!.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '最近就诊: ${DateFormat('yyyy-MM-dd').format(_selectedPatient!.updated_at)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showPatientSearchDialog(context),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('选择'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: const Color(0xFF667eea)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '患者: ${_selectedPatient!.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667eea),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

     // 构建时间选择区域
  Widget _buildDateTimeSection() {
     return Container(
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: const Color(0xFFFF8A65),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '预约时间',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF8A65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: const Color(0xFFFF8A65)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(_date),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: const Color(0xFFFF8A65)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

     // 构建费用和状态区域
   Widget _buildCostAndStatusSection() {
     return Container(
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_money,
                color: const Color(0xFF4CAF50),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '费用与状态',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                    labelText: '费用估计',
                    hintText: '预估费用(可选)',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '预约状态',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

     // 构建备注区域
   Widget _buildNotesSection() {
     return Container(
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note,
                color: const Color(0xFF9C27B0),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '备注信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: '备注',
              hintText: '其他备注信息(可选)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// 十字画笔
class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5;

    // 绘制水平线 - 占据整个宽度
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // 绘制垂直线 - 高度约为三个字符高度
    double verticalHeight = 40; // 调整为合适的高度
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

// 现代化时间选择器对话框
class _ModernTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const _ModernTimePickerDialog({
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<_ModernTimePickerDialog> createState() => _ModernTimePickerDialogState();
}

class _ModernTimePickerDialogState extends State<_ModernTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        height: 460,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '选择时间',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            
            // 时间显示区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeSelector(
                    items: List.generate(24, (index) => index),
                    selectedValue: _selectedHour,
                    onChanged: (value) {
                      setState(() {
                        _selectedHour = value;
                      });
                    },
                    label: '时',
                    color: Colors.blue,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Text(
                      ':',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.grey),
                    ),
                  ),
                  _buildTimeSelector(
                    items: [0, 15, 30, 45],
                    selectedValue: _selectedMinute,
                    onChanged: (value) {
                      setState(() {
                        _selectedMinute = value;
                      });
                    },
                    label: '分',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
            // 快捷时间按钮（两行：上午/下午）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('快捷选择', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('上午', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildHourQuickChip(7),
                            _buildHourQuickChip(8),
                            _buildHourQuickChip(9),
                            _buildHourQuickChip(10),
                            _buildHourQuickChip(11),
                            _buildHourQuickChip(12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('下午', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildHourQuickChip(13),
                            _buildHourQuickChip(15),
                            _buildHourQuickChip(16),
                            _buildHourQuickChip(17),
                            _buildHourQuickChip(18),
                            _buildHourQuickChip(19),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 底部按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onTimeSelected(
                          TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 14,
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
  }

  Widget _buildTimeSelector({
    required List<int> items,
    required int selectedValue,
    required Function(int) onChanged,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        // 时间选择器
        Container(
          height: 96,
          width: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final value = items[index];
              final isSelected = value == selectedValue;
              
              return StatefulBuilder(
                builder: (context, setLocal) {
                  bool hovering = false;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setLocal(() => hovering = true),
                    onExit: (_) => setLocal(() => hovering = false),
                    child: GestureDetector(
                      onTap: () => onChanged(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hovering && !isSelected ? Colors.grey.shade100 : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          value.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: isSelected ? 24 : 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? color
                                : (hovering ? AppTheme.primaryColor : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 标签
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHourQuickChip(int hour) {
    final isSelected = _selectedHour == hour && _selectedMinute == 0;
    bool hovering = false;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setLocal(() => hovering = true),
          onExit: (_) => setLocal(() => hovering = false),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedHour = hour;
                _selectedMinute = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (hovering ? Colors.grey.shade200 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade300),
                ),
              ),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade800),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickTimeButton(String label, String time, int hour, int minute) {
    final isSelected = _selectedHour == hour && _selectedMinute == minute;
    
    bool hovering = false;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setLocal(() => hovering = true),
          onExit: (_) => setLocal(() => hovering = false),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedHour = hour;
                _selectedMinute = minute;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (hovering ? Colors.grey.shade200 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade300),
                ),
                boxShadow: hovering && !isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                '$label\n$time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}