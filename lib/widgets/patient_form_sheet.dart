import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class PatientFormSheet extends StatefulWidget {
  final Patient? patient;
  final Function(bool, String) onSaved;
  final int? initialMedicalRecordNumber;

  const PatientFormSheet({
    Key? key,
    this.patient,
    required this.onSaved,
    this.initialMedicalRecordNumber,
  }) : super(key: key);

  @override
  _PatientFormSheetState createState() => _PatientFormSheetState();
}

class _PatientFormSheetState extends State<PatientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = '男'; // 默认为男
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _doctorController = TextEditingController();
  final _medicalRecordController = TextEditingController();
  final _treatmentItemsController = TextEditingController(); // 添加治疗项目控制器
  DateTime _firstVisitDate = DateTime.now(); // 将该变量改为非final类型
  bool _isLoading = false;

  // 添加 ScrollController
  final ScrollController _scrollController = ScrollController();

  // 额外电话号码的控制器列表
  final List<TextEditingController> _additionalPhoneControllers = [];

  // 牙齿状况相关状态
  List<Map<String, dynamic>> _dentalRecords = [];

  // 添加一个实例变量来跟踪当前显示的牙齿记录索引
  int _currentDentalRecordIndex = 0;

  @override
  void initState() {
    super.initState();

    print('PatientFormSheet初始化开始...');

    if (widget.patient != null) {
      // 编辑现有患者
      print('初始化编辑患者表单');
      _nameController.text = widget.patient!.name;
      _ageController.text = widget.patient!.age.toString();
      _gender = widget.patient!.gender == '女' ? '女' : '男';
      _processPhoneNumbers(widget.patient!.phone);
      _addressController.text = widget.patient!.address ?? '';
      _idNumberController.text = widget.patient!.identificationNumber ?? '';
      _doctorController.text = widget.patient!.doctor ?? '';
      _treatmentItemsController.text = widget.patient!.treatmentItems ?? '';

      if (widget.patient!.medicalRecordNumber != null) {
        _medicalRecordController.text =
            widget.patient!.medicalRecordNumber.toString();
        print('使用现有患者的病历号: ${_medicalRecordController.text}');
      }

      // 加载牙齿状况数据
      _loadDentalCondition(widget.patient!.dentalCondition);
    } else {
      // 添加新患者
      print('初始化新患者表单');
      _phoneController.text = '';

      // 初始化一个空的牙齿记录
      print('创建新的牙齿记录...');
      final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      setState(() {
        _dentalRecords = [
          {
            'date': currentDate,
            'chart1-top-left': '',
            'chart1-top-right': '',
            'chart1-bottom-left': '',
            'chart1-bottom-right': '',
            'chart1-note': '请在此输入图表1的备注',
            'chart2-top-left': '',
            'chart2-top-right': '',
            'chart2-bottom-left': '',
            'chart2-bottom-right': '',
            'chart2-note': '请在此输入图表2的备注',
            'chart3-top-left': '',
            'chart3-top-right': '',
            'chart3-bottom-left': '',
            'chart3-bottom-right': '',
            'chart3-note': '请在此输入图表3的备注',
          },
        ];

        print('初始化牙齿记录数据:');
        print('记录数量: ${_dentalRecords.length}');
        print('日期: ${_dentalRecords[0]['date']}');
        print('图表1数据: ${_dentalRecords[0]}');
      });

      // 设置病历号
      if (widget.initialMedicalRecordNumber != null &&
          widget.initialMedicalRecordNumber! > 0) {
        _medicalRecordController.text =
            widget.initialMedicalRecordNumber.toString();
        print('使用传入的初始病历号: ${widget.initialMedicalRecordNumber}');
      } else {
        _medicalRecordController.text = '加载中...';
        print('未提供初始病历号，设置临时值并异步获取');
        _fetchAndSetMedicalRecordNumber();
      }
    }

    print('PatientFormSheet初始化完成');

    // 确保在初始化完成后触发一次重建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          print('强制更新UI - 当前牙齿记录数: ${_dentalRecords.length}');
          for (var record in _dentalRecords) {
            print('记录数据:');
            print('  日期: ${record['date']}');
            print('  图表1-左上: ${record['chart1-top-left']}');
            print('  图表1-备注: ${record['chart1-note']}');
            print('  图表2-备注: ${record['chart2-note']}');
            print('  图表3-备注: ${record['chart3-note']}');
          }
        });
      }
    });
  }

  // 获取并设置默认病历号的方法
  Future<void> _fetchAndSetMedicalRecordNumber() async {
    print('开始获取下一个病历号...');

    try {
      if (!mounted) return;

      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      // 获取最大病历号，而不是患者总数
      final maxMedicalRecordNumber =
          await dbProvider.getMaxMedicalRecordNumber();

      print('获取到最大病历号: $maxMedicalRecordNumber');

      if (mounted) {
        setState(() {
          _medicalRecordController.text =
              (maxMedicalRecordNumber + 1).toString();
        });
        print('病历号已设置为最大病历号+1: ${_medicalRecordController.text}');
      }
    } catch (e) {
      print('获取病历号失败: $e');
      if (mounted) {
        setState(() {
          _medicalRecordController.text = '1';
        });
        print('出错，设置默认病历号为: 1');
      }
    }
  }

  // 专门处理电话号码的辅助方法
  void _processPhoneNumbers(String phoneStr) {
    print('处理电话号码: $phoneStr');
    print('电话号码类型: ${phoneStr.runtimeType}');
    print('电话号码长度: ${phoneStr.length}');

    // 原始格式判断
    if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
      print('电话号码原始格式: JSON数组格式');
    } else if (phoneStr.contains(',')) {
      print('电话号码原始格式: 逗号分隔格式');
    } else {
      print('电话号码原始格式: 单个电话号码');
    }

    if (phoneStr.isEmpty) {
      _phoneController.text = '';
      return;
    }

    // 特殊情况处理：删除JSON字符串中可能存在的转义字符
    String cleanPhoneStr = phoneStr;
    if (phoneStr.contains('\\')) {
      cleanPhoneStr = phoneStr.replaceAll('\\', '');
      print('移除转义字符后: $cleanPhoneStr');
    }

    // 尝试直接解析多个电话号码
    List<String> phoneNumbers = [];

    // 检查是否为JSON格式
    if (cleanPhoneStr.startsWith('[') && cleanPhoneStr.endsWith(']')) {
      print('检测到JSON格式电话号码: $cleanPhoneStr');

      try {
        // 尝试标准JSON解析
        final parsed = jsonDecode(cleanPhoneStr);
        print('JSON解析结果类型: ${parsed.runtimeType}');

        if (parsed is List) {
          print('成功解析为JSON数组: $parsed');
          if (parsed.isNotEmpty) {
            phoneNumbers = parsed.map((p) => p.toString()).toList();
            print('从JSON提取的电话号码列表: $phoneNumbers');
          }
        } else if (parsed is String) {
          // 处理嵌套JSON字符串的情况
          print('JSON解析结果是字符串，尝试再次解析');
          try {
            final nestedParsed = jsonDecode(parsed);
            if (nestedParsed is List) {
              phoneNumbers = nestedParsed.map((p) => p.toString()).toList();
              print('从嵌套JSON提取的电话号码列表: $phoneNumbers');
            } else {
              // 单个电话号码
              phoneNumbers = [parsed];
            }
          } catch (e) {
            print('嵌套JSON解析失败: $e，当作单个电话号码处理');
            phoneNumbers = [parsed];
          }
        }
      } catch (e) {
        print('标准JSON解析失败: $e，类型: ${e.runtimeType}');

        // 使用正则表达式提取电话号码
        final RegExp regex = RegExp(r'"([^"]*)"');
        final matches = regex.allMatches(cleanPhoneStr);

        if (matches.isNotEmpty) {
          for (final match in matches) {
            if (match.group(1) != null && match.group(1)!.isNotEmpty) {
              phoneNumbers.add(match.group(1)!);
            }
          }
          print('通过正则表达式提取的电话: $phoneNumbers');
        }

        // 如果正则表达式没有匹配到，尝试直接分割字符串
        if (phoneNumbers.isEmpty) {
          // 去除方括号
          String content = cleanPhoneStr.substring(1, cleanPhoneStr.length - 1);
          // 分割字符串
          List<String> parts = content.split(',');
          for (var part in parts) {
            String clean = part.trim();
            // 去除可能的引号
            if (clean.startsWith('"') && clean.endsWith('"')) {
              clean = clean.substring(1, clean.length - 1);
            }
            if (clean.isNotEmpty) {
              phoneNumbers.add(clean);
            }
          }
          print('通过分割字符串提取的电话: $phoneNumbers');
        }
      }
    } else if (cleanPhoneStr.contains(',')) {
      // 处理逗号分隔的电话号码
      print('处理逗号分隔的电话号码: $cleanPhoneStr');
      phoneNumbers =
          cleanPhoneStr
              .split(',')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
      print('通过逗号分割提取的电话: $phoneNumbers');
    } else {
      // 单个电话号码
      phoneNumbers = [cleanPhoneStr];
      print('单个电话号码: $cleanPhoneStr');
    }

    // 设置电话号码到输入框
    if (phoneNumbers.isNotEmpty) {
      _phoneController.text = phoneNumbers[0];
      print('设置主电话: ${phoneNumbers[0]}');

      // 清理之前的额外电话控制器
      if (_additionalPhoneControllers.isNotEmpty) {
        print('清理之前的额外电话控制器: ${_additionalPhoneControllers.length}个');
        for (var controller in _additionalPhoneControllers) {
          controller.dispose();
        }
        _additionalPhoneControllers.clear();
      }

      // 添加额外电话
      for (int i = 1; i < phoneNumbers.length; i++) {
        print('添加备用电话 $i: ${phoneNumbers[i]}');
        _additionalPhoneControllers.add(
          TextEditingController(text: phoneNumbers[i]),
        );
      }

      print(
        '设置了${phoneNumbers.length}个电话号码，主电话:${_phoneController.text}，额外电话:${_additionalPhoneControllers.length}个',
      );
    } else {
      // 无法解析，使用原始字符串
      _phoneController.text = phoneStr;
      print('无法解析电话号码，使用原始字符串: $phoneStr');
    }
  }

  // 从患者数据中加载牙齿状况数据
  void _loadDentalCondition(String? dentalCondition) {
    print('开始加载牙齿状况数据: $dentalCondition');

    if (dentalCondition == null || dentalCondition.isEmpty) {
      print('牙齿状况数据为空，创建默认记录');
      // 创建默认的空记录
      _dentalRecords = [_createEmptyDentalRecord()];
      return;
    }

    try {
      print('尝试解析牙齿状况数据: $dentalCondition');
      // 解析JSON
      Map<String, dynamic> condition = json.decode(dentalCondition);
      print('原始牙齿状况数据: $condition');

      // 找出所有索引
      Set<int> indices = {};
      condition.keys.forEach((key) {
        if (key.contains('-')) {
          final parts = key.split('-');
          if (parts.length > 1 && parts.last.isNotEmpty) {
            try {
              final index = int.parse(parts.last);
              indices.add(index);
            } catch (e) {
              print('解析索引失败: $key');
            }
          }
        }
      });

      print('找到的索引列表: $indices');
      if (indices.isEmpty) {
        print('未找到有效的索引，创建默认记录');
        _dentalRecords = [_createEmptyDentalRecord()];
        return;
      }

      // 根据索引构建记录
      _dentalRecords = [];
      for (int i in indices) {
        Map<String, dynamic> record = {
          'date':
              condition['date-$i'] ??
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
        };

        // 提取每个图表的数据
        for (int chartNum = 1; chartNum <= 3; chartNum++) {
          String chartPrefix = 'chart$chartNum';
          // 提取所有字段，确保即使原始数据未提供也有默认值
          record['$chartPrefix-top-left'] =
              condition['$chartPrefix-top-left-$i'] ?? '';
          record['$chartPrefix-top-right'] =
              condition['$chartPrefix-top-right-$i'] ?? '';
          record['$chartPrefix-bottom-left'] =
              condition['$chartPrefix-bottom-left-$i'] ?? '';
          record['$chartPrefix-bottom-right'] =
              condition['$chartPrefix-bottom-right-$i'] ?? '';
          record['$chartPrefix-note'] =
              condition['$chartPrefix-note-$i'] ?? '请在此输入图表$chartNum的备注';
        }

        print('构建的记录 $i: $record');
        _dentalRecords.add(record);
      }

      print('最终设置的牙齿记录: $_dentalRecords');
    } catch (e) {
      print('解析牙齿状况数据失败: $e');
      // 创建默认的空记录
      _dentalRecords = [_createEmptyDentalRecord()];
    }

    print('记录数量: ${_dentalRecords.length}');
  }

  // 创建一个新的空记录
  Map<String, dynamic> _createEmptyDentalRecord() {
    Map<String, dynamic> record = {
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };

    // 为每个图表创建空字段
    for (int i = 1; i <= 3; i++) {
      String chartPrefix = 'chart$i';
      record['$chartPrefix-top-left'] = '';
      record['$chartPrefix-top-right'] = '';
      record['$chartPrefix-bottom-left'] = '';
      record['$chartPrefix-bottom-right'] = '';
      record['$chartPrefix-note'] = '请在此输入图表$i的备注';
    }

    return record;
  }

  void _addNewDentalRecord() {
    print('添加新的牙齿记录...');
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    setState(() {
      _dentalRecords.add({
        'date': currentDate,
        'chart1-top-left': '',
        'chart1-top-right': '',
        'chart1-bottom-left': '',
        'chart1-bottom-right': '',
        'chart1-note': '请在此输入图表1的备注',
        'chart2-top-left': '',
        'chart2-top-right': '',
        'chart2-bottom-left': '',
        'chart2-bottom-right': '',
        'chart2-note': '请在此输入图表2的备注',
        'chart3-top-left': '',
        'chart3-top-right': '',
        'chart3-bottom-left': '',
        'chart3-bottom-right': '',
        'chart3-note': '请在此输入图表3的备注',
      });

      print('新记录已添加:');
      print('当前记录总数: ${_dentalRecords.length}');
      print('新记录数据:');
      print('  日期: ${_dentalRecords.last['date']}');
      print('  图表1-备注: ${_dentalRecords.last['chart1-note']}');
      print('  图表2-备注: ${_dentalRecords.last['chart2-note']}');
      print('  图表3-备注: ${_dentalRecords.last['chart3-note']}');
    });

    // 确保UI更新并滚动到新添加的记录
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeDentalRecord(int index) {
    setState(() {
      if (_dentalRecords.length > 1) {
        _dentalRecords.removeAt(index);
      } else {
        // 至少保留一条记录
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('至少需要保留一条牙齿状况记录')));
      }
    });
  }

  // 将牙齿状况数据转换为保存格式
  String _dentalConditionToJson() {
    print('开始转换牙齿状况数据为JSON');
    print('当前记录数: ${_dentalRecords.length}');

    final Map<String, dynamic> result = {};

    for (int i = 0; i < _dentalRecords.length; i++) {
      final record = _dentalRecords[i];
      print('处理记录 #$i: $record');

      // 保存日期
      result['date-$i'] = record['date'];

      // 保存图表1数据
      result['chart1-top-left-$i'] = record['chart1-top-left'] ?? '';
      result['chart1-top-right-$i'] = record['chart1-top-right'] ?? '';
      result['chart1-bottom-left-$i'] = record['chart1-bottom-left'] ?? '';
      result['chart1-bottom-right-$i'] = record['chart1-bottom-right'] ?? '';
      result['chart1-note-$i'] = record['chart1-note'] ?? '';

      // 保存图表2数据
      result['chart2-top-left-$i'] = record['chart2-top-left'] ?? '';
      result['chart2-top-right-$i'] = record['chart2-top-right'] ?? '';
      result['chart2-bottom-left-$i'] = record['chart2-bottom-left'] ?? '';
      result['chart2-bottom-right-$i'] = record['chart2-bottom-right'] ?? '';
      result['chart2-note-$i'] = record['chart2-note'] ?? '';

      // 保存图表3数据
      result['chart3-top-left-$i'] = record['chart3-top-left'] ?? '';
      result['chart3-top-right-$i'] = record['chart3-top-right'] ?? '';
      result['chart3-bottom-left-$i'] = record['chart3-bottom-left'] ?? '';
      result['chart3-bottom-right-$i'] = record['chart3-bottom-right'] ?? '';
      result['chart3-note-$i'] = record['chart3-note'] ?? '';
    }

    final jsonString = jsonEncode(result);
    print('转换后的JSON字符串: $jsonString');
    return jsonString;
  }

  // 添加额外电话号码字段
  void _addAdditionalPhone() {
    setState(() {
      _additionalPhoneControllers.add(TextEditingController());
    });
  }

  // 移除额外电话号码字段
  void _removeAdditionalPhone(int index) {
    setState(() {
      _additionalPhoneControllers[index].dispose();
      _additionalPhoneControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 添加 ScrollController 的释放
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    // 清理额外电话号码控制器
    for (var controller in _additionalPhoneControllers) {
      controller.dispose();
    }
    _addressController.dispose();
    _idNumberController.dispose();
    _doctorController.dispose();
    _medicalRecordController.dispose();
    _treatmentItemsController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    // 验证所有电话号码
    bool isPhoneValid = true;
    String errorMessage = '';

    // 验证主要电话号码
    if (_phoneController.text.trim().isNotEmpty &&
        !RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text.trim())) {
      isPhoneValid = false;
      errorMessage = '主要电话号码格式不正确，请输入正确的11位手机号码';
    }

    // 验证额外电话号码
    for (var i = 0; i < _additionalPhoneControllers.length; i++) {
      String phone = _additionalPhoneControllers[i].text.trim();
      if (phone.isNotEmpty && !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
        isPhoneValid = false;
        errorMessage = '备用电话号码格式不正确，请输入正确的11位手机号码';
        break;
      }
    }

    if (!isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      // 如果验证失败，显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请检查输入信息是否正确'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // 获取数据库提供者
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 从表单控制器获取值
      final name = _nameController.text.trim();
      final age = int.tryParse(_ageController.text.trim()) ?? 0;

      // 收集所有电话号码，过滤掉空值
      List<String> allPhones = [_phoneController.text.trim()];
      for (var controller in _additionalPhoneControllers) {
        if (controller.text.isNotEmpty) {
          allPhones.add(controller.text.trim());
        }
      }

      // 移除空字符串
      allPhones = allPhones.where((phone) => phone.isNotEmpty).toList();

      print('保存前收集的电话号码: $allPhones');

      // 根据电话号码数量决定存储格式
      String phoneData;
      if (allPhones.isEmpty) {
        // 无电话号码: 存储为空字符串
        phoneData = '';
      } else if (allPhones.length == 1) {
        // 单个电话号码：直接以字符串形式存储
        phoneData = allPhones[0];
      } else {
        // 多个电话号码：以JSON数组形式存储
        phoneData = jsonEncode(allPhones);
      }

      print('最终格式化的电话号码数据: $phoneData');
      print('格式化后的数据类型: ${phoneData.runtimeType}');

      // 构建患者对象 - 有ID时更新，无ID时新增
      final patient = Patient(
        id: widget.patient?.id,
        medicalRecordNumber:
            _medicalRecordController.text.isEmpty
                ? null
                : int.tryParse(_medicalRecordController.text.trim()),
        name: name,
        age: age,
        gender: _gender, // 使用下拉菜单选择的性别，保证为"男"或"女"
        phone: phoneData, // 这里已经是直接字符串或JSON格式，Patient.toMap不应再对其编码
        address:
            _addressController.text.isEmpty
                ? null
                : _addressController.text.trim(),
        identificationNumber:
            _idNumberController.text.isEmpty
                ? null
                : _idNumberController.text.trim(),
        doctor:
            _doctorController.text.isEmpty
                ? null
                : _doctorController.text.trim(),
        firstVisitDate: _firstVisitDate,
        totalCost: widget.patient?.totalCost ?? 0.0,
        dentalCondition: _dentalConditionToJson(), // 添加牙齿状况数据
        treatmentItems: _treatmentItemsController.text.trim(), // 添加治疗项目数据
      );

      String message;
      bool success = false;

      try {
        // 执行数据库操作前显示提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在保存患者信息...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        // 区分更新还是新增
        print('准备保存患者信息 - ID: ${patient.id}');
        if (widget.patient?.id != null) {
          // 编辑现有患者 - 确保使用ID来确定是更新模式
          print('更新现有患者 - ID: ${patient.id}');
          final result = await dbProvider.updatePatient(patient);
          message = '患者信息更新成功！';
          success = result;
        } else {
          // 添加新患者
          print('添加新患者');
          final id = await dbProvider.addPatient(patient);
          message = '患者添加成功！';
          success = id > 0;
        }

        // 隐藏加载指示器
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        // 调用回调通知父组件
        widget.onSaved(success, message);

        // 如果操作成功，关闭表单
        if (success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));

          // 延迟关闭表单，确保用户能看到成功消息
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.pop(context, true); // 返回true表示成功保存并需要刷新
            }
          });
        }
      } catch (dbError) {
        print('数据库操作错误: $dbError');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('数据库操作失败: $dbError')));
        }
        widget.onSaved(false, '数据库操作失败: $dbError');
      }
    } catch (e) {
      // 处理错误
      print('保存患者信息时发生错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
      widget.onSaved(false, '保存失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('开始构建 PatientFormSheet, 当前牙齿记录索引: $_currentDentalRecordIndex');
    print('当前牙齿记录数量: ${_dentalRecords.length}');

    return Scaffold(
      appBar: AppBar(title: Text(widget.patient == null ? '添加患者' : '编辑患者')),
      body: GestureDetector(
        onTap: () {
          // 点击空白区域隐藏键盘
          FocusScope.of(context).unfocus();
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            controller: _scrollController,
            children: [
              // 病历号卡片
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.assignment_ind,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '病历号',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _medicalRecordController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '输入病历号',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 首诊日期卡片
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '首诊日期',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(_firstVisitDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        color: Colors.blue,
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _firstVisitDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _firstVisitDate = pickedDate;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 患者基本信息卡片 - 移到牙齿状况卡片之前
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.purple.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            '患者基本信息',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 姓名、年龄行
                      Row(
                        children: [
                          // 姓名
                          Expanded(
                            child: _buildInfoField(
                              icon: Icons.badge,
                              iconColor: Colors.blue,
                              label: '姓名',
                              controller: _nameController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入姓名';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 年龄
                          Expanded(
                            child: _buildInfoField(
                              icon: Icons.cake,
                              iconColor: Colors.orange,
                              label: '年龄',
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入年龄';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // 性别
                      _buildGenderSelector(),

                      // 联系电话
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildInfoField(
                                  icon: Icons.phone,
                                  iconColor: Colors.green,
                                  label: '主要电话',
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  // 移除必填验证
                                ),
                              ),
                              // 添加按钮
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 16.0,
                                  left: 8.0,
                                ),
                                child: IconButton(
                                  onPressed: _addAdditionalPhone,
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.green.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  tooltip: '添加备用电话',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                          // 额外的电话号码输入框
                          ..._additionalPhoneControllers.asMap().entries.map((
                            entry,
                          ) {
                            int index = entry.key;
                            TextEditingController controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.phone_forwarded,
                                            color: Colors.blue.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '备用电话:',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              TextFormField(
                                                controller: controller,
                                                maxLines: 1,
                                                keyboardType:
                                                    TextInputType.phone,
                                                decoration: InputDecoration(
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  isDense: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 删除按钮
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8.0,
                                      bottom: 16.0,
                                    ),
                                    child: IconButton(
                                      onPressed:
                                          () => _removeAdditionalPhone(index),
                                      icon: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                      ),
                                      tooltip: '删除备用电话',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),

                      // 地址
                      _buildInfoField(
                        icon: Icons.home,
                        iconColor: Colors.amber,
                        label: '地址',
                        controller: _addressController,
                      ),

                      // 身份证号
                      _buildInfoField(
                        icon: Icons.credit_card,
                        iconColor: Colors.indigo,
                        label: '身份证号',
                        controller: _idNumberController,
                      ),

                      // 主治医生
                      _buildInfoField(
                        icon: Icons.healing,
                        iconColor: Colors.red,
                        label: '主治医生',
                        controller: _doctorController,
                      ),
                    ],
                  ),
                ),
              ),

              // 牙齿状况卡片
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.medical_services,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            '牙齿状况',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 显示当前选中的牙齿记录
                      if (_dentalRecords.isNotEmpty)
                        _buildDentalRecordSimplified(
                          _dentalRecords[_currentDentalRecordIndex],
                          _currentDentalRecordIndex,
                        )
                      else
                        const Center(child: Text('暂无牙齿记录')),

                      // 分页指示器和导航按钮
                      if (_dentalRecords.length > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    _currentDentalRecordIndex > 0
                                        ? () {
                                          setState(() {
                                            _currentDentalRecordIndex--;
                                            print(
                                              '切换到上一条记录: $_currentDentalRecordIndex',
                                            );
                                          });
                                        }
                                        : null,
                                icon: const Icon(
                                  Icons.arrow_back_ios,
                                  size: 16,
                                ),
                                label: const Text('上一条'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${_currentDentalRecordIndex + 1}/${_dentalRecords.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed:
                                    _currentDentalRecordIndex <
                                            _dentalRecords.length - 1
                                        ? () {
                                          setState(() {
                                            _currentDentalRecordIndex++;
                                            print(
                                              '切换到下一条记录: $_currentDentalRecordIndex',
                                            );
                                          });
                                        }
                                        : null,
                                icon: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                label: const Text('下一条'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 添加新记录按钮
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _addNewDentalRecord,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('添加牙齿记录'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 治疗项目卡片 - 使用专门的构建方法
              _buildTreatmentItemField(),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('保存中...'),
                            ],
                          )
                          : const Text('保存修改', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建性别选择器
  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.wc, color: Colors.pink.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            '性别:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Row(
              children: [
                Radio<String>(
                  value: '男',
                  groupValue: _gender,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _gender = value!;
                    });
                  },
                ),
                const Text('男'),
                const SizedBox(width: 32),
                Radio<String>(
                  value: '女',
                  groupValue: _gender,
                  activeColor: Colors.pink,
                  onChanged: (value) {
                    setState(() {
                      _gender = value!;
                    });
                  },
                ),
                const Text('女'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建美化的信息输入字段
  Widget _buildInfoField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: maxLines > 1 ? 12 : 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  validator: validator,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 治疗项目输入框 - 修改为垂直居中
  Widget _buildTreatmentItemField() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: Colors.teal.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '治疗项目',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _treatmentItemsController,
                decoration: const InputDecoration(
                  hintText: '请输入治疗项目',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16, // 增加垂直内边距
                  ),
                ),
                textAlignVertical: TextAlignVertical.center, // 使文本垂直居中
                maxLines: 3,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5, // 调整行高
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 修复牙齿状况记录切换功能 - 将旧的底部导航栏方法替换
  Widget _buildDentalRecordSimplified(Map<String, dynamic> record, int index) {
    print('构建牙齿记录卡片: $index, 数据: $record');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_note,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '就诊日期',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record['date'] ??
                              DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                      ),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(record['date']) ??
                              DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dentalRecords[index]['date'] = DateFormat(
                              'yyyy-MM-dd',
                            ).format(pickedDate);
                          });
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '选择日期',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                      ),
                      onPressed: () => _removeDentalRecord(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '删除记录',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 图表内容
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 三个图表
                _buildDentalChartSimplified('图表1', record, index),
                _buildDentalChartSimplified('图表2', record, index),
                _buildDentalChartSimplified('图表3', record, index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 简化版的牙齿图表 - 减小备注高度
  Widget _buildDentalChartSimplified(
    String title,
    Map<String, dynamic> record,
    int recordIndex,
  ) {
    final chartPrefix = title.toLowerCase().replaceAll(' ', '');
    final actualPrefix = "chart${title.substring(2, 3)}"; // 从"图表1"提取为"chart1"

    // 打印当前图表的数据以便调试
    print('构建图表 $title (索引: $recordIndex)');
    print('图表前缀: $actualPrefix');
    print('图表数据: ${record.map((k, v) => MapEntry(k, v))}');

    // 正确提取与此图表相关的数据
    Map<String, dynamic> chartData = {
      'top-left': record['$actualPrefix-top-left'] ?? '',
      'top-right': record['$actualPrefix-top-right'] ?? '',
      'bottom-left': record['$actualPrefix-bottom-left'] ?? '',
      'bottom-right': record['$actualPrefix-bottom-right'] ?? '',
      'note': record['$actualPrefix-note'] ?? '',
    };

    print('正确提取的图表数据: $chartData');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getChartIcon(title),
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 牙齿区域表格
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 上排标题
                Row(
                  children: [
                    const SizedBox(width: 60),
                    Expanded(
                      child: Center(
                        child: Text(
                          '左侧',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Center(
                        child: Text(
                          '右侧',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 上排
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '上排',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    // 左上
                    Expanded(
                      child: _buildInputCell(
                        Icons.arrow_upward,
                        Colors.blue,
                        chartData['top-left'],
                        (value) {
                          setState(() {
                            _dentalRecords[recordIndex]['$actualPrefix-top-left'] =
                                value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 右上
                    Expanded(
                      child: _buildInputCell(
                        Icons.arrow_upward,
                        Colors.red,
                        chartData['top-right'],
                        (value) {
                          setState(() {
                            _dentalRecords[recordIndex]['$actualPrefix-top-right'] =
                                value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 下排
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '下排',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    // 左下
                    Expanded(
                      child: _buildInputCell(
                        Icons.arrow_downward,
                        Colors.green,
                        chartData['bottom-left'],
                        (value) {
                          setState(() {
                            _dentalRecords[recordIndex]['$actualPrefix-bottom-left'] =
                                value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 右下
                    Expanded(
                      child: _buildInputCell(
                        Icons.arrow_downward,
                        Colors.orange,
                        chartData['bottom-right'],
                        (value) {
                          setState(() {
                            _dentalRecords[recordIndex]['$actualPrefix-bottom-right'] =
                                value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 备注 - 减小高度
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.amber[800], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '备注信息',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '请在此输入备注信息...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    controller: TextEditingController(text: chartData['note']),
                    maxLines: 2, // 减小为2行
                    onChanged: (value) {
                      setState(() {
                        _dentalRecords[recordIndex]['$actualPrefix-note'] =
                            value;
                      });
                    },
                    onTap: () {
                      final defaultText = '请在此输入图表${title.substring(2, 3)}的备注';
                      if (chartData['note'] == defaultText) {
                        setState(() {
                          _dentalRecords[recordIndex]['$actualPrefix-note'] =
                              '';
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 只在图表2和图表3之间添加分隔线
          if (title != '图表3')
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  // 根据图表编号返回对应图标
  IconData _getChartIcon(String title) {
    switch (title) {
      case '图表1':
        return Icons.filter_1;
      case '图表2':
        return Icons.filter_2;
      case '图表3':
        return Icons.filter_3;
      default:
        return Icons.sticky_note_2;
    }
  }

  // 构建输入单元格
  Widget _buildInputCell(
    IconData icon,
    Color iconColor,
    String value,
    Function(String) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  '牙齿状态',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '输入值',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
              controller: TextEditingController(text: value),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
