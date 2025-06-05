import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/dental_treatment.dart';
import '../models/patient.dart';
import '../providers/database_provider.dart';
import '../theme/app_theme.dart';

class AppointmentFormDialog extends StatefulWidget {
  final int? patientId; // 可以为空，允许选择患者
  final Appointment? appointment; // 如果是编辑模式，传入预约对象

  const AppointmentFormDialog({
    Key? key,
    this.patientId,
    this.appointment,
  }) : super(key: key);

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // 控制器
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _patientSearchController =
      TextEditingController();

  // 表单数据
  late DateTime _appointmentDate;
  String _treatmentType = '常规检查';
  String _status = '已预约';
  int? _selectedPatientId;

  // 患者数据
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoadingPatients = false;
  bool _patientDropdownOpen = false;
  bool _isPatientSearchDialogOpen = false;

  // 治疗类型选项
  final List<String> _treatmentTypes = [
    '洗牙',
    '补牙',
    '根管治疗',
    '杀神经',
    '根管准备',
    '根管填充',
    '烤瓷牙',
    '全瓷牙',
    '活动牙',
    '吸附性义齿',
    '正畸',
  ];

  // 已选择的治疗项目
  List<String> _selectedTreatments = [];

  // 自定义治疗项目
  TextEditingController _customTreatmentController = TextEditingController();

  // 状态选项
  final List<String> _statusOptions = [
    '已预约',
    '已完成',
    '已取消',
    '未到诊',
  ];

  @override
  void initState() {
    super.initState();
    _appointmentDate = DateTime.now().add(const Duration(days: 1));
    _appointmentDate = DateTime(
      _appointmentDate.year,
      _appointmentDate.month,
      _appointmentDate.day,
      9, // 默认上午9点
      0,
    );

    // 如果是编辑模式，加载预约数据
    if (widget.appointment != null) {
      _appointmentDate = widget.appointment!.appointment_date;
      _treatmentType = widget.appointment!.treatment_type ?? '常规检查';
      _status = widget.appointment!.status;
      _selectedPatientId = widget.appointment!.patient_id;

      // 如果治疗类型包含多个项目（用逗号分隔），则解析为多选项目
      if (_treatmentType.contains('、')) {
        _selectedTreatments = _treatmentType.split('、');
      }

      if (widget.appointment!.notes != null) {
        _notesController.text = widget.appointment!.notes!;
      }

      if (widget.appointment!.cost != null) {
        _costController.text = widget.appointment!.cost!.toString();
      }
    } else {
      // 如果传入了patientId，使用该ID
      _selectedPatientId = widget.patientId;
    }

    // 初始化日期和时间控制器
    _dateController.text = DateFormat('yyyy-MM-dd').format(_appointmentDate);
    _timeController.text = DateFormat('HH:mm').format(_appointmentDate);

    // 加载患者数据
    _loadPatients();

    // 添加患者搜索监听
    _patientSearchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _costController.dispose();
    _patientSearchController.removeListener(_filterPatients);
    _patientSearchController.dispose();
    _customTreatmentController.dispose();
    super.dispose();
  }

  // 加载患者列表
  Future<void> _loadPatients() async {
    if (mounted) {
      setState(() {
        _isLoadingPatients = true;
      });
    }

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      List<Patient> patients = await dbProvider.getAllPatients();

      // 按更新时间倒序排序（最近更新的在前面）
      patients.sort((a, b) => b.updated_at.compareTo(a.updated_at));

      if (mounted) {
        setState(() {
          _allPatients = patients;
          _filteredPatients = patients;
          _isLoadingPatients = false;
        });
      }

      // 如果有选中的患者ID，尝试在列表中查找该患者，并显示其名称
      if (_selectedPatientId != null) {
        _setSelectedPatientName();
      }
    } catch (e) {
      print('加载患者数据错误: $e');
      if (mounted) {
        setState(() {
          _isLoadingPatients = false;
        });
      }
    }
  }

  // 设置选中患者的名称
  void _setSelectedPatientName() {
    final selectedPatient = _allPatients.firstWhere(
      (p) => p.id == _selectedPatientId,
      orElse: () => Patient(
        id: _selectedPatientId,
        name: '未知患者',
        age: 0,
        gender: '未知',
        phone: '',
        first_visit_date: DateTime.now(),
      ),
    );

    if (mounted && selectedPatient.id != null) {
      _patientSearchController.text = selectedPatient.name;
    }
  }

  // 根据搜索文本筛选患者
  void _filterPatients() {
    final query = _patientSearchController.text.toLowerCase();

    // 如果查询为空且下拉框已关闭，则不做任何操作
    if (query.isEmpty && !_patientDropdownOpen) {
      return;
    }

    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _allPatients;
      } else {
        _filteredPatients = _allPatients.where((patient) {
          // 通过姓名搜索
          final nameMatch = patient.name.toLowerCase().contains(query);

          // 通过拼音搜索
          bool pinyinMatch = false;
          if (patient.name_pinyin != null) {
            pinyinMatch = patient.name_pinyin!.toLowerCase().contains(query);
          }

          // 通过拼音首字母搜索
          bool initialsMatch = false;
          if (patient.name_initials != null) {
            initialsMatch =
                patient.name_initials!.toLowerCase().contains(query);
          }

          return nameMatch || pinyinMatch || initialsMatch;
        }).toList();
      }

      // 总是显示下拉框
      _patientDropdownOpen = true;
    });
  }

  // 在数据库中实时搜索患者
  Future<void> _searchPatientsInDatabase(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredPatients = _allPatients;
      });
      return;
    }

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      List<Patient> searchResults = await dbProvider.searchPatients(query);

      // 按更新时间倒序排序
      searchResults.sort((a, b) => b.updated_at.compareTo(a.updated_at));

      if (mounted) {
        setState(() {
          _filteredPatients = searchResults;
        });
      }
    } catch (e) {
      print('搜索患者数据错误: $e');
    }
  }

  // 选择日期
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _appointmentDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _appointmentDate.hour,
          _appointmentDate.minute,
        );
        _dateController.text =
            DateFormat('yyyy-MM-dd').format(_appointmentDate);
      });
    }
  }

  // 选择时间
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_appointmentDate),
    );

    if (picked != null) {
      setState(() {
        _appointmentDate = DateTime(
          _appointmentDate.year,
          _appointmentDate.month,
          _appointmentDate.day,
          picked.hour,
          picked.minute,
        );
        _timeController.text = DateFormat('HH:mm').format(_appointmentDate);
      });
    }
  }

  // 显示患者搜索对话框
  void _showPatientSearchDialog(BuildContext context) {
    _patientSearchController.clear();
    _patientDropdownOpen = true;
    _filteredPatients = _allPatients;

    // 获取主题颜色
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;
    final accentColor =
        isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor;

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
                        hintText: '搜索患者 (姓名/拼音/电话)',
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
                        // 如果用户正在输入，则进行数据库搜索
                        if (value.length >= 1) {
                          _searchPatientsInDatabase(value).then((_) {
                            setState(() {}); // 更新对话框UI
                          });
                        } else {
                          setState(() {
                            _filteredPatients = _allPatients;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // 患者列表 - 改为表格形式显示
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
                                                  setState(() {
                                                    _selectedPatientId =
                                                        patient.id;
                                                    _patientSearchController
                                                        .text = patient.name;
                                                  });
                                                  Navigator.of(context).pop();

                                                  // 更新主组件的状态
                                                  this.setState(() {});
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

  // 选择治疗项目
  void _showTreatmentSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TreatmentSelectionDialog(
          selectedTreatments: _selectedTreatments,
          onConfirm: (selectedItems) {
            setState(() {
              _selectedTreatments = selectedItems;
              _updateTreatmentType();
            });
          },
        );
      },
    );
  }

  // 添加自定义治疗项目
  void _addCustomTreatment() {
    final customTreatment = _customTreatmentController.text.trim();
    if (customTreatment.isNotEmpty) {
      setState(() {
        if (!_selectedTreatments.contains(customTreatment)) {
          _selectedTreatments.add(customTreatment);
          _updateTreatmentType();
        }
        _customTreatmentController.clear();
      });
    }
  }

  // 更新治疗类型字段，将多选项目合并为一个字符串
  void _updateTreatmentType() {
    if (_selectedTreatments.isEmpty) {
      // 如果没有选择项目，保持默认值
      _treatmentType = '常规检查';
      return;
    }

    // 将选择的项目合并为一个字符串，用顿号分隔
    setState(() {
      _treatmentType = _getCombinedTreatmentType();
    });
  }

  // 获取合并后的治疗项目字符串
  String _getCombinedTreatmentType() {
    if (_selectedTreatments.isEmpty) {
      return '常规检查';
    }
    return _selectedTreatments.join('、');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    final textColor = isPurpleTheme ? AppTheme.purplePrimaryText : null;

    final secondaryTextColor = isPurpleTheme
        ? AppTheme.purpleSecondaryText
        : isDarkMode
            ? Colors.grey[400]
            : Colors.grey[700];

    final accentColor =
        isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor;

    final inputBorderColor = isPurpleTheme
        ? AppTheme.purpleDividerColor
        : isDarkMode
            ? Colors.grey[700]
            : Colors.grey[300];

    return AlertDialog(
      title: Text(
        widget.appointment == null ? '添加预约' : '编辑预约',
        style: TextStyle(color: textColor),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 患者选择
                if (widget.patientId == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          _showPatientSearchDialog(context);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '患者',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintText:
                                _selectedPatientId == null ? '点击选择患者' : '',
                            hintStyle: TextStyle(
                                color: secondaryTextColor?.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.person, color: accentColor),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: inputBorderColor!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: inputBorderColor!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: accentColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: Icon(Icons.search, color: accentColor),
                          ),
                          child: _selectedPatientId != null
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    _patientSearchController.text,
                                    style: TextStyle(color: textColor),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // 日期和时间
                Row(
                  children: [
                    // 日期
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '日期',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintText: '选择日期',
                            prefixIcon:
                                Icon(Icons.calendar_today, color: accentColor),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: inputBorderColor!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: inputBorderColor!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: accentColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _dateController.text,
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 时间
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '时间',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintText: '选择时间',
                            prefixIcon:
                                Icon(Icons.access_time, color: accentColor),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: inputBorderColor!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: inputBorderColor!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: accentColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _timeController.text,
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 状态
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('状态',
                        style:
                            TextStyle(color: secondaryTextColor, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: inputBorderColor!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add_check, color: accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _status,
                                  dropdownColor: isPurpleTheme
                                      ? AppTheme.purpleCardBackground
                                      : isDarkMode
                                          ? const Color(0xFF303030)
                                          : Colors.white,
                                  isExpanded: true,
                                  items: _statusOptions.map((status) {
                                    Color statusColor;
                                    switch (status) {
                                      case '已预约':
                                        statusColor = Colors.blue;
                                        break;
                                      case '已完成':
                                        statusColor = Colors.green;
                                        break;
                                      case '已取消':
                                        statusColor = Colors.red;
                                        break;
                                      case '未到诊':
                                        statusColor = Colors.orange;
                                        break;
                                      default:
                                        statusColor = Colors.grey;
                                    }

                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: status == _status
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _status = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 治疗项目 - 已移到费用估计上方
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '治疗项目*',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.arrow_drop_down,
                              size: 18, color: accentColor),
                          label: Text(
                            '从列表选择',
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            _showTreatmentSelectionDialog(context);
                          },
                        ),
                      ],
                    ),

                    // 自定义治疗项目输入框
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customTreatmentController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: '输入治疗项目',
                              hintStyle: TextStyle(
                                  color: secondaryTextColor?.withOpacity(0.7)),
                              prefixIcon: Icon(Icons.medical_services,
                                  color: accentColor),
                              border: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: inputBorderColor!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: inputBorderColor!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: accentColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onFieldSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _addCustomTreatment();
                              }
                            },
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (_selectedTreatments.isEmpty) {
                                return '请选择或输入治疗项目';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addCustomTreatment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              Text('添加', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),

                // 已选治疗项目显示
                if (_selectedTreatments.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
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
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _selectedTreatments
                              .map((treatment) => Chip(
                                    label: Text(
                                      treatment,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    deleteIcon: Icon(Icons.close, size: 16),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedTreatments.remove(treatment);
                                        _updateTreatmentType();
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 费用
                TextFormField(
                  controller: _costController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: '费用',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    hintText: '选填',
                    hintStyle:
                        TextStyle(color: secondaryTextColor?.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.attach_money, color: accentColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorderColor!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorderColor!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return '请输入有效金额';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 备注
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: '备注',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    hintText: '选填',
                    hintStyle:
                        TextStyle(color: secondaryTextColor?.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.note, color: accentColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorderColor!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorderColor!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
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
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
          ),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // 检查是否选择了患者
              if (_selectedPatientId == null && widget.patientId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请选择患者')),
                );
                return;
              }

              // 创建预约对象
              final Appointment appointment = Appointment(
                id: widget.appointment?.id,
                patient_id: _selectedPatientId ?? widget.patientId,
                patient: null,
                appointment_date: _appointmentDate,
                status: _status,
                treatment_type: _getCombinedTreatmentType(),
                notes: _notesController.text.isEmpty
                    ? null
                    : _notesController.text,
                cost: _costController.text.isEmpty
                    ? null
                    : double.tryParse(_costController.text),
                created_at: widget.appointment?.created_at, // 如果是编辑模式，保留原始的创建时间
                updated_at: DateTime.now(), // 确保更新时间是当前时间
              );

              Navigator.of(context).pop(appointment);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.appointment == null ? '添加' : '保存'),
        ),
      ],
    );
  }
}
