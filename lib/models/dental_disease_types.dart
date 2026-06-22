/// 牙科疾病类型常量定义
class DentalDiseaseTypes {
  /// 牙科疾病类型映射
  static const Map<String, List<String>> diseases = {
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
        final matchingSubTypes = subTypes.where((subType) => subType.contains(keyword)).toList();
        if (matchingSubTypes.isNotEmpty) {
          filtered[type] = matchingSubTypes;
        }
      }
    });
    return filtered;
  }
}