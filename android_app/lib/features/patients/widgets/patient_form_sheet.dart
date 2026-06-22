import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';
import 'package:dentist_app/widgets/stateful_text_field.dart';
import 'package:dentist_app/features/patients/widgets/patient_basic_info_widget.dart';
import 'package:dentist_app/features/patients/widgets/patient_phone_widget.dart';
import 'package:dentist_app/features/patients/widgets/patient_dental_records_widget.dart';

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
  final _medicalRecordController = TextEditingController();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // 子组件数据
  Map<String, dynamic> _basicInfo = {};
  String _phoneData = '';
  String _dentalConditionData = '';

  @override
  void initState() {
    super.initState();

    print('PatientFormSheet初始化开始...');

    if (widget.patient != null) {
      // 编辑现有患者
      print('初始化编辑患者表单');
      _basicInfo = {
        'name': widget.patient!.name,
        'age': widget.patient!.age.toString(),
        'gender': widget.patient!.gender,
        'address': widget.patient!.address ?? '',
        'idNumber': widget.patient!.identificationNumber ?? '',
        'doctor': widget.patient!.doctor ?? '',
        'medicalRecordNumber': widget.patient!.medicalRecordNumber?.toString() ?? '',
        'treatmentItems': widget.patient!.treatmentItems ?? '',
        'firstVisitDate': widget.patient!.firstVisitDate ?? DateTime.now(),
      };
      _phoneData = widget.patient!.phone ?? '';
      _dentalConditionData = widget.patient!.dentalCondition ?? '';

      if (widget.patient!.medicalRecordNumber != null) {
        _medicalRecordController.text =
            widget.patient!.medicalRecordNumber.toString();
        print('使用现有患者的病历号: ${_medicalRecordController.text}');
      }
    } else {
      // 添加新患者
      print('初始化新患者表单');
      _basicInfo = {
        'name': '',
        'age': '',
        'gender': '男',
        'address': '',
        'idNumber': '',
        'doctor': '',
        'medicalRecordNumber': '',
        'treatmentItems': '',
        'firstVisitDate': DateTime.now(),
      };
      _phoneData = '';
      _dentalConditionData = '';

      // 设置主治医生字段的默认值为当前登录用户的医生姓名
      _setDefaultDoctorName();
    }

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

    print('PatientFormSheet初始化完成');
  }

  // 获取并设置默认病历号的方法
  Future<void> _fetchAndSetMedicalRecordNumber() async {
    print('开始获取下一个病历号...');

    try {
      if (!mounted) return;

      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      // 获取最大病历号，而不是患者总数
      final maxMedicalRecordNumber =
          await Provider.of<PatientProvider>(context, listen: false).getMaxMedicalRecordNumber();

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

  /// 设置主治医生字段的默认值
  void _setDefaultDoctorName() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser != null && currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
        setState(() {
          _basicInfo['doctor'] = currentUser.doctor!;
        });
        print('设置患者主治医生默认值: ${currentUser.doctor}');
      } else {
        print('当前用户未设置医生姓名，主治医生字段保持为空');
      }
    } catch (e) {
      print('设置患者主治医生默认值失败: $e');
      // 如果获取失败，保持字段为空
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _medicalRecordController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    // 验证电话号码
    bool isPhoneValid = true;
    String errorMessage = '';

    try {
      List<String> phones = [];
      if (_phoneData.isNotEmpty) {
        if (_phoneData.startsWith('[')) {
          phones = jsonDecode(_phoneData).cast<String>();
        } else {
          phones = [_phoneData];
        }
      }

      for (var phone in phones) {
        if (phone.isNotEmpty && !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
          isPhoneValid = false;
          errorMessage = '电话号码格式不正确，请输入正确的11位手机号码';
          break;
        }
      }
    } catch (e) {
      print('电话号码解析失败: $e');
    }

    if (!isPhoneValid) {
      widget.onSaved(false, errorMessage);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      widget.onSaved(false, '请检查输入信息是否正确');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      final name = _basicInfo['name']?.toString().trim() ?? '';
      final age = int.tryParse(_basicInfo['age']?.toString().trim() ?? '0') ?? 0;
      final gender = _basicInfo['gender']?.toString() ?? '男';
      final address = _basicInfo['address']?.toString().trim();
      final idNumber = _basicInfo['idNumber']?.toString().trim();
      final doctor = _basicInfo['doctor']?.toString().trim();
      final treatmentItems = _basicInfo['treatmentItems']?.toString().trim();
      final firstVisitDate = _basicInfo['firstVisitDate'] as DateTime?;

      final patient = Patient(
        id: widget.patient?.id,
        medicalRecordNumber: _medicalRecordController.text.isEmpty
            ? null
            : int.tryParse(_medicalRecordController.text.trim()),
        name: name,
        age: age,
        gender: gender,
        phone: _phoneData,
        address: (address != null && address.isEmpty) ? null : address,
        identificationNumber: (idNumber != null && idNumber.isEmpty) ? null : idNumber,
        doctor: (doctor != null && doctor.isEmpty) ? null : doctor,
        firstVisitDate: firstVisitDate ?? DateTime.now(),
        totalCost: widget.patient?.totalCost ?? 0.0,
        dentalCondition: _dentalConditionData,
        treatmentItems: treatmentItems,
      );

      String message;
      bool success = false;

      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在保存患者信息...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        if (widget.patient?.id != null) {
          print('更新现有患者 - ID: ${patient.id}');
          final result = await Provider.of<PatientProvider>(context, listen: false).updatePatient(patient);
          message = '患者信息更新成功！';
          success = result;
        } else {
          print('添加新患者');
          final id = await Provider.of<PatientProvider>(context, listen: false).addPatient(patient);
          message = '患者添加成功！';
          success = id > 0;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        widget.onSaved(success, message);

        if (success && mounted) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      } catch (dbError) {
        print('数据库操作错误: $dbError');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        widget.onSaved(false, '数据库操作失败: $dbError');
      }
    } catch (e) {
      print('保存患者信息时发生错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      widget.onSaved(false, '保存失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('开始构建 PatientFormSheet');

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
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 0,
                color: Colors.transparent,
                child: TextFormField(
                  controller: _medicalRecordController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: '病历号',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.assignment_ind, color: Colors.blue.shade700),
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),

              // 基本信息组件
              PatientBasicInfoWidget(
                initialName: _basicInfo['name']?.toString(),
                initialAge: _basicInfo['age']?.toString(),
                initialGender: _basicInfo['gender']?.toString(),
                initialAddress: _basicInfo['address']?.toString(),
                initialIdNumber: _basicInfo['idNumber']?.toString(),
                initialDoctor: _basicInfo['doctor']?.toString(),
                initialMedicalRecordNumber: _basicInfo['medicalRecordNumber']?.toString(),
                initialTreatmentItems: _basicInfo['treatmentItems']?.toString(),
                initialFirstVisitDate: _basicInfo['firstVisitDate'] as DateTime?,
                onInfoChanged: (info) {
                  setState(() {
                    _basicInfo = info;
                  });
                },
              ),

              // 电话号码组件
              PatientPhoneWidget(
                initialPhone: _phoneData,
                onPhoneChanged: (phoneData) {
                  setState(() {
                    _phoneData = phoneData;
                  });
                },
              ),

              // 牙齿状况记录组件
              PatientDentalRecordsWidget(
                initialDentalCondition: _dentalConditionData,
                onDentalConditionChanged: (dentalCondition) {
                  setState(() {
                    _dentalConditionData = dentalCondition;
                  });
                },
              ),

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
}