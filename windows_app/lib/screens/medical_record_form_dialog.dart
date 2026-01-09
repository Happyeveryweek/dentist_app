import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';
import '../models/medical_template.dart';
import '../providers/medical_record_provider.dart';
import '../providers/user_provider.dart';
import '../services/medical_template_service.dart';
import '../utils/dental_condition_integration.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/success_toast.dart';

/// 病历表单对话框 - 分步骤表单
class MedicalRecordFormDialog extends StatefulWidget {
  final Patient patient;
  final PatientMedicalRecord? medicalRecord; // 编辑模式时传入
  final Future<void> Function(PatientMedicalRecord) onSave;

  const MedicalRecordFormDialog({
    Key? key,
    required this.patient,
    this.medicalRecord,
    required this.onSave,
  }) : super(key: key);

  @override
  State<MedicalRecordFormDialog> createState() => _MedicalRecordFormDialogState();
}

class _MedicalRecordFormDialogState extends State<MedicalRecordFormDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // 表单控制器
  final TextEditingController _recordNumberController = TextEditingController();
  final TextEditingController _chiefComplaintController = TextEditingController();
  final TextEditingController _presentIllnessController = TextEditingController();
  final TextEditingController _pastMedicalHistoryController = TextEditingController();
  final TextEditingController _pastDentalHistoryController = TextEditingController();
  final TextEditingController _allergyHistoryController = TextEditingController();
  final TextEditingController _oralExaminationController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _treatmentPlanController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // 表单数据
  DateTime _recordDate = DateTime.now();
  String _doctorName = '';
  Set<String> _selectedDentalConditionDates = {};
  
  // 疾病选择状态
  Set<String> _selectedSystemicDiseases = {};
  Set<String> _selectedDentalDiseases = {};
  Set<String> _selectedAllergies = {};
  
  // 模板数据缓存
  Map<String, List<String>> _dentalDiseaseOptions = {};
  Map<String, List<String>> _systemicDiseaseOptions = {};
  Map<String, List<String>> _allergyOptions = {};
  bool _templatesLoaded = false;
  
  // 自定义输入
  final TextEditingController _customSystemicDiseaseController = TextEditingController();
  final TextEditingController _customDentalDiseaseController = TextEditingController();
  final TextEditingController _customAllergyController = TextEditingController();

  // 牙齿状况相关
  List<String> _availableDentalConditionDates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeForm();
    _loadDentalConditionDates();
    
    // 每次打开病历表单都强制刷新模板数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplateData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recordNumberController.dispose();
    _chiefComplaintController.dispose();
    _presentIllnessController.dispose();
    _pastMedicalHistoryController.dispose();
    _pastDentalHistoryController.dispose();
    _allergyHistoryController.dispose();
    _oralExaminationController.dispose();
    _diagnosisController.dispose();
    _treatmentPlanController.dispose();
    _notesController.dispose();
    _customSystemicDiseaseController.dispose();
    _customDentalDiseaseController.dispose();
    _customAllergyController.dispose();
    super.dispose();
  }

  /// 检查当前用户是否有权限编辑病历
  bool _hasEditPermission() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') return true;
    
    // 新建病历时，所有医生都有权限
    if (widget.medicalRecord == null) return true;
    
    // 编辑现有病历时，检查是否是自己创建的
    final record = widget.medicalRecord!;
    final createdByDoctor = record.createdByDoctor ?? record.doctorName;
    return createdByDoctor == currentUser.doctor;
  }

  /// 获取病历创建医生信息
  String _getCreatorInfo() {
    if (widget.medicalRecord == null) return '';
    
    final record = widget.medicalRecord!;
    final createdByDoctor = record.createdByDoctor ?? record.doctorName;
    
    if (createdByDoctor.isNotEmpty) {
      return '创建医生：$createdByDoctor';
    }
    
    return '';
  }

  void _initializeForm() {
    // 设置默认医生
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _doctorName = userProvider.currentUser?.doctor ?? userProvider.currentUser?.username ?? '';

    if (widget.medicalRecord != null) {
      // 编辑模式 - 填充现有数据
      final record = widget.medicalRecord!;
      _recordNumberController.text = record.recordNumber;
      _recordDate = record.recordDate;
      _chiefComplaintController.text = record.chiefComplaint;
      _presentIllnessController.text = record.presentIllness;
      _pastMedicalHistoryController.text = record.pastMedicalHistory;
      _pastDentalHistoryController.text = record.pastDentalHistory;
      _allergyHistoryController.text = record.allergyHistory;
      
      // 解析现有的疾病选择（在模板数据加载完成后进行）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _parseExistingDiseaseSelections(record);
      });
      _oralExaminationController.text = record.oralExamination;
      _diagnosisController.text = record.diagnosis;
      _treatmentPlanController.text = record.treatmentPlan;
      _notesController.text = record.notes;
      _doctorName = record.doctorName;
      // 解析多选的牙齿状况日期
      if (record.selectedDentalConditionDate != null && record.selectedDentalConditionDate!.isNotEmpty) {
        try {
          // 尝试解析为JSON数组
          final List<dynamic> dates = jsonDecode(record.selectedDentalConditionDate!);
          _selectedDentalConditionDates = dates.map((date) => date.toString()).toSet();
        } catch (e) {
          // 如果解析失败，可能是旧的单选格式，直接添加
          _selectedDentalConditionDates = {record.selectedDentalConditionDate!};
        }
      }
    } else {
      // 新建模式 - 生成病历编号
      _generateRecordNumber();
    }
    
    // 注意：模板数据的加载移到了initState的postFrameCallback中
  }

  /// 加载模板数据
  Future<void> _loadTemplateData() async {
    try {
      final provider = Provider.of<MedicalRecordProvider>(context, listen: false);
      
      // 清除模板缓存，确保获取最新数据
      provider.clearTemplateCache();
      
      // 并行加载所有类别的模板数据，强制刷新
      final futures = await Future.wait([
        provider.getTemplatesByCategory(MedicalRecordTemplateCategory.dentalDisease, forceRefresh: true),
        provider.getTemplatesByCategory(MedicalRecordTemplateCategory.systemicDisease, forceRefresh: true),
        provider.getTemplatesByCategory(MedicalRecordTemplateCategory.allergy, forceRefresh: true),
      ]);
      
      // 将模板数据转换为疾病选项格式
      final dentalOptions = _convertTemplatesToOptions(futures[0]);
      final systemicOptions = _convertTemplatesToOptions(futures[1]);
      final allergyOptions = _convertTemplatesToOptions(futures[2]);
      
      setState(() {
        _dentalDiseaseOptions = dentalOptions;
        _systemicDiseaseOptions = systemicOptions;
        _allergyOptions = allergyOptions;
        _templatesLoaded = true;
      });
      
      // 如果是编辑模式，解析现有的疾病选择
      if (widget.medicalRecord != null) {
        _parseExistingDiseaseSelections(widget.medicalRecord!);
      }
    } catch (e) {
      print('加载模板数据失败: $e');
      // 如果加载失败，使用空数据，提示用户初始化模板数据
      setState(() {
        _dentalDiseaseOptions = {};
        _systemicDiseaseOptions = {};
        _allergyOptions = {};
        _templatesLoaded = true;
      });
      
      // 显示提示信息
      if (mounted) {
        SuccessToastManager.showError(
          context,
          message: '病历模板数据未初始化，请先在病历管理中初始化模板数据',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _generateRecordNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);
    _recordNumberController.text = 'MR$dateStr$timeStr';
  }

  void _loadDentalConditionDates() {
    try {
      if (widget.patient.dental_condition != null && widget.patient.dental_condition!.isNotEmpty) {
        final dentalData = DentalConditionIntegration.parseDentalCondition(widget.patient.dental_condition!);
        _availableDentalConditionDates = DentalConditionIntegration.getAvailableDates(dentalData);
      }
    } catch (e) {
      print('加载牙齿状况日期失败: $e');
    }
  }

  /// 将模板数据转换为疾病选项格式
  Map<String, List<String>> _convertTemplatesToOptions(List<MedicalRecordTemplate> templates) {
    final Map<String, List<String>> options = {};

    for (final template in templates) {
      if (template.isMainType) {
        // 主疾病类型
        if (!options.containsKey(template.name)) {
          options[template.name] = [];
        }
      } else {
        // 子类型
        final parentName = template.parentName!;
        if (!options.containsKey(parentName)) {
          options[parentName] = [];
        }
        options[parentName]!.add(template.name);
      }
    }

    return options;
  }

  /// 解析现有病历中的疾病选择
  void _parseExistingDiseaseSelections(PatientMedicalRecord record) {
    if (!_templatesLoaded) {
      // 如果模板数据还没加载完成，延迟执行
      Future.delayed(const Duration(milliseconds: 500), () {
        _parseExistingDiseaseSelections(record);
      });
      return;
    }

    // 解析全身疾病既往史
    if (record.pastMedicalHistory.isNotEmpty) {
      final diseases = record.pastMedicalHistory.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final validDiseases = <String>{};
      
      for (final disease in diseases) {
        if (disease.startsWith('其他:')) {
          // 处理自定义疾病
          final customDisease = disease.substring(3).trim();
          _customSystemicDiseaseController.text = customDisease;
        } else {
          // 检查是否在当前模板数据中存在
          if (_isDiseaseInOptions(disease, _systemicDiseaseOptions)) {
            validDiseases.add(disease);
          }
        }
      }
      
      setState(() {
        _selectedSystemicDiseases = validDiseases;
      });
    }

    // 解析口腔疾病既往史
    if (record.pastDentalHistory.isNotEmpty) {
      final diseases = record.pastDentalHistory.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final validDiseases = <String>{};
      
      for (final disease in diseases) {
        if (disease.startsWith('其他:')) {
          // 处理自定义疾病
          final customDisease = disease.substring(3).trim();
          _customDentalDiseaseController.text = customDisease;
        } else {
          // 检查是否在当前模板数据中存在
          if (_isDiseaseInOptions(disease, _dentalDiseaseOptions)) {
            validDiseases.add(disease);
          }
        }
      }
      
      setState(() {
        _selectedDentalDiseases = validDiseases;
      });
    }

    // 解析过敏史
    if (record.allergyHistory.isNotEmpty) {
      final allergies = record.allergyHistory.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final validAllergies = <String>{};
      
      for (final allergy in allergies) {
        if (allergy.startsWith('其他:')) {
          // 处理自定义过敏
          final customAllergy = allergy.substring(3).trim();
          _customAllergyController.text = customAllergy;
        } else {
          // 检查是否在当前模板数据中存在
          if (_isDiseaseInOptions(allergy, _allergyOptions)) {
            validAllergies.add(allergy);
          }
        }
      }
      
      setState(() {
        _selectedAllergies = validAllergies;
      });
    }
  }

  /// 检查疾病是否在选项中存在
  bool _isDiseaseInOptions(String disease, Map<String, List<String>> options) {
    // 检查是否是主类型
    if (options.containsKey(disease)) {
      return true;
    }
    
    // 检查是否是子类型（格式：主类型 - 子类型）
    for (final entry in options.entries) {
      final mainType = entry.key;
      final subTypes = entry.value;
      
      if (disease == mainType) {
        return true;
      }
      
      if (disease.startsWith('$mainType - ')) {
        final subType = disease.substring('$mainType - '.length);
        return subTypes.contains(subType);
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: DentalColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _buildTabBarView(),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DentalColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
              Icons.medical_services_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.medicalRecord == null ? '新建病历' : '编辑病历',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '患者: ${widget.patient.name}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                if (_getCreatorInfo().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getCreatorInfo(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: DentalColors.background,
        border: Border(
          bottom: BorderSide(
            color: DentalColors.divider,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: DentalColors.primary,
        unselectedLabelColor: DentalColors.onSurfaceVariant,
        indicatorColor: DentalColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: '基本信息'),
          Tab(text: '既往史'),
          Tab(text: '牙科检查'),
          Tab(text: '诊断治疗'),
          Tab(text: '注意事项'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return Column(
      children: [
        // 权限警告
        if (!_hasEditPermission() && widget.medicalRecord != null)
          _buildPermissionWarning(),
        
        // 表单内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicInfoStep(),
              _buildMedicalHistoryStep(),
              _buildDentalExaminationStep(),
              _buildDiagnosisTreatmentStep(),
              _buildNotesStep(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '您只能查看此病历记录，无法编辑。只有创建医生和管理员可以编辑病历。',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DentalColors.surface,
        border: Border(
          top: BorderSide(
            color: DentalColors.divider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 上一步按钮
          if (_tabController.index > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _tabController.animateTo(_tabController.index - 1);
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('上一步'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: DentalColors.primary),
                  foregroundColor: DentalColors.primary,
                ),
              ),
            ),
          
          if (_tabController.index > 0) const SizedBox(width: 12),
          
          // 下一步/保存按钮
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : (_tabController.index == 4 && !_hasEditPermission() ? null : _handleNextOrSave),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(_tabController.index == 4 ? Icons.save_rounded : Icons.arrow_forward_rounded),
              label: Text(_tabController.index == 4 ? 
                (_hasEditPermission() ? '保存病历' : '无权限保存') : '下一步'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tabController.index == 4 && !_hasEditPermission() ? 
                  Colors.grey : DentalColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNextOrSave() {
    if (_tabController.index == 4) {
      _saveMedicalRecord();
    } else {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  Future<void> _saveMedicalRecord() async {
    print('_saveMedicalRecord: 开始保存病历');
    print('_saveMedicalRecord: patient.id = ${widget.patient.id}, patient.name = ${widget.patient.name}');
    
    // 验证必填字段
    if (_chiefComplaintController.text.trim().isEmpty) {
      print('_saveMedicalRecord: 主诉不能为空');
      SuccessToastManager.showError(
        context,
        message: '请填写主诉',
        duration: const Duration(seconds: 3),
      );
      _tabController.animateTo(0);
      return;
    }
    
    // 只在基本信息步骤进行表单验证
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      print('_saveMedicalRecord: 表单验证失败');
      // 如果验证失败，跳转到第一个步骤
      _tabController.animateTo(0);
      return;
    }

    // 验证患者ID
    if (widget.patient.id == null || widget.patient.id! <= 0) {
      print('_saveMedicalRecord: 患者ID无效: ${widget.patient.id}');
      SuccessToastManager.showError(
        context,
        message: '患者信息无效，无法保存病历',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final record = PatientMedicalRecord(
        id: widget.medicalRecord?.id,
        patientId: widget.patient.id!,
        recordNumber: _recordNumberController.text,
        recordDate: _recordDate,
        chiefComplaint: _chiefComplaintController.text,
        presentIllness: _presentIllnessController.text,
        pastMedicalHistory: _buildPastMedicalHistoryText(),
        pastDentalHistory: _buildPastDentalHistoryText(),
        allergyHistory: _buildAllergyHistoryText(),
        oralExamination: _oralExaminationController.text,
        diagnosis: _diagnosisController.text,
        treatmentPlan: _treatmentPlanController.text,
        notes: _notesController.text,
        doctorName: _doctorName,
        selectedDentalConditionDate: _selectedDentalConditionDates.isEmpty ? null : jsonEncode(_selectedDentalConditionDates.toList()),
      );

      print('_saveMedicalRecord: 调用onSave回调');
      await widget.onSave(record);
      print('_saveMedicalRecord: onSave回调完成，准备关闭对话框');
      // 注意：不在这里关闭对话框，由onSave回调决定是否关闭
    } catch (e) {
      print('_saveMedicalRecord: 保存失败: $e');
      SuccessToastManager.showError(
        context,
        message: '保存失败: $e',
        duration: const Duration(seconds: 4),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _buildPastMedicalHistoryText() {
    final List<String> items = [];
    items.addAll(_selectedSystemicDiseases);
    if (_customSystemicDiseaseController.text.isNotEmpty) {
      items.add('其他: ${_customSystemicDiseaseController.text}');
    }
    return items.join('; ');
  }

  String _buildPastDentalHistoryText() {
    final List<String> items = [];
    items.addAll(_selectedDentalDiseases);
    if (_customDentalDiseaseController.text.isNotEmpty) {
      items.add('其他: ${_customDentalDiseaseController.text}');
    }
    return items.join('; ');
  }

  String _buildAllergyHistoryText() {
    final List<String> items = [];
    items.addAll(_selectedAllergies);
    if (_customAllergyController.text.isNotEmpty) {
      items.add('其他: ${_customAllergyController.text}');
    }
    return items.join('; ');
  }

  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 步骤标题
            _buildStepHeader(
              '基本信息',
              '请填写病历的基本信息',
              Icons.info_outline_rounded,
            ),
            const SizedBox(height: 24),

            // 患者信息模块（包含电话、病历号、首诊日期）
            _buildPatientInfoSection(),
            const SizedBox(height: 20),

            // 病历信息（病历编号、日期、医生）
            _buildMedicalRecordInfoSection(),
            const SizedBox(height: 20),

            // 主诉
            _buildInputField(
              controller: _chiefComplaintController,
              label: '主诉',
              hint: '患者主要症状和就诊原因',
              icon: Icons.record_voice_over_rounded,
              maxLines: 3,
              enabled: _hasEditPermission(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入主诉';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 现病史
            _buildInputField(
              controller: _presentIllnessController,
              label: '现病史',
              hint: '患者当前疾病的发生、发展过程',
              enabled: _hasEditPermission(),
              icon: Icons.history_rounded,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入现病史';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),
            
            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DentalColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DentalColors.info.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: DentalColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '主诉应简明扼要，现病史需详细描述症状的时间、性质、程度等',
                      style: TextStyle(
                        color: DentalColors.info,
                        fontSize: 14,
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

  Widget _buildMedicalHistoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤标题
          _buildStepHeader(
            '既往史和过敏史',
            '请选择患者的疾病史和过敏史',
            Icons.history_edu_rounded,
          ),
          const SizedBox(height: 24),

          // 全身疾病既往史
          _templatesLoaded
              ? _buildDiseaseSelectionSection(
                  title: '全身疾病既往史',
                  icon: Icons.health_and_safety_rounded,
                  diseases: _systemicDiseaseOptions,
                  selectedDiseases: _selectedSystemicDiseases,
                  customController: _customSystemicDiseaseController,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedSystemicDiseases = selected;
                    });
                  },
                )
              : const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 32),

          // 口腔疾病既往史
          _templatesLoaded
              ? _buildDiseaseSelectionSection(
                  title: '口腔疾病既往史',
                  icon: Icons.medical_services_rounded,
                  diseases: _dentalDiseaseOptions,
                  selectedDiseases: _selectedDentalDiseases,
                  customController: _customDentalDiseaseController,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedDentalDiseases = selected;
                    });
                  },
                )
              : const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 32),

          // 过敏史
          _buildAllergySection(),
          const SizedBox(height: 32),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DentalColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.warning.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: DentalColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请仔细询问患者的疾病史和过敏史，这对制定治疗方案非常重要',
                    style: TextStyle(
                      color: DentalColors.warning,
                      fontSize: 14,
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

  Widget _buildDentalExaminationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤标题
          _buildStepHeader(
            '牙科专业检查',
            '记录口腔检查结果和牙科疾病',
            Icons.medical_services_rounded,
          ),
          const SizedBox(height: 24),

          // 牙科疾病选择
          _buildCurrentDentalDiseasesSection(),
          const SizedBox(height: 32),

          // 口腔检查记录
          _buildInputField(
            controller: _oralExaminationController,
            label: '口腔检查记录',
            enabled: _hasEditPermission(),
            hint: '详细记录口腔检查发现的问题',
            icon: Icons.visibility_rounded,
            maxLines: 5,
          ),
          const SizedBox(height: 24),

          // 牙齿状况关联
          _buildDentalConditionSelector(),
          const SizedBox(height: 32),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DentalColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.info.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DentalColors.info,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请根据实际检查情况选择相应的牙科疾病，并详细记录检查发现',
                    style: TextStyle(
                      color: DentalColors.info,
                      fontSize: 14,
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

  Widget _buildDiagnosisTreatmentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤标题
          _buildStepHeader(
            '诊断和治疗',
            '记录诊断结论和治疗方案',
            Icons.assignment_rounded,
          ),
          const SizedBox(height: 24),

          // 诊断结论
          _buildInputField(
            controller: _diagnosisController,
            label: '诊断结论',
            enabled: _hasEditPermission(),
            hint: '根据检查结果给出明确的诊断',
            icon: Icons.assignment_turned_in_rounded,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入诊断结论';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // 治疗方案
          _buildInputField(
            controller: _treatmentPlanController,
            label: '治疗方案',
            enabled: _hasEditPermission(),
            hint: '详细描述治疗计划和步骤',
            icon: Icons.healing_rounded,
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入治疗方案';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // 治疗方案建议模板
          _buildTreatmentTemplates(),
          const SizedBox(height: 32),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DentalColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.success.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: DentalColors.success,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '诊断应准确明确，治疗方案应具体可行，便于后续治疗执行',
                    style: TextStyle(
                      color: DentalColors.success,
                      fontSize: 14,
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

  Widget _buildNotesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤标题
          _buildStepHeader(
            '注意事项和医嘱',
            '记录特殊注意事项和医嘱',
            Icons.note_add_rounded,
          ),
          const SizedBox(height: 24),

          // 注意事项
          _buildInputField(
            controller: _notesController,
            label: '注意事项和医嘱',
            enabled: _hasEditPermission(),
            hint: '记录患者需要注意的事项、用药指导、复诊安排等',
            icon: Icons.note_rounded,
            maxLines: 6,
          ),
          const SizedBox(height: 24),

          // 常用医嘱模板
          _buildNotesTemplates(),
          const SizedBox(height: 32),

          // 病历摘要
          _buildRecordSummary(),
          const SizedBox(height: 32),

          // 最终提示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DentalColors.primary.withOpacity(0.1),
                  DentalColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.save_rounded,
                  color: DentalColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请检查所有信息是否准确完整，确认无误后点击保存病历',
                    style: TextStyle(
                      color: DentalColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  // 辅助方法
  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: DentalColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: DentalColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: DentalColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? DentalColors.background : DentalColors.background.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.divider,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DentalColors.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: DentalColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _hasEditPermission() ? () async {
            final date = await showDialog<DateTime>(
              context: context,
              builder: (context) => ModernDatePickerDialog(
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              ),
            );
            if (date != null) {
              onChanged(date);
            }
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: DentalColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.divider,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('yyyy年MM月dd日').format(value),
                    style: const TextStyle(
                      fontSize: 16,
                      color: DentalColors.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: DentalColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseSelectionSection({
    required String title,
    required IconData icon,
    required Map<String, List<String>> diseases,
    required Set<String> selectedDiseases,
    required TextEditingController customController,
    required Function(Set<String>) onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 疾病类型网格
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DentalColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.divider,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // 疾病类型选择
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: diseases.keys.map((diseaseType) {
                  final isSelected = selectedDiseases.any((selected) => 
                      selected.startsWith(diseaseType));
                  
                  return FilterChip(
                    label: Text(diseaseType),
                    selected: isSelected,
                    onSelected: _hasEditPermission() ? (selected) {
                      final newSelected = Set<String>.from(selectedDiseases);
                      if (selected) {
                        newSelected.add(diseaseType);
                      } else {
                        newSelected.removeWhere((item) => item.startsWith(diseaseType));
                      }
                      onSelectionChanged(newSelected);
                    } : null,
                    backgroundColor: _hasEditPermission() ? DentalColors.surface : Colors.grey.shade200,
                    selectedColor: DentalColors.primary.withOpacity(0.2),
                    checkmarkColor: DentalColors.primary,
                    labelStyle: TextStyle(
                      color: _hasEditPermission() ? 
                        (isSelected ? DentalColors.primary : DentalColors.onSurface) : 
                        Colors.grey,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),

              // 显示选中疾病类型的子类型
              ...diseases.entries.where((entry) => 
                  selectedDiseases.any((selected) => selected.startsWith(entry.key))
              ).map((entry) => _buildSubTypeSelection(
                entry.key,
                entry.value,
                selectedDiseases,
                onSelectionChanged,
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 其他疾病输入框
        _buildInputField(
          controller: customController,
          label: '其他${title.replaceAll('既往史', '')}',
          enabled: _hasEditPermission(),
          hint: '请输入其他疾病情况',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSubTypeSelection(
    String diseaseType,
    List<String> subTypes,
    Set<String> selectedDiseases,
    Function(Set<String>) onSelectionChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DentalColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$diseaseType 详细类型:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: DentalColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subTypes.map((subType) {
              final fullType = '$diseaseType - $subType';
              final isSelected = selectedDiseases.contains(fullType);
              
              return FilterChip(
                label: Text(subType),
                selected: isSelected,
                onSelected: _hasEditPermission() ? (selected) {
                  final newSelected = Set<String>.from(selectedDiseases);
                  if (selected) {
                    newSelected.add(fullType);
                  } else {
                    newSelected.remove(fullType);
                  }
                  onSelectionChanged(newSelected);
                } : null,
                backgroundColor: _hasEditPermission() ? DentalColors.surface : Colors.grey.shade200,
                selectedColor: DentalColors.primary.withOpacity(0.3),
                checkmarkColor: DentalColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? DentalColors.primary : DentalColors.onSurface,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_rounded,
              size: 18,
              color: DentalColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              '过敏史',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DentalColors.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // 过敏类型选择
              _templatesLoaded
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allergyOptions.keys.map((allergyType) {
                        final isSelected = _selectedAllergies.any((selected) => 
                            selected.startsWith(allergyType));
                        
                        return FilterChip(
                          label: Text(allergyType),
                          selected: isSelected,
                          onSelected: _hasEditPermission() ? (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAllergies.add(allergyType);
                              } else {
                                _selectedAllergies.removeWhere((item) => item.startsWith(allergyType));
                              }
                            });
                          } : null,
                          backgroundColor: _hasEditPermission() ? DentalColors.surface : Colors.grey.shade200,
                          selectedColor: DentalColors.error.withOpacity(0.2),
                          checkmarkColor: DentalColors.error,
                          labelStyle: TextStyle(
                            color: _hasEditPermission() ? 
                              (isSelected ? DentalColors.error : DentalColors.onSurface) : 
                              Colors.grey,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    )
                  : const CircularProgressIndicator(),

              // 显示选中过敏类型的具体项目
              if (_templatesLoaded)
                ..._allergyOptions.entries.where((entry) => 
                    _selectedAllergies.any((selected) => selected.startsWith(entry.key))
                ).map((entry) => _buildAllergySubTypeSelection(entry.key, entry.value)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 其他过敏输入框
        _buildInputField(
          controller: _customAllergyController,
          label: '其他过敏',
          enabled: _hasEditPermission(),
          hint: '请输入其他过敏情况',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildAllergySubTypeSelection(String allergyType, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DentalColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$allergyType 具体项目:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: DentalColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              final fullType = '$allergyType - $item';
              final isSelected = _selectedAllergies.contains(fullType);
              
              return FilterChip(
                label: Text(item),
                selected: isSelected,
                onSelected: _hasEditPermission() ? (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAllergies.add(fullType);
                    } else {
                      _selectedAllergies.remove(fullType);
                    }
                  });
                } : null,
                backgroundColor: _hasEditPermission() ? DentalColors.surface : Colors.grey.shade200,
                selectedColor: DentalColors.error.withOpacity(0.3),
                checkmarkColor: DentalColors.error,
                labelStyle: TextStyle(
                  color: _hasEditPermission() ? 
                    (isSelected ? DentalColors.error : DentalColors.onSurface) : 
                    Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDentalDiseasesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.medical_services_rounded,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '当前牙科疾病',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DentalColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.divider,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // 疾病类型选择
              _templatesLoaded
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dentalDiseaseOptions.keys.map((diseaseType) {
                        final isSelected = _selectedDentalDiseases.any((selected) => 
                            selected.startsWith(diseaseType));
                        
                        return FilterChip(
                          label: Text(diseaseType),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDentalDiseases.add(diseaseType);
                              } else {
                                _selectedDentalDiseases.removeWhere((item) => item.startsWith(diseaseType));
                              }
                            });
                          },
                          backgroundColor: DentalColors.surface,
                          selectedColor: DentalColors.primary.withOpacity(0.2),
                          checkmarkColor: DentalColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? DentalColors.primary : DentalColors.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    )
                  : const CircularProgressIndicator(),

              // 显示选中疾病类型的子类型
              if (_templatesLoaded)
                ..._dentalDiseaseOptions.entries.where((entry) => 
                    _selectedDentalDiseases.any((selected) => selected.startsWith(entry.key))
                ).map((entry) => _buildCurrentDentalSubTypeSelection(entry.key, entry.value)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 其他牙科疾病输入框
        _buildInputField(
          controller: _customDentalDiseaseController,
          label: '其他牙科疾病',
          enabled: _hasEditPermission(),
          hint: '请输入其他牙科疾病情况',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildCurrentDentalSubTypeSelection(String diseaseType, List<String> subTypes) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DentalColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$diseaseType 详细类型:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: DentalColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subTypes.map((subType) {
              final fullType = '$diseaseType - $subType';
              final isSelected = _selectedDentalDiseases.contains(fullType);
              
              return FilterChip(
                label: Text(subType),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDentalDiseases.add(fullType);
                    } else {
                      _selectedDentalDiseases.remove(fullType);
                    }
                  });
                },
                backgroundColor: DentalColors.surface,
                selectedColor: DentalColors.primary.withOpacity(0.3),
                checkmarkColor: DentalColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? DentalColors.primary : DentalColors.onSurface,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDentalConditionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: DentalColors.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              '关联牙齿状况',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '选择与此病历相关的牙齿状况记录日期',
          style: TextStyle(
            fontSize: 14,
            color: DentalColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DentalColors.secondary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.secondary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // 无关联选项
              CheckboxListTile(
                title: const Text('无关联牙齿状况'),
                value: _selectedDentalConditionDates.isEmpty,
                onChanged: _hasEditPermission() ? (value) {
                  setState(() {
                    if (value == true) {
                      _selectedDentalConditionDates.clear();
                    }
                  });
                } : null,
                activeColor: DentalColors.secondary,
                contentPadding: EdgeInsets.zero,
              ),

              // 可用日期选项
              if (_availableDentalConditionDates.isNotEmpty) ...[
                const Divider(),
                ..._availableDentalConditionDates.map((date) => CheckboxListTile(
                  title: Text('牙齿状况记录 - $date'),
                  value: _selectedDentalConditionDates.contains(date),
                  onChanged: _hasEditPermission() ? (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDentalConditionDates.add(date);
                      } else {
                        _selectedDentalConditionDates.remove(date);
                      }
                    });
                  } : null,
                  activeColor: DentalColors.secondary,
                  contentPadding: EdgeInsets.zero,
                )),
              ] else ...[
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DentalColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: DentalColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '该患者暂无牙齿状况记录',
                          style: TextStyle(
                            color: DentalColors.warning,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentTemplates() {
    return FutureBuilder<List<MedicalTemplate>>(
      future: MedicalTemplateService.getTreatmentTemplates(),
      builder: (context, snapshot) {
        final treatmentTemplates = snapshot.data ?? [];
        
        // 如果没有加载到模板，使用默认模板
        if (treatmentTemplates.isEmpty) {
          final defaultTemplates = [
            {'title': '洁牙治疗', 'content': '1. 超声波洁牙\n2. 抛光处理\n3. 氟化物涂布\n4. 口腔卫生指导'},
            {'title': '充填治疗', 'content': '1. 局部麻醉\n2. 去除龋坏组织\n3. 窝洞预备\n4. 充填材料填充\n5. 形态调整和抛光'},
            {'title': '根管治疗', 'content': '1. 开髓引流\n2. 根管预备\n3. 根管消毒\n4. 根管充填\n5. 冠部修复'},
            {'title': '牙周治疗', 'content': '1. 龈上洁治\n2. 龈下刮治\n3. 根面平整\n4. 局部药物治疗\n5. 维护期治疗'},
            {'title': '拔牙术', 'content': '1. 术前检查\n2. 局部麻醉\n3. 牙齿拔除\n4. 创口处理\n5. 术后护理指导'},
          ];
          
          return _buildTemplateSection(
            title: '常用治疗方案模板',
            icon: Icons.library_books_rounded,
            color: DentalColors.secondary,
            hint: '点击下方模板快速填入治疗方案',
            templates: defaultTemplates,
            onTemplateSelected: (content) {
              _treatmentPlanController.text = content;
            },
          );
        }

        return _buildTemplateSection(
          title: '常用治疗方案模板',
          icon: Icons.library_books_rounded,
          color: DentalColors.secondary,
          hint: '点击下方模板快速填入治疗方案',
          templates: treatmentTemplates.map((t) => {'title': t.title, 'content': t.content}).toList(),
          onTemplateSelected: (content) {
            _treatmentPlanController.text = content;
          },
        );
      },
    );
  }

  Widget _buildNotesTemplates() {
    return FutureBuilder<List<MedicalTemplate>>(
      future: MedicalTemplateService.getNotesTemplates(),
      builder: (context, snapshot) {
        final notesTemplates = snapshot.data ?? [];
        
        // 如果没有加载到模板，使用默认模板
        if (notesTemplates.isEmpty) {
          final defaultTemplates = [
            {'title': '术后护理', 'content': '1. 术后2小时内禁食\n2. 24小时内避免刷牙漱口\n3. 避免用患侧咀嚼\n4. 如有异常及时复诊'},
            {'title': '用药指导', 'content': '1. 按时服用抗生素\n2. 疼痛时可服用止痛药\n3. 注意药物过敏反应\n4. 完成整个疗程'},
            {'title': '口腔卫生', 'content': '1. 早晚刷牙，饭后漱口\n2. 使用软毛牙刷\n3. 配合使用牙线\n4. 定期口腔检查'},
            {'title': '复诊安排', 'content': '1. 一周后复查\n2. 观察愈合情况\n3. 必要时调整治疗方案\n4. 长期随访观察'},
            {'title': '饮食建议', 'content': '1. 避免过硬食物\n2. 减少甜食摄入\n3. 多吃富含维生素食物\n4. 充足饮水'},
          ];
          
          return _buildTemplateSection(
            title: '常用医嘱模板',
            icon: Icons.note_add_rounded,
            color: DentalColors.info,
            hint: '点击下方模板快速填入注意事项',
            templates: defaultTemplates,
            onTemplateSelected: (content) {
              final currentText = _notesController.text;
              final newText = currentText.isEmpty 
                  ? content
                  : '$currentText\n\n$content';
              _notesController.text = newText;
            },
          );
        }

        return _buildTemplateSection(
          title: '常用医嘱模板',
          icon: Icons.note_add_rounded,
          color: DentalColors.info,
          hint: '点击下方模板快速填入注意事项',
          templates: notesTemplates.map((t) => {'title': t.title, 'content': t.content}).toList(),
          onTemplateSelected: (content) {
            final currentText = _notesController.text;
            final newText = currentText.isEmpty 
                ? content
                : '$currentText\n\n$content';
            _notesController.text = newText;
          },
        );
      },
    );
  }

  Widget _buildRecordSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.summarize_rounded,
              size: 16,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '病历摘要',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DentalColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryItem('患者姓名', widget.patient.name),
              _buildSummaryItem('病历编号', _recordNumberController.text),
              _buildSummaryItem('病历日期', DateFormat('yyyy年MM月dd日').format(_recordDate)),
              _buildSummaryItem('主治医生', _doctorName),
              if (_chiefComplaintController.text.isNotEmpty)
                _buildSummaryItem('主诉', _chiefComplaintController.text),
              if (_diagnosisController.text.isNotEmpty)
                _buildSummaryItem('诊断', _diagnosisController.text),
              if (_selectedDentalConditionDates.isNotEmpty)
                _buildSummaryItem('关联牙齿状况', _selectedDentalConditionDates.join(', ')),
              if (_selectedSystemicDiseases.isNotEmpty)
                _buildSummaryItem('全身疾病既往史', _selectedSystemicDiseases.join(', ')),
              if (_selectedDentalDiseases.isNotEmpty)
                _buildSummaryItem('口腔疾病既往史', _selectedDentalDiseases.join(', ')),
              if (_selectedAllergies.isNotEmpty)
                _buildSummaryItem('过敏史', _selectedAllergies.join(', ')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DentalColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: DentalColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 患者信息模块
  Widget _buildPatientInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DentalColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DentalColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 18,
                color: DentalColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '患者信息',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: DentalColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 第一行：姓名、年龄、性别
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('姓名', widget.patient.name),
              ),
              Expanded(
                child: _buildInfoItem('年龄', '${widget.patient.age}岁'),
              ),
              Expanded(
                child: _buildInfoItem('性别', widget.patient.gender),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 第二行：电话、病历号、首诊日期
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('电话', widget.patient.displayPhone()),
              ),
              Expanded(
                child: _buildInfoItem('病历号', widget.patient.medical_record_number?.toString() ?? '无'),
              ),
              Expanded(
                child: _buildInfoItem('首诊', DateFormat('yyyy-MM-dd').format(widget.patient.first_visit_date)),
              ),
            ],
          ),
          
          // 身份证号（如果有）
          if (widget.patient.identification_number != null) ...[
            const SizedBox(height: 12),
            _buildInfoItem('身份证号', widget.patient.identification_number!.toString()),
          ],
        ],
      ),
    );
  }

  // 病历信息模块
  Widget _buildMedicalRecordInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.medical_services_rounded,
              size: 18,
              color: DentalColors.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              '病历信息',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 病历编号和日期
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _recordNumberController,
                label: '病历编号',
                enabled: _hasEditPermission(),
                hint: '自动生成',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入病历编号';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: '病历日期',
                value: _recordDate,
                onChanged: (date) {
                  setState(() {
                    _recordDate = date;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 医生信息
        _buildInputField(
          controller: TextEditingController(text: _doctorName),
          label: '医生',
          hint: '主治医生姓名',
          icon: Icons.medical_services_rounded,
          enabled: false,
        ),
      ],
    );
  }

  // 信息项显示组件
  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DentalColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: DentalColors.onSurface,
          ),
        ),
      ],
    );
  }

  // 通用模板区域构建方法
  Widget _buildTemplateSection({
    required String title,
    required IconData icon,
    required Color color,
    required String hint,
    required List<Map<String, String>> templates,
    required Function(String) onTemplateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                hint,
                style: TextStyle(
                  fontSize: 14,
                  color: DentalColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: templates.map((template) {
                  return OutlinedButton(
                    onPressed: () {
                      onTemplateSelected(template['content']!);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color),
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      template['title']!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}