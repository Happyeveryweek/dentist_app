import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/patient.dart';
import '../../../models/patient_medical_record.dart';
import '../../../models/medical_record_template.dart';
import '../../../providers/medical_record_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/medical_template_service.dart';
import '../../../utils/dental_condition_integration.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/success_toast.dart';
import './medical_record_form_input_field.dart';
import './medical_record_form_date_field.dart';
import './medical_record_info_item.dart';
import './medical_record_summary_item.dart';
import './medical_record_step_header.dart';
import './disease_selection_widget.dart';
import './allergy_selection_widget.dart';
import './dental_disease_selection_widget.dart';
import './template_selection_widget.dart';
import './info_display_widgets.dart';
import '../../../utils/log_manager.dart';

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
  State<MedicalRecordFormDialog> createState() =>
      _MedicalRecordFormDialogState();
}

class _MedicalRecordFormDialogState extends State<MedicalRecordFormDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // 表单控制器
  final TextEditingController _recordNumberController = TextEditingController();
  final TextEditingController _chiefComplaintController =
      TextEditingController();
  final TextEditingController _presentIllnessController =
      TextEditingController();
  final TextEditingController _pastMedicalHistoryController =
      TextEditingController();
  final TextEditingController _pastDentalHistoryController =
      TextEditingController();
  final TextEditingController _allergyHistoryController =
      TextEditingController();
  final TextEditingController _oralExaminationController =
      TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _treatmentPlanController =
      TextEditingController();
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
  final TextEditingController _customSystemicDiseaseController =
      TextEditingController();
  final TextEditingController _customDentalDiseaseController =
      TextEditingController();
  final TextEditingController _customAllergyController =
      TextEditingController();

  // 牙齿状况相关
  List<String> _availableDentalConditionDates = [];

  // 模板选中状态追踪
  final Set<String> _selectedTreatmentTemplates = {};
  final Set<String> _selectedNotesTemplates = {};

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
    final medicalRecord = widget.medicalRecord;
    if (medicalRecord == null) return true;

    // 编辑现有病历时，检查是否是自己创建的
    final createdByDoctor = medicalRecord.createdByDoctor ?? medicalRecord.doctorName;
    return createdByDoctor == currentUser.doctor;
  }

  /// 获取病历创建医生信息
  String _getCreatorInfo() {
    final medicalRecord = widget.medicalRecord;
    if (medicalRecord == null) return '';

    final createdByDoctor = medicalRecord.createdByDoctor ?? medicalRecord.doctorName;

    if (createdByDoctor.isNotEmpty) {
      return '创建医生：$createdByDoctor';
    }

    return '';
  }

  void _initializeForm() {
    // 设置默认医生
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _doctorName = userProvider.currentUser?.doctor ??
        userProvider.currentUser?.username ??
        '';

    final medicalRecord = widget.medicalRecord;
    if (medicalRecord != null) {
      // 编辑模式 - 填充现有数据
      _recordNumberController.text = medicalRecord.recordNumber;
      _recordDate = medicalRecord.recordDate;
      _chiefComplaintController.text = medicalRecord.chiefComplaint;
      _presentIllnessController.text = medicalRecord.presentIllness;
      _pastMedicalHistoryController.text = medicalRecord.pastMedicalHistory;
      _pastDentalHistoryController.text = medicalRecord.pastDentalHistory;
      _allergyHistoryController.text = medicalRecord.allergyHistory;

      // 解析现有的疾病选择（在模板数据加载完成后进行）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _parseExistingDiseaseSelections(medicalRecord);
        _restoreTemplateSelections(medicalRecord);
      });
      _oralExaminationController.text = medicalRecord.oralExamination;
      _diagnosisController.text = medicalRecord.diagnosis;
      _treatmentPlanController.text = medicalRecord.treatmentPlan;
      _notesController.text = medicalRecord.notes;
      _doctorName = medicalRecord.doctorName;
      // 解析多选的牙齿状况日期
      final selectedDentalConditionDate =
          medicalRecord.selectedDentalConditionDate;
      if (selectedDentalConditionDate != null &&
          selectedDentalConditionDate.isNotEmpty) {
        try {
          // 尝试解析为JSON数组
          final List<dynamic> dates = jsonDecode(selectedDentalConditionDate);
          _selectedDentalConditionDates =
              dates.map((date) => date.toString()).toSet();
        } catch (e) {
          // 如果解析失败，可能是旧的单选格式，直接添加
          _selectedDentalConditionDates = {selectedDentalConditionDate};
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
      final provider =
          Provider.of<MedicalRecordProvider>(context, listen: false);

      // 清除模板缓存，确保获取最新数据
      provider.clearTemplateCache();

      // 并行加载所有类别的模板数据，强制刷新
      final futures = await Future.wait([
        provider.getTemplatesByCategory(
            MedicalRecordTemplateCategory.dentalDisease,
            forceRefresh: true),
        provider.getTemplatesByCategory(
            MedicalRecordTemplateCategory.systemicDisease,
            forceRefresh: true),
        provider.getTemplatesByCategory(MedicalRecordTemplateCategory.allergy,
            forceRefresh: true),
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
      final medicalRecord = widget.medicalRecord;
      if (medicalRecord != null) {
        _parseExistingDiseaseSelections(medicalRecord);
      }
    } catch (e) {
      LogManager.e('MedicalRecordFormDialog', '加载模板数据失败', error: e);
      // 如果加载失败，使用空数据，提示用户初始化模板数据
      setState(() {
        _dentalDiseaseOptions = {};
        _systemicDiseaseOptions = {};
        _allergyOptions = {};
        _templatesLoaded = true;
      });

      // 显示提示信息
      if (mounted) {
        AppToastManager.showError(
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
      final dentalCondition = widget.patient.dentalCondition;
      if (dentalCondition != null && dentalCondition.isNotEmpty) {
        final dentalData = DentalConditionIntegration.parseDentalCondition(
            dentalCondition);
        _availableDentalConditionDates =
            DentalConditionIntegration.getAvailableDates(dentalData);
      }
    } catch (e) {
      LogManager.e('MedicalRecordFormDialog', '加载牙齿状况日期失败', error: e);
    }
  }

  /// 将模板数据转换为疾病选项格式
  Map<String, List<String>> _convertTemplatesToOptions(
      List<MedicalRecordTemplate> templates) {
    final Map<String, List<String>> options = {};

    for (final template in templates) {
      if (template.isMainType) {
        // 主疾病类型
        if (!options.containsKey(template.name)) {
          options[template.name] = [];
        }
      } else {
        // 子类型
        final parentName = template.parentName;
        if (parentName == null) continue;
        if (!options.containsKey(parentName)) {
          options[parentName] = [];
        }
        options[parentName]?.add(template.name);
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
      final diseases = record.pastMedicalHistory
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
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
      final diseases = record.pastDentalHistory
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
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
      final allergies = record.allergyHistory
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
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

  /// 恢复模板选中状态（编辑模式）
  Future<void> _restoreTemplateSelections(PatientMedicalRecord record) async {
    // 获取治疗方案模板
    final treatmentTemplates =
        await MedicalTemplateService.getTreatmentTemplates();
    final defaultTreatmentTemplates = [
      {'title': '洁牙治疗', 'content': '1. 超声波洁牙\n2. 抛光处理\n3. 氟化物涂布\n4. 口腔卫生指导'},
      {
        'title': '充填治疗',
        'content': '1. 局部麻醉\n2. 去除龋坏组织\n3. 窝洞预备\n4. 充填材料填充\n5. 形态调整和抛光'
      },
      {
        'title': '根管治疗',
        'content': '1. 开髓引流\n2. 根管预备\n3. 根管消毒\n4. 根管充填\n5. 冠部修复'
      },
      {
        'title': '牙周治疗',
        'content': '1. 龈上洁治\n2. 龈下刮治\n3. 根面平整\n4. 局部药物治疗\n5. 维护期治疗'
      },
      {
        'title': '拔牙术',
        'content': '1. 术前检查\n2. 局部麻醉\n3. 牙齿拔除\n4. 创口处理\n5. 术后护理指导'
      },
    ];

    final treatmentList = treatmentTemplates.isEmpty
        ? defaultTreatmentTemplates
        : treatmentTemplates
            .map((t) => {'title': t.title, 'content': t.content})
            .toList();

    // 比对治疗方案内容，恢复选中状态
    final treatmentPlan = record.treatmentPlan.trim();
    if (treatmentPlan.isNotEmpty) {
      for (final template in treatmentList) {
        final templateContent = template['content'];
        final templateTitle = template['title'];
        if (templateContent != null &&
            templateContent.trim() == treatmentPlan &&
            templateTitle != null) {
          setState(() {
            _selectedTreatmentTemplates.add(templateTitle);
          });
          break;
        }
      }
    }

    // 获取注意事项模板
    final notesTemplates = await MedicalTemplateService.getNotesTemplates();
    final defaultNotesTemplates = [
      {
        'title': '术后护理',
        'content': '1. 术后2小时内禁食\n2. 24小时内避免刷牙漱口\n3. 避免用患侧咀嚼\n4. 如有异常及时复诊'
      },
      {
        'title': '用药指导',
        'content': '1. 按时服用抗生素\n2. 疼痛时可服用止痛药\n3. 注意药物过敏反应\n4. 完成整个疗程'
      },
      {
        'title': '口腔卫生',
        'content': '1. 早晚刷牙，饭后漱口\n2. 使用软毛牙刷\n3. 配合使用牙线\n4. 定期口腔检查'
      },
      {
        'title': '复诊安排',
        'content': '1. 一周后复查\n2. 观察愈合情况\n3. 必要时调整治疗方案\n4. 长期随访观察'
      },
      {
        'title': '饮食建议',
        'content': '1. 避免过硬食物\n2. 减少甜食摄入\n3. 多吃富含维生素食物\n4. 充足饮水'
      },
    ];

    final notesList = notesTemplates.isEmpty
        ? defaultNotesTemplates
        : notesTemplates
            .map((t) => {'title': t.title, 'content': t.content})
            .toList();

    // 比对注意事项内容，恢复选中状态
    final notes = record.notes.trim();
    if (notes.isNotEmpty) {
      final noteSections = notes.split('\n\n');
      for (final template in notesList) {
        final templateContent = template['content'];
        final templateTitle = template['title'];
        if (templateContent == null || templateTitle == null) continue;
        // 检查是否包含该模板内容
        if (noteSections.any((section) => section.trim() == templateContent.trim())) {
          setState(() {
            _selectedNotesTemplates.add(templateTitle);
          });
        }
      }
    }
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
              color: Colors.black.withValues(alpha: 0.1),
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

  void _handleNextOrSave() {
    if (_tabController.index == 4) {
      _saveMedicalRecord();
    } else {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  Future<void> _saveMedicalRecord() async {
    // 显式校验所有必填字段，避免跨 Tab 切换后 FormState 不可靠导致误判
    String? errorMessage;
    int? errorTabIndex;

    if (_recordNumberController.text.trim().isEmpty) {
      errorMessage = '请输入病历编号';
      errorTabIndex = 0;
    } else if (_chiefComplaintController.text.trim().isEmpty) {
      errorMessage = '请输入主诉';
      errorTabIndex = 0;
    } else if (_presentIllnessController.text.trim().isEmpty) {
      errorMessage = '请输入现病史';
      errorTabIndex = 0;
    } else if (_diagnosisController.text.trim().isEmpty) {
      errorMessage = '请输入诊断结论';
      errorTabIndex = 3;
    } else if (_treatmentPlanController.text.trim().isEmpty) {
      errorMessage = '请输入治疗方案';
      errorTabIndex = 3;
    }

    if (errorMessage != null) {
      LogManager.e('MedicalRecordFormDialog',
          '_saveMedicalRecord: 表单验证失败 - $errorMessage');
      AppToastManager.showError(
        context,
        message: errorMessage,
        duration: const Duration(seconds: 3),
      );
      _tabController.animateTo(errorTabIndex ?? 0);
      return;
    }

    // 验证患者ID
    final patientId = widget.patient.id;
    if (patientId == null || patientId <= 0) {
      AppToastManager.showError(
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
        patientId: patientId,
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
        selectedDentalConditionDate: _selectedDentalConditionDates.isEmpty
            ? null
            : jsonEncode(_selectedDentalConditionDates.toList()),
      );

      await widget.onSave(record);

      // 注意：不在这里关闭对话框，由onSave回调决定是否关闭
    } catch (e) {
      LogManager.e('MedicalRecordFormDialog', '_saveMedicalRecord: 保存失败',
          error: e);
      if (!mounted) return;
      AppToastManager.showError(
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

  // 辅助方法

  /// 构建输入字段
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return MedicalRecordFormInputField(
      controller: controller,
      label: label,
      hint: hint,
      icon: icon,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
    );
  }

  /// 构建日期字段
  Widget _buildDateField({
    required String label,
    required DateTime value,
    required Function(DateTime) onChanged,
  }) {
    return MedicalRecordFormDateField(
      label: label,
      value: value,
      onChanged: onChanged,
      enabled: _hasEditPermission(),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return MedicalRecordInfoItem(
      label: label,
      value: value,
    );
  }

  /// 构建摘要项
  Widget _buildSummaryItem(String label, String value) {
    return MedicalRecordSummaryItem(
      label: label,
      value: value,
    );
  }

  /// 构建步骤头部
  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    return MedicalRecordStepHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
    );
  }

  /// 构建头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: DentalColors.primaryGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
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
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                if (_getCreatorInfo().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getCreatorInfo(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
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

  /// 构建标签栏
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
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

  /// 构建标签视图
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

  /// 构建权限警告
  Widget _buildPermissionWarning() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
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

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
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
          // Previous/Cancel Button - Smaller (Flex 1)
          if (_tabController.index > 0) ...[
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(_tabController.index - 1);
                  },
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 20, color: DentalColors.primary),
                  label: const Text('上一步',
                      style: TextStyle(color: DentalColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: DentalColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Next/Save Button - Larger (Flex 2)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_tabController.index == 4 && !_hasEditPermission()
                        ? null
                        : _handleNextOrSave),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _tabController.index == 4
                            ? Icons.save_rounded
                            : Icons.arrow_forward_rounded,
                        size: 20),
                label: Text(
                  _tabController.index == 4
                      ? (_hasEditPermission() ? '保存病历' : '无权限保存')
                      : '下一步',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _tabController.index == 4 && !_hasEditPermission()
                          ? Colors.grey
                          : DentalColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: DentalColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建牙齿状况选择器
  Widget _buildDentalConditionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: DentalColors.secondary,
            ),
            SizedBox(width: 8),
            Text(
              '关联牙齿状况',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
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
            color: DentalColors.secondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildDentalConditionOption(
                title: '无关联牙齿状况',
                value: _selectedDentalConditionDates.isEmpty,
                onChanged: _hasEditPermission()
                    ? (value) {
                        setState(() {
                          if (value) {
                            _selectedDentalConditionDates.clear();
                          }
                        });
                      }
                    : null,
              ),
              if (_availableDentalConditionDates.isNotEmpty) ...[
                const Divider(),
                ..._availableDentalConditionDates.map(
                  (date) => _buildDentalConditionOption(
                    title: '牙齿状况记录 - $date',
                    value: _selectedDentalConditionDates.contains(date),
                    onChanged: _hasEditPermission()
                        ? (value) {
                            setState(() {
                              if (value) {
                                _selectedDentalConditionDates.add(date);
                              } else {
                                _selectedDentalConditionDates.remove(date);
                              }
                            });
                          }
                        : null,
                  ),
                ),
              ] else ...[
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DentalColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: DentalColors.warning,
                        size: 16,
                      ),
                      SizedBox(width: 8),
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

  Widget _buildDentalConditionOption({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final isEnabled = onChanged != null;

    return InkWell(
      onTap: isEnabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged:
                  isEnabled ? (checked) => onChanged(checked ?? false) : null,
              activeColor: DentalColors.secondary,
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isEnabled
                      ? DentalColors.onSurface
                      : DentalColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建基本信息步骤
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
            PatientInfoDisplayWidget(
              patient: widget.patient,
              buildInfoItem: (label, value) {
                return _buildInfoItem(label, value);
              },
            ),
            const SizedBox(height: 20),

            // 病历信息（病历编号、日期、医生）
            MedicalRecordInfoDisplayWidget(
              recordNumberController: _recordNumberController,
              recordDate: _recordDate,
              doctorName: _doctorName,
              hasEditPermission: _hasEditPermission(),
              onDateChanged: (date) {
                setState(() {
                  _recordDate = date;
                });
              },
              buildInputField: ({
                required TextEditingController controller,
                required String label,
                required String hint,
                required IconData icon,
                int maxLines = 1,
                bool enabled = true,
                String? Function(String?)? validator,
              }) {
                return _buildInputField(
                  controller: controller,
                  label: label,
                  hint: hint,
                  icon: icon,
                  maxLines: maxLines,
                  enabled: enabled,
                  validator: validator,
                );
              },
              buildDateField: ({
                required String label,
                required DateTime value,
                required Function(DateTime) onChanged,
              }) {
                return _buildDateField(
                  label: label,
                  value: value,
                  onChanged: onChanged,
                );
              },
            ),
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
                color: DentalColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DentalColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: DentalColors.info,
                    size: 20,
                  ),
                  SizedBox(width: 12),
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

  /// 构建既往史步骤
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
              ? DiseaseSelectionWidget(
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
                  hasEditPermission: _hasEditPermission(),
                  buildInputField: ({
                    required TextEditingController controller,
                    required String label,
                    required String hint,
                    required IconData icon,
                    int maxLines = 1,
                    bool enabled = true,
                    String? Function(String?)? validator,
                  }) {
                    return _buildInputField(
                      controller: controller,
                      label: label,
                      hint: hint,
                      icon: icon,
                      maxLines: maxLines,
                      enabled: enabled,
                      validator: validator,
                    );
                  },
                )
              : const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 32),

          // 口腔疾病既往史
          _templatesLoaded
              ? DiseaseSelectionWidget(
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
                  hasEditPermission: _hasEditPermission(),
                  buildInputField: ({
                    required TextEditingController controller,
                    required String label,
                    required String hint,
                    required IconData icon,
                    int maxLines = 1,
                    bool enabled = true,
                    String? Function(String?)? validator,
                  }) {
                    return _buildInputField(
                      controller: controller,
                      label: label,
                      hint: hint,
                      icon: icon,
                      maxLines: maxLines,
                      enabled: enabled,
                      validator: validator,
                    );
                  },
                )
              : const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 32),

          // 过敏史
          AllergySelectionWidget(
            allergyOptions: _allergyOptions,
            selectedAllergies: _selectedAllergies,
            customController: _customAllergyController,
            templatesLoaded: _templatesLoaded,
            hasEditPermission: _hasEditPermission(),
            onAllergyChanged: (selected) {
              setState(() {
                _selectedAllergies = selected;
              });
            },
            buildInputField: ({
              required TextEditingController controller,
              required String label,
              required String hint,
              required IconData icon,
              int maxLines = 1,
              bool enabled = true,
              String? Function(String?)? validator,
            }) {
              return _buildInputField(
                controller: controller,
                label: label,
                hint: hint,
                icon: icon,
                maxLines: maxLines,
                enabled: enabled,
                validator: validator,
              );
            },
          ),
          const SizedBox(height: 32),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DentalColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: DentalColors.warning,
                  size: 20,
                ),
                SizedBox(width: 12),
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

  /// 构建牙科检查步骤
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
          DentalDiseaseSelectionWidget(
            dentalDiseaseOptions: _dentalDiseaseOptions,
            selectedDentalDiseases: _selectedDentalDiseases,
            customController: _customDentalDiseaseController,
            templatesLoaded: _templatesLoaded,
            hasEditPermission: _hasEditPermission(),
            onSelectionChanged: (selected) {
              setState(() {
                _selectedDentalDiseases = selected;
              });
            },
            buildInputField: ({
              required TextEditingController controller,
              required String label,
              required String hint,
              required IconData icon,
              int maxLines = 1,
              bool enabled = true,
              String? Function(String?)? validator,
            }) {
              return _buildInputField(
                controller: controller,
                label: label,
                hint: hint,
                icon: icon,
                maxLines: maxLines,
                enabled: enabled,
                validator: validator,
              );
            },
          ),
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
              color: DentalColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DentalColors.info,
                  size: 20,
                ),
                SizedBox(width: 12),
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

  /// 构建诊断治疗步骤
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
          TreatmentTemplateWidget(
            selectedTreatmentTemplates: _selectedTreatmentTemplates,
            treatmentPlanController: _treatmentPlanController,
            onTemplateChanged: (selectedTemplates, content) {
              setState(() {
                if (selectedTemplates.contains(content)) {
                  // 已选中，移除内容
                  _selectedTreatmentTemplates.clear();
                  _treatmentPlanController.text = '';
                } else {
                  // 未选中，替换内容（治疗方案只能选一个）
                  _selectedTreatmentTemplates.clear();
                  _selectedTreatmentTemplates.add(content);
                  _treatmentPlanController.text = content;
                }
              });
            },
          ),
          const SizedBox(height: 32),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DentalColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: DentalColors.success,
                  size: 20,
                ),
                SizedBox(width: 12),
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

  /// 构建注意事项步骤
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
          NotesTemplateWidget(
            selectedNotesTemplates: _selectedNotesTemplates,
            notesController: _notesController,
            onTemplateChanged: (selectedTemplates, title, content) {
              setState(() {
                if (selectedTemplates.contains(title)) {
                  // 已选中，移除内容
                  _selectedNotesTemplates.remove(title);
                  final currentText = _notesController.text;
                  // 移除该模板的内容
                  final lines = currentText.split('\n\n');
                  lines.removeWhere(
                      (section) => section.trim() == content.trim());
                  _notesController.text = lines.join('\n\n').trim();
                } else {
                  // 未选中，追加内容
                  _selectedNotesTemplates.add(title);
                  final currentText = _notesController.text;
                  final newText = currentText.isEmpty
                      ? content
                      : '$currentText\n\n$content';
                  _notesController.text = newText;
                }
              });
            },
          ),
          const SizedBox(height: 32),

          // 病历摘要
          RecordSummaryDisplayWidget(
            patient: widget.patient,
            recordNumber: _recordNumberController.text,
            recordDate: _recordDate,
            doctorName: _doctorName,
            chiefComplaint: _chiefComplaintController.text,
            diagnosis: _diagnosisController.text,
            selectedDentalConditionDates: _selectedDentalConditionDates,
            selectedSystemicDiseases: _selectedSystemicDiseases,
            selectedDentalDiseases: _selectedDentalDiseases,
            selectedAllergies: _selectedAllergies,
            buildSummaryItem: (label, value) {
              return _buildSummaryItem(label, value);
            },
          ),
          const SizedBox(height: 32),

          // 最终提示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DentalColors.primary.withValues(alpha: 0.1),
                  DentalColors.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.save_rounded,
                  color: DentalColors.primary,
                  size: 20,
                ),
                SizedBox(width: 12),
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
}
