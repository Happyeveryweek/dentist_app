import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../providers/database_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/medical_record_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';
import '../utils/dental_condition_integration.dart';
import '../utils/permission_utils.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';
import './patient_form_dialog.dart';
import './appointment_form_dialog.dart';
import './appointment_details_screen.dart';
import './financial_form_dialog.dart';
import './financial_detail_screen.dart';
import './financial_detail_form_dialog.dart';
import './financial_management_screen.dart' show FinancialRecordEditDialog;
import 'patients_screen.dart';
import '../widgets/material_detail_manager.dart';
import '../widgets/success_toast.dart' show DeleteConfirmDialogManager;
import './medical_record_form_dialog.dart';
import '../models/patient_medical_record.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Patient? _patient;
  List<Appointment> _appointments = [];
  // 移除_patientMaterials变量 - 材料管理已迁移到MaterialDetailManager
  List<FinancialRecord> _financialRecords = [];
  List<FinancialItem> _financialItems = [];
  List<PatientMedicalRecord> _medicalRecords = [];
  late TabController _tabController;
  
  // 标记数据是否已更改，用于通知父页面是否需要刷新
  bool _dataChanged = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _loadPatientData();
      _dataLoaded = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);

      // 直接使用传入的患者对象
      final patient = widget.patient;

      // 读取患者预约数据
      final appointments =
          await appointmentProvider.getAppointmentsByPatient(widget.patient.id!);

          // 读取患者材料数据 - 供MaterialDetailManager使用
      // 注意：MaterialDetailManager会自己加载数据，这里可以不加载

      // 读取患者收费记录数据 - 只有有权限的用户才能加载
      List<FinancialRecord> patientFinancialRecords = [];
      List<FinancialItem> allFinancialItems = [];
      
      if (_canViewPatientFinancialRecords()) {
        print('🔍 开始加载患者收费记录，患者ID: ${widget.patient.id}');
        
        // 清除缓存，确保从数据库获取最新数据
        financialProvider.clearCache();
        
        // 使用不带权限过滤的方法，因为页面级别已经做了权限检查
        final allFinancialRecords = await financialProvider.getAllFinancialRecords();
        print('🔍 获取到所有收费记录数量: ${allFinancialRecords.length}');
        
        patientFinancialRecords = allFinancialRecords
            .where((record) => record.patientId == widget.patient.id!)
            .toList();
        print('🔍 筛选后该患者的收费记录数量: ${patientFinancialRecords.length}');
        
        // 读取该患者的所有收费项目
        for (var record in patientFinancialRecords) {
          final items = await financialProvider.getFinancialItems(record.id!);
          allFinancialItems.addAll(items);
          print('🔍 收费记录 ${record.id} 包含 ${items.length} 个收费项目');
        }
        print('🔍 该患者总收费项目数量: ${allFinancialItems.length}');
      } else {
        print('🔍 权限检查失败，无法加载患者收费记录');
      }

      // 读取患者病历数据
      List<PatientMedicalRecord> medicalRecords = [];
      try {
        if (medicalRecordProvider.initialized) {
          medicalRecords = await medicalRecordProvider.getPatientMedicalRecords(widget.patient.id!);
        }
      } catch (e) {
        print('加载病历数据失败: $e');
        // 不阻止页面加载，只是病历数据为空
      }

      if (mounted) {
        setState(() {
          _patient = patient;
          _appointments = appointments;
          // 移除_patientMaterials赋值 - 材料管理已迁移到MaterialDetailManager
          _financialRecords = patientFinancialRecords;
          _financialItems = allFinancialItems;
          _medicalRecords = medicalRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载患者数据错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // 延迟显示错误消息，确保widget已完全构建
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('加载数据错误: $e')),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 系统返回按钮也要传递数据更改标志
        Navigator.of(context).pop(_dataChanged);
        return false; // 阻止默认返回行为，因为我们已经手动处理了
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回时传递数据更改标志
            Navigator.of(context).pop(_dataChanged);
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: DentalColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _patient?.name ?? '患者详情',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: DentalColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.primary.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.edit_rounded,
                color: DentalColors.primary,
              ),
              tooltip: '编辑患者',
              onPressed: _isLoading ? null : _editPatient,
            ),
          ),
        ],
        bottom: _isLoading
            ? null
            : TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '基本信息'),
                Tab(text: '患者病历'),
                Tab(text: '患者材料'),
                Tab(text: '预约记录'),
                Tab(text: '收费记录'),
              ],
            ),
      ),
      body: _isLoading
            ? const LoadingIndicator()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPatientInfoTab(),
                  _buildMedicalRecordsTab(),
                  _buildPatientMaterialsTab(),
                  _buildAppointmentsTab(),
                  _buildFinancialRecordsTab(),
                ],
              ),
      // 移除浮动操作按钮 - 各标签页的添加功能已集成到各自的管理器中
      // floatingActionButton: _tabController.index == 1
      //     ? FloatingActionButton(
      //         heroTag: 'patient_detail_add_button',
      //         onPressed: _addAppointment,
      //         child: const Icon(Icons.add),
      //       )
      //     : null,
      ),
    );
  }

  Widget _buildPatientInfoTab() {
    if (_patient == null) {
      return const Center(child: Text('无法加载患者信息'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部概览卡片 - 更紧凑的设计
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  DentalColors.background.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: DentalColors.primary.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: DentalColors.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // 患者头像/标识
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: _patient!.gender == '女'
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFFCE4EC),
                                const Color(0xFFF8BBD9),
                              ],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFE3F2FD),
                                const Color(0xFFBBDEFB),
                              ],
                            ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_patient!.gender == '女'
                                  ? Colors.pink
                                  : Colors.blue)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _patient!.name.isNotEmpty ? _patient!.name[0] : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _patient!.gender == '女'
                              ? Colors.pink.shade600
                              : Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 患者主要信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 姓名
                        Row(
                          children: [
                            Text(
                              _patient!.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: _patient!.gender == '女'
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.pink.shade50,
                                          Colors.pink.shade100,
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.blue.shade50,
                                          Colors.blue.shade100,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _patient!.gender == '女'
                                      ? Colors.pink.shade200
                                      : Colors.blue.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_patient!.gender == '女'
                                            ? Colors.pink
                                            : Colors.blue)
                                        .withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _patient!.gender == '女'
                                        ? Icons.female_rounded
                                        : Icons.male_rounded,
                                    size: 18,
                                    color: _patient!.gender == '女'
                                        ? Colors.pink.shade500
                                        : Colors.blue.shade500,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _patient!.gender,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _patient!.gender == '女'
                                          ? Colors.pink.shade600
                                          : Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    DentalColors.success.withOpacity(0.1),
                                    DentalColors.success.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: DentalColors.success.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: DentalColors.success.withOpacity(0.15),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    size: 16,
                                    color: DentalColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_patient!.age}岁',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: DentalColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // 首诊日期显示
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    DentalColors.info.withOpacity(0.1),
                                    DentalColors.info.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: DentalColors.info.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: DentalColors.info.withOpacity(0.15),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: DentalColors.info,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '首诊: ${DateFormat('yyyy-MM-dd').format(_patient!.first_visit_date)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: DentalColors.info,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 电话信息
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: DentalColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.phone_rounded,
                                size: 16,
                                color: DentalColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _patient!.displayPhone(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: DentalColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // 身份证号信息
                        if (_patient!.identification_number != null)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: DentalColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.credit_card_rounded,
                                  size: 16,
                                  color: DentalColors.secondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _patient!.identification_number!,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: DentalColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 用分区标签分割内容
          _buildSectionHeader('个人信息', Icons.person, const Color(0xFF2ecc71)),
          // 个人信息卡片 - 紧凑单行设计
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 病历号
                  Expanded(
                    flex: 2,
                    child: _buildCompactPersonalInfoItem(
                      icon: Icons.badge,
                      label: '病历号',
                      value: _patient!.medical_record_number?.toString() ?? '无',
                      color: const Color(0xFF2ecc71),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 主治医生
                  Expanded(
                    flex: 2,
                    child: _buildCompactPersonalInfoItem(
                      icon: Icons.medical_services,
                      label: '主治医生',
                      value: _patient!.doctor ?? '无',
                      color: const Color(0xFF2ecc71),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 联系电话
                  Expanded(
                    flex: 3,
                    child: _buildCompactPersonalInfoItem(
                      icon: Icons.phone,
                      label: '联系电话',
                      value: _patient!.phoneList.isNotEmpty 
                        ? (_patient!.phoneList.length > 1 
                          ? '${_patient!.mainPhone} (+${_patient!.phoneList.length - 1})'
                          : _patient!.mainPhone)
                        : '无',
                      color: const Color(0xFF2ecc71),
                    ),
                  ),
                  if (_patient!.address != null && _patient!.address!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    // 住址
                    Expanded(
                      flex: 4,
                      child: _buildCompactPersonalInfoItem(
                        icon: Icons.home,
                        label: '住址',
                        value: _patient!.address!,
                        color: const Color(0xFF2ecc71),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 牙齿状况和治疗分区
          _buildSectionHeader(
              '诊疗信息', Icons.medical_information, const Color(0xFFe74c3c)),
          // 诊疗信息卡片 - 简化设计
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildDentalCondition(),
                  if (_patient!.dental_condition != null &&
                      _patient!.dental_condition!.isNotEmpty &&
                      _patient!.treatment_items != null &&
                      _patient!.treatment_items!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFFe74c3c).withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  if (_patient!.treatment_items != null &&
                      _patient!.treatment_items!.isNotEmpty)
                    _buildDetailItem(
                      '治疗项目',
                      _patient!.treatment_items!,
                      Icons.medical_services,
                      const Color(0xFFe74c3c),
                    ),
                  if (_patient!.dental_condition == null &&
                      _patient!.treatment_items == null)
                    Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFe74c3c).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFe74c3c).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.medical_information_outlined,
                            size: 48,
                            color: const Color(0xFFe74c3c).withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无诊疗信息',
                            style: TextStyle(
                              color: const Color(0xFFe74c3c).withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 信息标签小部件
  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 详细信息项目部件
  Widget _buildDetailItem(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 分区标题小部件
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 紧凑个人信息项小部件
  Widget _buildCompactPersonalInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDentalCondition() {
    if (_patient!.dental_condition == null ||
        _patient!.dental_condition!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('暂无牙齿状况记录'),
      );
    }

    try {
      // 为MySQL和SQLite数据来源处理不同的数据类型
      Map<String, dynamic> dentalCharts;

      if (Provider.of<DatabaseProvider>(context, listen: false)
              .dataSourceType ==
          'mysql') {
        // MySQL数据源
        print('使用MySQL数据源解析dental_condition');

        // 处理dental_condition字段的数据
        final dynamic rawData = _patient!.dental_condition;
        String jsonStr = '';

        try {
          // 根据实际类型进行处理
          if (rawData is List<int>) {
            // 已经是List<int>类型，直接解码
            jsonStr = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is Uint8List) {
            // 是Uint8List类型，直接解码
            jsonStr = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is String) {
            // 是String类型，直接使用
            jsonStr = rawData;
          } else {
            // 其他类型，尝试toString()
            jsonStr = rawData.toString();
          }

          print(
              '处理后的dental_condition: ${jsonStr.length > 50 ? jsonStr.substring(0, 50) + "..." : jsonStr}');
        } catch (e) {
          print('转换dental_condition错误: $e');
          // 转换失败，使用toString作为后备方案
          jsonStr = rawData != null ? rawData.toString() : '{}';
        }

        // 尝试解析JSON字符串
        try {
          final decodedData = jsonDecode(jsonStr);
          if (decodedData is Map) {
            dentalCharts = Map<String, dynamic>.from(decodedData);

            // 额外处理可能存在的编码问题
            if (Provider.of<DatabaseProvider>(context, listen: false)
                    .dataSourceType ==
                'mysql') {
              _fixChineseEncodingInMap(dentalCharts);
            }
          } else {
            throw FormatException('期望Map类型，实际为: ${decodedData.runtimeType}');
          }
        } catch (e) {
          print('JSON解析错误: $e，尝试修复格式问题');

          // 尝试清理JSON字符串中可能存在的问题字符
          final cleanedJson =
              jsonStr.replaceAll(RegExp(r'[\u0000-\u001F]'), '');

          try {
            final decodedData = jsonDecode(cleanedJson);
            if (decodedData is Map) {
              dentalCharts = Map<String, dynamic>.from(decodedData);

              // 额外处理可能存在的编码问题
              if (Provider.of<DatabaseProvider>(context, listen: false)
                      .dataSourceType ==
                  'mysql') {
                _fixChineseEncodingInMap(dentalCharts);
              }
            } else {
              throw FormatException(
                  '清理后期望Map类型，实际为: ${decodedData.runtimeType}');
            }
          } catch (e2) {
            print('清理后JSON解析仍然失败: $e2');
            // 尝试最后的修复方法
            try {
              // 对于MySQL，尝试手动处理JSON字符串中的编码问题
              if (Provider.of<DatabaseProvider>(context, listen: false)
                      .dataSourceType ==
                  'mysql') {
                String fixedJson = _fixJsonEncoding(jsonStr);
                final decodedData = jsonDecode(fixedJson);
                if (decodedData is Map) {
                  dentalCharts = Map<String, dynamic>.from(decodedData);
                  _fixChineseEncodingInMap(dentalCharts);
                } else {
                  throw FormatException(
                      '修复后期望Map类型，实际为: ${decodedData.runtimeType}');
                }
              } else {
                // 解析失败，使用空Map
                dentalCharts = {};
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('牙齿状况数据格式错误: $e2'),
                );
              }
            } catch (e3) {
              print('所有修复尝试均失败: $e3');
              // 解析失败，使用空Map
              dentalCharts = {};
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('牙齿状况数据格式错误: $e3'),
              );
            }
          }
        }
      } else {
        // SQLite数据源
        dentalCharts = _patient!.dentalCharts;
      }

      if (dentalCharts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('暂无牙齿状况记录'),
        );
      }

      // 找出有多少行数据
      int rowCount = 0;
      for (String key in dentalCharts.keys) {
        if (key.startsWith('date-')) {
          int index = int.tryParse(key.split('-').last) ?? 0;
          rowCount = rowCount > index ? rowCount : index + 1;
        }
      }

      // 创建包含日期和索引的列表用于排序
      List<Map<String, dynamic>> rowsWithDate = [];
      for (int i = 0; i < rowCount; i++) {
        // 获取日期
        String rawDateStr = dentalCharts['date-$i'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        // 确保日期字符串只包含年月日，去掉时分秒
        DateTime date;
        String dateStr;
        try {
          // 尝试解析日期字符串，然后重新格式化为年月日
          if (rawDateStr.contains('-')) {
            // 尝试解析包含"-"的日期格式
            date = DateTime.parse(rawDateStr.split(' ')[0]); // 只取日期部分
          } else if (rawDateStr.contains('/')) {
            // 尝试解析包含"/"的日期格式
            date = DateFormat('yyyy/MM/dd')
                .parse(rawDateStr.split(' ')[0]); // 只取日期部分
          } else {
            // 其他格式
            date = DateTime.parse(rawDateStr);
          }
          // 统一格式化为年-月-日
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          // 解析失败时使用原始字符串和当前日期
          print('日期解析错误: $e，使用原始日期字符串');
          dateStr = rawDateStr;
          date = DateTime.now(); // 使用当前日期作为fallback
        }

        rowsWithDate.add({
          'index': i,
          'date': date,
          'dateStr': dateStr,
        });
      }

      // 按日期排序，最新的在前面
      rowsWithDate.sort((a, b) => b['date'].compareTo(a['date']));

      List<Widget> chartRows = [];
      for (var rowData in rowsWithDate) {
        int i = rowData['index'];
        String dateStr = rowData['dateStr'];

        // 获取创建者医生信息
        String createdByDoctor = _ensureString(dentalCharts['created_by_doctor-$i']);

        // 获取各位置数据并确保是字符串类型
        // 第一个图表
        String chart1TopLeft =
            _ensureString(dentalCharts['chart1-top-left-$i']);
        String chart1TopRight =
            _ensureString(dentalCharts['chart1-top-right-$i']);
        String chart1BottomLeft =
            _ensureString(dentalCharts['chart1-bottom-left-$i']);
        String chart1BottomRight =
            _ensureString(dentalCharts['chart1-bottom-right-$i']);
        String chart1Note = _ensureString(dentalCharts['chart1-note-$i']);

        // 第二个图表
        String chart2TopLeft =
            _ensureString(dentalCharts['chart2-top-left-$i']);
        String chart2TopRight =
            _ensureString(dentalCharts['chart2-top-right-$i']);
        String chart2BottomLeft =
            _ensureString(dentalCharts['chart2-bottom-left-$i']);
        String chart2BottomRight =
            _ensureString(dentalCharts['chart2-bottom-right-$i']);
        String chart2Note = _ensureString(dentalCharts['chart2-note-$i']);

        // 第三个图表
        String chart3TopLeft =
            _ensureString(dentalCharts['chart3-top-left-$i']);
        String chart3TopRight =
            _ensureString(dentalCharts['chart3-top-right-$i']);
        String chart3BottomLeft =
            _ensureString(dentalCharts['chart3-bottom-left-$i']);
        String chart3BottomRight =
            _ensureString(dentalCharts['chart3-bottom-right-$i']);
        String chart3Note = _ensureString(dentalCharts['chart3-note-$i']);

        chartRows.add(
          _buildDentalChartCard(
            dateStr,
            createdByDoctor,
            chart1TopLeft,
            chart1TopRight,
            chart1BottomLeft,
            chart1BottomRight,
            chart1Note,
            chart2TopLeft,
            chart2TopRight,
            chart2BottomLeft,
            chart2BottomRight,
            chart2Note,
            chart3TopLeft,
            chart3TopRight,
            chart3BottomLeft,
            chart3BottomRight,
            chart3Note,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 添加标题
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
            const SizedBox(height: 8),
            // 添加滚动视图来显示多行牙齿状况 - 动态调整高度避免滚动条
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _calculateOptimalChartHeight(chartRows.length),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: chartRows,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('解析牙齿状况数据出错: $e'),
      );
    }
  }

  // 计算牙齿状况图表的最佳高度
  double _calculateOptimalChartHeight(int chartCount) {
    // 每个图表卡片的基础高度 (优化后更紧凑)
    // 包含：创建者信息(15px) + 日期和图表行(75px) + 卡片间距(8px) + 内边距(12px) = 约110px
    const double baseChartHeight = 110.0;
    // 标题和间距的额外高度
    const double headerHeight = 40.0;
    // 底部间距
    const double bottomPadding = 16.0;
    
    // 计算总高度
    double totalHeight = headerHeight + (chartCount * baseChartHeight) + bottomPadding;
    
    // 设置合理的最小和最大高度
    const double minHeight = 180.0; // 减少最小高度
    const double maxHeight = 700.0; // 适当的最大高度
    
    // 确保高度在合理范围内
    return totalHeight.clamp(minHeight, maxHeight);
  }

  // 确保值为字符串类型的辅助方法
  String _ensureString(dynamic value) {
    if (value == null) return '';

    try {
      if (value is List<int>) {
        // 二进制数据转换为字符串，尝试多种编码方式
        try {
          final utf8Result = utf8.decode(value, allowMalformed: true);
          if (_containsChinese(utf8Result)) {
            return utf8Result;
          }

          // 尝试其他编码
          if (Provider.of<DatabaseProvider>(context, listen: false)
                  .dataSourceType ==
              'mysql') {
            // MySQL默认通常是latin1或utf8
            try {
              // 尝试转换为latin1编码字符串再转回utf8
              final latin1Result = String.fromCharCodes(value);
              if (_containsChinese(latin1Result)) {
                return latin1Result;
              }
            } catch (e) {
              print('latin1转换失败: $e');
            }
          }

          return utf8Result;
        } catch (e) {
          print('二进制数据转换为字符串失败: $e');
          // 尝试直接从字符码转换
          return String.fromCharCodes(value);
        }
      } else if (value is Uint8List) {
        // Uint8List转换为字符串，尝试多种编码方式
        try {
          final utf8Result = utf8.decode(value, allowMalformed: true);
          if (_containsChinese(utf8Result)) {
            return utf8Result;
          }

          // 尝试其他编码
          if (Provider.of<DatabaseProvider>(context, listen: false)
                  .dataSourceType ==
              'mysql') {
            // 尝试转换为latin1编码字符串
            try {
              final latin1Result = String.fromCharCodes(value);
              if (_containsChinese(latin1Result)) {
                return latin1Result;
              }
            } catch (e) {
              print('latin1转换失败: $e');
            }
          }

          return utf8Result;
        } catch (e) {
          print('Uint8List转换为字符串失败: $e');
          // 尝试直接从字符码转换
          return String.fromCharCodes(value);
        }
      } else if (value is String) {
        // 对已经是字符串的值检查是否需要重新解码
        if (Provider.of<DatabaseProvider>(context, listen: false)
                    .dataSourceType ==
                'mysql' &&
            !_containsChinese(value) &&
            _containsEncodedBytes(value)) {
          try {
            // 检测到可能是编码问题的字符串，尝试重新解码
            List<int> bytes = value.codeUnits;
            final decodedString = utf8.decode(bytes, allowMalformed: true);
            if (_containsChinese(decodedString)) {
              return decodedString;
            }
          } catch (e) {
            print('字符串重新解码失败: $e');
          }
        }
        return value;
      }
    } catch (e) {
      print('字符串处理异常: $e');
    }

    // 默认返回toString结果
    return value.toString();
  }

  // 检测字符串是否包含中文字符
  bool _containsChinese(String text) {
    // 中文Unicode范围大致为\u4e00-\u9fff
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  // 检测字符串是否可能包含编码问题的字节
  bool _containsEncodedBytes(String text) {
    // 检查是否包含常见的非ASCII字符但又不是中文
    return RegExp(r'[\u0080-\u00ff]').hasMatch(text);
  }

  Widget _buildDentalChartCard(
    String dateStr,
    String createdByDoctor,
    String chart1TopLeft,
    String chart1TopRight,
    String chart1BottomLeft,
    String chart1BottomRight,
    String chart1Note,
    String chart2TopLeft,
    String chart2TopRight,
    String chart2BottomLeft,
    String chart2BottomRight,
    String chart2Note,
    String chart3TopLeft,
    String chart3TopRight,
    String chart3BottomLeft,
    String chart3BottomRight,
    String chart3Note,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8), // 减少底部间距
      child: Container(
        padding: const EdgeInsets.all(6), // 减少内边距
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 创建者信息显示 - 更紧凑的设计
            if (createdByDoctor.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6), // 减少底部间距
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 减少内边距
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // 让容器尽可能小
                  children: [
                    Icon(
                      Icons.person,
                      size: 10, // 减小图标尺寸
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 3), // 减少间距
                    Text(
                      '创建医生: $createdByDoctor',
                      style: TextStyle(
                        fontSize: 9, // 减小字体
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 日期显示 - 更紧凑
                Container(
                  width: 110, // 稍微减小宽度
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), // 减少内边距
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: AppTheme.primaryColor), // 减小图标
                      const SizedBox(width: 3), // 减少间距
                      Expanded(
                        child: Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11), // 减小字体
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6), // 减少间距

                // 图表部分
                Expanded(
                  child: Row(
                    children: [
                      // 第一个牙齿图表
                      Expanded(
                        child: _buildReadOnlyCrossChart(
                          chart1TopLeft,
                          chart1TopRight,
                          chart1BottomLeft,
                          chart1BottomRight,
                          chart1Note,
                        ),
                      ),
                      const SizedBox(width: 6), // 减少间距
                      // 第二个牙齿图表
                      Expanded(
                        child: _buildReadOnlyCrossChart(
                          chart2TopLeft,
                          chart2TopRight,
                          chart2BottomLeft,
                          chart2BottomRight,
                          chart2Note,
                        ),
                      ),
                      const SizedBox(width: 6), // 减少间距
                      // 第三个牙齿图表
                      Expanded(
                        child: _buildReadOnlyCrossChart(
                          chart3TopLeft,
                          chart3TopRight,
                          chart3BottomLeft,
                          chart3BottomRight,
                          chart3Note,
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
    );
  }

  // 新增方法：构建只读的十字图表，与表单中样式一致
  Widget _buildReadOnlyCrossChart(
    String topLeft,
    String topRight,
    String bottomLeft,
    String bottomRight,
    String note,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 70, // 进一步减少高度
          padding: const EdgeInsets.symmetric(horizontal: 35.0), // 减少水平内边距
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
                  height: 42, // 进一步减少高度
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
                        // 左上象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                                right: 3, top: 14), // 进一步减少内边距
                            child: Text(
                              topLeft,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11), // 减小字体
                            ),
                          ),
                        ),
                        // 右上象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(
                                left: 3, top: 14), // 进一步减少内边距
                            child: Text(
                              topRight,
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 11), // 减小字体
                            ),
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
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                                right: 3, bottom: 14), // 进一步减少内边距
                            child: Text(
                              bottomLeft,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11), // 减小字体
                            ),
                          ),
                        ),
                        // 右下象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(
                                left: 3, bottom: 14), // 进一步减少内边距
                            child: Text(
                              bottomRight,
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 11), // 减小字体
                            ),
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
        // 备注显示区域 - 减少高度以节省空间
        Container(
          margin: const EdgeInsets.only(top: 3), // 减少顶部间距
          height: 24, // 减少固定高度
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // 减少内边距
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // 内容底部对齐
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 如果有备注内容就显示，占据上部空间
              if (note.isNotEmpty)
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      note,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 10), // 减小字体
                    ),
                  ),
                ),
              // 始终显示横线在底部
              Container(
                height: 1.5,
                width: double.infinity,
                color: Colors.blue.shade300,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _fixChineseEncodingInMap(Map<String, dynamic> map) {
    // 遍历Map，尝试修复所有字符串值的编码问题
    map.forEach((key, value) {
      if (value is String &&
          !_containsChinese(value) &&
          _containsEncodedBytes(value)) {
        try {
          // 尝试修复编码问题
          List<int> bytes = value.codeUnits;

          // 尝试不同的解码方式
          String? fixedValue;

          // 尝试UTF-8解码
          try {
            final utf8Decoded = utf8.decode(bytes, allowMalformed: true);
            if (_containsChinese(utf8Decoded)) {
              fixedValue = utf8Decoded;
            }
          } catch (e) {
            print('UTF-8解码失败: $e');
          }

          // 尝试直接使用String.fromCharCodes
          if (fixedValue == null) {
            try {
              final directDecoded = String.fromCharCodes(bytes);
              if (_containsChinese(directDecoded)) {
                fixedValue = directDecoded;
              }
            } catch (e) {
              print('直接解码失败: $e');
            }
          }

          // 如果找到修复的值，更新Map
          if (fixedValue != null && fixedValue != value) {
            map[key] = fixedValue;
            print('修复编码问题: "$value" -> "$fixedValue"');
          }
        } catch (e) {
          print('修复编码过程中出错: $e');
        }
      }
    });
  }

  String _fixJsonEncoding(String jsonStr) {
    // 修复JSON字符串中的编码问题

    // 步骤1: 处理常见的MySQL编码问题
    // 尝试不同的编码组合
    String fixedJson = jsonStr;

    // 尝试处理可能的转义序列问题
    fixedJson =
        fixedJson.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      try {
        final codePoint = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(codePoint);
      } catch (e) {
        return match.group(0)!;
      }
    });

    // 如果看起来是双重编码的问题，尝试解决
    if (fixedJson.contains(r'\u') && !_containsChinese(fixedJson)) {
      try {
        // 尝试解码一次
        final decoded = jsonDecode(fixedJson);
        if (decoded is String) {
          return decoded;
        } else if (decoded is Map) {
          return jsonEncode(decoded);
        }
      } catch (e) {
        print('尝试解决双重编码问题失败: $e');
      }
    }

    // 对于包含特殊字符序列但不包含中文的字符串，尝试特殊处理
    if (!_containsChinese(fixedJson) && _containsEncodedBytes(fixedJson)) {
      try {
        List<int> bytes = fixedJson.codeUnits;
        String decodedStr = utf8.decode(bytes, allowMalformed: true);
        if (_containsChinese(decodedStr)) {
          return decodedStr;
        }
      } catch (e) {
        print('尝试特殊处理编码失败: $e');
      }
    }

    return fixedJson;
  }

  Widget _buildMedicalRecordsTab() {
    if (_medicalRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: DentalColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_rounded,
                size: 64,
                color: DentalColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无病历记录',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '为患者创建第一份病历记录',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addMedicalRecord,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建病历'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DentalColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      );
    }

    // 按创建时间倒序排序，最新的排在前面
    final sortedRecords = List<PatientMedicalRecord>.from(_medicalRecords);
    sortedRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        // 顶部操作栏
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.medical_services_rounded,
                color: DentalColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '病历记录 (${_medicalRecords.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DentalColors.onSurface,
                ),
              ),
              const Spacer(),
              // 刷新按钮
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: DentalColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DentalColors.info.withOpacity(0.3),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: DentalColors.info,
                    size: 18,
                  ),
                  tooltip: '刷新病历数据',
                  onPressed: _refreshMedicalRecords,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addMedicalRecord,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建病历'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DentalColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 1,
                ),
              ),
            ],
          ),
        ),
        // 病历列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedRecords.length,
            itemBuilder: (context, index) {
              final record = sortedRecords[index];
              return _buildMedicalRecordCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              '暂无预约记录',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addAppointment,
              icon: const Icon(Icons.add),
              label: const Text('添加预约'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 按日期排序，最近的排在前面
    _appointments
        .sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                onTap: () => _viewAppointmentDetails(appointment),
                mouseCursor: SystemMouseCursors.click,
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.event,
                      color: _getStatusColor(appointment.status),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(appointment.appointment_date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(appointment.status)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        appointment.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(appointment.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 牙位信息显示
                      if (appointment.treatment_type != null && 
                          appointment.treatment_type!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    DentalIcons.tooth,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '牙位信息',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTreatmentTypeForDisplay(appointment.treatment_type) ?? '未指定',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (appointment.notes != null &&
                          appointment.notes!.isNotEmpty)
                        Text(
                          '备注: ${appointment.notes}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ),
              // 操作按钮行
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 查看详情按钮
                    TextButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('查看'),
                      onPressed: () => _viewAppointmentDetails(appointment),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    // 编辑按钮
                    PermissionUtils.canEditDoctor(context, appointment.patient?.doctor)
                      ? TextButton.icon(
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('编辑'),
                          onPressed: () => _editAppointment(appointment),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                        )
                      : TextButton.icon(
                          icon: const Icon(Icons.lock, size: 18),
                          label: const Text('权限不足'),
                          onPressed: () => SuccessToastManager.showError(
                            context,
                            message: '您只能编辑自己医生患者的预约',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                        ),
                    // 删除按钮
                    PermissionUtils.canDeleteDoctor(context, appointment.patient?.doctor)
                      ? TextButton.icon(
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('删除'),
                          onPressed: () => _deleteAppointment(appointment),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        )
                      : TextButton.icon(
                          icon: const Icon(Icons.lock, size: 18),
                          label: const Text('权限不足'),
                          onPressed: () => SuccessToastManager.showError(
                            context,
                            message: '您只能删除自己医生患者的预约',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已完成':
        return Colors.green;
      case '已取消':
        return Colors.red;
      case '待确认':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _editPatient() async {
    if (_patient == null) return;

    // 所有医生都可以编辑任何患者，但编辑权限在表单内部控制
    
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);

    // 从数据库获取最新的患者信息，确保包含完整的牙齿状况数据
    Patient? freshPatient;
    try {
      if (_patient!.id != null) {
        print('编辑前获取最新患者数据: ID ${_patient!.id}');
        freshPatient = await patientProvider.getPatient(_patient!.id!);
        if (freshPatient == null) {
          print('无法获取最新患者数据，使用当前患者数据');
          freshPatient = _patient;
        } else {
          print(
              '成功获取最新患者数据，包含牙齿状况: ${freshPatient.dental_condition?.substring(0, 50)}...');
        }
      } else {
        freshPatient = _patient;
      }
    } catch (e) {
      print('获取最新患者数据失败: $e，使用当前患者数据');
      freshPatient = _patient;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => PatientFormDialog(
        patient: freshPatient,
        onSave: _savePatient,
      ),
    );
  }

  // 移除添加患者材料的方法 - 功能已迁移到MaterialDetailManager
  // void _addPatientMaterial() async { ... }

  void _savePatient(Patient updatedPatient) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 患者已经在PatientFormDialog中保存过了，这里只需要刷新数据
      
      // 重新加载数据
      await _loadPatientData();

      if (mounted) {
        // 使用公用成功提示组件
        SuccessToastManager.show(context, message: '患者信息已更新');
        
        // 标记数据已更改，以便父页面知道需要刷新
        _dataChanged = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addAppointment() async {
    // 实现添加预约功能
    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: DateTime.now(),
        preselectedPatient: widget.patient,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final appointmentProvider =
            Provider.of<AppointmentProvider>(context, listen: false);
        await appointmentProvider.addAppointment(result);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          // 使用公用成功提示组件
          SuccessToastManager.show(context, message: '预约已添加');
          // 标记数据已更改
          _dataChanged = true;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加预约失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _viewAppointmentDetails(Appointment appointment) {
    // 跳转到预约详情页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailsScreen(
          appointmentId: appointment.id!,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editAppointment(Appointment appointment) async {
    // 检查编辑权限
    if (!PermissionUtils.canEditDoctor(context, appointment.patient?.doctor)) {
      SuccessToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }
    
    // 实现编辑预约功能
    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: DateTime.now(),
        preselectedPatient: widget.patient,
        appointment: appointment,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final appointmentProvider =
            Provider.of<AppointmentProvider>(context, listen: false);
        await appointmentProvider.updateAppointment(result);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          // 使用公用成功提示组件
          SuccessToastManager.show(context, message: '预约已更新');
          // 标记数据已更改
          _dataChanged = true;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新预约失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _deleteAppointment(Appointment appointment) async {
    // 检查删除权限
    if (!PermissionUtils.canDeleteDoctor(context, appointment.patient?.doctor)) {
      SuccessToastManager.showError(
        context,
        message: '您只能删除自己医生患者的预约',
      );
      return;
    }
    
    // 实现删除预约功能
    final confirm = await DeleteConfirmDialogManager.showAppointmentDelete(
      context,
      appointmentInfo: '这个预约',
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final appointmentProvider =
            Provider.of<AppointmentProvider>(context, listen: false);
        await appointmentProvider.deleteAppointment(appointment.id!);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          // 使用公用删除成功提示组件
          DeleteSuccessToastManager.show(context, message: '预约已删除');
          // 标记数据已更改
          _dataChanged = true;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除预约失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // 格式化显示治疗类型和牙位信息
  String _formatTreatmentTypeForDisplay(String? treatmentTypeStr) {
    if (treatmentTypeStr == null || treatmentTypeStr.isEmpty) {
      return '常规复诊';
    }

    try {
      // 尝试解析JSON数据
      Map<String, dynamic> data = json.decode(treatmentTypeStr);
      List<String> displayParts = [];

      // 处理牙位信息
      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        List teethData = data['teethData'];

        for (int i = 0; i < teethData.length; i++) {
          List<String> positions = [];
          Map<String, dynamic> tooth = Map<String, dynamic>.from(teethData[i]);

          // 检查所有可能的字段名称
          final fieldMapping = {
            'topLeft': '右上',
            'topRight': '左上',
            'bottomLeft': '右下',
            'bottomRight': '左下',
            'upperLeft': '右上',
            'upperRight': '左上',
            'lowerLeft': '右下',
            'lowerRight': '左下',
          };

          fieldMapping.forEach((field, label) {
            if (tooth.containsKey(field) &&
                tooth[field] != null &&
                tooth[field].toString().isNotEmpty) {
              positions.add('$label ${tooth[field]}');
            }
          });

          if (positions.isNotEmpty) {
            displayParts.add('牙位${i + 1}: ${positions.join('，')}');
          }
        }
      }

      // 处理治疗项目
      if (data.containsKey('treatments') && data['treatments'] is List) {
        List<String> treatments = List<String>.from(data['treatments']);
        if (treatments.isNotEmpty) {
          if (displayParts.isNotEmpty) {
            displayParts.add('- ${treatments.join("、")}');
          } else {
            displayParts.add(treatments.join("、"));
          }
        }
      }

      return displayParts.isNotEmpty ? displayParts.join(' ') : '常规复诊';
    } catch (e) {
      // 如果不是JSON格式，直接返回原始字符串
      return treatmentTypeStr;
    }
  }

  // 移除旧的_buildMaterialsTab方法 - 已被MaterialDetailManager替代

  // 移除旧的_buildMaterialCard和_showImageDetail方法 - 已被MaterialDetailManager替代

  Widget _buildPatientMaterialsTab() {
    if (_patient == null) {
      return const Center(child: Text('无法加载患者信息'));
    }

    return MaterialDetailManager(
      patient: _patient!,
      onMaterialsChanged: () {
        // 材料变化时标记数据已更改
        _dataChanged = true;
        // 可以选择性地重新加载患者数据
        // _loadPatientData();
      },
    );
  }

  Widget _buildFinancialRecordsTab() {
    // 检查当前用户是否有权限查看该患者的财务记录
    if (!_canViewPatientFinancialRecords()) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.orange.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '权限不足',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                '您只能查看自己医生的患者的财务记录',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (_financialRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无收费记录',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                '点击下方按钮添加第一条收费记录',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addFinancialRecord,
              icon: const Icon(Icons.add),
              label: const Text('添加收费记录'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 按创建时间排序，最近的排在前面
    _financialRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _financialRecords.length,
      itemBuilder: (context, index) {
        final record = _financialRecords[index];
        final items = _financialItems
            .where((item) => item.financialRecordId == record.id)
            .toList();
        
        return _buildFinancialRecordCard(record, items);
      },
    );
  }

  // 构建财务记录卡片（与财务管理页面保持一致）
  Widget _buildFinancialRecordCard(FinancialRecord record, List<FinancialItem> items) {
    final totalReceivable = items.fold<double>(
      0,
      (sum, item) => sum + item.itemPrice,
    );
    
    final totalCollected = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    
    final outstandingAmount = totalReceivable - totalCollected;
    
    // 计算当前记录所属患者的应收费总额（所有记录的总和）
    double patientTotalReceivable = 0.0;
    if (_financialRecords.isNotEmpty && _financialItems.isNotEmpty) {
      try {
        for (final r in _financialRecords) {
          if (r.id != null) {
            for (final item in _financialItems) {
              if (item.financialRecordId == r.id) {
                patientTotalReceivable += (item.itemPrice * (item.quantity ?? 1));
              }
            }
          }
        }
      } catch (e) {
        print('计算患者应收费总额时出错: $e');
        patientTotalReceivable = totalReceivable; // 出错时使用当前记录金额作为备选
      }
    } else {
      patientTotalReceivable = totalReceivable; // 没有数据时使用当前记录金额
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewFinancialRecordDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：基本信息
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: ((widget.patient.gender == '女') || (widget.patient.gender.toLowerCase() == 'female'))
                          ? Colors.pink.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.patient.name.isNotEmpty ? widget.patient.name[0] : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: ((widget.patient.gender == '女') || (widget.patient.gender.toLowerCase() == 'female'))
                              ? Colors.pink
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patient.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 第二行：收费项目信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '收费项目',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...items.take(3).map((item) => Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    // 应收
                                    Text(
                                      '¥${item.itemPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 已收金额（仅显示金额）
                                    Text(
                                      '¥${item.totalPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 日期
                                    Text(
                                      DateFormat('MM-dd').format(item.chargeDate),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    if (items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                        child: Text(
                          '+${items.length - 3} 更多项目',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 第三行：财务统计信息
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactInfoItem(
                      icon: Icons.calculate,
                      label: '应收费',
                      value: '¥${patientTotalReceivable.toStringAsFixed(2)}',
                      valueColor: Colors.purple[700],
                    ),
                  ),
                  Expanded(
                    child: _buildCompactInfoItem(
                      icon: Icons.payment,
                      label: '当前应收费',
                      value: '¥${totalReceivable.toStringAsFixed(2)}',
                      valueColor: Colors.blue[700],
                    ),
                  ),
                  Expanded(
                    child: _buildCompactInfoItem(
                      icon: Icons.check_circle,
                      label: '已收费',
                      value: '¥${totalCollected.toStringAsFixed(2)}',
                      valueColor: Colors.green[700],
                    ),
                  ),
                  Expanded(
                    child: _buildCompactInfoItem(
                      icon: Icons.warning,
                      label: '欠费',
                      value: '¥${outstandingAmount.toStringAsFixed(2)}',
                      valueColor: outstandingAmount > 0 ? Colors.red : Colors.green[700],
                    ),
                  ),
                ],
              ),
              
              // 第四行：操作按钮
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_canViewPatientFinancialRecords()) ...[
                    TextButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('查看'),
                      onPressed: () => _viewFinancialRecordDetails(record),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('编辑'),
                      onPressed: () => _editFinancialRecord(record),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('删除'),
                      onPressed: () => _deleteFinancialRecord(record),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ] else ...[
                    TextButton.icon(
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('权限不足'),
                      onPressed: () => PermissionUtils.showPermissionDeniedDialog(
                        context,
                        message: '您只能操作自己医生的患者的财务记录。',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建紧凑信息项（与财务管理页面一致）
  Widget _buildCompactInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addFinancialRecord() async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能为自己医生的患者添加收费记录。',
      );
      return;
    }

    // 实现添加收费记录功能
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FinancialFormDialog(
        contextPatient: widget.patient,
        onResult: (success) {
          if (success) {
            // 保存成功后重新加载数据但不关闭页面
            _loadPatientData();
            if (mounted) {
              // 使用公用成功提示组件
              SuccessToastManager.show(context, message: '收费记录已添加');
              // 标记数据已更改
              _dataChanged = true;
            }
          }
        },
      ),
    );
  }

  void _viewFinancialRecordDetails(FinancialRecord record) async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能查看自己医生的患者的财务记录。',
      );
      return;
    }

    // 跳转到收费记录详情页面，并等待返回结果
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialDetailScreen(
          patient: widget.patient,
          initialRecordId: record.id,
        ),
      ),
    );

    // 如果财务详情页有数据变动，重新加载患者数据
    if (result == true) {
      await _loadPatientData();
      // 标记数据已更改
      _dataChanged = true;
    }
  }

  void _editFinancialRecord(FinancialRecord record) async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能编辑自己医生的患者的财务记录。',
      );
      return;
    }

    // 使用和财务管理页面相同的编辑对话框
    final result = await _showEditFinancialRecordDialog(widget.patient, record);
    if (result == true) {
      await _loadPatientData();
    }
  }

  // 显示编辑财务记录对话框（与财务管理页面保持一致）
  // 这是专门用于财务管理列表编辑按钮的方法，显示收费信息列表并允许编辑备注
  Future<bool> _showEditFinancialRecordDialog(Patient patient, FinancialRecord record) async {
    try {
      // 显示完整的编辑对话框，包含收费信息列表和备注编辑
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FinancialRecordEditDialog(
          patient: patient,
          record: record,
        ),
      );
      
      if (result == true) {
        // 标记数据已更改
        _dataChanged = true;
      }
      
      return result ?? false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('编辑财务记录失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // 记录错误日志
      print('编辑财务记录时发生错误: $e');
      return false;
    }
  }

  void _deleteFinancialRecord(FinancialRecord record) async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能删除自己医生的患者的财务记录。',
      );
      return;
    }

    // 实现删除收费记录功能
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '确认删除',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '确定要删除这个收费记录吗？此操作无法撤销。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final financialProvider =
            Provider.of<FinancialProvider>(context, listen: false);
        await financialProvider.deleteFinancialRecord(record.id!);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          // 使用公共成功提示组件
          SuccessToastManager.show(context, message: '收费记录已删除');
          // 标记数据已更改
          _dataChanged = true;
        }
      } catch (e) {
        if (mounted) {
          // 使用公共错误提示组件
          SuccessToastManager.showError(context, message: '删除收费记录失败: $e');
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // 病历相关方法
  Widget _buildMedicalRecordCard(PatientMedicalRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewMedicalRecordDetails(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部信息行
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: DentalColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: DentalColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '病历编号: ${record.recordNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('yyyy-MM-dd').format(record.recordDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (record.doctorName.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '医生: ${record.doctorName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 主诉信息
              if (record.chiefComplaint.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: DentalColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '主诉',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: DentalColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.chiefComplaint,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // 诊断信息
              if (record.diagnosis.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DentalColors.success.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: DentalColors.success.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.medical_information_rounded,
                            size: 16,
                            color: DentalColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '诊断',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: DentalColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.diagnosis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // 底部操作按钮
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _viewMedicalRecordDetails(record),
                    icon: Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: DentalColors.primary,
                    ),
                    label: Text(
                      '查看详情',
                      style: TextStyle(
                        color: DentalColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 只有有编辑权限的用户才显示编辑按钮
                  if (_canEditMedicalRecord(record)) ...[
                    TextButton.icon(
                      onPressed: () => _editMedicalRecord(record),
                      icon: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      label: Text(
                        '编辑',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: () => _exportMedicalRecordToPdf(record),
                    icon: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 16,
                      color: Colors.orange[600],
                    ),
                    label: Text(
                      'PDF',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '创建于 ${DateFormat('MM-dd HH:mm').format(record.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 检查当前用户是否可以编辑指定的病历记录
  bool _canEditMedicalRecord(PatientMedicalRecord record) {
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
      
      // 非管理员用户只能编辑自己创建的病历记录
      if (currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
        final createdByDoctor = record.createdByDoctor ?? record.doctorName;
        return createdByDoctor == currentUser.doctor;
      }
      
      return false;
    } catch (e) {
      print('检查病历编辑权限时出错: $e');
      return false;
    }
  }

  /// 检查当前用户是否可以删除指定的病历记录
  bool _canDeleteMedicalRecord(PatientMedicalRecord record) {
    // 删除权限与编辑权限相同
    return _canEditMedicalRecord(record);
  }

  void _addMedicalRecord() async {
    if (_patient == null) {
      print('_addMedicalRecord: _patient is null');
      return;
    }
    
    print('_addMedicalRecord: patient id = ${_patient!.id}, name = ${_patient!.name}');
    
    try {
      final result = await showDialog<PatientMedicalRecord>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MedicalRecordFormDialog(
          patient: _patient!,
          onSave: (record) async {
            try {
              // 调用MedicalRecordProvider保存病历
              final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
              final recordId = await medicalRecordProvider.createMedicalRecord(record);
              
              if (recordId > 0) {
                // 保存成功，返回带ID的记录
                final savedRecord = record.copyWith(id: recordId);
                Navigator.of(context).pop(savedRecord);
              } else {
                throw Exception('保存病历失败');
              }
            } catch (e) {
              // 显示错误信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('保存病历失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
              // 不关闭对话框，让用户可以重试
            }
          },
        ),
      );

      if (result != null) {
        // 重新加载病历数据
        await _loadPatientData();
        _dataChanged = true;
        
        if (mounted) {
          SuccessToastManager.show(context, message: '病历记录已创建');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建病历失败: $e')),
        );
      }
    }
  }

  void _viewMedicalRecordDetails(PatientMedicalRecord record) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _MedicalRecordDetailDialog(
        patient: _patient!,
        record: record,
        canEdit: _canEditMedicalRecord(record),
        canDelete: _canDeleteMedicalRecord(record),
        onEdit: () {
          Navigator.of(context).pop();
          _editMedicalRecord(record);
        },
        onDelete: () async {
          // 不关闭病历详情页，直接执行删除操作
          await _deleteMedicalRecord(record);
        },
      ),
    );
  }

  void _editMedicalRecord(PatientMedicalRecord record) async {
    if (_patient == null) return;
    
    // 检查编辑权限
    if (!_canEditMedicalRecord(record)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('权限不足：只能编辑自己创建的病历记录'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final result = await showDialog<PatientMedicalRecord>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MedicalRecordFormDialog(
          patient: _patient!,
          medicalRecord: record,
          onSave: (updatedRecord) async {
            try {
              // 调用MedicalRecordProvider更新病历
              final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
              final success = await medicalRecordProvider.updateMedicalRecord(updatedRecord);
              
              if (success) {
                Navigator.of(context).pop(updatedRecord);
              } else {
                throw Exception('更新病历失败');
              }
            } catch (e) {
              // 显示错误信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('更新病历失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
              // 不关闭对话框，让用户可以重试
            }
          },
        ),
      );

      if (result != null) {
        // 重新加载病历数据
        await _loadPatientData();
        _dataChanged = true;
        
        if (mounted) {
          SuccessToastManager.show(context, message: '病历记录已更新');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('编辑病历失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteMedicalRecord(PatientMedicalRecord record) async {
    if (_patient == null) return;
    
    // 检查删除权限
    if (!_canDeleteMedicalRecord(record)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('权限不足：只能删除自己创建的病历记录'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 使用公共删除确认框组件
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除病历记录 "${record.recordNumber}" 吗？此操作不可撤销。',
    );

    if (confirmed) {
      try {
        final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
        await medicalRecordProvider.deleteMedicalRecord(record.id!);
        
        // 重新加载病历数据
        await _loadPatientData();
        _dataChanged = true;
        
        if (mounted) {
          DeleteSuccessToastManager.show(context, message: '病历记录已删除');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除病历失败: $e')),
          );
        }
      }
    }
  }

  void _exportMedicalRecordToPdf(PatientMedicalRecord record) async {
    if (_patient == null) return;
    
    try {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在生成PDF...'),
            ],
          ),
        ),
      );

      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 生成PDF
      final pdfBytes = await medicalRecordProvider.exportMedicalRecordToPdf(
        _patient!,
        record,
        clinicName: '牙科诊所', // 可以从配置中获取
      );

      // 关闭加载指示器
      Navigator.of(context).pop();

      // 使用file_picker保存文件
      final fileName = '病历_${_patient!.name}_${record.recordNumber}_${DateFormat('yyyyMMdd').format(record.recordDate)}.pdf';
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存病历PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (result != null) {
        // 使用公共成功提示组件
        SuccessToastManager.show(
          context, 
          message: 'PDF已保存成功',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // 关闭加载指示器（如果还在显示）
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('导出PDF失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// 刷新病历记录数据
  Future<void> _refreshMedicalRecords() async {
    if (_patient == null) return;
    
    try {
      // 显示加载状态
      setState(() {
        _isLoading = true;
      });
      
      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 从数据库重新获取最新的病历数据
      List<PatientMedicalRecord> medicalRecords = [];
      if (medicalRecordProvider.initialized) {
        medicalRecords = await medicalRecordProvider.getPatientMedicalRecords(_patient!.id!);
      }
      
      if (mounted) {
        setState(() {
          _medicalRecords = medicalRecords;
          _isLoading = false;
        });
        
        // 显示刷新成功提示
        SuccessToastManager.show(
          context, 
          message: '病历数据已刷新',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // 显示错误提示
        SuccessToastManager.showError(
          context,
          message: '刷新病历数据失败: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// 检查当前用户是否可以查看该患者的财务记录
  bool _canViewPatientFinancialRecords() {
    // 使用 widget.patient 而不是 _patient，因为在数据加载时 _patient 可能还是 null
    final patient = _patient ?? widget.patient;
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      print('=== 财务记录权限检查 ===');
      print('当前用户: ${currentUser?.username}');
      print('用户角色: ${currentUser?.role}');
      print('用户医生: ${currentUser?.doctor}');
      print('患者姓名: ${patient.name}');
      print('患者医生: ${patient.doctor}');
      print('用户是否为管理员: ${currentUser?.isAdmin}');
      
      if (currentUser == null) {
        print('权限检查结果: false (用户未登录)');
        return false;
      }
      
      // 管理员拥有所有权限
      if (currentUser.isAdmin) {
        print('权限检查结果: true (管理员权限)');
        return true;
      }
      
      // 非管理员用户只能查看自己医生的患者的财务记录
      // 如果患者没有指定医生，或者当前用户的医生与患者的医生匹配，则允许查看
      if (patient.doctor == null || patient.doctor!.isEmpty) {
        // 如果患者没有指定医生，所有用户都可以查看
        print('权限检查结果: true (患者未指定医生)');
        return true;
      }
      
      // 检查当前用户的医生是否与患者的医生匹配
      final hasPermission = currentUser.doctor != null && currentUser.doctor == patient.doctor;
      print('权限检查结果: $hasPermission (医生匹配检查)');
      return hasPermission;
    } catch (e) {
      print('检查财务记录查看权限时出错: $e');
      return false;
    }
  }
}

/// 病历详情对话框
class _MedicalRecordDetailDialog extends StatelessWidget {
  final Patient patient;
  final PatientMedicalRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;
  final bool canDelete;

  const _MedicalRecordDetailDialog({
    Key? key,
    required this.patient,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
    this.canDelete = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85, // 稍微增宽
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.96, // 增加五分之一高度 (0.8 * 1.2 = 0.96)
          maxWidth: 900, // 增加最大宽度
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DentalColors.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: DentalColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: DentalColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '病历详情',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: DentalColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '病历编号: ${record.recordNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // 内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本信息
                    _buildBasicInfoSection(),
                    
                    // 主诉
                    if (record.chiefComplaint.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('主诉', Icons.chat_bubble_outline, record.chiefComplaint),
                    ],
                    
                    // 现病史
                    if (record.presentIllness.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('现病史', Icons.history, record.presentIllness),
                    ],
                    
                    // 既往史
                    if (record.pastMedicalHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('全身疾病既往史', Icons.medical_services, record.pastMedicalHistory),
                    ],
                    
                    if (record.pastDentalHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('口腔疾病既往史', Icons.local_hospital, record.pastDentalHistory),
                    ],
                    
                    // 过敏史
                    if (record.allergyHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('过敏史', Icons.warning_amber, record.allergyHistory, isWarning: true),
                    ],
                    
                    // 口腔检查
                    if (record.oralExamination.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('口腔检查', Icons.search, record.oralExamination),
                    ],
                    
                    // 关联牙齿状况
                    if (record.selectedDentalConditionDate != null && record.selectedDentalConditionDate!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildMultipleDentalConditionSection(record.selectedDentalConditionDate!),
                    ],
                    
                    // 诊断
                    if (record.diagnosis.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('诊断', Icons.medical_information, record.diagnosis, isHighlight: true),
                    ],
                    
                    // 治疗方案
                    if (record.treatmentPlan.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('治疗方案', Icons.healing, record.treatmentPlan),
                    ],
                    
                    // 注意事项
                    if (record.notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildContentSection('注意事项', Icons.note_alt, record.notes),
                    ],
                  ],
                ),
              ),
            ),
            
            // 底部操作按钮
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // PDF导出按钮
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _exportToPdf(context),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('导出PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  // 只有有编辑权限的用户才显示编辑按钮
                  if (canEdit) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('编辑'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DentalColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // 只有有删除权限的用户才显示删除按钮
                  if (canDelete) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('删除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: DentalColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: DentalColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: DentalColors.primary),
              const SizedBox(width: 8),
              Text(
                '基本信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: DentalColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 患者信息卡片 - 包含基本信息和联系信息
          _buildPatientInfoCard(),
          const SizedBox(height: 12),
          
          // 病历信息卡片
          _buildInfoCard(
            '病历信息',
            [
              _buildCompactInfoRow('日期', DateFormat('yyyy-MM-dd').format(record.recordDate)),
              _buildCompactInfoRow('医生', record.doctorName),
              _buildCompactInfoRow('创建', DateFormat('MM-dd HH:mm').format(record.createdAt)),
            ],
            Colors.orange.withOpacity(0.1),
            Colors.orange.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, Color bgColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: children.map((child) => Expanded(child: child)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '患者信息',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          
          // 第一行：姓名、年龄、性别
          Row(
            children: [
              Expanded(child: _buildCompactInfoRow('姓名', patient.name)),
              Expanded(child: _buildCompactInfoRow('年龄', '${patient.age}岁')),
              Expanded(child: _buildCompactInfoRow('性别', patient.gender)),
            ],
          ),
          const SizedBox(height: 8),
          
          // 第二行：电话、病历号、首诊日期
          Row(
            children: [
              Expanded(child: _buildCompactInfoRow('电话', patient.displayPhone())),
              Expanded(child: _buildCompactInfoRow('病历号', patient.medical_record_number?.toString() ?? "无")),
              Expanded(child: _buildCompactInfoRow('首诊', DateFormat('yyyy-MM-dd').format(patient.first_visit_date))),
            ],
          ),
          const SizedBox(height: 8),
          
          // 第三行：身份证号、住址
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildCompactInfoRow('身份证号', patient.identification_number ?? "无"),
              ),
              Expanded(
                flex: 2,
                child: _buildCompactInfoRow('住址', patient.address ?? "无"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThreeColumnInfoRow(List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: items.map((item) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50, // 固定标签宽度，确保对齐
                  child: Text(
                    '${item.$1}:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(
    String title,
    IconData icon,
    String content, {
    bool isWarning = false,
    bool isHighlight = false,
  }) {
    Color backgroundColor = Colors.grey[50]!;
    Color borderColor = Colors.grey[200]!;
    Color iconColor = DentalColors.primary;
    
    if (isWarning) {
      backgroundColor = Colors.orange[50]!;
      borderColor = Colors.orange[200]!;
      iconColor = Colors.orange;
    } else if (isHighlight) {
      backgroundColor = DentalColors.success.withOpacity(0.05);
      borderColor = DentalColors.success.withOpacity(0.2);
      iconColor = DentalColors.success;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _exportToPdf(BuildContext context) async {
    try {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 生成PDF
      final pdfBytes = await medicalRecordProvider.exportMedicalRecordToPdf(
        patient,
        record,
        clinicName: '牙科诊所', // 可以从配置中获取
      );

      // 关闭加载指示器
      Navigator.of(context).pop();

      // 使用file_picker保存文件
      final fileName = '病历_${patient.name}_${record.recordNumber}_${DateFormat('yyyyMMdd').format(record.recordDate)}.pdf';
      
      // 使用file_picker保存文件
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存病历PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (result != null) {
        // 使用公共成功提示组件
        SuccessToastManager.show(
          context, 
          message: 'PDF已保存成功',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // 关闭加载指示器（如果还在显示）
      Navigator.of(context).pop();
      
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('导出PDF失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildMultipleDentalConditionSection(String selectedDatesJson) {
    // 解析多选的牙齿状况日期
    List<String> selectedDates = [];
    try {
      // 尝试解析为JSON数组
      final List<dynamic> dates = jsonDecode(selectedDatesJson);
      selectedDates = dates.map((date) => date.toString()).toList();
    } catch (e) {
      // 如果解析失败，可能是旧的单选格式，直接使用
      selectedDates = [selectedDatesJson];
    }

    if (selectedDates.isEmpty) {
      return const SizedBox.shrink();
    }

    // 解析患者的牙齿状况数据
    Map<String, dynamic> dentalData = {};
    if (patient.dental_condition != null && patient.dental_condition!.isNotEmpty) {
      try {
        dentalData = DentalConditionIntegration.parseDentalCondition(patient.dental_condition!);
      } catch (e) {
        print('解析牙齿状况数据失败: $e');
      }
    }

    List<Widget> dentalWidgets = [];
    
    // 为每个选中的日期构建牙齿状况
    for (int i = 0; i < selectedDates.length; i++) {
      final selectedDate = selectedDates[i];
      final dentalRecord = DentalConditionIntegration.getDentalConditionByDate(dentalData, selectedDate);
      
      if (dentalRecord.isNotEmpty) {
        dentalWidgets.add(_buildSingleDentalConditionSection(selectedDate, dentalRecord, i + 1));
        
        // 如果不是最后一个，添加间距
        if (i < selectedDates.length - 1) {
          dentalWidgets.add(const SizedBox(height: 16));
        }
      } else {
        // 数据不可用的情况
        dentalWidgets.add(
          _buildContentSection(
            '关联牙齿状况 ${i + 1}', 
            Icons.grid_view, 
            '关联日期: $selectedDate（数据不可用）',
            isWarning: true,
          ),
        );
        if (i < selectedDates.length - 1) {
          dentalWidgets.add(const SizedBox(height: 16));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dentalWidgets,
    );
  }

  Widget _buildSingleDentalConditionSection(String selectedDate, Map<String, dynamic> dentalRecord, int index) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域 - 青色背景
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.withOpacity(0.8),
                  Colors.teal.withOpacity(0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '关联牙齿状况 $index',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '关联日期: ${DentalConditionIntegration.formatDateForDisplay(selectedDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // 图表内容区域 - 浅青色背景
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // 第一个牙齿图表
                Expanded(
                  child: _buildCompactCrossChart(
                    '图表1',
                    dentalRecord['chart1-top-left'] ?? '',
                    dentalRecord['chart1-top-right'] ?? '',
                    dentalRecord['chart1-bottom-left'] ?? '',
                    dentalRecord['chart1-bottom-right'] ?? '',
                    dentalRecord['chart1-note'] ?? '',
                  ),
                ),
                const SizedBox(width: 12),
                // 第二个牙齿图表
                Expanded(
                  child: _buildCompactCrossChart(
                    '图表2',
                    dentalRecord['chart2-top-left'] ?? '',
                    dentalRecord['chart2-top-right'] ?? '',
                    dentalRecord['chart2-bottom-left'] ?? '',
                    dentalRecord['chart2-bottom-right'] ?? '',
                    dentalRecord['chart2-note'] ?? '',
                  ),
                ),
                const SizedBox(width: 12),
                // 第三个牙齿图表
                Expanded(
                  child: _buildCompactCrossChart(
                    '图表3',
                    dentalRecord['chart3-top-left'] ?? '',
                    dentalRecord['chart3-top-right'] ?? '',
                    dentalRecord['chart3-bottom-left'] ?? '',
                    dentalRecord['chart3-bottom-right'] ?? '',
                    dentalRecord['chart3-note'] ?? '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDentalConditionSection(String selectedDate) {
    // 解析患者的牙齿状况数据
    Map<String, dynamic> dentalData = {};
    if (patient.dental_condition != null && patient.dental_condition!.isNotEmpty) {
      try {
        dentalData = DentalConditionIntegration.parseDentalCondition(patient.dental_condition!);
      } catch (e) {
        print('解析牙齿状况数据失败: $e');
      }
    }

    // 获取指定日期的牙齿状况记录
    final dentalRecord = DentalConditionIntegration.getDentalConditionByDate(dentalData, selectedDate);
    
    if (dentalRecord.isEmpty) {
      return _buildContentSection(
        '关联牙齿状况', 
        Icons.grid_view, 
        '关联日期: $selectedDate（数据不可用）',
        isWarning: true,
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域 - 青色背景
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.withOpacity(0.8),
                  Colors.teal.withOpacity(0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '关联牙齿状况',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '关联日期: ${DentalConditionIntegration.formatDateForDisplay(selectedDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // 图表内容区域 - 浅青色背景
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // 第一个牙齿图表
                Expanded(
                  child: _buildCompactCrossChart(
                    '图表1',
                    dentalRecord['chart1-top-left'] ?? '',
                    dentalRecord['chart1-top-right'] ?? '',
                    dentalRecord['chart1-bottom-left'] ?? '',
                    dentalRecord['chart1-bottom-right'] ?? '',
                    dentalRecord['chart1-note'] ?? '',
                  ),
                ),
                const SizedBox(width: 12),
                // 第二个牙齿图表
                Expanded(
                  child: _buildCompactCrossChart(
                    '图表2',
                    dentalRecord['chart2-top-left'] ?? '',
                    dentalRecord['chart2-top-right'] ?? '',
                    dentalRecord['chart2-bottom-left'] ?? '',
                    dentalRecord['chart2-bottom-right'] ?? '',
                    dentalRecord['chart2-note'] ?? '',
                  ),
                ),
                const SizedBox(width: 12),
                // 第三个牙齿图表
                Expanded(
                  child: _buildCompactCrossChart(
                    '图表3',
                    dentalRecord['chart3-top-left'] ?? '',
                    dentalRecord['chart3-top-right'] ?? '',
                    dentalRecord['chart3-bottom-left'] ?? '',
                    dentalRecord['chart3-bottom-right'] ?? '',
                    dentalRecord['chart3-note'] ?? '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCrossChart(
    String title,
    String topLeft,
    String topRight,
    String bottomLeft,
    String bottomRight,
    String note,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图表标题
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.teal.shade700,
          ),
        ),
        const SizedBox(height: 8),
        
        // 十字图表
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Stack(
            children: [
              // 十字线 - 横线
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1.5,
                  color: Colors.teal.shade600,
                ),
              ),
              // 十字线 - 竖线
              Center(
                child: Container(
                  width: 1.5,
                  height: 40,
                  color: Colors.teal.shade600,
                ),
              ),

              // 四个象限的文本显示
              Column(
                children: [
                  // 上排 - 左上和右上
                  Expanded(
                    child: Row(
                      children: [
                        // 左上象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 3, top: 12),
                            child: Text(
                              topLeft,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        // 右上象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 3, top: 12),
                            child: Text(
                              topRight,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 3, bottom: 12),
                            child: Text(
                              bottomLeft,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        // 右下象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 3, bottom: 12),
                            child: Text(
                              bottomRight,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
        
        // 备注显示区域
        Container(
          margin: const EdgeInsets.only(top: 4),
          height: 20,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 如果有备注内容就显示
              if (note.isNotEmpty)
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      note,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              // 底部横线
              Container(
                height: 1,
                width: double.infinity,
                color: Colors.teal.shade600,
              ),
            ],
          ),
        ),
      ],
    );
  }
}