/// 全身疾病类型常量定义
class SystemicDiseaseTypes {
  /// 全身疾病类型映射
  static const Map<String, List<String>> diseases = {
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

  /// 获取所有疾病类型名称
  static List<String> get allDiseaseTypes => diseases.keys.toList();

  /// 获取指定疾病类型的子类型
  static List<String> getSubTypes(String diseaseType) {
    return diseases[diseaseType] ?? [];
  }

  /// 检查是否为有效的疾病类型
  static bool isValidDiseaseType(String diseaseType) {
    return diseases.containsKey(diseaseType);
  }

  /// 检查是否为有效的子类型
  static bool isValidSubType(String diseaseType, String subType) {
    final subTypes = diseases[diseaseType];
    return subTypes != null && subTypes.contains(subType);
  }

  /// 获取疾病类型的显示名称（用于UI显示）
  static String getDisplayName(String diseaseType) {
    return diseaseType;
  }

  /// 获取所有疾病类型和子类型的扁平化列表
  static List<String> getAllDiseaseItems() {
    final List<String> allItems = [];
    diseases.forEach((type, subTypes) {
      allItems.add(type);
      allItems.addAll(subTypes.map((subType) => '$type - $subType'));
    });
    return allItems;
  }

  /// 根据搜索关键词过滤疾病类型
  static Map<String, List<String>> filterDiseases(String keyword) {
    if (keyword.isEmpty) return diseases;

    final Map<String, List<String>> filtered = {};
    diseases.forEach((type, subTypes) {
      if (type.contains(keyword)) {
        filtered[type] = subTypes;
      } else {
        final matchingSubTypes =
            subTypes.where((subType) => subType.contains(keyword)).toList();
        if (matchingSubTypes.isNotEmpty) {
          filtered[type] = matchingSubTypes;
        }
      }
    });
    return filtered;
  }

  /// 获取常见疾病类型（用于快速选择）
  static List<String> get commonDiseaseTypes => [
        '高血压',
        '糖尿病',
        '心脏病',
        '肝炎',
        '胃炎',
        '关节炎',
      ];

  /// 获取需要特别注意的疾病类型（影响牙科治疗）
  static List<String> get criticalDiseaseTypes => [
        '心脏病',
        '高血压',
        '糖尿病',
        '血液病',
        '传染病',
        '肾脏疾病',
      ];

  /// 检查是否为需要特别注意的疾病
  static bool isCriticalDisease(String diseaseType) {
    return criticalDiseaseTypes.contains(diseaseType);
  }
}
