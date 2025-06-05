import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../providers/database_provider.dart';

// 患者表单对话框
class PatientFormDialog extends StatefulWidget {
  final Function(Patient) onSave;
  final Patient? patient; // 如果是编辑模式，传入患者对象

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
  final TextEditingController _doctorController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _firstVisitDate = DateTime.now();

    if (widget.patient != null) {
      // 编辑模式，加载患者数据
      _loadPatientData();
    } else {
      // 添加模式，初始化默认值
      _initializeDefaultValues();
    }
  }

  // 初始化默认值的方法
  Future<void> _initializeDefaultValues() async {
    // 添加一个初始的牙齿状况行
    _addNewDentalChartRow();

    // 获取默认病历号
    await _getDefaultMedicalRecordNumber();
  }

  // 获取默认病历号
  Future<void> _getDefaultMedicalRecordNumber() async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      int defaultRecordNumber = 1; // 默认值

      // 获取最大病历号
      if (dbProvider.dataSourceType == 'sqlite') {
        final db = await dbProvider.database;
        final result = await db!.query(
          'patients',
          columns: ['medical_record_number'],
          where: 'medical_record_number IS NOT NULL',
          orderBy: 'medical_record_number DESC',
          limit: 1,
        );

        if (result.isNotEmpty) {
          // 直接从结果中获取整数值，避免通过Patient对象转换
          var maxRecordNumber = result.first['medical_record_number'];
          if (maxRecordNumber != null) {
            // 确保转换为整数
            if (maxRecordNumber is int) {
              defaultRecordNumber = maxRecordNumber + 1;
            } else if (maxRecordNumber is String) {
              defaultRecordNumber = int.tryParse(maxRecordNumber) ?? 1;
              defaultRecordNumber += 1;
            }
            print('找到最大病历号: $maxRecordNumber, 新病历号: $defaultRecordNumber');
          } else {
            print('医疗记录号为空，使用默认值: 1');
          }
        } else {
          print('未找到现有病历号，使用默认值: 1');
        }
      } else {
        // MySQL查询
        final results = await dbProvider.mysqlConnection!.query(
          'SELECT medical_record_number FROM patients WHERE medical_record_number IS NOT NULL ORDER BY medical_record_number + 0 DESC LIMIT 1',
        );

        if (results.isNotEmpty &&
            results.first['medical_record_number'] != null) {
          // 直接从结果中获取值，避免通过Patient对象转换
          var maxRecordNumber = results.first['medical_record_number'];
          if (maxRecordNumber != null) {
            // 确保转换为整数
            if (maxRecordNumber is int) {
              defaultRecordNumber = maxRecordNumber + 1;
            } else if (maxRecordNumber is String) {
              defaultRecordNumber = int.tryParse(maxRecordNumber) ?? 1;
              defaultRecordNumber += 1;
            }
            print('找到最大病历号: $maxRecordNumber, 新病历号: $defaultRecordNumber');
          } else {
            print('医疗记录号为空，使用默认值: 1');
          }
        } else {
          print('未找到现有病历号，使用默认值: 1');
        }
      }

      if (mounted) {
        setState(() {
          _medicalRecordController.text = defaultRecordNumber.toString();
        });
      }
    } catch (e) {
      print('获取最大病历号失败: $e');
      // 设置一个默认值
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

        // 创建新的牙齿图表行
        DentalChartRow row = DentalChartRow(
          index: i,
          date: chartDate,
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

  // 添加新的牙齿状况行
  void _addNewDentalChartRow() {
    setState(() {
      _dentalChartRows.add(DentalChartRow(
        index: _dentalChartRows.length,
        date: DateTime.now(),
      ));
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

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _primaryPhoneController.dispose();
    _backupPhoneController.dispose();
    _medicalRecordController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _doctorController.dispose();
    _treatmentItemsController.dispose();
    // 释放牙齿状况行中的控制器
    for (var row in _dentalChartRows) {
      row.dispose();
    }
    _hideExistingPatientOverlay();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _firstVisitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _firstVisitDate) {
      setState(() {
        _firstVisitDate = picked;
      });
    }
  }

  Future<void> _selectChartDate(
      BuildContext context, DentalChartRow row) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: row.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != row.date) {
      setState(() {
        row.date = picked;
      });
    }
  }

  void _checkNameExists() async {
    // 如果名字为空，不检查
    if (_nameController.text.isEmpty) {
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // 先检查名字是否存在
    bool nameExists = await dbProvider.checkPatientNameExists(
        _nameController.text, widget.patient?.id);

    if (nameExists) {
      // 如果名字存在，获取该患者的详细信息
      List<Patient> patients =
          await dbProvider.searchPatients(_nameController.text);
      if (patients.isNotEmpty) {
        // 找到匹配当前输入姓名的患者
        for (var patient in patients) {
          if (patient.name == _nameController.text &&
              patient.id != widget.patient?.id) {
            setState(() {
              _existingPatient = patient;
            });
            _showExistingPatientOverlay();
            return;
          }
        }
      }
    } else {
      // 名字不存在，清除已存在患者信息
      setState(() {
        _existingPatient = null;
        _hideExistingPatientOverlay();
      });
    }
  }

  void _showExistingPatientOverlay() {
    if (_existingPatient == null) return;

    _hideExistingPatientOverlay(); // 先隐藏已存在的弹窗

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 65), // 调整弹窗位置
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '发现同名患者',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _hideExistingPatientOverlay,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 患者信息
                  _buildInfoRow(
                      '病历号',
                      _existingPatient!.medical_record_number?.toString() ??
                          '无'),
                  _buildInfoRow('姓名', _existingPatient!.name),
                  _buildInfoRow('性别', _existingPatient!.gender),
                  _buildInfoRow('电话', _existingPatient!.phone),
                  if (_existingPatient!.address != null &&
                      _existingPatient!.address!.isNotEmpty)
                    _buildInfoRow('地址', _existingPatient!.address!),

                  const SizedBox(height: 12),
                  const Text(
                    '请确认是否为新患者',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.patient == null ? '添加患者' : '编辑患者',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 表单内容
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一行：病历号、姓名、年龄、性别、首诊日期
                      Row(
                        children: [
                          // 病历号
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _medicalRecordController,
                              decoration: const InputDecoration(
                                labelText: '病历号',
                                hintText: '选填',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 姓名
                          Expanded(
                            flex: 2,
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                // 当输入框失去焦点时检查姓名是否存在
                                if (!hasFocus &&
                                    _nameController.text.isNotEmpty) {
                                  _checkNameExists();
                                }
                              },
                              child: CompositedTransformTarget(
                                link: _layerLink,
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: '姓名',
                                    hintText: '输入患者姓名',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '请输入姓名';
                                    }
                                    return null;
                                  },
                                  onTap: () {
                                    // 清除弹窗
                                    _hideExistingPatientOverlay();
                                  },
                                  onChanged: (value) {
                                    // 清除弹窗
                                    _hideExistingPatientOverlay();
                                  },
                                  onEditingComplete: () {
                                    _checkNameExists();
                                    FocusScope.of(context)
                                        .nextFocus(); // 移动到下一个输入框
                                  },
                                  onFieldSubmitted: (value) {
                                    _checkNameExists();
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 年龄
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              decoration: const InputDecoration(
                                labelText: '年龄',
                                hintText: '输入年龄',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return null; // 允许年龄为空
                                }
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
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: const InputDecoration(
                                labelText: '性别',
                              ),
                              items: const [
                                DropdownMenuItem(value: '男', child: Text('男')),
                                DropdownMenuItem(value: '女', child: Text('女')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _gender = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 首诊日期
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: '首诊日期',
                                ),
                                child: Text(
                                  DateFormat('yyyy-MM-dd')
                                      .format(_firstVisitDate),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 第二行：主要电话和备用电话
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 主电话
                          Expanded(
                            flex: 2,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _primaryPhoneController,
                                    decoration: const InputDecoration(
                                      labelText: '主要电话',
                                      hintText: '输入11位手机号码',
                                    ),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null; // 允许电话号码为空
                                      }
                                      final RegExp phoneRegex =
                                          RegExp(r'^1[3-9]\d{9}$');
                                      if (!phoneRegex.hasMatch(value)) {
                                        return '请输入正确的11位手机号码';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(_hasBackupPhone
                                      ? Icons.remove_circle
                                      : Icons.add_circle),
                                  color: _hasBackupPhone
                                      ? Colors.red
                                      : Colors.blue,
                                  tooltip:
                                      _hasBackupPhone ? '移除备用电话' : '添加备用电话',
                                  onPressed: () {
                                    setState(() {
                                      _hasBackupPhone = !_hasBackupPhone;
                                      if (!_hasBackupPhone) {
                                        _backupPhoneController.clear();
                                      }
                                    });
                                  },
                                ),
                                if (_hasBackupPhone)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: TextFormField(
                                        controller: _backupPhoneController,
                                        decoration: const InputDecoration(
                                          labelText: '备用电话',
                                          hintText: '输入11位手机号码',
                                        ),
                                        keyboardType: TextInputType.phone,
                                        validator: (value) {
                                          if (value != null &&
                                              value.isNotEmpty) {
                                            final RegExp phoneRegex =
                                                RegExp(r'^1[3-9]\d{9}$');
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
                                  child: TextFormField(
                                    controller: _doctorController,
                                    decoration: const InputDecoration(
                                      labelText: '主治医生',
                                      hintText: '选填',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // 身份证号
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _idNumberController,
                                    decoration: const InputDecoration(
                                      labelText: '身份证号',
                                      hintText: '选填',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 第三行：住址（占据整行）
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: '住址',
                          hintText: '选填住址信息',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 第四行：牙齿状况（十字图表）
                      _buildDentalConditionSection(),
                      const SizedBox(height: 24),

                      // 第五行：治疗项目（占据整行）
                      TextFormField(
                        controller: _treatmentItemsController,
                        decoration: const InputDecoration(
                          labelText: '治疗项目',
                          hintText: '填写患者需要的治疗项目',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 底部按钮
            const SizedBox(height: 16),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final dbProvider =
                          Provider.of<DatabaseProvider>(context, listen: false);
                      bool canProceed = true;

                      // 检查病历号是否重复
                      if (_medicalRecordController.text.isNotEmpty) {
                        int medicalRecordNumber =
                            int.parse(_medicalRecordController.text);
                        bool medicalRecordExists =
                            await dbProvider.checkMedicalRecordExists(
                                medicalRecordNumber, widget.patient?.id);

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
                            await dbProvider.checkPatientNameExists(
                                _nameController.text, widget.patient?.id);

                        if (nameExists) {
                          // 使用更美观的对话框
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('重复的姓名',
                                  style: TextStyle(fontSize: 16)),
                              content: const Text('此姓名已存在，请确认是否为新患者'),
                              backgroundColor: Colors.white.withOpacity(0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                    color: Colors.orange, width: 1),
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
                                      style: TextStyle(color: Colors.orange)),
                                ),
                              ],
                            ),
                          );
                          canProceed = false;
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
                        id: widget.patient?.id,
                        name: _nameController.text,
                        name_pinyin: widget.patient
                            ?.name_pinyin, // 拼音字段会在DatabaseProvider中自动填充
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
                        address_pinyin: widget.patient
                            ?.address_pinyin, // 拼音字段会在DatabaseProvider中自动填充
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
                        total_cost: widget.patient?.total_cost ?? 0.0,
                        created_at: widget.patient?.created_at ??
                            DateTime.now(), // 编辑模式保留原创建时间，新建模式使用当前时间
                        updated_at: DateTime.now(), // 始终更新"更新时间"
                      );

                      // 返回患者对象
                      widget.onSave(patient);
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 改进牙齿状况部分的标题和整体布局
  Widget _buildDentalConditionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _addNewDentalChartRow,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),

          // 牙齿状况记录列表 - 增加最大高度以显示更多记录
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _dentalChartRows.length > 1 ? 350 : 160,
            ),
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
    Function(String) onTopLeftChanged,
    Function(String) onTopRightChanged,
    Function(String) onBottomLeftChanged,
    Function(String) onBottomRightChanged,
    Function(String) onNoteChanged,
    int chartIndex,
  ) {
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
                            style: const TextStyle(fontSize: 12),
                            cursorColor: Colors.blue.shade300,
                            maxLines: 1,
                            onChanged: onTopLeftChanged,
                          ),
                        ),
                        // 右上象限
                        Expanded(
                          child: TextField(
                            controller: topRightController,
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
                            style: const TextStyle(fontSize: 12),
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
                            style: const TextStyle(fontSize: 12),
                            cursorColor: Colors.blue.shade300,
                            maxLines: 1,
                            onChanged: onBottomLeftChanged,
                          ),
                        ),
                        // 右下象限
                        Expanded(
                          child: TextField(
                            controller: bottomRightController,
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
                            style: const TextStyle(fontSize: 12),
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
            decoration: InputDecoration(
              hintText: '',
              contentPadding: const EdgeInsets.only(bottom: 8),
              isDense: true,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
              ),
              fillColor: Colors.transparent,
              filled: false,
            ),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.left,
            onChanged: onNoteChanged,
          ),
        ),
      ],
    );
  }

  // 修改牙齿状况行的显示，增加两个牙齿图表之间的间距
  Widget _buildDentalChartRow(DentalChartRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 日期选择器 - 调整宽度
          Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _selectChartDate(context, row),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(row.date),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                    (value) => row.chart1.topLeft = value,
                    (value) => row.chart1.topRight = value,
                    (value) => row.chart1.bottomLeft = value,
                    (value) => row.chart1.bottomRight = value,
                    (value) => row.chart1.note = value,
                    1,
                  ),
                ),

                const SizedBox(width: 8), // 减少间距

                // 第二个牙齿图表
                Expanded(
                  child: _buildSimpleCrossChart(
                    row.chart2.topLeftController,
                    row.chart2.topRightController,
                    row.chart2.bottomLeftController,
                    row.chart2.bottomRightController,
                    row.chart2.noteController,
                    (value) => row.chart2.topLeft = value,
                    (value) => row.chart2.topRight = value,
                    (value) => row.chart2.bottomLeft = value,
                    (value) => row.chart2.bottomRight = value,
                    (value) => row.chart2.note = value,
                    2,
                  ),
                ),

                const SizedBox(width: 8), // 间距

                // 新增第三个牙齿图表
                Expanded(
                  child: _buildSimpleCrossChart(
                    row.chart3.topLeftController,
                    row.chart3.topRightController,
                    row.chart3.bottomLeftController,
                    row.chart3.bottomRightController,
                    row.chart3.noteController,
                    (value) => row.chart3.topLeft = value,
                    (value) => row.chart3.topRight = value,
                    (value) => row.chart3.bottomLeft = value,
                    (value) => row.chart3.bottomRight = value,
                    (value) => row.chart3.note = value,
                    3,
                  ),
                ),
              ],
            ),
          ),

          // 删除按钮 - 更紧凑
          if (_dentalChartRows.length > 1)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
        ],
      ),
    );
  }
}

// 定义牙齿图表类
class DentalChart {
  final TextEditingController topLeftController = TextEditingController();
  final TextEditingController topRightController = TextEditingController();
  final TextEditingController bottomLeftController = TextEditingController();
  final TextEditingController bottomRightController = TextEditingController();
  final TextEditingController noteController =
      TextEditingController(); // 添加备注控制器

  String topLeft = '';
  String topRight = '';
  String bottomLeft = '';
  String bottomRight = '';
  String note = ''; // 添加备注字段

  void dispose() {
    topLeftController.dispose();
    topRightController.dispose();
    bottomLeftController.dispose();
    bottomRightController.dispose();
    noteController.dispose(); // 释放备注控制器
  }
}

// 定义牙齿图表行类
class DentalChartRow {
  int index;
  DateTime date;
  DentalChart chart1 = DentalChart();
  DentalChart chart2 = DentalChart();
  DentalChart chart3 = DentalChart();

  DentalChartRow({
    required this.index,
    required this.date,
  });

  void dispose() {
    chart1.dispose();
    chart2.dispose();
    chart3.dispose();
  }
}
