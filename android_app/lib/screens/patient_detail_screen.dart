import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/providers/database_provider.dart';

import 'package:dentist_app/providers/patient_image_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:dentist_app/models/material_image.dart';
import 'package:dentist_app/widgets/app_card.dart';
import 'package:dentist_app/features/patients/widgets/patient_image_viewer.dart';
import 'package:dentist_app/features/patients/widgets/patient_basic_info_card.dart';
import 'package:dentist_app/features/patients/widgets/patient_phone_display.dart';
import 'package:dentist_app/features/patients/widgets/patient_dental_condition_display.dart';
import 'package:dentist_app/features/patients/widgets/patient_medical_records_section.dart';

import 'package:dentist_app/screens/patients_screen.dart';
import 'package:dentist_app/utils/toast_util.dart';
import 'package:dentist_app/features/patients/widgets/patient_form_sheet.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dentist_app/utils/permission_utils.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  List<String> _phoneNumbers = [];
  Patient? _freshPatient;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 避免在构建过程中调用状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatientData();
    });
  }

  Future<void> _loadPatientData() async {
    try {
      if (widget.patient.id != null) {
        final dbProvider = Provider.of<DatabaseProvider>(
          context,
          listen: false,
        );
        final imageProvider = Provider.of<PatientImageProvider>(
          context,
          listen: false,
        );

        // 清除可能的缓存 - 避免在构建过程中触发状态更新
        // await Provider.of<PatientProvider>(context, listen: false).forceRefreshPatients();
        
        // 强制刷新图片数据缓存
        if (imageProvider.hasCachedData(widget.patient.id!)) {
          print('清除患者图片缓存，强制重新获取最新数据');
          imageProvider.clearPatientCache(widget.patient.id!);
        }

        try {
          print('强制重新获取患者数据 ID: ${widget.patient.id}');
          final freshPatient = await Provider.of<PatientProvider>(context, listen: false).getPatientById(
            widget.patient.id!,
          );

          if (freshPatient != null && mounted) {
            setState(() {
              _freshPatient = freshPatient;
              // 重新初始化电话号码列表
              _initPhoneNumbers(freshPatient);
            });


            
            // 强制重新获取图片数据
            print('开始强制重新获取患者图片数据');
            await imageProvider.getPatientImages(widget.patient.id!);
            
            print('成功更新患者数据: ${freshPatient.toMap()}');
          } else {
            if (mounted) {
              print('获取最新患者数据失败，使用缓存数据');
              // 使用传入的数据初始化
              _initPhoneNumbers(widget.patient);
            }
          }
        } catch (dbError) {
          print('获取患者数据错误: $dbError');
          // 使用传入的数据初始化
          if (mounted) {
            _initPhoneNumbers(widget.patient);
          }
        }
      } else {
        // 如果没有ID，使用传入的数据初始化
        if (mounted) {
          _initPhoneNumbers(widget.patient);
        }
      }
    } catch (e) {
      print('加载患者数据错误: $e');
      // 使用传入的数据初始化
      if (mounted) {
        _initPhoneNumbers(widget.patient);
      }
    }
  }

  void _initPhoneNumbers(Patient patient) {
    try {
      _phoneNumbers = [];
      print('初始化电话号码: ${patient.phone}');

      // 先检查是否为空
      if (patient.phone.isEmpty) {
        _phoneNumbers = ['未设置'];
        return;
      }

      String phoneData = patient.phone.trim();

      // 判断是否为JSON数组格式
      if (phoneData.startsWith('[') && phoneData.endsWith(']')) {
        try {
          // 尝试解析JSON格式的电话号码
          final parsedPhones = jsonDecode(phoneData) as List<dynamic>;
          if (parsedPhones.isNotEmpty) {
            _phoneNumbers = parsedPhones.map((p) => p.toString()).toList();
            print('JSON解析成功，电话号码列表: $_phoneNumbers');
          } else {
            _phoneNumbers = ['未设置'];
          }
        } catch (jsonError) {
          print('JSON解析失败: $jsonError，尝试其他方式解析');

          // 去除方括号并处理内容
          String content = phoneData.substring(1, phoneData.length - 1);

          // 尝试匹配引号中的内容
          final RegExp regex = RegExp(r'"([^"]*)"');
          final matches = regex.allMatches(content);
          List<String> phones = [];

          if (matches.isNotEmpty) {
            for (final match in matches) {
              if (match.group(1)?.isNotEmpty == true) {
                phones.add(match.group(1)!);
              }
            }
          }

          if (phones.isEmpty) {
            // 如果没有找到引号包围的内容，尝试直接按逗号分割
            phones = content.split(',').map((p) => p.trim()).toList();

            // 处理可能的引号
            phones =
                phones.map((p) {
                  if ((p.startsWith('"') && p.endsWith('"')) ||
                      (p.startsWith("'") && p.endsWith("'"))) {
                    return p.substring(1, p.length - 1);
                  }
                  return p;
                }).toList();
          }

          _phoneNumbers = phones.where((p) => p.isNotEmpty).toList();

          if (_phoneNumbers.isEmpty) {
            _phoneNumbers = ['未设置'];
          }
        }
      } else if (phoneData.contains(',')) {
        // 逗号分隔的电话号码
        _phoneNumbers =
            phoneData
                .split(',')
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList();
        print('逗号分隔电话号码: $_phoneNumbers');

        if (_phoneNumbers.isEmpty) {
          _phoneNumbers = ['未设置'];
        }
      } else {
        // 单个电话号码
        _phoneNumbers = [phoneData];
        print('单个电话号码: $phoneData');
      }

      print('最终电话号码列表: $_phoneNumbers');
    } catch (e) {
      print('电话号码初始化错误: $e');
      _phoneNumbers = ['未设置'];
    }
  }



  Patient get _currentPatient => _freshPatient ?? widget.patient;

  @override
  Widget build(BuildContext context) {
    try {
      // 打印患者数据以进行调试
      try {
        print('显示患者详细信息: ${_currentPatient.toMap()}');
        print('患者数据来源: ${_freshPatient != null ? "最新查询" : "缓存"}');
      } catch (e) {
        // 捕获任何打印异常，避免界面闪红
        print('打印患者数据时发生错误: $e');
      }

      // 确保_phoneNumbers被初始化
      if (_phoneNumbers.isEmpty) {
        _initPhoneNumbers(_currentPatient);
      }

      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: const Text(
            '患者详情',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PermissionWrapper(
              module: 'patients',
              action: 'edit',
              recordDoctor: _currentPatient.doctor,
              onPermissionDenied: () {
                PermissionUtils.showPermissionDeniedMessage(
                  context,
                  customMessage: '您只能编辑自己负责的患者',
                );
              },
              child: IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                onPressed: () async {
                // 确保使用包含原始电话号码格式的患者对象
                final patientToEdit = _currentPatient;
                // 打印详细日志用于诊断
                print('传递给编辑表单的患者数据: ${patientToEdit.toMap()}');
                print('传递的电话号码格式: ${patientToEdit.phone}');
                print('电话号码格式类型: ${patientToEdit.phone.runtimeType}');
                patientToEdit.debugPhoneFormat();
                print('电话号码是否包含逗号: ${patientToEdit.phone.contains(',')}');
                print('解析后的电话号码列表: $_phoneNumbers');

                // 创建一个确保电话号码为JSON格式的患者对象
                final Patient patientForEdit = patientToEdit.withPhoneAsJson();

                // 如果电话号码包含逗号但不是JSON格式，强制转换为JSON格式
                if (patientForEdit.phone.contains(',') &&
                    !patientForEdit.phone.startsWith('[')) {
                  // 手动创建新的患者对象并设置JSON格式的电话号码
                  List<String> phones =
                      patientForEdit.phone
                          .split(',')
                          .map((p) => p.trim())
                          .where((p) => p.isNotEmpty)
                          .toList();

                  if (phones.length > 1) {
                    String jsonPhones = jsonEncode(phones);
                    print('手动强制转换为JSON格式电话: $jsonPhones');

                    final forcedJsonPatient = patientForEdit.copyWithPhone(
                      jsonPhones,
                    );
                    patientForEdit.debugPhoneFormat();
                    print('转换后的电话格式: ${forcedJsonPatient.phone}');

                    // 使用新患者对象
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => PatientFormSheet(
                              patient: forcedJsonPatient,
                              initialMedicalRecordNumber:
                                  forcedJsonPatient.medicalRecordNumber,
                              onSaved: (isSuccess, message) {
                                if (isSuccess) {
                                  _loadPatientData();
                                  if (mounted) {
                                    // 使用公共组件的成功提示
                                    SuccessToastManager.show(context, message: "患者信息已更新");
                                  }
                                }
                              },
                            ),
                      ),
                    );

                    // 处理结果
                    if (result == true && mounted) {
                      setState(() {
                        _freshPatient = null;
                        _isLoading = true;
                      });
                      await _loadPatientData();
                    }
                    return; // 提前返回，避免执行下面的代码
                  }
                }

                // 如果不需要特殊处理，使用原始逻辑
                print('使用标准流程处理电话: ${patientForEdit.phone}');
                patientForEdit.debugPhoneFormat();

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PatientFormSheet(
                          patient: patientForEdit,
                          initialMedicalRecordNumber:
                              patientForEdit.medicalRecordNumber,
                          onSaved: (isSuccess, message) {
                            if (isSuccess) {
                              _loadPatientData();
                              if (mounted) {
                                // 使用公共组件的成功提示
                                SuccessToastManager.show(context, message: "患者信息已更新");
                              }
                            }
                          },
                        ),
                  ),
                );
              },
            ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadPatientData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PatientBasicInfoCard(
                  patient: _currentPatient,
                ),
                const SizedBox(height: 16),

                // 牙齿状况显示
                if (_currentPatient.dentalCondition != null &&
                    _currentPatient.dentalCondition!.isNotEmpty) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '牙齿状况',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '从医生视角看患者：显示的是患者的实际牙位（右上、左上、右下、左下）',
                              child: Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // 添加牙位方向提示信息
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '注意：牙位显示为从医生视角看患者，对应患者的实际牙位',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PatientDentalConditionDisplay(
                          dentalConditionJson: _currentPatient.dentalCondition!,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 患者图片查看器
                Consumer<PatientImageProvider>(
                  builder: (context, imageProvider, child) {
                    // 检查是否有错误
                    final error = imageProvider.getError(_currentPatient.id!);
                    if (error != null) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[400],
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '加载图片失败',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                error,
                                style: TextStyle(
                                  color: Colors.red[500],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => imageProvider.refreshPatientData(_currentPatient.id!),
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Consumer<PatientImageProvider>(
                      builder: (context, imageProvider, child) {
                        // 检查是否有缓存数据
                        if (imageProvider.hasCachedData(_currentPatient.id!)) {
                          final materials = imageProvider.getCachedMaterials(_currentPatient.id!);
                          final images = imageProvider.getCachedImages(_currentPatient.id!);
                          return PatientImageViewer(
                            materials: materials,
                            images: images,
                          );
                        }

                        // 如果没有缓存数据，触发加载（只触发一次）
                        if (!imageProvider.isLoading(_currentPatient.id!) &&
                            !imageProvider.hasCachedData(_currentPatient.id!)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            imageProvider.getPatientImages(_currentPatient.id!);
                          });
                        }

                        if (imageProvider.isLoading(_currentPatient.id!)) {
                          return const Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          );
                        }

                        final error = imageProvider.getError(_currentPatient.id!);
                        if (error != null) {
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red[600],
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '加载图片失败',
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    error,
                                    style: TextStyle(
                                      color: Colors.red[500],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => imageProvider.refreshPatientData(_currentPatient.id!),
                                    child: const Text('重试'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return PatientImageViewer(
                          materials: [],
                          images: [],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 病历记录查看器
                PatientMedicalRecordsSection(
                  patient: _currentPatient,
                ),

              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // 出现任何异常时，显示错误回退页面
      print('患者详情页面构建错误: $e');
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('患者详情'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('加载患者数据出错'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loadPatientData();
                  });
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
  }


  // 拨打电话功能
  void _callPhoneNumber(String phoneNumber) async {
    if (phoneNumber == '未设置' || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无效的电话号码')));
      return;
    }

    // 检查并请求拨打电话权限
    PermissionStatus status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }

    // 构建拨打电话的URL
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      // 使用不同方法尝试启动拨号，提高兼容性
      bool launched = false;

      // 首先尝试使用url_launcher
      try {
        launched = await launchUrl(
          launchUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        print('url_launcher方式失败: $e');
        launched = false;
      }

      if (!launched && mounted) {
        ToastUtil.showInfo(context, '正在尝试拨打电话: $phoneNumber');
      }
    } catch (e) {
      print('拨打电话错误: $e');
      if (mounted) {
        // 在模拟器上显示电话号码，因为模拟器通常无法拨打电话
        ToastUtil.showInfo(context, '模拟器无法拨打电话，实际号码: $phoneNumber');
      }
    }
  }
}
