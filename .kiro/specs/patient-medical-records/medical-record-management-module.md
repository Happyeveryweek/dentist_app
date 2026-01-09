# 病历管理模块实现方案

## 概述

病历管理模块是对现有患者病历功能的重要扩展，将硬编码的疾病类型数据动态化，提供可视化的管理界面。该模块将集成到业务管理页面中，位于采购管理标签页之后。

## 核心需求

### 功能需求

1. **疾病数据动态化**: 将现有硬编码的牙科疾病、全身疾病、过敏类型转为数据库存储
2. **可视化管理**: 提供直观的管理界面，支持疾病类型的增删改查
3. **一键初始化**: 提供初始化按钮，将预设疾病数据导入数据库
4. **系统集成**: 无缝集成到现有的业务管理页面
5. **动态获取**: 病历表单从数据库动态获取疾病选项

### 技术需求

1. **数据模型扩展**: 扩展medical_record_items表，支持模板数据存储
2. **架构一致性**: 遵循现有的Provider + DataSource架构模式
3. **双数据源支持**: 同时支持SQLite和MySQL数据库
4. **向后兼容**: 确保现有功能不受影响

## 实现架构

### 数据层设计

#### 1. 数据模型

**MedicalRecordTemplate 模型**
```dart
class MedicalRecordTemplate {
  final int? id;
  final String category;           // dental_disease, systemic_disease, allergy
  final String name;               // 疾病名称
  final String? parentName;        // 父级疾病名称（用于子类型）
  final String description;        // 详细描述
  final bool isActive;             // 是否启用
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### 2. 数据库表扩展

**扩展medical_record_items表**
```sql
-- 必需字段：标识是否为模板数据
ALTER TABLE medical_record_items ADD COLUMN is_template BOOLEAN DEFAULT FALSE;
-- 支持疾病层级结构的字段
ALTER TABLE medical_record_items ADD COLUMN parent_name VARCHAR(100);
```

### 业务逻辑层设计

#### 1. MedicalRecordProvider 扩展

**新增方法**
```dart
// 模板数据管理
Future<void> loadTemplatesByCategory(String category);
Future<void> createTemplate(MedicalRecordTemplate template);
Future<void> updateTemplate(MedicalRecordTemplate template);
Future<void> deleteTemplate(int id);
Future<void> initializeDefaultTemplates();

// 供病历表单使用
Map<String, List<String>> getDiseaseOptions(String category);
List<String> getSeverityOptions(String category, String diseaseName);
```

#### 2. MedicalRecordDataSource 扩展

**新增接口方法**
```dart
// 模板数据CRUD
Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category);
Future<MedicalRecordTemplate?> getTemplateById(int id);
Future<int> createTemplate(MedicalRecordTemplate template);
Future<bool> updateTemplate(MedicalRecordTemplate template);
Future<bool> deleteTemplate(int id);

// 初始化和检查
Future<bool> initializeDefaultTemplates();
Future<bool> hasTemplateData();
Future<bool> hasRelatedRecords(int templateId);
```

### 用户界面设计

#### 1. 业务管理页面集成

**修改_BusinessManagementScreen**
```dart
final List<String> _tabTitles = ['财务管理', '采购管理', '病历管理', '用户管理'];

// 添加病历管理标签页
TabBarView(
  children: [
    const FinancialRecordsScreen(),
    const PurchaseRecordsScreen(), 
    const MedicalRecordManagementScreen(), // 新增
    const UsersScreen(),
  ],
)
```

#### 2. 病历管理主界面

**MedicalRecordManagementScreen 结构**
```dart
class MedicalRecordManagementScreen extends StatefulWidget {
  // 包含三个子标签页：
  // - 牙科疾病管理
  // - 全身疾病管理  
  // - 过敏类型管理
}
```

#### 3. 疾病类型编辑对话框

**DiseaseTypeEditDialog 功能**
- 疾病名称输入
- 父级疾病选择（可选，用于创建子类型）
- 详细描述输入
- 表单验证和重复检查

## 实施计划

### 阶段1: 数据层实现 (任务10.1-10.4)

1. **创建MedicalRecordTemplate模型** (10.1)
   - 定义完整的数据模型
   - 实现序列化和反序列化方法

2. **扩展数据库表结构** (10.2)
   - 修改medical_record_items表
   - 更新SQLite和MySQL表结构定义

3. **扩展数据访问层** (10.3)
   - 在MedicalRecordDataSource中添加模板管理方法
   - 实现SQLite和MySQL的具体实现

4. **扩展业务逻辑层** (10.4)
   - 在MedicalRecordProvider中添加模板管理功能
   - 实现缓存机制和状态管理

### 阶段2: 界面层实现 (任务10.5-10.7)

5. **创建病历管理界面** (10.5)
   - 实现主界面和三个子标签页
   - 添加疾病列表显示和操作按钮

6. **实现编辑对话框** (10.6)
   - 创建疾病类型编辑表单
   - 实现表单验证和数据绑定

7. **集成到业务管理页面** (10.7)
   - 修改_BusinessManagementScreen
   - 添加病历管理标签页

### 阶段3: 系统集成 (任务10.8-10.10)

8. **修改病历表单** (10.8)
   - 将硬编码数据替换为数据库获取
   - 更新疾病选择组件

9. **实现数据迁移** (10.9)
   - 创建初始化脚本
   - 实现预设数据导入功能

10. **测试和优化** (10.10)
    - 全面测试所有功能
    - 优化性能和用户体验

## 关键技术点

### 1. 数据迁移策略

**初始化预设数据**
```dart
class DefaultTemplateInitializer {
  static Future<void> initialize(MedicalRecordDataSource dataSource) {
    // 检查是否已有模板数据
    if (await dataSource.hasTemplateData()) return;
    
    // 批量导入预设数据
    await _initializeDentalDiseases(dataSource);
    await _initializeSystemicDiseases(dataSource);
    await _initializeAllergies(dataSource);
  }
}
```

### 2. 动态数据获取

**病历表单集成**
```dart
// 原来的硬编码方式
// final diseases = DentalDiseaseTypes.diseases;

// 新的数据库方式  
final diseases = await _medicalRecordProvider.getDiseaseOptions('dental_disease');
```

### 3. 缓存机制

**模板数据缓存**
```dart
class MedicalRecordProvider {
  Map<String, List<MedicalRecordTemplate>> _templateCache = {};
  DateTime? _lastTemplateLoadTime;
  
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) {
    // 检查缓存有效性
    // 从缓存或数据库获取数据
  }
}
```

## 预期效果

### 功能效果

1. **灵活性提升**: 诊所可根据实际需要自定义疾病类型
2. **维护便利**: 通过界面管理疾病数据，无需修改代码
3. **数据一致性**: 统一的疾病数据源，避免重复维护
4. **扩展性增强**: 支持新增疾病类型和分类

### 技术效果

1. **架构优化**: 数据与代码分离，提高系统可维护性
2. **性能提升**: 缓存机制减少数据库查询
3. **兼容性保证**: 向后兼容，不影响现有功能
4. **扩展性增强**: 为未来功能扩展提供基础

## 风险控制

### 数据安全

1. **备份机制**: 在数据迁移前自动备份现有数据
2. **回滚方案**: 提供数据回滚功能，确保数据安全
3. **验证机制**: 严格的数据验证，防止无效数据

### 兼容性保证

1. **渐进式迁移**: 支持新旧数据源并存
2. **降级方案**: 在数据库异常时回退到硬编码数据
3. **版本控制**: 记录数据结构版本，支持平滑升级

### 性能优化

1. **懒加载**: 按需加载模板数据
2. **缓存策略**: 合理的缓存机制减少数据库压力
3. **索引优化**: 为查询字段添加适当索引

## 总结

病历管理模块是对现有患者病历功能的重要增强，通过将硬编码数据动态化，大大提升了系统的灵活性和可维护性。该模块遵循现有的技术架构，确保与系统的无缝集成，为诊所提供更加个性化和专业的病历管理解决方案。