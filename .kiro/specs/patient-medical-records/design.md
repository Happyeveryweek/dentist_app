# 患者病历功能设计文档

## 概述

本设计文档详细描述了为牙科诊所Windows端应用添加患者病历管理功能的技术架构和实现方案。该功能将无缝集成到现有的患者详情页面中，提供完整的牙科专业病历记录、全身检查记录、过敏史管理以及PDF导出功能。

## 架构设计

### 整体架构

患者病历系统采用现有的分层架构模式：

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Screens/Widgets)               │
├─────────────────────────────────────────────────────────────┤
│                  Business Logic Layer (Providers)           │
├─────────────────────────────────────────────────────────────┤
│                   Data Access Layer (DataSources)           │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer (Models/Schemas)              │
├─────────────────────────────────────────────────────────────┤
│                Database Layer (SQLite/MySQL)                │
└─────────────────────────────────────────────────────────────┘
```

### 核心组件

1. **MedicalRecordProvider**: 病历数据状态管理
2. **MedicalRecordDataSource**: 病历数据访问抽象层
3. **PatientMedicalRecord**: 病历主记录模型
4. **MedicalRecordItem**: 病历详细项目模型
5. **MedicalRecordFormDialog**: 病历编辑表单
6. **MedicalRecordPdfExporter**: PDF导出功能

## 组件和接口设计

### 数据模型设计

#### PatientMedicalRecord 模型

```dart
class PatientMedicalRecord {
  final int? id;
  final int patientId;
  final String recordNumber;           // 病历编号
  final DateTime recordDate;           // 病历日期
  final String chiefComplaint;         // 主诉
  final String presentIllness;         // 现病史
  final String pastMedicalHistory;     // 全身疾病既往史
  final String pastDentalHistory;      // 口腔疾病既往史
  final String allergyHistory;         // 过敏史
  final String oralExamination;        // 口腔检查
  final String diagnosis;              // 诊断
  final String treatmentPlan;          // 治疗方案
  final String notes;                  // 注意事项
  final String doctorName;             // 医生姓名
  final String? selectedDentalConditionDate; // 关联的牙齿状况日期
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### MedicalRecordItem 模型

```dart
class MedicalRecordItem {
  final int? id;
  final int medicalRecordId;
  final String category;               // 类别：dental_disease, systemic_disease, allergy
  final String itemType;               // 具体类型：如龋齿、高血压等
  final String severity;               // 严重程度
  final String description;            // 详细描述
  final String notes;                  // 备注
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### 数据访问层设计

#### MedicalRecordDataSource 接口

```dart
abstract class MedicalRecordDataSource {
  // 病历主记录操作
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId);
  Future<PatientMedicalRecord?> getMedicalRecordById(int id);
  Future<int> createMedicalRecord(PatientMedicalRecord record);
  Future<bool> updateMedicalRecord(PatientMedicalRecord record);
  Future<bool> deleteMedicalRecord(int id);
  
  // 病历项目操作
  Future<List<MedicalRecordItem>> getMedicalRecordItems(int recordId);
  Future<MedicalRecordItem> addMedicalRecordItem(MedicalRecordItem item);
  Future<bool> updateMedicalRecordItem(MedicalRecordItem item);
  Future<bool> deleteMedicalRecordItem(int id);
  
  // 搜索和统计
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query);
  Future<int> getMedicalRecordsCount(int patientId);
}
```

#### SQLite 和 MySQL 实现

- **SqliteMedicalRecordDataSource**: SQLite数据库实现
- **MySqlMedicalRecordDataSource**: MySQL数据库实现

### 业务逻辑层设计

#### MedicalRecordProvider

```dart
class MedicalRecordProvider extends ChangeNotifier {
  final MedicalRecordDataSource _dataSource;
  
  // 状态管理
  List<PatientMedicalRecord> _medicalRecords = [];
  Map<int, List<MedicalRecordItem>> _recordItems = {};
  bool _isLoading = false;
  String? _error;
  
  // 核心方法
  Future<void> loadPatientMedicalRecords(int patientId);
  Future<void> createMedicalRecord(PatientMedicalRecord record);
  Future<void> updateMedicalRecord(PatientMedicalRecord record);
  Future<void> deleteMedicalRecord(int id);
  Future<void> exportToPdf(PatientMedicalRecord record);
}
```

### 用户界面设计

#### 患者病历标签页

集成到现有的 `PatientDetailScreen` 中，作为第三个标签页：

```dart
TabBarView(
  children: [
    _buildPatientInfoTab(),      // 基本信息
    _buildPatientMaterialsTab(), // 患者材料
    _buildMedicalRecordsTab(),   // 患者病历 (新增)
    _buildAppointmentsTab(),     // 预约记录
    _buildFinancialRecordsTab(), // 收费记录
  ],
)
```

#### 病历列表界面

- 显示患者所有病历记录
- 按日期倒序排列
- 支持搜索和筛选
- 提供添加新病历按钮

#### 病历详情界面

- 完整显示病历信息
- 支持编辑和删除操作
- 提供PDF导出功能
- 显示病历项目列表

#### 病历编辑表单

采用分步骤表单设计：

1. **基本信息步骤**
   - 病历日期
   - 主诉
   - 现病史

2. **既往史和过敏史步骤**
   - 全身疾病既往史
   - 口腔疾病既往史
   - 药物过敏史
   - 食物过敏史

3. **牙科专业检查步骤**
   - 常见牙齿疾病多选
   - 口腔检查记录
   - 牙位图表记录

4. **诊断和治疗步骤**
   - 诊断结论
   - 治疗方案
   - 注意事项

## 数据模型设计

### 数据库表结构

#### patient_medical_records 表

```sql
CREATE TABLE patient_medical_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  record_number VARCHAR(50) NOT NULL,
  record_date TEXT NOT NULL,
  chief_complaint TEXT,
  present_illness TEXT,
  past_medical_history TEXT,
  past_dental_history TEXT,
  allergy_history TEXT,
  oral_examination TEXT,
  diagnosis TEXT,
  treatment_plan TEXT,
  notes TEXT,
  doctor_name VARCHAR(100),
  selected_dental_condition_date TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (patient_id) REFERENCES patients(id)
);
```

#### medical_record_items 表

```sql
CREATE TABLE medical_record_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medical_record_id INTEGER NOT NULL,
  category VARCHAR(50) NOT NULL,
  item_type VARCHAR(100) NOT NULL,
  severity VARCHAR(20),
  description TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (medical_record_id) REFERENCES patient_medical_records(id)
);
```

### 预定义数据结构

#### 牙科疾病类型

```dart
class DentalDiseaseTypes {
  static const Map<String, List<String>> diseases = {
    '龋齿': ['浅龋', '中龋', '深龋', '猛性龋'],
    '牙缺损': ['楔状缺损', '磨损', '酸蚀', '外伤性缺损'],
    '牙结石': ['龈上结石', '龈下结石', '轻度', '中度', '重度'],
    '牙松动': ['I度松动', 'II度松动', 'III度松动'],
    '牙缺损修复': ['充填', '嵌体', '贴面', '冠修复'],
    '牙周病': ['牙龈炎', '轻度牙周炎', '中度牙周炎', '重度牙周炎'],
    '正畸': ['牙列不齐', '咬合不正', '间隙', '拥挤'],
  };
}
```

#### 全身疾病类型

```dart
class SystemicDiseaseTypes {
  static const Map<String, List<String>> diseases = {
    '心脏病': ['冠心病', '心律不齐', '心肌病', '先天性心脏病'],
    '高血压': ['轻度高血压', '中度高血压', '重度高血压'],
    '糖尿病': ['1型糖尿病', '2型糖尿病', '妊娠糖尿病'],
    '传染病': ['乙肝', '丙肝', '结核', 'HIV'],
    '血液病': ['贫血', '血小板减少', '凝血功能异常'],
  };
}
```

## 错误处理设计

### 错误类型定义

```dart
enum MedicalRecordError {
  networkError,
  databaseError,
  validationError,
  permissionError,
  exportError,
}

class MedicalRecordException implements Exception {
  final MedicalRecordError type;
  final String message;
  final dynamic originalError;
  
  const MedicalRecordException(this.type, this.message, [this.originalError]);
}
```

### 错误处理策略

1. **网络错误**: 自动重试机制，显示网络状态提示
2. **数据库错误**: 记录错误日志，显示用户友好提示
3. **验证错误**: 实时表单验证，高亮错误字段
4. **权限错误**: 显示权限不足提示，引导用户联系管理员
5. **导出错误**: 提供重试选项，记录详细错误信息

## 测试策略

### 单元测试

- 数据模型测试
- 数据访问层测试
- 业务逻辑测试
- 工具类测试

### 集成测试

- 数据库操作测试
- Provider状态管理测试
- UI组件交互测试

### 端到端测试

- 完整病历创建流程测试
- PDF导出功能测试
- 权限控制测试

## PDF导出设计

### PDF布局设计

```
┌─────────────────────────────────────────────────────────────┐
│                      诊所标题和Logo                          │
├─────────────────────────────────────────────────────────────┤
│                      患者病历                               │
├─────────────────────────────────────────────────────────────┤
│  患者基本信息                                               │
│  姓名: [患者姓名]    年龄: [年龄]    性别: [性别]           │
│  电话: [电话]        病历号: [病历号]                       │
├─────────────────────────────────────────────────────────────┤
│  病历信息                                                   │
│  病历日期: [日期]    医生: [医生姓名]                       │
│  主诉: [主诉内容]                                           │
│  现病史: [现病史内容]                                       │
│  全身疾病既往史: [全身疾病既往史内容]                       │
│  口腔疾病既往史: [口腔疾病既往史内容]                       │
│  过敏史: [过敏史内容]                                       │
│  口腔检查: [检查结果]                                       │
│  关联牙齿状况: [牙齿状况日期] - [牙齿图表显示]              │
│  诊断: [诊断结论]                                           │
│  治疗方案: [治疗计划]                                       │
│  注意事项: [注意事项]                                       │
├─────────────────────────────────────────────────────────────┤
│  医生签名: ________________    日期: ________________       │
└─────────────────────────────────────────────────────────────┘
```

### PDF生成技术

使用 `pdf` 包生成PDF文档：

```dart
class MedicalRecordPdfExporter {
  static Future<Uint8List> generatePdf(
    Patient patient,
    PatientMedicalRecord record,
    List<MedicalRecordItem> items,
  ) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          _buildHeader(),
          _buildPatientInfo(patient),
          _buildMedicalRecord(record, items),
          _buildSignature(),
        ],
      ),
    );
    
    return pdf.save();
  }
}
```

## 性能优化

### 数据加载优化

1. **分页加载**: 病历列表采用分页加载机制
2. **懒加载**: 病历详情按需加载
3. **缓存策略**: 常用数据本地缓存
4. **预加载**: 预测用户行为，提前加载数据

### UI性能优化

1. **虚拟滚动**: 长列表使用虚拟滚动
2. **图片优化**: 图片压缩和缓存
3. **动画优化**: 减少不必要的动画效果
4. **内存管理**: 及时释放不用的资源

## 安全性设计

### 数据安全

1. **数据加密**: 敏感数据加密存储
2. **访问控制**: 基于角色的权限控制
3. **审计日志**: 记录所有操作日志
4. **数据备份**: 定期数据备份

### 隐私保护

1. **数据脱敏**: 导出时可选择脱敏处理
2. **访问记录**: 记录数据访问历史
3. **权限最小化**: 最小权限原则
4. **数据清理**: 定期清理过期数据

## 国际化支持

### 多语言支持

虽然当前主要支持中文，但设计时考虑国际化扩展：

```dart
class MedicalRecordLocalizations {
  static const Map<String, String> zhCN = {
    'medical_record': '患者病历',
    'chief_complaint': '主诉',
    'present_illness': '现病史',
    'past_medical_history': '既往史',
    'allergy_history': '过敏史',
    // ... 更多翻译
  };
}
```

## 可扩展性设计

### 插件化架构

为未来功能扩展预留接口：

```dart
abstract class MedicalRecordPlugin {
  String get name;
  String get version;
  
  Widget buildCustomField(String fieldName);
  Future<void> processCustomData(Map<String, dynamic> data);
}
```

### 配置化设计

支持诊所个性化配置：

```dart
class MedicalRecordConfig {
  final List<String> customDiseaseTypes;
  final Map<String, String> customFieldLabels;
  final bool enableAdvancedFeatures;
  final String clinicLogo;
  final String clinicName;
}
```

## 牙齿状况集成设计

### 数据关联方案

病历记录通过`selected_dental_condition_date`字段关联患者的牙齿状况数据：

```dart
class DentalConditionIntegration {
  // 从患者的dental_condition字段解析牙齿状况数据
  static Map<String, dynamic> parseDentalCondition(String dentalConditionJson) {
    try {
      return jsonDecode(dentalConditionJson);
    } catch (e) {
      return {};
    }
  }
  
  // 根据日期获取特定的牙齿状况记录
  static Map<String, String> getDentalConditionByDate(
    Map<String, dynamic> dentalData, 
    String targetDate
  ) {
    // 查找匹配日期的牙齿状况数据
    // 返回包含chart1、chart2、chart3数据的Map
  }
  
  // 获取所有可用的牙齿状况日期列表
  static List<String> getAvailableDates(Map<String, dynamic> dentalData) {
    // 解析所有date-X字段，返回日期列表
  }
}
```

### 现有牙齿状况数据格式

基于现有系统的数据结构，牙齿状况数据格式为：
```json
{
  "date-0": "2025-03-26",
  "chart1-top-left-0": "",
  "chart1-top-right-0": "4",
  "chart1-bottom-left-0": "",
  "chart1-bottom-right-0": "",
  "chart1-note-0": "治疗",
  "chart2-top-left-0": "",
  "chart2-top-right-0": "",
  "chart2-bottom-left-0": "",
  "chart2-bottom-right-0": "",
  "chart2-note-0": "",
  "chart3-top-left-0": "",
  "chart3-top-right-0": "",
  "chart3-bottom-left-0": "",
  "chart3-bottom-right-0": "",
  "chart3-note-0": "",
  "date-1": "2025-04-05",
  "chart1-top-left-1": "",
  "chart1-top-right-1": "5",
  "chart1-bottom-left-1": "",
  "chart1-bottom-right-1": "",
  "chart1-note-1": "治疗"
}
```

### UI集成方案

1. **牙齿状况选择器**
   - 在病历表单中添加牙齿状况日期选择下拉框
   - 显示患者所有可用的牙齿状况记录日期
   - 支持"无关联"选项

2. **牙齿状况显示组件**
   - 在病历详情中只读显示选中的牙齿状况
   - 复用现有的牙齿图表显示组件（_buildReadOnlyCrossChart）
   - 显示三个图表和对应的备注信息

3. **PDF导出集成**
   - 在PDF中包含关联的牙齿状况图表
   - 保持与患者详情页面一致的显示格式

## 病历管理模块设计

### 概述

病历管理模块将现有硬编码的疾病类型数据动态化，提供可视化的管理界面，允许用户自定义疾病类型、严重程度等信息。

### 数据模型扩展

#### MedicalRecordTemplate 模型

```dart
class MedicalRecordTemplate {
  final int? id;
  final String category;           // 类别：dental_disease, systemic_disease, allergy
  final String name;               // 疾病名称
  final String? parentName;        // 父级疾病名称（用于子类型）
  final String description;        // 详细描述
  final bool isActive;             // 是否启用
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### medical_record_items 表扩展

```sql
-- 必需字段：标识是否为模板数据
ALTER TABLE medical_record_items ADD COLUMN is_template BOOLEAN DEFAULT FALSE;
-- 支持疾病层级结构的字段
ALTER TABLE medical_record_items ADD COLUMN parent_name VARCHAR(100);
```

### 用户界面设计

#### 病历管理主界面

集成到业务管理页面，作为第四个标签页：

```dart
final List<String> _tabTitles = ['财务管理', '采购管理', '病历管理', '用户管理'];
```

#### 病历管理标签页结构

```dart
TabBarView(
  children: [
    _buildDentalDiseasesTab(),    // 牙科疾病管理
    _buildSystemicDiseasesTab(),  // 全身疾病管理
    _buildAllergiesTab(),         // 过敏类型管理
  ],
)
```

#### 疾病类型编辑对话框

```dart
class DiseaseTypeEditDialog extends StatefulWidget {
  final MedicalRecordTemplate? template;
  final String category;
  
  // 表单字段：
  // - 疾病名称
  // - 父级疾病（可选）
  // - 严重程度选项（多选）
  // - 详细描述
  // - 排序顺序
}
```

### 数据访问层扩展

#### MedicalRecordDataSource 接口扩展

```dart
abstract class MedicalRecordDataSource {
  // 模板数据操作
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category);
  Future<MedicalRecordTemplate?> getTemplateById(int id);
  Future<int> createTemplate(MedicalRecordTemplate template);
  Future<bool> updateTemplate(MedicalRecordTemplate template);
  Future<bool> deleteTemplate(int id);
  
  // 初始化预设数据
  Future<bool> initializeDefaultTemplates();
  Future<bool> hasTemplateData();
  
  // 检查关联数据
  Future<bool> hasRelatedRecords(int templateId);
}
```

### 业务逻辑层扩展

#### MedicalRecordProvider 扩展

```dart
class MedicalRecordProvider extends ChangeNotifier {
  // 模板数据状态
  Map<String, List<MedicalRecordTemplate>> _templates = {};
  bool _templatesLoaded = false;
  
  // 模板数据管理方法
  Future<void> loadTemplatesByCategory(String category);
  Future<void> createTemplate(MedicalRecordTemplate template);
  Future<void> updateTemplate(MedicalRecordTemplate template);
  Future<void> deleteTemplate(int id);
  Future<void> initializeDefaultTemplates();
  
  // 获取疾病选项（供病历表单使用）
  Map<String, List<String>> getDiseaseOptions(String category);
  List<String> getSeverityOptions(String category, String diseaseName);
}
```

### 数据迁移策略

#### 初始化预设数据

```dart
class DefaultTemplateInitializer {
  static Future<void> initializeDentalDiseases(MedicalRecordDataSource dataSource) {
    // 将 DentalDiseaseTypes.diseases 转换为 MedicalRecordTemplate 对象
    // 批量插入数据库
  }
  
  static Future<void> initializeSystemicDiseases(MedicalRecordDataSource dataSource) {
    // 将 SystemicDiseaseTypes.diseases 转换为 MedicalRecordTemplate 对象
    // 批量插入数据库
  }
  
  static Future<void> initializeAllergies(MedicalRecordDataSource dataSource) {
    // 将 AllergyTypes.allergies 转换为 MedicalRecordTemplate 对象
    // 批量插入数据库
  }
}
```

### 集成方案

#### 病历表单集成

修改 `MedicalRecordFormDialog` 中的疾病选择逻辑：

```dart
// 原来的硬编码方式
// final diseases = DentalDiseaseTypes.diseases;

// 新的数据库方式
final diseases = await _medicalRecordProvider.getDiseaseOptions('dental_disease');
```

#### 业务管理页面集成

在 `_BusinessManagementScreen` 中添加病历管理标签页：

```dart
case 3: return Icons.medical_information_rounded; // 病历管理 - 医疗信息图标
```

### 功能特性

#### 核心功能

1. **疾病类型管理**: 增删改查疾病类型
2. **分类管理**: 按牙科疾病、全身疾病、过敏类型分类
3. **层级管理**: 支持主疾病和子类型的层级结构
4. **严重程度配置**: 为每个疾病类型配置严重程度选项
5. **排序管理**: 支持自定义排序顺序
6. **批量操作**: 支持批量导入、导出、删除
7. **搜索过滤**: 支持按名称、类别搜索疾病类型

#### 高级功能

1. **数据验证**: 防止重复添加、检查关联数据
2. **导入导出**: 支持Excel格式的批量导入导出
3. **版本控制**: 记录疾病类型的修改历史
4. **权限控制**: 基于用户角色的操作权限
5. **数据统计**: 显示各类疾病的使用频率统计

## 部署和维护

### 数据库迁移

提供数据库版本管理和迁移脚本：

```dart
class MedicalRecordMigration {
  static Future<void> migrateToVersion2() async {
    // 添加新字段
    // 数据格式转换
    // 索引优化
  }
  
  static Future<void> migrateToVersion3() async {
    // 添加病历管理相关表结构
    // 初始化预设疾病数据
    // 更新现有病历记录关联
  }
}
```

### 监控和日志

1. **性能监控**: 关键操作性能监控
2. **错误监控**: 异常情况自动报告
3. **使用统计**: 功能使用情况统计
4. **健康检查**: 系统健康状态检查