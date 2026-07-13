import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/medical_template.dart';
import '../utils/app_paths.dart';
import '../utils/log_manager.dart';

/// 医疗模板服务
/// 负责管理治疗方案模板和医嘱模板的本地JSON文件存储
class MedicalTemplateService {
  static const String _treatmentTemplatesFileName = 'treatment_templates.json';
  static const String _notesTemplatesFileName = 'notes_templates.json';

  /// 获取治疗方案模板文件路径
  static String get _treatmentTemplatesPath {
    return path.join(AppPaths.dataDirectory, _treatmentTemplatesFileName);
  }

  /// 获取医嘱模板文件路径
  static String get _notesTemplatesPath {
    return path.join(AppPaths.dataDirectory, _notesTemplatesFileName);
  }

  /// 根据类型获取文件路径
  static String _getTemplateFilePath(String type) {
    switch (type) {
      case MedicalTemplateType.treatment:
        return _treatmentTemplatesPath;
      case MedicalTemplateType.notes:
        return _notesTemplatesPath;
      default:
        throw ArgumentError('无效的模板类型: $type');
    }
  }

  /// 初始化默认模板数据
  static Future<void> initializeDefaultTemplates() async {
    LogManager.w(
        'MedicalTemplateService', 'MedicalTemplateService: 开始初始化默认模板数据');

    try {
      // 确保数据目录存在
      await AppPaths.ensureDirectoryExists(AppPaths.dataDirectory);

      // 初始化治疗方案模板
      await _initializeTreatmentTemplates();

      // 初始化医嘱模板
      await _initializeNotesTemplates();

      LogManager.i(
          'MedicalTemplateService', 'MedicalTemplateService: 默认模板数据初始化完成');
    } catch (e) {
      LogManager.e(
          'MedicalTemplateService', 'MedicalTemplateService: 初始化默认模板数据失败',
          error: e);
      rethrow;
    }
  }

  /// 初始化默认治疗方案模板
  static Future<void> _initializeTreatmentTemplates() async {
    final defaultTemplates = [
      MedicalTemplate(
        id: 'treatment_001',
        title: '洁牙治疗',
        content: '1. 超声波洁牙\n2. 抛光处理\n3. 氟化物涂布\n4. 口腔卫生指导',
        type: MedicalTemplateType.treatment,
        sortOrder: 1,
      ),
      MedicalTemplate(
        id: 'treatment_002',
        title: '充填治疗',
        content: '1. 局部麻醉\n2. 去除龋坏组织\n3. 窝洞预备\n4. 充填材料填充\n5. 形态调整和抛光',
        type: MedicalTemplateType.treatment,
        sortOrder: 2,
      ),
      MedicalTemplate(
        id: 'treatment_003',
        title: '根管治疗',
        content: '1. 开髓引流\n2. 根管预备\n3. 根管消毒\n4. 根管充填\n5. 冠部修复',
        type: MedicalTemplateType.treatment,
        sortOrder: 3,
      ),
      MedicalTemplate(
        id: 'treatment_004',
        title: '牙周治疗',
        content: '1. 龈上洁治\n2. 龈下刮治\n3. 根面平整\n4. 局部药物治疗\n5. 维护期治疗',
        type: MedicalTemplateType.treatment,
        sortOrder: 4,
      ),
      MedicalTemplate(
        id: 'treatment_005',
        title: '拔牙术',
        content: '1. 术前检查\n2. 局部麻醉\n3. 牙齿拔除\n4. 创口处理\n5. 术后护理指导',
        type: MedicalTemplateType.treatment,
        sortOrder: 5,
      ),
      MedicalTemplate(
        id: 'treatment_006',
        title: '种植牙治疗',
        content: '1. 术前评估和设计\n2. 种植体植入\n3. 愈合期观察\n4. 基台连接\n5. 冠修复',
        type: MedicalTemplateType.treatment,
        sortOrder: 6,
      ),
      MedicalTemplate(
        id: 'treatment_007',
        title: '正畸治疗',
        content: '1. 正畸检查和诊断\n2. 治疗方案制定\n3. 矫治器安装\n4. 定期调整\n5. 保持器佩戴',
        type: MedicalTemplateType.treatment,
        sortOrder: 7,
      ),
    ];

    await _saveTemplates(MedicalTemplateType.treatment, defaultTemplates);
  }

  /// 初始化默认医嘱模板
  static Future<void> _initializeNotesTemplates() async {
    final defaultTemplates = [
      MedicalTemplate(
        id: 'notes_001',
        title: '术后护理',
        content: '1. 术后2小时内禁食\n2. 24小时内避免刷牙漱口\n3. 避免用患侧咀嚼\n4. 如有异常及时复诊',
        type: MedicalTemplateType.notes,
        sortOrder: 1,
      ),
      MedicalTemplate(
        id: 'notes_002',
        title: '用药指导',
        content: '1. 按时服用抗生素\n2. 疼痛时可服用止痛药\n3. 注意药物过敏反应\n4. 完成整个疗程',
        type: MedicalTemplateType.notes,
        sortOrder: 2,
      ),
      MedicalTemplate(
        id: 'notes_003',
        title: '口腔卫生',
        content: '1. 早晚刷牙，饭后漱口\n2. 使用软毛牙刷\n3. 配合使用牙线\n4. 定期口腔检查',
        type: MedicalTemplateType.notes,
        sortOrder: 3,
      ),
      MedicalTemplate(
        id: 'notes_004',
        title: '复诊安排',
        content: '1. 一周后复查\n2. 观察愈合情况\n3. 必要时调整治疗方案\n4. 长期随访观察',
        type: MedicalTemplateType.notes,
        sortOrder: 4,
      ),
      MedicalTemplate(
        id: 'notes_005',
        title: '饮食建议',
        content: '1. 避免过硬食物\n2. 减少甜食摄入\n3. 多吃富含维生素食物\n4. 充足饮水',
        type: MedicalTemplateType.notes,
        sortOrder: 5,
      ),
      MedicalTemplate(
        id: 'notes_006',
        title: '拔牙后注意事项',
        content: '1. 咬紧纱布30分钟\n2. 24小时内不要漱口\n3. 避免吸烟和饮酒\n4. 如有持续出血请及时就诊',
        type: MedicalTemplateType.notes,
        sortOrder: 6,
      ),
      MedicalTemplate(
        id: 'notes_007',
        title: '根管治疗后护理',
        content: '1. 避免用患牙咀嚼硬物\n2. 及时进行冠修复\n3. 定期复查\n4. 注意口腔卫生',
        type: MedicalTemplateType.notes,
        sortOrder: 7,
      ),
    ];

    await _saveTemplates(MedicalTemplateType.notes, defaultTemplates);
  }

  /// 获取指定类型的所有模板
  static Future<List<MedicalTemplate>> getTemplates(String type) async {
    try {
      final filePath = _getTemplateFilePath(type);
      final file = File(filePath);

      if (!await file.exists()) {
        LogManager.w('MedicalTemplateService',
            'MedicalTemplateService: 模板文件不存在，返回空列表: $filePath');
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final templates =
          jsonList.map((json) => MedicalTemplate.fromMap(json)).toList();

      // 按排序顺序排列
      templates.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      LogManager.w('MedicalTemplateService',
          'MedicalTemplateService: 加载了 ${templates.length} 个 $type 模板');
      return templates;
    } catch (e) {
      LogManager.e('MedicalTemplateService', 'MedicalTemplateService: 加载模板失败',
          error: e);
      return [];
    }
  }

  /// 保存指定类型的模板列表
  static Future<void> _saveTemplates(
      String type, List<MedicalTemplate> templates) async {
    try {
      final filePath = _getTemplateFilePath(type);
      final file = File(filePath);

      // 确保父目录存在
      await file.parent.create(recursive: true);

      final jsonList = templates.map((template) => template.toMap()).toList();
      final jsonString = jsonEncode(jsonList);

      await file.writeAsString(jsonString, encoding: utf8);
      LogManager.w('MedicalTemplateService',
          'MedicalTemplateService: 保存了 ${templates.length} 个 $type 模板到 $filePath');
    } catch (e) {
      LogManager.e('MedicalTemplateService', 'MedicalTemplateService: 保存模板失败',
          error: e);
      rethrow;
    }
  }

  /// 添加新模板
  static Future<void> addTemplate(MedicalTemplate template) async {
    try {
      final templates = await getTemplates(template.type);

      // 检查ID是否已存在
      if (templates.any((t) => t.id == template.id)) {
        throw Exception('模板ID已存在: ${template.id}');
      }

      templates.add(template);
      await _saveTemplates(template.type, templates);
    } catch (e) {
      LogManager.e('MedicalTemplateService', 'MedicalTemplateService: 添加模板失败',
          error: e);
      rethrow;
    }
  }

  /// 更新模板
  static Future<void> updateTemplate(MedicalTemplate template) async {
    try {
      final templates = await getTemplates(template.type);

      final index = templates.indexWhere((t) => t.id == template.id);
      if (index == -1) {
        throw Exception('模板不存在: ${template.id}');
      }

      templates[index] = template;
      await _saveTemplates(template.type, templates);
    } catch (e) {
      LogManager.e('MedicalTemplateService', 'MedicalTemplateService: 更新模板失败',
          error: e);
      rethrow;
    }
  }

  /// 删除模板
  static Future<void> deleteTemplate(String type, String id) async {
    try {
      final templates = await getTemplates(type);

      final index = templates.indexWhere((t) => t.id == id);
      if (index == -1) {
        throw Exception('模板不存在: $id');
      }

      templates.removeAt(index);
      await _saveTemplates(type, templates);
    } catch (e) {
      LogManager.e('MedicalTemplateService', 'MedicalTemplateService: 删除模板失败',
          error: e);
      rethrow;
    }
  }

  /// 获取治疗方案模板
  static Future<List<MedicalTemplate>> getTreatmentTemplates() async {
    return await getTemplates(MedicalTemplateType.treatment);
  }

  /// 获取医嘱模板
  static Future<List<MedicalTemplate>> getNotesTemplates() async {
    return await getTemplates(MedicalTemplateType.notes);
  }

  /// 检查是否有模板数据
  static Future<bool> hasTemplateData() async {
    try {
      final treatmentTemplates = await getTreatmentTemplates();
      final notesTemplates = await getNotesTemplates();
      return treatmentTemplates.isNotEmpty || notesTemplates.isNotEmpty;
    } catch (e) {
      LogManager.e('MedicalTemplateService', 'MedicalTemplateService: 检查模板数据失败',
          error: e);
      return false;
    }
  }

  /// 生成新的模板ID
  static String generateTemplateId(String type) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix =
        type == MedicalTemplateType.treatment ? 'treatment' : 'notes';
    return '${prefix}_$timestamp';
  }
}
