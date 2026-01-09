# 患者病历功能实施计划

## 实施概述

本实施计划将患者病历功能的开发分解为具体的编码任务，每个任务都是可独立执行的代码实现步骤。所有任务都遵循现有的代码架构和设计模式，确保与系统的无缝集成。

### 新增：病历管理模块

基于用户需求，新增病历管理模块，将现有硬编码的疾病类型数据动态化管理：

**核心功能：**
- 将现有的牙科疾病、全身疾病、过敏类型从硬编码转为数据库存储
- 提供病历管理界面，支持疾病类型的增删改查
- 一键初始化功能，将预设疾病数据导入数据库
- 集成到业务管理页面，位于采购管理下方
- 病历表单动态从数据库获取疾病选项

**技术架构：**
- 扩展medical_record_items表，支持模板数据存储
- 创建MedicalRecordTemplate模型管理疾病类型
- 新增病历管理界面和编辑对话框
- 修改现有病历表单，使用数据库数据源

## 任务列表

- [x] 1. 创建数据模型和数据库表结构




  - 创建PatientMedicalRecord和MedicalRecordItem模型类
  - 实现数据库表结构定义（SQLite和MySQL）
  - 添加数据模型的序列化和反序列化方法
  - _需求: 1.1, 6.1, 6.2, 6.3_

- [x] 1.1 创建PatientMedicalRecord模型


  - 在windows_app/lib/models/目录下创建patient_medical_record.dart文件
  - 实现包含所有病历字段的数据模型（包括全身疾病既往史和口腔疾病既往史）
  - 添加selected_dental_condition_date字段用于关联牙齿状况
  - 添加fromMap和toMap方法用于数据库操作
  - 实现copyWith方法用于数据更新
  - _需求: 1.1, 6.1_

- [x] 1.2 创建MedicalRecordItem模型


  - 在windows_app/lib/models/目录下创建medical_record_item.dart文件
  - 实现病历详细项目的数据模型
  - 支持不同类别的病历项目（牙科疾病、全身疾病、过敏史）
  - _需求: 2.1, 3.1, 6.2_

- [x] 1.3 创建数据库表结构定义


  - 在windows_app/lib/models/schemas/sqlite_schema.dart中添加SQLitePatientMedicalRecordsTableSchema和SQLiteMedicalRecordItemsTableSchema类
  - 在windows_app/lib/models/schemas/mysql_schema.dart中添加MySQLPatientMedicalRecordsTableSchema和MySQLMedicalRecordItemsTableSchema类
  - 更新windows_app/lib/models/schemas/table_schema.dart工厂类，在getSchema方法中添加'patient_medical_records'和'medical_record_items'表的支持
  - 确保表结构支持双数据源架构和字段一致性
  - _需求: 6.1, 6.2, 6.3, 8.3_

- [x] 1.4 创建预定义疾病类型常量


  - 创建dental_disease_types.dart文件定义牙科疾病类型
  - 创建systemic_disease_types.dart文件定义全身疾病类型
  - 创建allergy_types.dart文件定义过敏类型
  - _需求: 2.1, 2.2, 3.1, 3.2_

- [x] 1.5 创建牙齿状况集成工具类


  - 在windows_app/lib/utils/目录下创建dental_condition_integration.dart文件
  - 实现解析患者dental_condition字段的方法
  - 实现根据日期获取特定牙齿状况记录的方法
  - 实现获取所有可用牙齿状况日期列表的方法
  - _需求: 2.4, 4.4_

- [-] 2. 实现数据访问层


  - 创建MedicalRecordDataSource抽象接口
  - 实现SQLite和MySQL数据源
  - 集成到现有的数据源架构中
  - _需求: 6.3, 8.2, 8.3_

- [x] 2.1 创建MedicalRecordDataSource接口


  - 在windows_app/lib/data_sources/目录下创建medical_record_data_source.dart文件
  - 定义MedicalRecordDataSource抽象类，包含所有病历数据操作方法
  - 定义病历主记录和病历项目的CRUD操作接口
  - 包含搜索、分页和统计功能的接口定义
  - _需求: 6.3, 8.2_

- [x] 2.2 实现SQLite数据源


  - 在medical_record_data_source.dart中实现SqliteMedicalRecordDataSource类
  - 实现patient_medical_records表的所有CRUD操作
  - 实现medical_record_items表的所有CRUD操作
  - 实现搜索、分页和关联查询功能
  - 遵循现有的SQLite数据源实现模式（参考PatientDataSource）
  - _需求: 6.3, 8.3_

- [x] 2.3 实现MySQL数据源


  - 在medical_record_data_source.dart中实现MySqlMedicalRecordDataSource类
  - 实现patient_medical_records表的所有CRUD操作（处理MySQL特有的数据类型）
  - 实现medical_record_items表的所有CRUD操作
  - 处理MySQL的Blob类型和编码问题（参考现有的MySqlPatientDataSource）
  - 实现动态连接获取机制（使用connectionGetter模式）
  - _需求: 6.3, 8.3_

- [x] 3. 创建业务逻辑层Provider




  - 实现MedicalRecordProvider状态管理
  - 集成权限控制和缓存机制
  - 实现数据验证和错误处理
  - _需求: 7.1, 7.2, 8.2_

- [x] 3.1 创建MedicalRecordProvider基础结构


  - 在windows_app/lib/providers/目录下创建medical_record_provider.dart文件
  - 实现基础的Provider类结构和状态管理
  - 集成双数据源支持和权限控制
  - _需求: 7.1, 7.2, 8.2_

- [x] 3.2 实现病历CRUD操作方法


  - 在MedicalRecordProvider中实现创建、读取、更新、删除病历的方法
  - 添加数据验证和错误处理逻辑
  - 实现缓存机制提升性能
  - _需求: 1.1, 6.5, 8.2_

- [x] 3.3 实现病历项目管理方法


  - 添加病历项目的增删改查方法
  - 实现批量操作和事务处理
  - 支持不同类别项目的分类管理
  - _需求: 2.1, 3.1, 6.2_
-

- [-] 4. 创建病历表单组件


  - 实现分步骤的病历编辑表单
  - 创建牙科疾病和全身疾病选择组件
  - 实现表单验证和数据绑定
  - _需求: 2.1, 2.2, 3.1, 4.1_

- [x] 4.1 创建病历表单对话框


  - 在windows_app/lib/screens/目录下创建medical_record_form_dialog.dart文件
  - 实现分步骤表单界面
  - 集成现有的UI主题和样式
  - _需求: 4.1, 4.2, 8.4_

- [x] 4.2 实现基本信息步骤表单


  - 创建病历日期、主诉、现病史输入组件
  - 实现表单验证和实时保存
  - 添加用户友好的输入提示
  - _需求: 4.1, 4.2, 4.5_

- [x] 4.3 实现既往史和过敏史步骤表单


  - 创建全身疾病既往史多选组件
  - 创建口腔疾病既往史多选组件（复用牙科疾病类型）
  - 实现过敏史分类录入（药物、食物）
  - 添加"其它"选项和自定义输入框
  - _需求: 2.1, 3.1, 3.2, 3.4, 4.3_

- [x] 4.4 实现牙科专业检查步骤表单


  - 创建牙科疾病多选组件
  - 实现口腔检查记录输入
  - 添加牙齿状况关联选择器（选择现有的牙齿状况记录日期）
  - _需求: 2.1, 2.2, 2.4, 4.4_

- [x] 4.5 实现诊断和治疗步骤表单






  - 创建诊断结论输入组件
  - 实现治疗方案制定界面
  - 添加注意事项和医嘱记录
  - _需求: 4.5, 4.6, 4.7_

- [x] 5. 集成病历标签页到患者详情页面




  - 修改PatientDetailScreen添加病历标签页
  - 实现病历列表和详情显示
  - 确保与现有标签页的一致性
  - _需求: 1.1, 1.2, 1.3, 8.4_

- [x] 5.1 修改患者详情页面结构





  - 更新windows_app/lib/screens/patient_detail_screen.dart文件
  - 在TabController中添加病历标签页
  - 调整标签页顺序和布局
  - _需求: 1.1, 1.2, 8.4_

- [x] 5.2 实现病历标签页内容





  - 创建_buildMedicalRecordsTab方法
  - 实现病历列表显示和空状态处理
  - 添加新建病历和操作按钮
  - _需求: 1.3, 1.4, 8.4_

- [x] 5.3 实现病历详情显示组件




  - 创建病历详情卡片组件
  - 实现病历信息的结构化显示
  - 集成牙齿状况只读显示（复用现有的_buildReadOnlyCrossChart组件）
  - 添加编辑和删除操作
  - _需求: 4.1, 4.2, 8.4_

- [-] 6. 实现PDF导出功能



  - 创建PDF生成器类
  - 实现标准化的病历PDF布局
  - 集成文件保存和用户提示
  - _需求: 5.1, 5.2, 5.3, 5.4_

- [x] 6.1 创建PDF导出器类


  - 在windows_app/lib/utils/目录下创建medical_record_pdf_exporter.dart文件
  - 使用pdf包实现PDF生成功能
  - 设计标准化的病历PDF模板
  - _需求: 5.1, 5.2, 5.4_

- [x] 6.2 实现PDF内容布局




  - 创建患者基本信息部分
  - 实现病历内容的结构化布局
  - 集成关联的牙齿状况图表到PDF中
  - 添加诊所标识和签名区域
  - _需求: 5.2, 5.3, 5.4_

- [x] 6.3 集成PDF导出到UI





  - 在病历详情页面添加导出按钮
  - 实现文件保存对话框
  - 添加导出成功/失败提示
  - _需求: 5.1, 5.5, 5.6_

- [-] 7. 实现病历权限控制和安全功能



  - 实现基于医生身份的病历权限控制
  - 添加创建医生字段到病历数据模型
  - 实现操作日志记录
  - 添加数据验证和安全检查
  - _需求: 7.1, 7.2, 7.3, 7.4_

- [x] 7.1 扩展病历数据模型支持医生权限控制


  - 在PatientMedicalRecord模型中添加created_by_doctor字段，存储创建病历的医生姓名
  - 更新windows_app/lib/models/patient_medical_record.dart，添加createdByDoctor属性
  - 更新fromMap和toMap方法，支持新字段的序列化和反序列化
  - 更新copyWith方法，支持createdByDoctor字段的更新
  - _需求: 7.1, 7.2_

- [x] 7.2 更新数据库表结构支持医生字段


  - 修改windows_app/lib/models/schemas/sqlite_schema.dart中的SQLitePatientMedicalRecordsTableSchema类
  - 修改windows_app/lib/models/schemas/mysql_schema.dart中的MySQLPatientMedicalRecordsTableSchema类
  - 在patient_medical_records表中添加created_by_doctor字段（VARCHAR类型）
  - 确保SQLite和MySQL表结构定义的一致性
  - _需求: 7.1, 8.3_

- [x] 7.3 更新数据访问层支持医生字段


  - 修改windows_app/lib/data_sources/medical_record_data_source.dart
  - 更新SqliteMedicalRecordDataSource和MySqlMedicalRecordDataSource类
  - 在所有CRUD操作中支持created_by_doctor字段的处理
  - 添加基于医生过滤的查询方法（getDoctorMedicalRecords等）
  - _需求: 7.1, 6.3_

- [x] 7.4 实现MedicalRecordProvider权限控制逻辑


  - 修改windows_app/lib/providers/medical_record_provider.dart
  - 集成UserProvider，获取当前登录用户信息
  - 实现权限检查逻辑：管理员拥有所有权限，医生只能编辑/删除自己创建的病历
  - 在创建病历时自动设置created_by_doctor字段为当前登录医生姓名
  - 在更新和删除操作中添加权限验证
  - 实现基于权限的数据过滤（医生可查看所有病历，但只能操作自己的）
  - _需求: 7.1, 7.2, 8.2_

- [x] 7.5 更新病历表单界面支持权限控制



  - 检查windows_app/lib/screens/medical_record_form_dialog.dart是否需要修改
  - 根据用户权限显示/隐藏编辑和删除按钮
  - 在病历详情显示中添加创建医生信息
  - 确保表单提交时正确设置创建医生字段
  - _需求: 7.1, 4.1_

- [ ] 7.6 实现操作日志记录


  - 在关键操作中添加日志记录
  - 记录创建、修改、删除操作
  - 包含操作用户和时间信息
  - 记录权限验证结果和失败原因
  - _需求: 7.3, 7.4_

- [ ] 7.7 添加数据验证和安全检查
  - 实现表单数据验证规则
  - 添加SQL注入防护
  - 实现敏感数据处理
  - 添加权限验证的安全检查
  - _需求: 7.5, 8.1_

- [ ] 8. 数据库迁移和初始化
  - 更新数据库初始化脚本
  - 创建数据迁移脚本
  - 确保向后兼容性
  - _需求: 6.1, 6.6, 8.3_

- [ ] 8.1 更新数据库初始化脚本
  - 修改windows_app/lib/providers/database_provider.dart
  - 在_createDatabase和_createMySQLTables方法的tableNames数组中添加'patient_medical_records'和'medical_record_items'
  - 确保新表通过TableSchemaFactory正确创建
  - 更新数据库版本号（如果需要）
  - _需求: 6.1, 8.3_

- [ ] 8.2 创建数据库迁移脚本
  - 实现从旧版本到新版本的数据迁移
  - 处理表结构变更和数据转换
  - 确保迁移过程的安全性
  - _需求: 6.6, 8.3_

- [ ] 8.3 集成到现有数据库架构
  - 验证TableSchemaFactory中新表的正确注册
  - 测试SQLite和MySQL双数据源的表创建
  - 验证表结构的一致性和外键约束
  - 测试数据库连接和基本CRUD操作
  - _需求: 6.3, 8.2, 8.3_

- [ ] 9. 测试和优化
  - 创建单元测试
  - 进行集成测试
  - 性能优化和错误处理完善
  - _需求: 8.1, 8.5_

- [ ]* 9.1 创建单元测试
  - 为数据模型创建测试用例
  - 测试数据访问层的CRUD操作
  - 验证业务逻辑的正确性
  - _需求: 8.1_

- [ ]* 9.2 创建集成测试
  - 测试完整的病历创建流程
  - 验证PDF导出功能
  - 测试权限控制机制
  - _需求: 8.1, 8.5_

- [ ]* 9.3 性能优化和错误处理
  - 优化数据库查询性能
  - 完善错误处理和用户提示
  - 添加加载状态和进度指示
  - _需求: 8.5_

- [-] 10. 病历管理模块开发



  - 创建病历管理界面和功能
  - 实现疾病类型数据库管理
  - 集成到业务管理页面
  - _需求: 新增需求_

- [x] 10.1 创建病历管理数据模型


  - 在windows_app/lib/models/目录下创建medical_record_template.dart文件
  - 实现MedicalRecordTemplate模型，用于存储疾病类型等模板数据
  - 支持牙科疾病、全身疾病、过敏类型三大类别
  - 支持层级结构（主疾病和子类型）
  - 添加fromMap和toMap方法用于数据库操作
  - _需求: 新增需求_

- [x] 10.2 扩展medical_record_items表结构


  - 修改medical_record_items表结构，添加is_template字段标识是否为模板数据
  - 添加parent_name字段支持疾病层级结构（如"龋齿"下的"浅龋"等）
  - 更新windows_app/lib/models/schemas/sqlite_schema.dart中的SQLiteMedicalRecordItemsTableSchema类
  - 更新windows_app/lib/models/schemas/mysql_schema.dart中的MySQLMedicalRecordItemsTableSchema类
  - 确保SQLite和MySQL表结构定义的一致性
  - _需求: 新增需求_

- [x] 10.3 创建病历管理数据访问层



  - 在medical_record_data_source.dart中添加模板数据管理方法
  - 实现模板数据的CRUD操作（创建、读取、更新、删除）
  - 实现初始化预设数据的方法
  - 支持按类别查询模板数据
  - _需求: 新增需求_

- [x] 10.4 扩展MedicalRecordProvider功能








  - 在MedicalRecordProvider中添加模板数据管理方法
  - 实现loadTemplateData、createTemplate、updateTemplate、deleteTemplate方法
  - 实现initializeDefaultTemplates方法，用于初始化预设疾病数据
  - 添加模板数据缓存机制
  - _需求: 新增需求_

- [x] 10.5 创建病历管理界面








  - 在windows_app/lib/screens/目录下创建medical_record_management_screen.dart文件
  - 实现病历管理主界面，包含三个标签页：牙科疾病、全身疾病、过敏类型
  - 每个标签页显示对应类别的疾病列表
  - 提供添加、编辑、删除疾病类型的功能
  - 添加初始化按钮，一键导入预设疾病数据
  - _需求: 新增需求_

- [x] 10.6 实现疾病类型编辑对话框


  - 创建disease_type_edit_dialog.dart文件
  - 实现疾病类型的添加和编辑表单
  - 支持设置疾病名称、类别、父级疾病（可选）、详细描述
  - 添加表单验证和重复检查
  - _需求: 新增需求_

- [x] 10.7 集成病历管理到业务管理页面


  - 修改windows_app/lib/screens/home_screen.dart中的_BusinessManagementScreen
  - 在采购管理和用户管理标签页之间添加病历管理标签页
  - 更新_tabTitles数组为['财务管理', '采购管理', '病历管理', '用户管理']
  - 更新TabBarView，在正确位置添加MedicalRecordManagementScreen
  - 更新图标选择逻辑，为病历管理添加合适的图标（如Icons.medical_information_rounded）
  - _需求: 新增需求_

- [x] 10.8 修改病历表单使用数据库数据


  - 修改medical_record_form_dialog.dart中的疾病选择逻辑
  - 将硬编码的DentalDiseaseTypes、SystemicDiseaseTypes、AllergyTypes替换为从数据库获取
  - 在表单初始化时加载模板数据
  - 更新疾病选择组件，使用数据库中的数据
  - _需求: 新增需求_

- [ ] 10.9 实现数据迁移和初始化



  - 创建数据迁移脚本，将现有硬编码数据导入数据库
  - 在DatabaseProvider中添加病历管理相关表的初始化
  - 实现首次运行时自动初始化预设疾病数据的逻辑
  - 确保数据迁移的向后兼容性
  - _需求: 新增需求_

- [ ] 10.10 优化和测试病历管理功能


  - 测试病历管理的所有CRUD操作
  - 验证初始化功能的正确性
  - 测试病历表单与数据库数据的集成
  - 优化界面交互和用户体验
  - 添加错误处理和用户提示
  - _需求: 新增需求_

- [ ] 11. 文档和部署准备
  - 更新用户文档
  - 创建部署指南
  - 准备发布说明
  - _需求: 8.6_

- [ ]* 11.1 更新用户文档
  - 编写病历功能使用说明
  - 编写病历管理功能使用说明
  - 创建操作截图和示例
  - 更新系统帮助文档
  - _需求: 8.6_

- [ ]* 11.2 创建部署指南
  - 编写数据库升级指南
  - 创建功能配置说明
  - 准备故障排除文档
  - _需求: 8.6_

- [ ] 12. 患者管理权限优化
  - 优化患者管理的权限控制机制
  - 实现基于医生身份的患者信息编辑权限
  - 特殊处理牙齿状况的编辑权限
  - _需求: 新增需求_

- [ ] 12.1 分析现有患者管理权限结构
  - 检查windows_app/lib/providers/patient_provider.dart中的现有权限控制逻辑
  - 分析windows_app/lib/screens/patient_detail_screen.dart中的权限检查机制
  - 识别需要修改的权限控制点
  - 确定患者数据模型中是否已有创建医生字段
  - _需求: 新增需求_

- [ ] 12.2 实现患者基本信息编辑权限控制
  - 修改PatientProvider中的权限检查逻辑
  - 实现基于医生身份的患者信息编辑权限：医生只能编辑自己创建的患者信息
  - 管理员保持所有权限不受限制
  - 所有医生都可以查看所有患者的基本信息
  - 在患者编辑界面根据权限显示/隐藏编辑功能
  - _需求: 新增需求_

- [ ] 12.3 实现牙齿状况特殊权限处理
  - 在患者详情页面的牙齿状况标签页中实现特殊权限逻辑
  - 允许所有医生（包括非创建者）编辑和删除任何患者的牙齿状况记录
  - 修改windows_app/lib/screens/patient_detail_screen.dart中牙齿状况相关的权限检查
  - 确保牙齿状况的添加、编辑、删除操作不受患者创建医生限制
  - _需求: 新增需求_

- [ ] 12.4 更新患者界面权限显示
  - 修改患者列表和详情页面，根据权限显示操作按钮
  - 在患者基本信息编辑区域添加权限提示
  - 为牙齿状况区域添加特殊权限说明
  - 确保用户界面清晰显示当前用户的操作权限
  - _需求: 新增需求_

- [ ] 12.5 测试患者管理权限功能
  - 测试管理员的完整权限功能
  - 测试医生对自己创建患者的编辑权限
  - 测试医生对其他医生创建患者的只读权限
  - 测试所有医生对牙齿状况的编辑权限
  - 验证权限控制的安全性和正确性
  - _需求: 新增需求_

## 实施注意事项

### 代码质量要求
- 所有代码必须遵循现有的Dart代码规范
- 使用现有的错误处理模式和日志记录方式
- 确保代码的可读性和可维护性

### 数据安全要求
- 所有数据库操作必须使用参数化查询防止SQL注入
- 敏感医疗数据需要适当的访问控制
- 实现操作审计和日志记录

### 性能要求
- 大量数据的分页加载和懒加载
- 合理使用缓存机制提升响应速度
- 优化数据库查询和索引设计

### 兼容性要求
- 确保与现有功能模块的兼容性
- 支持SQLite和MySQL双数据源
- 保持向后兼容性，不影响现有数据

### 用户体验要求
- 提供直观的用户界面和操作流程
- 实现合理的表单验证和错误提示
- 确保功能的响应性和稳定性