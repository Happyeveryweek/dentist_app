import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/patient.dart';
import '../models/dental_chart.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../providers/database_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/material_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/modern_date_picker.dart';
// 移除材料管理相关导入
// import '../widgets/patient_materials_manager.dart';
// import '../widgets/material_input_widget.dart';
import '../utils/image_compressor.dart';
import '../utils/permission_utils.dart';

// 患者表单对话框组件
class PatientFormDialog extends StatefulWidget {
  final Function(Patient) onSave;
  final Patient? patient; // 如果是编辑模式，传入患者对象
  // 移除自动滚动到材料部分的参数
  // final bool autoScrollToMaterials;

  const PatientFormDialog({
    Key? key,
    required this.onSave,
    this.patient,
  }) : super(key: key);

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _primaryPhoneController = TextEditingController();
  final TextEditingController _backupPhoneController = TextEditingController();
  final TextEditingController _medicalRecordController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController(); // 只初始化，不赋默认值
  final TextEditingController _treatmentItemsController =
      TextEditingController();

  bool _hasBackupPhone = false;
  late DateTime _firstVisitDate;
  String _gender = '男'; // 默认性别

  // 牙齿状况十字图相关变量
  List<DentalChartRow> _dentalChartRows = [];

  String? _nameExistsError;

  // 已存在的同名患者
  Patient? _existingPatient;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  
  // 追踪是否正在编辑已有患者（从同名患者填充后）
  Patient? _editingExistingPatient;
  
  // 姓名输入框的GlobalKey，用于精确定位弹窗
  final GlobalKey _nameFieldKey = GlobalKey();

  // 移除患者材料管理器相关引用
  // final GlobalKey<PatientMaterialsManagerState> _materialsManagerKey = GlobalKey<PatientMaterialsManagerState>();
  // final GlobalKey<MaterialInputWidgetState> _materialInputKey = GlobalKey<MaterialInputWidgetState>();

  // 滚动控制器（保留，用于基本信息滚动）
  final ScrollController _scrollController = ScrollController();
  // 移除材料容器相关
  // final GlobalKey _materialsContainerKey = GlobalKey();

  // 移除材料部分高亮状态
  // bool _highlightMaterials = false;

  // 保存状态控制
  bool _isLoading = false;
  
  // 权限控制 - 检查是否可以编辑基本信息
  bool _canEditBasicInfo = true;

  @override
  void initState() {
    super.initState();
    _firstVisitDate = DateTime.now();
    
    // 检查编辑权限
    _checkEditPermissions();
    
    if (widget.patient != null) {
      _loadPatientData();
    } else {
      _initializeDefaultValues();
      // 设置默认医生为当前登录用户的医生姓名（仅新增时）
      _setDefaultDoctor();
    }
    
    // 添加姓名输入框的监听器
    _nameController.addListener(_onNameChanged);
    
    // 移除自动滚动到材料部分的逻辑
    // if (widget.autoScrollToMaterials) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     Future.delayed(const Duration(milliseconds, 300), () {
    //       _scrollToMaterials();
    //     });
    //   });
    // }
  }
  
  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _ageController.dispose();
    _primaryPhoneController.dispose();
    _backupPhoneController.dispose();
    _medicalRecordController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _doctorController.dispose();
    _treatmentItemsController.dispose();
    _scrollController.dispose();
    // 释放牙齿状况行中的控制器
    for (var row in _dentalChartRows) {
      row.dispose();
    }
    _hideExistingPatientOverlay();
    super.dispose();
  }
  
  // 移除自动滚动到材料部分的方法
  // void _scrollToMaterials() { ... }

  // 姓名输入变化处理
  void _onNameChanged() {
    // 延迟检查，避免频繁查询
    if (_nameController.text.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_nameController.text.isNotEmpty && mounted) {
          _checkNameExists();
        }
      });
    }
  }

  // 初始化默认值的方法
  Future<void> _initializeDefaultValues() async {
    // 添加一个初始的牙齿状况行
    _addNewDentalChartRow();

    // 获取默认病历号
    await _getDefaultMedicalRecordNumber();
  }

  // 设置默认医生为当前登录用户的医生姓名
  Future<void> _setDefaultDoctor() async {
    try {
      // 通过UserProvider获取当前用户，这是正确的方式
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser ?? await userProvider.getCurrentUser();
      
      if (currentUser != null && currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
        // 如果当前用户有医生姓名，使用它作为默认值
        _doctorController.text = currentUser.doctor!;
        print('设置默认医生为: ${currentUser.doctor}');
      } else if (currentUser != null && currentUser.role == 'doctor') {
        // 如果是医生角色但没有设置医生姓名，使用用户名
        _doctorController.text = currentUser.username;
        print('设置默认医生为用户名: ${currentUser.username}');
      } else {
        // 默认为空，让用户自己填写
        _doctorController.text = '';
        print('当前用户没有医生姓名，主治医生字段留空');
      }
    } catch (e) {
      print('通过UserProvider设置默认医生时出错: $e');
      // 出错时使用空字符串
      _doctorController.text = '';
    }
  }

  // 获取默认病历号
  Future<void> _getDefaultMedicalRecordNumber() async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      int defaultRecordNumber = 1; // 默认值

      // 获取最大病历号
      if (patientProvider.dataSourceType == 'sqlite') {
        final db = await patientProvider.database;
        final result = await db!.query(
          'patients',
          columns: ['medical_record_number'],
          where: 'medical_record_number IS NOT NULL',
          orderBy: 'medical_record_number DESC',
          limit: 1,
        );

        if (result.isNotEmpty) {
          var maxRecordNumber = result.first['medical_record_number'];
          if (maxRecordNumber != null) {
            if (maxRecordNumber is int) {
              defaultRecordNumber = maxRecordNumber + 1;
            } else if (maxRecordNumber is String) {
              defaultRecordNumber = int.tryParse(maxRecordNumber) ?? 1;
              defaultRecordNumber += 1;
            }
          }
        }
      } else {
        // MySQL查询
        final results = await patientProvider.mysqlConnection!.query(
          'SELECT medical_record_number FROM patients WHERE medical_record_number IS NOT NULL ORDER BY medical_record_number + 0 DESC LIMIT 1',
        );

        if (results.isNotEmpty && results.first['medical_record_number'] != null) {
          var maxRecordNumber = results.first['medical_record_number'];
          if (maxRecordNumber != null) {
            if (maxRecordNumber is int) {
              defaultRecordNumber = maxRecordNumber + 1;
            } else if (maxRecordNumber is String) {
              defaultRecordNumber = int.tryParse(maxRecordNumber) ?? 1;
              defaultRecordNumber += 1;
            }
          }
        }
      }
      // 设置到输入框
      if (mounted) {
        setState(() {
          _medicalRecordController.text = defaultRecordNumber.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _medicalRecordController.text = '1';
        });
      }
    }
  }

  // 加载患者数据
  void _loadPatientData() {
    if (widget.patient != null) {
      _nameController.text = widget.patient!.name;
      _ageController.text = widget.patient!.age.toString();
      _gender = widget.patient!.gender;

      // 处理电话号码 - 彻底修复电话解析问题
      print(
          '原始电话数据: ${widget.patient!.phone}, 类型: ${widget.patient!.phone.runtimeType}');

      try {
        // 尝试直接使用phoneList
        List<String> phones = widget.patient!.phoneList;
        print('解析后的电话列表: $phones');

        if (phones.isNotEmpty) {
          _primaryPhoneController.text = phones[0];
          print('设置主电话: ${phones[0]}');

          if (phones.length > 1) {
            _backupPhoneController.text = phones[1];
            _hasBackupPhone = true;
            print('设置备用电话: ${phones[1]}');
          }
        }
      } catch (e) {
        print('处理电话时出错: $e');

        // 备选方案：处理格式为 ["电话1", "电话2"] 的字符串
        if (widget.patient!.phone is String) {
          String phoneStr = widget.patient!.phone.toString();
          print('尝试解析字符串形式的电话: $phoneStr');

          if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
            try {
              // 尝试解析JSON字符串
              var phoneJson = jsonDecode(phoneStr);
              if (phoneJson is List && phoneJson.isNotEmpty) {
                _primaryPhoneController.text = phoneJson[0].toString();
                print('从JSON字符串设置主电话: ${phoneJson[0]}');

                if (phoneJson.length > 1) {
                  _backupPhoneController.text = phoneJson[1].toString();
                  _hasBackupPhone = true;
                  print('从JSON字符串设置备用电话: ${phoneJson[1]}');
                }
              }
            } catch (jsonError) {
              print('JSON解析电话失败: $jsonError，尝试使用正则表达式');

              // 尝试使用正则表达式提取引号中的内容
              RegExp regex = RegExp(r'"([^"]*)"');
              var matches = regex.allMatches(phoneStr);
              List<String> extractedPhones =
                  matches.map((match) => match.group(1)!).toList();

              if (extractedPhones.isNotEmpty) {
                _primaryPhoneController.text = extractedPhones[0];
                print('从正则表达式设置主电话: ${extractedPhones[0]}');

                if (extractedPhones.length > 1) {
                  _backupPhoneController.text = extractedPhones[1];
                  _hasBackupPhone = true;
                  print('从正则表达式设置备用电话: ${extractedPhones[1]}');
                }
              } else {
                // 最后的方案：直接使用原始字符串
                _primaryPhoneController.text = phoneStr;
                print('使用原始字符串作为主电话: $phoneStr');
              }
            }
          } else {
            // 单个电话号码字符串
            _primaryPhoneController.text = phoneStr;
            print('使用原始字符串作为主电话: $phoneStr');
          }
        }
      }

      if (widget.patient!.medical_record_number != null) {
        _medicalRecordController.text =
            widget.patient!.medical_record_number.toString();
      }

      if (widget.patient!.address != null) {
        _addressController.text = widget.patient!.address!;
      }

      if (widget.patient!.identification_number != null) {
        _idNumberController.text = widget.patient!.identification_number!;
      }

      if (widget.patient!.doctor != null) {
        _doctorController.text = widget.patient!.doctor!;
      }

      if (widget.patient!.treatment_items != null) {
        _treatmentItemsController.text = widget.patient!.treatment_items!;
      }

      // 加载患者材料信息 - 由材料管理器处理

      if (widget.patient!.first_visit_date != null) {
        _firstVisitDate = widget.patient!.first_visit_date;
      }

      // 加载牙齿状况数据
      _loadDentalCondition();
    }
  }

  // 加载牙齿状况数据
  void _loadDentalCondition() {
    if (widget.patient?.dental_condition == null ||
        widget.patient!.dental_condition!.isEmpty) {
      print('患者没有牙齿状况数据，添加空行');
      _addNewDentalChartRow();
      return;
    }

    try {
      print('开始加载牙齿状况数据');
      print('原始牙齿状况数据: ${widget.patient!.dental_condition}');

      // 确保清空现有的行，避免重复添加
      _dentalChartRows.clear();

      // 直接使用Patient模型中的dentalCharts方法获取数据
      Map<String, dynamic> dentalCharts = widget.patient!.dentalCharts;
      print('从患者对象获取的牙齿图表数据: $dentalCharts');

      // 如果没有数据，添加空行
      if (dentalCharts.isEmpty) {
        print('无法解析牙齿状况数据，添加空行');
        _addNewDentalChartRow();
        return;
      }

      // 找出有多少行数据
      int rowCount = 0;
      for (String key in dentalCharts.keys) {
        if (key.startsWith('date-')) {
          int index = int.tryParse(key.split('-').last) ?? 0;
          rowCount = rowCount > index ? rowCount : index + 1;
        }
      }

      print('检测到牙齿状况行数: $rowCount');

      if (rowCount == 0) {
        print('未找到任何有效的日期行，添加空行');
        _addNewDentalChartRow();
        return;
      }

      List<DentalChartRow> tempRows = [];

      for (int i = 0; i < rowCount; i++) {
        // 获取该行的日期
        String dateStr = dentalCharts['date-$i'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());
        print('第 $i 行日期字符串: $dateStr');

        DateTime chartDate;
        try {
          // 尝试不同的日期格式
          if (dateStr.contains('-')) {
            chartDate = DateFormat('yyyy-MM-dd').parse(dateStr);
          } else if (dateStr.contains('/')) {
            chartDate = DateFormat('yyyy/MM/dd').parse(dateStr);
          } else {
            chartDate = DateTime.parse(dateStr);
          }
          print('解析日期成功: $chartDate');
        } catch (e) {
          print('日期解析错误: $e，使用当前日期');
          chartDate = DateTime.now();
        }

        // 获取创建者医生信息
        String createdByDoctor = dentalCharts['created_by_doctor-$i'] ?? '';

        // 创建新的牙齿图表行
        DentalChartRow row = DentalChartRow(
          index: i,
          date: chartDate,
          createdByDoctor: createdByDoctor,
        );

        // 获取牙齿数据 - 直接从图表中获取
        String topLeft1 = dentalCharts['chart1-top-left-$i'] ?? '';
        String topRight1 = dentalCharts['chart1-top-right-$i'] ?? '';
        String bottomLeft1 = dentalCharts['chart1-bottom-left-$i'] ?? '';
        String bottomRight1 = dentalCharts['chart1-bottom-right-$i'] ?? '';
        String note1 = dentalCharts['chart1-note-$i'] ?? ''; // 获取第一个图表的备注

        String topLeft2 = dentalCharts['chart2-top-left-$i'] ?? '';
        String topRight2 = dentalCharts['chart2-top-right-$i'] ?? '';
        String bottomLeft2 = dentalCharts['chart2-bottom-left-$i'] ?? '';
        String bottomRight2 = dentalCharts['chart2-bottom-right-$i'] ?? '';
        String note2 = dentalCharts['chart2-note-$i'] ?? ''; // 获取第二个图表的备注

        String topLeft3 = dentalCharts['chart3-top-left-$i'] ?? '';
        String topRight3 = dentalCharts['chart3-top-right-$i'] ?? '';
        String bottomLeft3 = dentalCharts['chart3-bottom-left-$i'] ?? '';
        String bottomRight3 = dentalCharts['chart3-bottom-right-$i'] ?? '';
        String note3 = dentalCharts['chart3-note-$i'] ?? ''; // 获取第三个图表的备注

        print(
            '第 $i 行图表1数据: $topLeft1, $topRight1, $bottomLeft1, $bottomRight1, 备注: $note1');
        print(
            '第 $i 行图表2数据: $topLeft2, $topRight2, $bottomLeft2, $bottomRight2, 备注: $note2');
        print(
            '第 $i 行图表3数据: $topLeft3, $topRight3, $bottomLeft3, $bottomRight3, 备注: $note3');

        // 确保设置数据和控制器文本
        row.chart1.topLeftController.text = topLeft1;
        row.chart1.topRightController.text = topRight1;
        row.chart1.bottomLeftController.text = bottomLeft1;
        row.chart1.bottomRightController.text = bottomRight1;
        row.chart1.noteController.text = note1; // 设置第一个图表的备注

        row.chart2.topLeftController.text = topLeft2;
        row.chart2.topRightController.text = topRight2;
        row.chart2.bottomLeftController.text = bottomLeft2;
        row.chart2.bottomRightController.text = bottomRight2;
        row.chart2.noteController.text = note2; // 设置第二个图表的备注

        row.chart3.topLeftController.text = topLeft3;
        row.chart3.topRightController.text = topRight3;
        row.chart3.bottomLeftController.text = bottomLeft3;
        row.chart3.bottomRightController.text = bottomRight3;
        row.chart3.noteController.text = note3; // 设置第三个图表的备注

        // 添加到临时列表
        tempRows.add(row);
        print('成功添加第 $i 行牙齿状况');
      }

      // 按时间排序，最近的时间在最上面
      tempRows.sort((a, b) => b.date.compareTo(a.date));
      
      // 更新状态，使用临时列表一次性更新UI
      setState(() {
        _dentalChartRows.addAll(tempRows);
      });

      // 如果没有加载到任何行，添加一个空的
      if (_dentalChartRows.isEmpty) {
        print('所有方法尝试后仍没有加载到任何牙齿状况行，添加新行');
        _addNewDentalChartRow();
      } else {
        print('成功加载了 ${_dentalChartRows.length} 行牙齿状况数据');
      }
    } catch (e) {
      print('加载牙齿状况时出错: $e');
      print('错误堆栈: ${StackTrace.current}');
      _addNewDentalChartRow();
    }
  }

  // 处理材料变化 - 由材料管理器处理
  void _onMaterialsChanged(List<PatientMaterialWithImages> materials) {
    // 材料变化由材料管理器内部处理
  }

  // 保存患者并获取ID
  Future<Patient> _savePatientAndGetId(Patient patient) async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      if (patient.id != null) {
        // 更新现有患者
        await patientProvider.updatePatient(patient);
        return patient;
      } else {
        // 添加新患者
        final newId = await patientProvider.addPatient(patient);
        return patient.copyWith(id: newId);
      }
    } catch (e) {
      print('保存患者失败: $e');
      rethrow;
    }
  }

  // 移除保存患者材料信息的方法
  // Future<void> _savePatientMaterials(int patientId) async { ... }

  // 添加新的牙齿状况行
  void _addNewDentalChartRow() {
    setState(() {
      _dentalChartRows.add(DentalChartRow(
        index: _dentalChartRows.length,
        date: DateTime.now(),
        createdByDoctor: _getCurrentDoctorName(), // 设置创建者为当前医生
      ));
      // 按时间排序，最近的时间在最上面
      _dentalChartRows.sort((a, b) => b.date.compareTo(a.date));
      // 重新设置索引
      for (int i = 0; i < _dentalChartRows.length; i++) {
        _dentalChartRows[i].index = i;
      }
      print('添加了新的牙齿状况行，当前共 ${_dentalChartRows.length} 行');
    });
  }

  // 生成牙齿状况的JSON数据
  String _generateDentalConditionJson() {
    Map<String, String> result = {};

    for (int i = 0; i < _dentalChartRows.length; i++) {
      DentalChartRow row = _dentalChartRows[i];

      // 添加日期
      result['date-$i'] = DateFormat('yyyy-MM-dd').format(row.date);

      // 添加创建者医生信息
      result['created_by_doctor-$i'] = row.createdByDoctor ?? _getCurrentDoctorName();

      // 添加第一个图表的数据
      result['chart1-top-left-$i'] = row.chart1.topLeftController.text;
      result['chart1-top-right-$i'] = row.chart1.topRightController.text;
      result['chart1-bottom-left-$i'] = row.chart1.bottomLeftController.text;
      result['chart1-bottom-right-$i'] = row.chart1.bottomRightController.text;

      // 添加第一个图表的备注
      result['chart1-note-$i'] = row.chart1.noteController.text;

      // 添加第二个图表的数据
      result['chart2-top-left-$i'] = row.chart2.topLeftController.text;
      result['chart2-top-right-$i'] = row.chart2.topRightController.text;
      result['chart2-bottom-left-$i'] = row.chart2.bottomLeftController.text;
      result['chart2-bottom-right-$i'] = row.chart2.bottomRightController.text;

      // 添加第二个图表的备注
      result['chart2-note-$i'] = row.chart2.noteController.text;

      // 添加第三个图表的数据
      result['chart3-top-left-$i'] = row.chart3.topLeftController.text;
      result['chart3-top-right-$i'] = row.chart3.topRightController.text;
      result['chart3-bottom-left-$i'] = row.chart3.bottomLeftController.text;
      result['chart3-bottom-right-$i'] = row.chart3.bottomRightController.text;

      // 添加第三个图表的备注
      result['chart3-note-$i'] = row.chart3.noteController.text;
    }

    print('生成牙齿状况JSON: $result');
    return jsonEncode(result);
  }

  // 获取当前登录医生的姓名
  String _getCurrentDoctorName() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser != null) {
        // 优先使用医生字段，如果没有则使用用户名
        return currentUser.doctor?.isNotEmpty == true 
            ? currentUser.doctor! 
            : currentUser.username;
      }
    } catch (e) {
      print('获取当前医生姓名失败: $e');
    }
    return '';
  }



  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: _firstVisitDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
      },
    );

    if (picked != null && picked != _firstVisitDate) {
      setState(() {
        _firstVisitDate = picked;
      });
    }
  }

  Future<void> _selectChartDate(
      BuildContext context, DentalChartRow row) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: row.date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
      },
    );

    if (picked != null && picked != row.date) {
      setState(() {
        row.date = picked;
        // 重新排序牙齿状况记录
        _dentalChartRows.sort((a, b) => b.date.compareTo(a.date));
        // 重新设置索引
        for (int i = 0; i < _dentalChartRows.length; i++) {
          _dentalChartRows[i].index = i;
        }
      });
    }
  }

  // 加载已存在患者数据到表单
  void _loadExistingPatientData(Patient patient) {
    print('开始加载已存在患者数据: ${patient.name}');
    
    setState(() {
      // 设置正在编辑已有患者
      _editingExistingPatient = patient;
      
      _nameController.text = patient.name;
      _ageController.text = patient.age.toString();
      _primaryPhoneController.text = patient.mainPhone;
      _medicalRecordController.text = patient.medical_record_number?.toString() ?? '';
      _addressController.text = patient.address ?? '';
      _idNumberController.text = patient.identification_number ?? '';
      _doctorController.text = patient.doctor ?? '';
      _treatmentItemsController.text = patient.treatment_items ?? '';
      _gender = patient.gender;
      _firstVisitDate = patient.first_visit_date;
      
      // 加载备用电话
      if (patient.phone != null) {
        try {
          if (patient.phone is String) {
            // 尝试解析JSON字符串
            try {
              final phoneData = json.decode(patient.phone);
              if (phoneData is Map && phoneData.containsKey('backup') && phoneData['backup'].isNotEmpty) {
                _backupPhoneController.text = phoneData['backup'];
                _hasBackupPhone = true;
              } else if (phoneData is List && phoneData.length > 1) {
                _backupPhoneController.text = phoneData[1].toString();
                _hasBackupPhone = true;
              }
            } catch (e) {
              // 不是JSON格式，可能是普通字符串电话号码
            }
          }
        } catch (e) {
          print('解析电话数据失败: $e');
        }
      }
      
      // 加载牙齿状况数据 - 使用与编辑患者相同的逻辑
      if (patient.dental_condition != null && patient.dental_condition!.isNotEmpty) {
        try {
          print('开始加载已存在患者的牙齿状况数据');
          print('原始牙齿状况数据: ${patient.dental_condition}');

          // 确保清空现有的行，避免重复添加
          _dentalChartRows.clear();

          // 直接使用Patient模型中的dentalCharts方法获取数据
          Map<String, dynamic> dentalCharts = patient.dentalCharts;
          print('从患者对象获取的牙齿图表数据: $dentalCharts');

          // 如果没有数据，添加空行
          if (dentalCharts.isEmpty) {
            print('无法解析牙齿状况数据，添加空行');
            _addNewDentalChartRow();
            return;
          }

          // 找出有多少行数据
          int rowCount = 0;
          for (String key in dentalCharts.keys) {
            if (key.startsWith('date-')) {
              int index = int.tryParse(key.split('-').last) ?? 0;
              rowCount = rowCount > index ? rowCount : index + 1;
            }
          }

          print('检测到牙齿状况行数: $rowCount');

          if (rowCount == 0) {
            print('未找到任何有效的日期行，添加空行');
            _addNewDentalChartRow();
            return;
          }

          List<DentalChartRow> tempRows = [];

          for (int i = 0; i < rowCount; i++) {
            // 获取该行的日期
            String dateStr = dentalCharts['date-$i'] ??
                DateFormat('yyyy-MM-dd').format(DateTime.now());
            print('第 $i 行日期字符串: $dateStr');

            DateTime chartDate;
            try {
              // 尝试不同的日期格式
              if (dateStr.contains('-')) {
                chartDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              } else if (dateStr.contains('/')) {
                chartDate = DateFormat('yyyy/MM/dd').parse(dateStr);
              } else {
                chartDate = DateTime.parse(dateStr);
              }
              print('解析日期成功: $chartDate');
            } catch (e) {
              print('日期解析错误: $e，使用当前日期');
              chartDate = DateTime.now();
            }

            // 获取创建者医生信息
            String createdByDoctor = dentalCharts['created_by_doctor-$i'] ?? '';

            // 创建新的牙齿图表行
            DentalChartRow row = DentalChartRow(
              index: i,
              date: chartDate,
              createdByDoctor: createdByDoctor,
            );

            // 获取牙齿数据 - 直接从图表中获取
            String topLeft1 = dentalCharts['chart1-top-left-$i'] ?? '';
            String topRight1 = dentalCharts['chart1-top-right-$i'] ?? '';
            String bottomLeft1 = dentalCharts['chart1-bottom-left-$i'] ?? '';
            String bottomRight1 = dentalCharts['chart1-bottom-right-$i'] ?? '';
            String note1 = dentalCharts['chart1-note-$i'] ?? '';

            String topLeft2 = dentalCharts['chart2-top-left-$i'] ?? '';
            String topRight2 = dentalCharts['chart2-top-right-$i'] ?? '';
            String bottomLeft2 = dentalCharts['chart2-bottom-left-$i'] ?? '';
            String bottomRight2 = dentalCharts['chart2-bottom-right-$i'] ?? '';
            String note2 = dentalCharts['chart2-note-$i'] ?? '';

            String topLeft3 = dentalCharts['chart3-top-left-$i'] ?? '';
            String topRight3 = dentalCharts['chart3-top-right-$i'] ?? '';
            String bottomLeft3 = dentalCharts['chart3-bottom-left-$i'] ?? '';
            String bottomRight3 = dentalCharts['chart3-bottom-right-$i'] ?? '';
            String note3 = dentalCharts['chart3-note-$i'] ?? '';

            print('第 $i 行图表1数据: $topLeft1, $topRight1, $bottomLeft1, $bottomRight1, 备注: $note1');
            print('第 $i 行图表2数据: $topLeft2, $topRight2, $bottomLeft2, $bottomRight2, 备注: $note2');
            print('第 $i 行图表3数据: $topLeft3, $topRight3, $bottomLeft3, $bottomRight3, 备注: $note3');

            // 确保设置数据和控制器文本
            row.chart1.topLeftController.text = topLeft1;
            row.chart1.topRightController.text = topRight1;
            row.chart1.bottomLeftController.text = bottomLeft1;
            row.chart1.bottomRightController.text = bottomRight1;
            row.chart1.noteController.text = note1;

            row.chart2.topLeftController.text = topLeft2;
            row.chart2.topRightController.text = topRight2;
            row.chart2.bottomLeftController.text = bottomLeft2;
            row.chart2.bottomRightController.text = bottomRight2;
            row.chart2.noteController.text = note2;

            row.chart3.topLeftController.text = topLeft3;
            row.chart3.topRightController.text = topRight3;
            row.chart3.bottomLeftController.text = bottomLeft3;
            row.chart3.bottomRightController.text = bottomRight3;
            row.chart3.noteController.text = note3;

            // 添加到临时列表
            tempRows.add(row);
            print('成功添加第 $i 行牙齿状况');
          }

          // 按时间排序，最近的时间在最上面
          tempRows.sort((a, b) => b.date.compareTo(a.date));
          
          // 重新设置索引
          for (int i = 0; i < tempRows.length; i++) {
            tempRows[i].index = i;
          }

          // 更新状态，使用临时列表一次性更新UI
          _dentalChartRows.addAll(tempRows);

          // 如果没有加载到任何行，添加一个空的
          if (_dentalChartRows.isEmpty) {
            print('所有方法尝试后仍没有加载到任何牙齿状况行，添加新行');
            _addNewDentalChartRow();
          } else {
            print('成功加载了 ${_dentalChartRows.length} 行牙齿状况数据');
          }
        } catch (e) {
          print('解析牙齿状况数据失败: $e');
          _dentalChartRows = [];
          _addNewDentalChartRow();
        }
      } else {
        print('患者没有牙齿状况数据，添加空行');
        _dentalChartRows = [];
        _addNewDentalChartRow();
      }
    });
    
    // 移除异步加载患者材料信息的逻辑
    // if (patient.id != null) {
    //   print('准备加载患者材料信息，患者ID: ${patient.id}');
    //   _loadExistingPatientMaterials(patient.id!);
    // }
  }

  void _checkNameExists() async {
    print('_checkNameExists 被调用，当前姓名: "${_nameController.text}"');
    
    // 如果名字为空，不检查
    if (_nameController.text.isEmpty) {
      print('姓名为空，跳过检查');
      return;
    }

    final patientProvider = Provider.of<PatientProvider>(context, listen: false);

    try {
      print('当前数据源类型: ${patientProvider.dataSourceType}');
      
      // 先检查名字是否存在
      bool nameExists = await patientProvider.checkPatientNameExists(
          _nameController.text, _editingExistingPatient?.id ?? widget.patient?.id);
      
      print('姓名检查结果: $nameExists');

      if (nameExists) {
        // 如果名字存在，获取该患者的详细信息
        print('开始搜索同名患者...');
        List<Patient> patients =
            await patientProvider.searchPatients(_nameController.text);
        print('找到 ${patients.length} 个同名患者');
        
        // 打印所有找到的患者信息用于调试
        for (int i = 0; i < patients.length; i++) {
          print('患者 $i: ${patients[i].name}, ID: ${patients[i].id}');
        }
        
        if (patients.isNotEmpty) {
          // 找到匹配当前输入姓名的患者
          for (var patient in patients) {
            if (patient.name == _nameController.text &&
                patient.id != (_editingExistingPatient?.id ?? widget.patient?.id)) {
              print('找到匹配的患者: ${patient.name}, ID: ${patient.id}');
              setState(() {
                _existingPatient = patient;
              });
              print('准备调用 _showExistingPatientOverlay');
              _showExistingPatientOverlay();
              return;
            }
          }
        }
        
        // 如果没有找到匹配的患者，尝试直接查询数据库
        print('尝试直接查询数据库...');
        await _tryDirectDatabaseQuery(_nameController.text);
      } else {
        // 名字不存在，清除已存在患者信息
        print('姓名不存在，清除弹窗');
        setState(() {
          _existingPatient = null;
          _hideExistingPatientOverlay();
        });
      }
    } catch (e) {
      print('检查姓名时出错: $e');
      print('错误堆栈: ${StackTrace.current}');
    }
  }
  
     // 尝试直接查询数据库
   Future<void> _tryDirectDatabaseQuery(String name) async {
     try {
       final patientProvider = Provider.of<PatientProvider>(context, listen: false);
       
       if (patientProvider.dataSourceType == 'sqlite') {
         // SQLite数据库查询逻辑
         final db = await patientProvider.database;
         if (db != null) {
           print('直接查询SQLite数据库...');
           final result = await db.query(
             'patients',
             where: 'name = ?',
             whereArgs: [name],
           );
           print('SQLite直接查询结果: ${result.length} 条记录');
           
           if (result.isNotEmpty) {
             final patient = Patient.fromMap(result.first);
             print('SQLite直接查询找到患者: ${patient.name}, ID: ${patient.id}');
             setState(() {
               _existingPatient = patient;
             });
             _showExistingPatientOverlay();
           }
         }
       } else if (patientProvider.dataSourceType == 'mysql') {
         // MySQL数据库查询逻辑 - 完全独立的处理
         print('直接查询MySQL数据库...');
         try {
           final results = await patientProvider.mysqlConnection!.query(
             'SELECT * FROM patients WHERE name = ?',
             [name],
           );
           print('MySQL直接查询结果: ${results.length} 条记录');
           
                       if (results.isNotEmpty) {
              // 将MySQL的ResultRow转换为Map<String, dynamic>
              final mysqlRow = results.first;
              final Map<String, dynamic> patientMap = {};
              
              // 手动转换每个字段，处理可能的二进制类型，避免乱码
              for (var field in mysqlRow.fields.keys) {
                var value = mysqlRow[field];
                if (value is Uint8List) {
                  try {
                    final stringValue = utf8.decode(value, allowMalformed: true);
                    patientMap[field] = stringValue;
                  } catch (e) {
                    print('Uint8List转换失败: $e');
                    patientMap[field] = '';
                  }
                } else if (value is List<int>) {
                  try {
                    final stringValue = utf8.decode(value, allowMalformed: true);
                    patientMap[field] = stringValue;
                  } catch (e) {
                    print('List<int>转换失败: $e');
                    patientMap[field] = '';
                  }
                } else {
                  patientMap[field] = value;
                }
              }
             
             final patient = Patient.fromMap(patientMap);
             print('MySQL直接查询找到患者: ${patient.name}, ID: ${patient.id}');
             setState(() {
               _existingPatient = patient;
             });
             _showExistingPatientOverlay();
           }
         } catch (mysqlError) {
           print('MySQL查询出错: $mysqlError');
         }
       }
     } catch (e) {
       print('直接查询数据库时出错: $e');
     }
   }

  void _showExistingPatientOverlay() {
    print('_showExistingPatientOverlay 被调用');
    if (_existingPatient == null) {
      print('_existingPatient 为空，不显示弹窗');
      return;
    }

    print('准备显示弹窗，患者: ${_existingPatient!.name}');
    _hideExistingPatientOverlay(); // 先隐藏已存在的弹窗

    final overlay = Overlay.of(context);
    
    // 使用姓名输入框的GlobalKey来精确定位弹窗
    final RenderBox? nameFieldBox = _nameFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (nameFieldBox == null) return;

    final nameFieldPosition = nameFieldBox.localToGlobal(Offset.zero);
    final nameFieldSize = nameFieldBox.size;
    
    // 获取屏幕尺寸
    final screenSize = MediaQuery.of(context).size;
    const overlayWidth = 320.0;
    const overlayHeight = 280.0;
    
    // 计算弹窗位置，确保不超出屏幕边界
    double left = nameFieldPosition.dx;
    double top = nameFieldPosition.dy + nameFieldSize.height + 8;
    
    // 如果弹窗会超出右边界，向左调整
    if (left + overlayWidth > screenSize.width) {
      left = screenSize.width - overlayWidth - 16;
    }
    
    // 如果弹窗会超出下边界，向上显示
    if (top + overlayHeight > screenSize.height) {
      top = nameFieldPosition.dy - overlayHeight - 8;
    }
    
    // 确保不超出左边界和上边界
    left = left.clamp(16.0, screenSize.width - overlayWidth - 16);
    top = top.clamp(16.0, screenSize.height - overlayHeight - 16);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 320, // 固定宽度，更小巧
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '⚠️ 发现同名患者',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _hideExistingPatientOverlay,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                
                // 患者信息区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('病历号', _existingPatient!.medical_record_number?.toString() ?? '无'),
                        _buildInfoRow('姓名', _existingPatient!.name),
                        _buildInfoRow('性别', _existingPatient!.gender),
                        _buildInfoRow('电话', _existingPatient!.phone),
                        if (_existingPatient!.address != null && _existingPatient!.address!.isNotEmpty)
                          _buildInfoRow('地址', _existingPatient!.address!),
                        
                        const SizedBox(height: 12),
                                                 Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: Colors.orange.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(6),
                             border: Border.all(color: Colors.orange.withOpacity(0.3)),
                           ),
                           child: const Text(
                             '请确认是否为新患者，或选择填充现有患者信息（包括材料）',
                             style: TextStyle(
                               fontSize: 11,
                               color: Colors.orange,
                               fontStyle: FontStyle.italic,
                             ),
                           ),
                         ),
                      ],
                    ),
                  ),
                ),
                
                // 操作按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _hideExistingPatientOverlay();
                            setState(() {
                              _editingExistingPatient = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            '继续添加',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _hideExistingPatientOverlay();
                            if (_existingPatient != null) {
                              _loadExistingPatientData(_existingPatient!);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            '确认填充',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _hideExistingPatientOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          gradient: DentalColors.backgroundGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: DentalColors.shadowMedium,
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: DentalColors.shadowLight,
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
              color: DentalColors.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行 - 带渐变背景（优化后更小巧）
              Container(
                decoration: BoxDecoration(
                  gradient: DentalColors.primaryGradient,
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
                            _editingExistingPatient != null 
                              ? Icons.edit
                              : (widget.patient == null ? Icons.person_add : Icons.edit),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _editingExistingPatient != null 
                            ? '编辑患者 (${_editingExistingPatient!.name})'
                            : (widget.patient == null ? '添加患者' : '编辑患者'),
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
              
              // 内容区域
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 权限提示信息
                        if (!_canEditBasicInfo)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '您正在编辑其他医生的患者，只能修改牙齿状况部分，其他信息为只读状态',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // 表单内容
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 第一行：病历号、姓名、年龄、性别、首诊日期
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: DentalColors.cardGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: DentalColors.primary.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // 病历号
                                      Expanded(
                                        flex: 2,
                                        child: _buildStyledTextField(
                                          controller: _medicalRecordController,
                                          labelText: '病历号',
                                          hintText: '选填',
                                          icon: Icons.medical_services,
                                          enabled: _canEditBasicInfo,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 姓名
                                      Expanded(
                                        flex: 2,
                                        child: _buildStyledTextField(
                                          key: _nameFieldKey,
                                          controller: _nameController,
                                          labelText: '姓名',
                                          hintText: '输入患者姓名',
                                          icon: Icons.person,
                                          enabled: _canEditBasicInfo,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return '请输入姓名';
                                            }
                                            return null;
                                          },
                                          onTap: () => _hideExistingPatientOverlay(),
                                          onChanged: (value) {
                                            // 监听器会自动处理
                                          },
                                          onFieldSubmitted: (value) => _checkNameExists(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 年龄
                                      Expanded(
                                        child: _buildStyledTextField(
                                          controller: _ageController,
                                          labelText: '年龄',
                                          hintText: '输入年龄',
                                          icon: Icons.cake,
                                          enabled: _canEditBasicInfo,
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) return null;
                                            if (int.tryParse(value) == null) {
                                              return '请输入有效年龄';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 性别
                                      Expanded(
                                        child: _buildStyledDropdown(
                                          value: _gender,
                                          labelText: '性别',
                                          icon: _gender == '男' ? Icons.male : Icons.female,
                                          enabled: _canEditBasicInfo,
                                          items: const [
                                            DropdownMenuItem(value: '男', child: Text('男')),
                                            DropdownMenuItem(value: '女', child: Text('女')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => _gender = value);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 首诊日期
                                      Expanded(
                                        flex: 2,
                                        child: _buildStyledDateField(
                                          labelText: '首诊日期',
                                          date: _firstVisitDate,
                                          enabled: _canEditBasicInfo,
                                          onTap: () => _selectDate(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 第二行：主要电话和备用电话
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: DentalColors.cardGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: DentalColors.info.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 主电话
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: _buildStyledTextField(
                                                controller: _primaryPhoneController,
                                                labelText: '主要电话',
                                                hintText: '输入11位手机号码',
                                                icon: Icons.phone,
                                                enabled: _canEditBasicInfo,
                                                keyboardType: TextInputType.phone,
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) return null;
                                                  final RegExp phoneRegex = RegExp(r'^1[3-9]\d{9}$');
                                                  if (!phoneRegex.hasMatch(value)) {
                                                    return '请输入正确的11位手机号码';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              decoration: BoxDecoration(
                                                color: _hasBackupPhone 
                                                  ? DentalColors.error.withOpacity(0.1)
                                                  : DentalColors.info.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  _hasBackupPhone ? Icons.remove_circle : Icons.add_circle,
                                                  color: _canEditBasicInfo 
                                                    ? (_hasBackupPhone ? DentalColors.error : DentalColors.info)
                                                    : Colors.grey,
                                                ),
                                                tooltip: _hasBackupPhone ? '移除备用电话' : '添加备用电话',
                                                onPressed: _canEditBasicInfo ? () {
                                                  setState(() {
                                                    _hasBackupPhone = !_hasBackupPhone;
                                                    if (!_hasBackupPhone) {
                                                      _backupPhoneController.clear();
                                                    }
                                                  });
                                                } : null,
                                              ),
                                            ),
                                            if (_hasBackupPhone)
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 8.0),
                                                  child: _buildStyledTextField(
                                                    controller: _backupPhoneController,
                                                    labelText: '备用电话',
                                                    hintText: '输入11位手机号码',
                                                    icon: Icons.phone_forwarded,
                                                    enabled: _canEditBasicInfo,
                                                    keyboardType: TextInputType.phone,
                                                    validator: (value) {
                                                      if (value != null && value.isNotEmpty) {
                                                        final RegExp phoneRegex = RegExp(r'^1[3-9]\d{9}$');
                                                        if (!phoneRegex.hasMatch(value)) {
                                                          return '请输入正确的11位手机号码';
                                                        }
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // 医生和身份证号
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            // 主治医生
                                            Expanded(
                                              child: _buildStyledTextField(
                                                controller: _doctorController,
                                                labelText: '主治医生',
                                                hintText: '选填',
                                                icon: Icons.medical_services,
                                                enabled: _canEditBasicInfo,
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // 身份证号
                                            Expanded(
                                              flex: 2,
                                              child: _buildStyledTextField(
                                                controller: _idNumberController,
                                                labelText: '身份证号',
                                                hintText: '选填',
                                                icon: Icons.badge,
                                                enabled: _canEditBasicInfo,
                                                keyboardType: TextInputType.number,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 第三行：住址（占据整行，改为单行）
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: DentalColors.cardGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: DentalColors.secondary.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: _buildStyledTextField(
                                    controller: _addressController,
                                    labelText: '住址',
                                    hintText: '选填住址信息',
                                    icon: Icons.location_on,
                                    enabled: _canEditBasicInfo,
                                    maxLines: 1,
                                    textAlignVertical: TextAlignVertical.center,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 第四行：牙齿状况（十字图表）- 增加高度
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: DentalColors.cardGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: DentalColors.dentalTeal.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: _buildDentalConditionSection(),
                                ),
                                const SizedBox(height: 16),

                                // 移除患者材料部分 - 已迁移到患者详情页
                                // AnimatedContainer(...PatientMaterialsManager...)



                                // 第五行：治疗项目（占据整行）- 减少高度
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: DentalColors.cardGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: DentalColors.success.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: _buildStyledTextField(
                                    controller: _treatmentItemsController,
                                    labelText: '治疗项目',
                                    hintText: '填写患者需要的治疗项目',
                                    icon: Icons.healing,
                                    enabled: _canEditBasicInfo,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 底部按钮
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: DentalColors.cardGradient,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: DentalColors.divider.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: DentalColors.divider.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    foregroundColor: DentalColors.onSurfaceVariant,
                                  ),
                                  child: const Text(
                                    '取消',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: DentalColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DentalColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : () {
                                    print('保存按钮被点击');
                                    _handleSave();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isLoading) ...[
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.patient != null ? '更新中...' : '保存中...',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          widget.patient != null ? '更新' : '保存',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 处理保存操作
  Future<void> _handleSave() async {
    print('_handleSave 方法被调用');
    print('开始表单验证...');
    
    if (_formKey.currentState!.validate()) {
      print('表单验证通过，开始保存流程');

      // 设置加载状态
      setState(() {
        _isLoading = true;
      });

      try {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        bool canProceed = true;

        // 检查病历号是否重复
        if (_medicalRecordController.text.isNotEmpty) {
          int medicalRecordNumber =
              int.parse(_medicalRecordController.text);
          bool medicalRecordExists =
              await patientProvider.checkMedicalRecordExists(
                  medicalRecordNumber, _editingExistingPatient?.id ?? widget.patient?.id);

          if (medicalRecordExists) {
            // 使用更美观的对话框
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('重复的病历号',
                    style: TextStyle(fontSize: 16)),
                content: const Text('此病历号已被使用，请重新输入'),
                backgroundColor: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                      color: Colors.red, width: 1),
                ),
                contentPadding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 16),
                titlePadding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 0),
                actionsPadding:
                    const EdgeInsets.fromLTRB(8, 0, 8, 8),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('确定',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            canProceed = false;
          }
        }

        // 检查姓名是否重复
        if (canProceed) {
          bool nameExists =
              await patientProvider.checkPatientNameExists(
                  _nameController.text, _editingExistingPatient?.id ?? widget.patient?.id);

          if (nameExists) {
            // 获取已存在的患者信息用于选择
            List<Patient> existingPatients = await patientProvider.searchPatients(_nameController.text);
            Patient? selectedPatient;

            // 找到匹配的患者
            for (var patient in existingPatients) {
              if (patient.name == _nameController.text &&
                  patient.id != (_editingExistingPatient?.id ?? widget.patient?.id)) {
                selectedPatient = patient;
                break;
              }
            }

            if (selectedPatient != null) {
              // 显示选择对话框
              final bool? shouldLoadExisting = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('发现同名患者',
                      style: TextStyle(fontSize: 16)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('系统中已存在同名患者：'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('姓名: ${selectedPatient!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('年龄: ${selectedPatient.age}岁'),
                            Text('性别: ${selectedPatient.gender}'),
                            Text('电话: ${selectedPatient.mainPhone}'),
                            Text('首诊日期: ${DateFormat('yyyy-MM-dd').format(selectedPatient.first_visit_date)}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('请选择：'),
                    ],
                  ),
                  backgroundColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.orange, width: 1),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('继续添加新患者', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('编辑已存在患者'),
                    ),
                  ],
                ),
              );

              if (shouldLoadExisting == true) {
                // 加载已存在患者的信息到表单中
                _loadExistingPatientData(selectedPatient);
                return; // 不继续保存，而是编辑现有患者
              } else if (shouldLoadExisting == false) {
                // 继续添加新患者，允许重名，清除编辑已有患者状态
                setState(() {
                  _editingExistingPatient = null;
                });
                canProceed = true;
              } else {
                // 用户取消了，不继续
                canProceed = false;
              }
            } else {
              canProceed = false;
            }
          }
        }

        if (!canProceed) {
          return;
        }

        // 构建电话号码数据
        dynamic phoneData;
        if (_primaryPhoneController.text.isEmpty &&
            (!_hasBackupPhone ||
                _backupPhoneController.text.isEmpty)) {
          // 如果主电话和备用电话都为空，设置为空字符串
          phoneData = '';
        } else if (_hasBackupPhone &&
            _backupPhoneController.text.isNotEmpty) {
          // 如果有备用电话，使用JSON数组
          phoneData = jsonEncode([
            _primaryPhoneController.text,
            _backupPhoneController.text
          ]);
        } else {
          // 只有主电话
          phoneData = _primaryPhoneController.text;
        }

        // 生成牙齿状况JSON
        String dentalCondition = _generateDentalConditionJson();

        // 创建患者对象
        final Patient patient = Patient(
          id: _editingExistingPatient?.id ?? widget.patient?.id,
          name: _nameController.text,
          name_pinyin: (_editingExistingPatient ?? widget.patient)
              ?.name_pinyin, // 拼音字段会在PatientProvider中自动填充
          age: _ageController.text.isNotEmpty
              ? int.parse(_ageController.text)
              : 0,
          gender: _gender,
          phone: phoneData,
          medical_record_number:
              _medicalRecordController.text.isNotEmpty
                  ? int.parse(_medicalRecordController.text)
                  : null,
          address: _addressController.text.isNotEmpty
              ? _addressController.text
              : null,
          address_pinyin: (_editingExistingPatient ?? widget.patient)
              ?.address_pinyin, // 拼音字段会在PatientProvider中自动填充
          identification_number:
              _idNumberController.text.isNotEmpty
                  ? _idNumberController.text
                  : null,
          doctor: _doctorController.text.isNotEmpty
              ? _doctorController.text
              : null,
          dental_condition:
              dentalCondition.isNotEmpty ? dentalCondition : null,
          treatment_items:
              _treatmentItemsController.text.isNotEmpty
                  ? _treatmentItemsController.text
                  : null,
          first_visit_date: _firstVisitDate,
          total_cost: (_editingExistingPatient ?? widget.patient)?.total_cost ?? 0.0,
          created_at: (_editingExistingPatient ?? widget.patient)?.created_at ??
              DateTime.now(), // 编辑模式保留原创建时间，新建模式使用当前时间
          updated_at: DateTime.now(), // 始终更新"更新时间"
        );

        // 先保存患者，获取ID
        final savedPatient = await _savePatientAndGetId(patient);

        // 移除保存患者材料信息的逻辑 - 已迁移到患者详情页
        // if (savedPatient.id != null) {
        //   await _savePatientMaterials(savedPatient.id!);
        // }

        // 返回患者对象
        widget.onSave(savedPatient);

        Navigator.of(context).pop();
      } finally {
        // 重置加载状态
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 改进牙齿状况部分的标题和整体布局
  Widget _buildDentalConditionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '牙齿状况',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加记录', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: _addNewDentalChartRow,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 2),

          // 牙齿状况记录列表 - 增加高度给更多空间
          Container(
            height: _dentalChartRows.length > 1 ? 400 : 220, // 增加高度
            child: SingleChildScrollView(
              child: Column(
                children: _dentalChartRows
                    .map((row) => _buildDentalChartRow(row))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 修改十字图表显示模块，保留十字线但隐藏所有输入框边框，只显示光标和文本，光标远离横线
  Widget _buildSimpleCrossChart(
    TextEditingController topLeftController,
    TextEditingController topRightController,
    TextEditingController bottomLeftController,
    TextEditingController bottomRightController,
    TextEditingController noteController,
    Function(String)? onTopLeftChanged,
    Function(String)? onTopRightChanged,
    Function(String)? onBottomLeftChanged,
    Function(String)? onBottomRightChanged,
    Function(String)? onNoteChanged,
    int chartIndex, {
    bool enabled = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Stack(
            children: [
              // 十字线 - 横线
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1.5,
                  color: Colors.blue.shade300,
                ),
              ),
              // 十字线 - 竖线（高度减少）
              Center(
                child: Container(
                  width: 1.5,
                  height: 50,
                  color: Colors.blue.shade300,
                ),
              ),

              // 四个象限的输入框
              Column(
                children: [
                  // 上排 - 左上和右上
                  Expanded(
                    child: Row(
                      children: [
                        // 左上象限
                        Expanded(
                          child: TextField(
                            controller: topLeftController,
                            enabled: enabled,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(
                                  left: 0, bottom: 0, right: 4, top: 18),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: '',
                              hintStyle: const TextStyle(fontSize: 0),
                              isDense: true,
                              filled: false,
                            ),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: enabled ? Colors.black87 : Colors.grey,
                            ),
                            cursorColor: Colors.blue.shade300,
                            maxLines: 1,
                            onChanged: onTopLeftChanged,
                          ),
                        ),
                        // 右上象限
                        Expanded(
                          child: TextField(
                            controller: topRightController,
                            enabled: enabled,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(
                                  left: 4, bottom: 0, right: 0, top: 18),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: '',
                              hintStyle: const TextStyle(fontSize: 0),
                              isDense: true,
                              filled: false,
                            ),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 12,
                              color: enabled ? Colors.black87 : Colors.grey,
                            ),
                            cursorColor: Colors.blue.shade300,
                            maxLines: 1,
                            onChanged: onTopRightChanged,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 下排 - 左下和右下
                  Expanded(
                    child: Row(
                      children: [
                        // 左下象限
                        Expanded(
                          child: TextField(
                            controller: bottomLeftController,
                            enabled: enabled,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(
                                  left: 0, top: 0, right: 4, bottom: 18),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: '',
                              hintStyle: const TextStyle(fontSize: 0),
                              isDense: true,
                              filled: false,
                            ),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: enabled ? Colors.black87 : Colors.grey,
                            ),
                            cursorColor: Colors.blue.shade300,
                            maxLines: 1,
                            onChanged: onBottomLeftChanged,
                          ),
                        ),
                        // 右下象限
                        Expanded(
                          child: TextField(
                            controller: bottomRightController,
                            enabled: enabled,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(
                                  left: 4, top: 0, right: 0, bottom: 18),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: '',
                              hintStyle: const TextStyle(fontSize: 0),
                              isDense: true,
                              filled: false,
                            ),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 12,
                              color: enabled ? Colors.black87 : Colors.grey,
                            ),
                            cursorColor: Colors.blue.shade300,
                            maxLines: 1,
                            onChanged: onBottomRightChanged,
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
        // 添加备注输入框，位于十字图下方
        Container(
          margin: const EdgeInsets.only(top: 5),
          height: 30,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: TextField(
            controller: noteController,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: '',
              contentPadding: const EdgeInsets.only(bottom: 8),
              isDense: true,
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: enabled ? Colors.blue.shade300 : Colors.grey.shade300, 
                  width: 1.5,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: enabled ? Colors.blue.shade300 : Colors.grey.shade300, 
                  width: 1.5,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
              ),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              fillColor: Colors.transparent,
              filled: false,
            ),
            style: TextStyle(
              fontSize: 12,
              color: enabled ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.left,
            onChanged: onNoteChanged,
          ),
        ),
      ],
    );
  }

  // 修改牙齿状况行的显示，增加两个牙齿图表之间的间距
  Widget _buildDentalChartRow(DentalChartRow row) {
    final bool canEdit = _canEditDentalChartRow(row);
    final bool canDelete = _canDeleteDentalChartRow(row);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canEdit ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 创建者信息和权限提示
          if (row.createdByDoctor != null && row.createdByDoctor!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: canEdit ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    canEdit ? Icons.edit : Icons.visibility,
                    size: 12,
                    color: canEdit ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '创建医生: ${row.createdByDoctor}',
                    style: TextStyle(
                      fontSize: 10,
                      color: canEdit ? Colors.green.shade700 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (!canEdit)
                    Text(
                      '只读',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 日期选择器 - 调整宽度
              Container(
                width: 110,
                margin: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: canEdit ? () => _selectChartDate(context, row) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: canEdit ? Colors.grey.shade300 : Colors.grey.shade200,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: canEdit ? Colors.white : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14, 
                          color: canEdit ? AppTheme.primaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(row.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: canEdit ? Colors.black87 : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canEdit)
                          const Icon(Icons.arrow_drop_down, size: 14),
                      ],
                    ),
                  ),
                ),
              ),

              // 牙齿图表组
              Expanded(
                child: Row(
                  children: [
                    // 第一个牙齿图表
                    Expanded(
                      child: _buildSimpleCrossChart(
                        row.chart1.topLeftController,
                        row.chart1.topRightController,
                        row.chart1.bottomLeftController,
                        row.chart1.bottomRightController,
                        row.chart1.noteController,
                        canEdit ? (value) => row.chart1.topLeft = value : null,
                        canEdit ? (value) => row.chart1.topRight = value : null,
                        canEdit ? (value) => row.chart1.bottomLeft = value : null,
                        canEdit ? (value) => row.chart1.bottomRight = value : null,
                        canEdit ? (value) => row.chart1.note = value : null,
                        1,
                        enabled: canEdit,
                      ),
                    ),

                    const SizedBox(width: 6), // 减少间距

                    // 第二个牙齿图表
                    Expanded(
                      child: _buildSimpleCrossChart(
                        row.chart2.topLeftController,
                        row.chart2.topRightController,
                        row.chart2.bottomLeftController,
                        row.chart2.bottomRightController,
                        row.chart2.noteController,
                        canEdit ? (value) => row.chart2.topLeft = value : null,
                        canEdit ? (value) => row.chart2.topRight = value : null,
                        canEdit ? (value) => row.chart2.bottomLeft = value : null,
                        canEdit ? (value) => row.chart2.bottomRight = value : null,
                        canEdit ? (value) => row.chart2.note = value : null,
                        2,
                        enabled: canEdit,
                      ),
                    ),

                    const SizedBox(width: 6), // 间距

                    // 新增第三个牙齿图表
                    Expanded(
                      child: _buildSimpleCrossChart(
                        row.chart3.topLeftController,
                        row.chart3.topRightController,
                        row.chart3.bottomLeftController,
                        row.chart3.bottomRightController,
                        row.chart3.noteController,
                        canEdit ? (value) => row.chart3.topLeft = value : null,
                        canEdit ? (value) => row.chart3.topRight = value : null,
                        canEdit ? (value) => row.chart3.bottomLeft = value : null,
                        canEdit ? (value) => row.chart3.bottomRight = value : null,
                        canEdit ? (value) => row.chart3.note = value : null,
                        3,
                        enabled: canEdit,
                      ),
                    ),
                  ],
                ),
              ),

              // 删除按钮 - 更紧凑，添加权限控制
              if (_dentalChartRows.length > 1 && canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: '删除此记录',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      _dentalChartRows.remove(row);
                      // 重新设置索引
                      for (int i = 0; i < _dentalChartRows.length; i++) {
                        _dentalChartRows[i].index = i;
                      }
                    });
                  },
                ),
              
              // 如果不能删除但有多行，显示锁定图标
              if (_dentalChartRows.length > 1 && !canDelete)
                Container(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.grey,
                    size: 18,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建样式化的文本输入框
  Widget _buildStyledTextField({
    Key? key,
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onFieldSubmitted,
    int maxLines = 1,
    TextAlignVertical? textAlignVertical,
    bool enabled = true,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      maxLines: maxLines,
      textAlignVertical: textAlignVertical ?? TextAlignVertical.center, // 使用传入的对齐方式或默认居中对齐
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: enabled ? DentalColors.primary : Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.error),
        ),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.8) : Colors.grey.withOpacity(0.1),
        contentPadding: maxLines > 1 
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16) // 多行输入框减少垂直内边距
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 单行输入框减少垂直内边距
        labelStyle: TextStyle(
          color: enabled ? DentalColors.onSurfaceVariant : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: enabled ? DentalColors.onSurfaceVariant.withOpacity(0.6) : Colors.grey.withOpacity(0.6),
        ),
        alignLabelWithHint: true, // 确保标签与提示文本对齐
      ),
      style: TextStyle(
        color: enabled ? DentalColors.onSurface : Colors.grey,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2, // 设置行高，有助于垂直居中
      ),
    );
  }

  // 构建样式化的下拉选择框
  Widget _buildStyledDropdown({
    required String value,
    required String labelText,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: enabled ? DentalColors.primary : Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.divider.withOpacity(0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DentalColors.primary, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.8) : Colors.grey.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: TextStyle(
          color: enabled ? DentalColors.onSurfaceVariant : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      items: enabled ? items : null,
      onChanged: enabled ? onChanged : null,
      style: TextStyle(
        color: DentalColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: DentalColors.primary),
    );
  }

  // 构建样式化的日期选择字段
  Widget _buildStyledDateField({
    required String labelText,
    required DateTime date,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? DentalColors.divider.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: enabled ? Colors.white.withOpacity(0.8) : Colors.grey.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: enabled ? DentalColors.primary : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labelText,
                    style: TextStyle(
                      color: enabled ? DentalColors.onSurfaceVariant : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy-MM-dd').format(date),
                    style: TextStyle(
                      color: enabled ? DentalColors.onSurface : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: enabled ? DentalColors.primary : Colors.grey),
          ],
        ),
      ),
    );
  }



  // 移除加载已存在患者材料信息的方法
  // Future<void> _loadExistingPatientMaterials(int patientId) async { ... }
  
  // 检查编辑权限
  void _checkEditPermissions() {
    if (widget.patient != null) {
      // 编辑模式：检查是否可以编辑基本信息（除了牙齿状况）
      _canEditBasicInfo = PermissionUtils.canEditDoctor(context, widget.patient!.doctor);
    } else {
      // 新增模式：可以编辑所有信息
      _canEditBasicInfo = true;
    }
  }

  // 检查是否可以编辑指定的牙齿状况行
  bool _canEditDentalChartRow(DentalChartRow row) {
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
      
      // 如果没有创建者信息，或者创建者为空，则不能编辑
      if (row.createdByDoctor == null || row.createdByDoctor!.isEmpty) {
        return false;
      }
      
      // 获取当前用户的医生姓名
      String currentDoctorName = currentUser.doctor?.isNotEmpty == true 
          ? currentUser.doctor! 
          : currentUser.username;
      
      // 只能编辑自己创建的牙齿状况
      return row.createdByDoctor == currentDoctorName;
    } catch (e) {
      print('检查牙齿状况编辑权限时出错: $e');
      return false;
    }
  }

  // 检查是否可以删除指定的牙齿状况行
  bool _canDeleteDentalChartRow(DentalChartRow row) {
    // 删除权限与编辑权限相同
    return _canEditDentalChartRow(row);
  }

}
