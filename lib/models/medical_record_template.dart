import 'package:mysql1/mysql1.dart';
import '../utils/datetime_formatter.dart';

/// 病历模板数据模型
/// 用于存储疾病类型等模板数据，支持牙科疾病、全身疾病、过敏类型三大类别
class MedicalRecordTemplate {
  final int? id;
  final String category;           // 类别：dental_disease, systemic_disease, allergy
  final String name;               // 疾病名称
  final String? parentName;        // 父级疾病名称（用于子类型）
  final String description;        // 详细描述
  final bool isActive;             // 是否启用
  final int sortOrder;             // 排序顺序
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalRecordTemplate({
    this.id,
    required this.category,
    required this.name,
    this.parentName,
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从Map构造MedicalRecordTemplate对象
  factory MedicalRecordTemplate.fromMap(Map<String, dynamic> map) {
    // 辅助方法：安全转换字符串，处理BLOB类型
    String safeStringFromField(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Blob) {
        try {
          return String.fromCharCodes(field.toBytes());
        } catch (e) {
          print('MedicalRecordTemplate.fromMap: Blob转换失败: $e');
          return '';
        }
      }
      try {
        return field.toString();
      } catch (e) {
        print('MedicalRecordTemplate.fromMap: 字段转换失败: $e');
        return '';
      }
    }

    // 处理创建时间和更新时间
    DateTime createdAt = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          createdAt = map['created_at'];
        } else {
          createdAt = DateTimeFormatter.fromDbString(map['created_at'].toString());
        }
      } catch (e) {
        print('解析created_at错误: ${map['created_at']}');
      }
    }

    DateTime updatedAt = DateTime.now();
    if (map['updated_at'] != null) {
      try {
        if (map['updated_at'] is DateTime) {
          updatedAt = map['updated_at'];
        } else {
          updatedAt = DateTimeFormatter.fromDbString(map['updated_at'].toString());
        }
      } catch (e) {
        print('解析updated_at错误: ${map['updated_at']}');
      }
    }

    // 处理parent_name字段，确保NULL值被正确识别
    String? parentName;
    if (map['parent_name'] == null) {
      parentName = null;
    } else {
      final parentNameStr = safeStringFromField(map['parent_name']);
      // 检查是否为空字符串、"null"字符串或"(Null)"字符串
      if (parentNameStr.isEmpty || 
          parentNameStr.toLowerCase() == 'null' || 
          parentNameStr == '(Null)') {
        parentName = null;
      } else {
        parentName = parentNameStr;
      }
    }

    return MedicalRecordTemplate(
      id: map['id'],
      category: safeStringFromField(map['category']),
      name: safeStringFromField(map['name']),
      parentName: parentName,
      description: safeStringFromField(map['description']),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 将MedicalRecordTemplate对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'parent_name': parentName,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  /// 复制MedicalRecordTemplate对象，但可以修改部分属性
  MedicalRecordTemplate copyWith({
    int? id,
    String? category,
    String? name,
    String? parentName,
    String? description,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalRecordTemplate(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      parentName: parentName ?? this.parentName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // 更新时间总是使用当前时间
    );
  }

  /// 获取完整的显示名称（包含父级疾病）
  String get fullDisplayName {
    if (parentName != null && parentName!.isNotEmpty) {
      return '$parentName - $name';
    }
    return name;
  }

  /// 检查是否为主疾病类型（没有父级）
  bool get isMainType => parentName == null || parentName!.isEmpty;

  /// 检查是否为子类型（有父级）
  bool get isSubType => parentName != null && parentName!.isNotEmpty;

  @override
  String toString() {
    return 'MedicalRecordTemplate{id: $id, category: $category, name: $name, parentName: $parentName, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalRecordTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          name == other.name &&
          parentName == other.parentName;

  @override
  int get hashCode => id.hashCode ^ category.hashCode ^ name.hashCode ^ (parentName?.hashCode ?? 0);
}

/// 病历模板类别常量
class MedicalRecordTemplateCategory {
  static const String dentalDisease = 'dental_disease';      // 牙科疾病
  static const String systemicDisease = 'systemic_disease';  // 全身疾病
  static const String allergy = 'allergy';                   // 过敏史

  static const List<String> all = [
    dentalDisease,
    systemicDisease,
    allergy,
  ];

  /// 获取类别的中文名称
  static String getCategoryName(String category) {
    switch (category) {
      case dentalDisease:
        return '牙科疾病';
      case systemicDisease:
        return '全身疾病';
      case allergy:
        return '过敏类型';
      default:
        return '未知类别';
    }
  }

  /// 获取类别的英文名称
  static String getCategoryEnglishName(String category) {
    switch (category) {
      case dentalDisease:
        return 'Dental Disease';
      case systemicDisease:
        return 'Systemic Disease';
      case allergy:
        return 'Allergy';
      default:
        return 'Unknown';
    }
  }

  /// 检查是否为有效的类别
  static bool isValidCategory(String category) {
    return all.contains(category);
  }
}

/// 默认模板数据初始化器
class DefaultTemplateInitializer {
  /// 获取默认的牙科疾病模板数据
  static List<MedicalRecordTemplate> getDentalDiseaseTemplates() {
    final List<MedicalRecordTemplate> templates = [];
    int sortOrder = 0;
    
    const Map<String, List<String>> dentalDiseases = {
      '龋齿': ['浅龋', '中龋', '深龋', '猛性龋', '继发龋', '根面龋'],
      '牙缺损': ['楔状缺损', '磨损', '酸蚀', '外伤性缺损', '发育缺陷'],
      '牙结石': ['龈上结石', '龈下结石', '轻度', '中度', '重度'],
      '牙松动': ['I度松动', 'II度松动', 'III度松动'],
      '牙缺损修复': ['充填', '嵌体', '贴面', '冠修复', '桩核冠'],
      '牙周病': ['牙龈炎', '轻度牙周炎', '中度牙周炎', '重度牙周炎', '侵袭性牙周炎'],
      '正畸': ['牙列不齐', '咬合不正', '间隙', '拥挤', '深覆盖', '深覆合', '开合', '反合'],
      '牙髓病': ['牙髓炎', '牙髓坏死', '牙髓钙化', '牙髓息肉'],
      '根尖周病': ['急性根尖周炎', '慢性根尖周炎', '根尖囊肿', '根尖肉芽肿'],
      '口腔黏膜病': ['口疮', '白斑', '扁平苔藓', '口干症'],
      '颞下颌关节病': ['关节盘移位', '关节炎', '关节强直', '关节弹响'],
      '牙外伤': ['牙震荡', '牙脱位', '牙折', '牙槽骨骨折'],
    };

    dentalDiseases.forEach((mainType, subTypes) {
      // 添加主疾病类型
      templates.add(MedicalRecordTemplate(
        category: MedicalRecordTemplateCategory.dentalDisease,
        name: mainType,
        description: '牙科疾病：$mainType',
        sortOrder: sortOrder++,
      ));

      // 添加子类型
      for (String subType in subTypes) {
        templates.add(MedicalRecordTemplate(
          category: MedicalRecordTemplateCategory.dentalDisease,
          name: subType,
          parentName: mainType,
          description: '$mainType的子类型：$subType',
          sortOrder: sortOrder++,
        ));
      }
    });

    return templates;
  }

  /// 获取默认的全身疾病模板数据
  static List<MedicalRecordTemplate> getSystemicDiseaseTemplates() {
    final List<MedicalRecordTemplate> templates = [];
    int sortOrder = 0;
    
    const Map<String, List<String>> systemicDiseases = {
      '心脏病': ['冠心病', '心律不齐', '心肌病', '先天性心脏病', '心脏瓣膜病', '心力衰竭'],
      '高血压': ['轻度高血压', '中度高血压', '重度高血压', '继发性高血压'],
      '糖尿病': ['1型糖尿病', '2型糖尿病', '妊娠糖尿病', '糖尿病前期'],
      '传染病': ['乙肝', '丙肝', '结核', 'HIV', '梅毒', '新冠肺炎'],
      '血液病': ['贫血', '血小板减少', '凝血功能异常', '白血病', '淋巴瘤'],
      '呼吸系统疾病': ['哮喘', '慢性阻塞性肺病', '肺炎', '肺结核', '肺癌'],
      '消化系统疾病': ['胃炎', '胃溃疡', '肝炎', '肝硬化', '胆囊炎', '肠炎'],
      '内分泌疾病': ['甲亢', '甲减', '甲状腺结节', '肾上腺疾病', '垂体疾病'],
      '肾脏疾病': ['慢性肾炎', '肾功能不全', '肾结石', '肾囊肿'],
      '神经系统疾病': ['癫痫', '帕金森病', '脑卒中', '偏头痛', '神经痛'],
      '精神疾病': ['抑郁症', '焦虑症', '双相情感障碍', '精神分裂症'],
      '骨关节疾病': ['关节炎', '骨质疏松', '腰椎间盘突出', '颈椎病'],
    };

    systemicDiseases.forEach((mainType, subTypes) {
      // 添加主疾病类型
      templates.add(MedicalRecordTemplate(
        category: MedicalRecordTemplateCategory.systemicDisease,
        name: mainType,
        description: '全身疾病：$mainType',
        sortOrder: sortOrder++,
      ));

      // 添加子类型
      for (String subType in subTypes) {
        templates.add(MedicalRecordTemplate(
          category: MedicalRecordTemplateCategory.systemicDisease,
          name: subType,
          parentName: mainType,
          description: '$mainType的子类型：$subType',
          sortOrder: sortOrder++,
        ));
      }
    });

    return templates;
  }

  /// 获取默认的过敏类型模板数据
  static List<MedicalRecordTemplate> getAllergyTemplates() {
    final List<MedicalRecordTemplate> templates = [];
    int sortOrder = 0;
    
    const Map<String, List<String>> allergies = {
      '药物过敏': [
        '青霉素', '头孢菌素', '磺胺类', '阿司匹林', '布洛芬', '利多卡因',
        '普鲁卡因', '碘伏', '碘酊', '氯己定', '甲硝唑', '红霉素',
        '四环素', '庆大霉素', '地塞米松', '氢化可的松',
      ],
      '食物过敏': [
        '海鲜', '虾蟹', '鱼类', '牛奶', '鸡蛋', '花生',
        '坚果', '大豆', '小麦', '芝麻', '水果', '蔬菜',
        '蜂蜜', '巧克力',
      ],
      '材料过敏': [
        '乳胶', '金属', '镍', '铬', '钴', '汞',
        '银汞合金', '复合树脂', '印模材料', '粘接剂', '漂白剂', '橡胶', '塑料',
      ],
      '环境过敏': [
        '花粉', '尘螨', '霉菌', '动物毛发', '化妆品', '香水',
        '洗涤剂', '消毒剂', '紫外线', '冷热刺激',
      ],
    };

    allergies.forEach((mainType, subTypes) {
      // 添加主过敏类型
      templates.add(MedicalRecordTemplate(
        category: MedicalRecordTemplateCategory.allergy,
        name: mainType,
        description: '过敏类型：$mainType',
        sortOrder: sortOrder++,
      ));

      // 添加具体过敏原
      for (String subType in subTypes) {
        templates.add(MedicalRecordTemplate(
          category: MedicalRecordTemplateCategory.allergy,
          name: subType,
          parentName: mainType,
          description: '$mainType的具体过敏原：$subType',
          sortOrder: sortOrder++,
        ));
      }
    });

    return templates;
  }

  /// 获取所有默认模板数据
  static List<MedicalRecordTemplate> getAllDefaultTemplates() {
    final List<MedicalRecordTemplate> allTemplates = [];
    allTemplates.addAll(getDentalDiseaseTemplates());
    allTemplates.addAll(getSystemicDiseaseTemplates());
    allTemplates.addAll(getAllergyTemplates());
    return allTemplates;
  }
}