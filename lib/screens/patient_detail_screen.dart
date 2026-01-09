import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/providers/database_provider.dart';

import 'package:dentist_app/providers/patient_image_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/medical_record_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:dentist_app/models/material_image.dart';
import 'package:dentist_app/models/patient_medical_record.dart';
import 'package:dentist_app/widgets/app_card.dart';
import 'package:dentist_app/widgets/patient_image_viewer.dart';

import 'package:dentist_app/screens/patients_screen.dart';
import 'package:dentist_app/screens/medical_record_detail_screen.dart';
import 'package:dentist_app/utils/toast_util.dart';
import 'package:dentist_app/widgets/patient_form_sheet.dart';
import 'package:dentist_app/widgets/success_toast.dart';
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
  
  // 病历记录相关状态
  List<PatientMedicalRecord>? _cachedMedicalRecords;
  bool _medicalRecordsLoaded = false;

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
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '基本信息',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _currentPatient.gender == '男'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _currentPatient.gender,
                              style: TextStyle(
                                color:
                                    _currentPatient.gender == '男'
                                        ? Colors.blue
                                        : Colors.pink,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        CupertinoIcons.person,
                        '姓名',
                        _currentPatient.name,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        CupertinoIcons.number,
                        '年龄',
                        '${_currentPatient.age}岁',
                      ),
                      const SizedBox(height: 12),

                      _buildPhoneNumbersSection(),

                      if (_currentPatient.medicalRecordNumber != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          CupertinoIcons.doc_text,
                          '病历号',
                          _currentPatient.medicalRecordNumber.toString(),
                        ),
                      ],
                      if (_currentPatient.doctor != null &&
                          _currentPatient.doctor!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          CupertinoIcons.person_2,
                          '主治医生',
                          _currentPatient.doctor!,
                        ),
                      ],
                      if (_currentPatient.address != null &&
                          _currentPatient.address!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          CupertinoIcons.location,
                          '地址',
                          _currentPatient.address!,
                          alignTop: true,
                        ),
                      ],
                      if (_currentPatient.identificationNumber != null &&
                          _currentPatient.identificationNumber!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          CupertinoIcons.creditcard,
                          '身份证号',
                          _currentPatient.identificationNumber!,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        CupertinoIcons.calendar,
                        '初诊日期',
                        DateFormat(
                          'yyyy年MM月dd日',
                        ).format(_currentPatient.firstVisitDate),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        CupertinoIcons.money_dollar,
                        '总费用',
                        '¥${_currentPatient.totalCost.toStringAsFixed(2)}',
                        valueColor: AppTheme.accentColor,
                      ),
                      if (_currentPatient.treatmentItems != null &&
                          _currentPatient.treatmentItems!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          '治疗项目',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _currentPatient.treatmentItems!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ),
                      ],
                      if (_currentPatient.dentalCondition != null &&
                          _currentPatient.dentalCondition!.isNotEmpty) ...[
                        const SizedBox(height: 20),
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
                        _buildDentalConditionInfo(
                          _currentPatient.dentalCondition!,
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                _buildMedicalRecordsSection(),

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

  // 病历记录部分
  Widget _buildMedicalRecordsSection() {
    if (_currentPatient.id == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medical_information,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '病历记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _cachedMedicalRecords = null;
                    _medicalRecordsLoaded = false;
                  });
                },
                tooltip: '刷新病历记录',
              ),
            ],
          ),
          const Divider(height: 24),
          _buildMedicalRecordsDisplay(),
        ],
      ),
    );
  }



  // 异步加载病历记录
  void _loadMedicalRecordsAsync() async {
    if (_currentPatient.id == null || !mounted) return;

    try {
      // 先设置加载状态
      if (mounted) {
        setState(() {
          _medicalRecordsLoaded = true; // 标记为已尝试加载
        });
      }

      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 确保数据库已初始化
      if (!dbProvider.isInitialized) {
        print('数据库未初始化，无法加载病历记录');
        return;
      }
      
      // 确保provider已初始化
      if (!medicalRecordProvider.initialized) {
        await medicalRecordProvider.initializeFromDatabase(dbProvider);
      }
      
      // 像患者提供者一样，直接调用简单的查询方法
      final records = await medicalRecordProvider.getPatientMedicalRecordsSimple(_currentPatient.id!);
      
      if (mounted) {
        setState(() {
          _cachedMedicalRecords = records;
        });
      }
    } catch (e) {
      print('加载病历记录失败: $e');
      // 错误状态已经通过_medicalRecordsLoaded = true设置
    }
  }

  // 显示病历记录
  Widget _buildMedicalRecordsDisplay() {
    // 如果还没有加载过，触发加载
    if (!_medicalRecordsLoaded) {
      // 使用addPostFrameCallback避免在build过程中调用setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMedicalRecordsAsync();
      });
      
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                '正在加载病历记录...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final records = _cachedMedicalRecords;

    // 如果加载完成但records为null，说明加载失败
    if (records == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '加载病历记录失败',
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cachedMedicalRecords = null;
                    _medicalRecordsLoaded = false;
                  });
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 如果记录为空
    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.description_outlined,
                color: Colors.grey[400],
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '暂无病历记录',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '该患者还没有创建病历记录',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: records.map((record) => _buildMedicalRecordCard(record)).toList(),
    );
  }

  // 病历记录卡片
  Widget _buildMedicalRecordCard(PatientMedicalRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _viewMedicalRecordDetails(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      record.recordNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MM-dd').format(record.recordDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (record.chiefComplaint.isNotEmpty) ...[
                Text(
                  '主诉: ${record.chiefComplaint}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              if (record.diagnosis.isNotEmpty) ...[
                Text(
                  '诊断: ${record.diagnosis}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '医生: ${record.doctorName.isNotEmpty ? record.doctorName : '未知'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '查看详情',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 查看病历详情
  void _viewMedicalRecordDetails(PatientMedicalRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordDetailScreen(
          patient: _currentPatient,
          record: record,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool alignTop = false,
    Color? valueColor,
    bool isPhone = false,
  }) {
    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child:
              isPhone
                  ? Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _callPhoneNumber(value),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.call,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? AppTheme.textColor,
                      fontSize: 14,
                      fontWeight:
                          valueColor != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildPhoneNumbersSection() {
    try {
      if (_phoneNumbers.isEmpty) {
        _phoneNumbers = ['未设置'];
      }

      if (_phoneNumbers.length == 1) {
        // 单个电话号码时，使用isPhone参数启用拨号功能
        return _buildInfoRow(
          CupertinoIcons.phone,
          '联系电话',
          _phoneNumbers[0],
          isPhone: _phoneNumbers[0] != '未设置',
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  CupertinoIcons.phone,
                  size: 18,
                  color: AppTheme.secondaryTextColor,
                ),
                SizedBox(width: 8),
                Text(
                  '联系电话',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _phoneNumbers.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            i == 0
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        i == 0 ? '主要' : '备用',
                        style: TextStyle(
                          color:
                              i == 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _phoneNumbers[i],
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontSize: 14,
                          decoration:
                              _phoneNumbers[i] != '未设置'
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                        ),
                      ),
                    ),
                    if (_phoneNumbers[i] != '未设置')
                      IconButton(
                        icon: const Icon(
                          Icons.phone,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _callPhoneNumber(_phoneNumbers[i]);
                        },
                        tooltip: '拨打此号码',
                      ),
                  ],
                ),
              ),
          ],
        );
      }
    } catch (e) {
      print('构建电话号码部分错误: $e');
      return _buildInfoRow(CupertinoIcons.phone, '联系电话', '未设置');
    }
  }

  Widget _buildDentalConditionInfo(String dentalConditionJson) {
    try {
      print('准备解析牙齿数据: $dentalConditionJson');

      Map<String, dynamic> dentalData = Map<String, dynamic>.from(
        jsonDecode(dentalConditionJson),
      );

      // 打印完整的牙齿数据以便调试
      print('完整的牙齿状况数据: $dentalData');

      // 特别检查备注字段
      List<String> noteKeys =
          dentalData.keys.where((key) => key.contains('note')).toList();
      print('数据中的备注字段: $noteKeys');
      for (var key in noteKeys) {
        print('备注内容 $key: ${dentalData[key] ?? "空值"}');
      }

      // 收集所有记录并按日期排序
      Map<String, Map<String, String>> groupedData = {};
      Set<String> allIndexes = {};

      // 首先获取所有的索引
      dentalData.keys.forEach((key) {
        if (key.startsWith('date-')) {
          String index = key.split('-').last;
          allIndexes.add(index);
        } else if (key.contains('-')) {
          List<String> parts = key.split('-');
          if (parts.length >= 2) {
            String dataIndex = parts.last;
            allIndexes.add(dataIndex);
          }
        }
      });

      print('找到的索引列表: $allIndexes');

      // 初始化所有组的数据
      for (String index in allIndexes) {
        groupedData[index] = {'date': ''};
      }

      // 处理所有数据
      dentalData.forEach((key, value) {
        if (key.startsWith('date-')) {
          String index = key.split('-').last;
          groupedData[index]!['date'] = value?.toString() ?? '';
        } else if (key.contains('-')) {
          List<String> parts = key.split('-');
          if (parts.length >= 2) {
            String dataIndex = parts.last;

            // 处理带有note的字段
            if (key.contains('note')) {
              String chartPrefix = parts[0]; // 例如 chart1
              groupedData[dataIndex]!['$chartPrefix-note'] =
                  value?.toString() ?? '';
              print(
                '设置备注 $key: ${value?.toString() ?? ""} => $chartPrefix-note',
              );
            }
            // 处理位置字段
            else if (parts.length >= 3) {
              String chartPrefix = parts[0]; // 例如 chart1
              String position = parts[1];
              if (parts.length > 3) {
                position = '${parts[1]}-${parts[2]}'; // 例如 top-left
              }
              groupedData[dataIndex]!['$chartPrefix-$position'] =
                  value?.toString() ?? '';
            }
          }
        }
      });

      print('分组后的牙齿数据: $groupedData');

      // 打印所有备注数据
      for (var entry in groupedData.entries) {
        print('索引 ${entry.key} 的备注:');
        for (var chartNum = 1; chartNum <= 3; chartNum++) {
          String noteKey = 'chart$chartNum-note';
          print('  图表$chartNum备注: ${entry.value[noteKey] ?? ""}');
        }
      }

      // 过滤出有内容的日期记录，并按日期倒序排序（最新的在前）
      List<Widget> dateRecords = [];
      
      // 将记录转换为列表并按日期排序
      List<MapEntry<String, Map<String, String>>> sortedEntries = groupedData.entries.toList();
      sortedEntries.sort((a, b) {
        String dateA = a.value['date'] ?? '';
        String dateB = b.value['date'] ?? '';
        // 倒序排序，最新日期在前
        return dateB.compareTo(dateA);
      });
      
      for (var entry in sortedEntries) {
        String index = entry.key;
        Map<String, String> data = entry.value;
        
        // 检查该日期是否有任何图表内容
        bool hasAnyContent = false;
        for (int i = 1; i <= 3; i++) {
          if (_hasChartContent('图表$i', data)) {
            hasAnyContent = true;
            break;
          }
        }
        
        // 只有当该日期有内容时才添加到显示列表
        if (hasAnyContent) {
          if (dateRecords.isNotEmpty) {
            dateRecords.add(const SizedBox(height: 16)); // 日期记录之间的间距
          }
          
          dateRecords.add(Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期栏
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
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
                                data['date'] ?? '未设置',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 图表内容 - 只显示有内容的图表
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildNonEmptyDentalCharts(data),
                      ),
                    ),
                  ],
                ),
              ));
        }
      }
      
      // 如果没有任何日期有内容，显示提示信息
      if (dateRecords.isEmpty) {
        dateRecords.add(
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  color: Colors.grey.shade400,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无牙齿状况记录',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请在编辑患者信息时添加牙齿状况',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dateRecords,
      );
    } catch (e) {
      print('解析牙齿状况数据错误: $e');
      return Center(child: Text('牙齿状况数据格式错误: $e'));
    }
  }

  // 构建非空的牙齿图表列表
  List<Widget> _buildNonEmptyDentalCharts(Map<String, String> data) {
    List<Widget> charts = [];
    
    // 检查并添加有内容的图表
    for (int i = 1; i <= 3; i++) {
      String title = '图表$i';
      if (_hasChartContent(title, data)) {
        if (charts.isNotEmpty) {
          charts.add(const SizedBox(height: 16)); // 添加间距
        }
        charts.add(_buildDentalChartInfo(title, data));
      }
    }
    
    // 如果没有任何图表有内容，显示提示信息
    if (charts.isEmpty) {
      charts.add(
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '该日期暂无牙齿状况记录',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return charts;
  }

  // 检查图表是否有内容（包括四个象限和备注）
  bool _hasChartContent(String title, Map<String, String> data) {
    final chartPrefix = "chart${title.substring(2, 3)}"; // 从"图表1"提取为"chart1"
    
    // 检查四个象限是否有内容
    final topLeft = data['$chartPrefix-top-left'] ?? '';
    final topRight = data['$chartPrefix-top-right'] ?? '';
    final bottomLeft = data['$chartPrefix-bottom-left'] ?? '';
    final bottomRight = data['$chartPrefix-bottom-right'] ?? '';
    
    // 检查备注是否有有效内容
    String noteValue = data['$chartPrefix-note'] ?? '';
    // 过滤掉默认提示文本
    if (noteValue.startsWith('请在此输入') && noteValue.endsWith('的备注')) {
      noteValue = '';
    }
    
    // 只要有任何一个字段有内容就显示该图表
    return topLeft.trim().isNotEmpty || 
           topRight.trim().isNotEmpty || 
           bottomLeft.trim().isNotEmpty || 
           bottomRight.trim().isNotEmpty || 
           noteValue.trim().isNotEmpty;
  }

  // 辅助方法：构建单个牙齿图表的信息显示 - 十字图表版本
  Widget _buildDentalChartInfo(String title, Map<String, String> data) {
    final chartPrefix = "chart${title.substring(2, 3)}"; // 从"图表1"提取为"chart1"

    // 检查备注内容是否存在
    String noteValue = data['$chartPrefix-note'] ?? '';
    // 检查备注是否为提示文本，避免显示
    if (noteValue.startsWith('请在此输入') && noteValue.endsWith('的备注')) {
      noteValue = '';
    }

    // 检查四个象限是否有内容
    final topLeft = data['$chartPrefix-top-left'] ?? '';
    final topRight = data['$chartPrefix-top-right'] ?? '';
    final bottomLeft = data['$chartPrefix-bottom-left'] ?? '';
    final bottomRight = data['$chartPrefix-bottom-right'] ?? '';
    
    final hasChartData = topLeft.trim().isNotEmpty || 
                        topRight.trim().isNotEmpty || 
                        bottomLeft.trim().isNotEmpty || 
                        bottomRight.trim().isNotEmpty;

    // 如果只有备注没有图表数据，使用紧凑显示
    if (!hasChartData && noteValue.trim().isNotEmpty) {
      return _buildCompactNoteOnlyChart(title, noteValue);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getChartIcon(title), size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 十字图表显示 - 只读版本
          Container(
            height: 100, // 适合移动端的高度
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                // 十字线 - 横线
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 2,
                    color: Colors.blue.shade300,
                  ),
                ),
                // 十字线 - 竖线
                Center(
                  child: Container(
                    width: 2,
                    height: 60,
                    color: Colors.blue.shade300,
                  ),
                ),

                // 四个象限的文本显示
                Column(
                  children: [
                    // 上排 - 左上和右上
                    Expanded(
                      child: Row(
                        children: [
                          // 左上象限 (患者右上)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 6, top: 12),
                              child: _buildQuadrantText(data['$chartPrefix-top-left'] ?? ''),
                            ),
                          ),
                          // 右上象限 (患者左上)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 6, top: 12),
                              child: _buildQuadrantText(data['$chartPrefix-top-right'] ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 下排 - 左下和右下
                    Expanded(
                      child: Row(
                        children: [
                          // 左下象限 (患者右下)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 6, bottom: 12),
                              child: _buildQuadrantText(data['$chartPrefix-bottom-left'] ?? ''),
                            ),
                          ),
                          // 右下象限 (患者左下)
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 6, bottom: 12),
                              child: _buildQuadrantText(data['$chartPrefix-bottom-right'] ?? ''),
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

          // 备注显示区域 - 位于十字图下方
          if (noteValue.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '备注',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noteValue,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建象限文本，空内容时显示占位符
  Widget _buildQuadrantText(String text) {
    if (text.trim().isEmpty) {
      return Text(
        '·', // 使用小点作为空内容占位符
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade300,
          fontWeight: FontWeight.w300,
        ),
      );
    }
    
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  // 构建仅有备注的紧凑图表显示
  Widget _buildCompactNoteOnlyChart(String title, String noteValue) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.amber.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getChartIcon(title),
              color: Colors.amber.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  noteValue,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.note_alt,
            size: 16,
            color: Colors.amber.shade600,
          ),
        ],
      ),
    );
  }

  // 为图表获取相应的图标
  IconData _getChartIcon(String title) {
    switch (title) {
      case '图表1':
        return Icons.healing;
      case '图表2':
        return Icons.health_and_safety;
      case '图表3':
        return Icons.medical_information;
      default:
        return Icons.medical_services;
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
