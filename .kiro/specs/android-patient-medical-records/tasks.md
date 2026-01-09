# 安卓端患者病历查看和PDF导出功能实施计划

## 项目概述

基于Windows端的病历功能实现，为安卓端添加患者病历查看和PDF导出功能。此功能将集成到现有的患者详情页面中，提供只读的病历查看和PDF导出能力。

## 详细任务列表

### 1. 数据模型层 (D:\Data\android\dentist_app\lib\models)

- [x] 1.1 创建患者病历数据模型
  - 创建文件 `D:\Data\android\dentist_app\lib\models\patient_medical_record.dart`
  - 从Windows端复制 `windows_app/lib/models/patient_medical_record.dart`
  - 实现PatientMedicalRecord类，包含所有病历字段
  - 实现fromMap、toMap、copyWith方法
  - 添加JSON序列化支持
  - _需求: 病历数据模型_

- [x] 1.2 创建病历项目数据模型
  - 创建文件 `D:\Data\android\dentist_app\lib\models\medical_record_item.dart`
  - 从Windows端复制 `windows_app/lib/models/medical_record_item.dart`
  - 实现MedicalRecordItem类
  - 实现数据序列化方法
  - _需求: 病历项目数据模型_

- [x] 1.3 创建病历模板数据模型
  - 创建文件 `D:\Data\android\dentist_app\lib\models\medical_record_template.dart`
  - 从Windows端复制 `windows_app/lib/models/medical_record_template.dart`
  - 实现MedicalRecordTemplate类用于疾病类型管理
  - 包含DefaultTemplateInitializer类提供预设疾病数据
  - _需求: 疾病类型模板_

### 2. 数据库架构层 (D:\Data\android\dentist_app\lib\models\schemas)

- [x] 2.1 创建SQLite病历表结构
  - 修改文件 `D:\Data\android\dentist_app\lib\models\schemas\sqlite_schema.dart`
  - 添加SQLitePatientMedicalRecordsTableSchema类
  - 定义patient_medical_records表结构
  - 添加SQLiteMedicalRecordItemsTableSchema类
  - 定义medical_record_items表结构
  - _需求: SQLite表结构_

- [x] 2.2 创建MySQL病历表结构
  - 修改文件 `D:\Data\android\dentist_app\lib\models\schemas\mysql_schema.dart`
  - 添加MySQLPatientMedicalRecordsTableSchema类
  - 添加MySQLMedicalRecordItemsTableSchema类
  - 处理MySQL特有的数据类型和编码问题
  - _需求: MySQL表结构_

- [x] 2.3 更新表结构工厂
  - 修改文件 `D:\Data\android\dentist_app\lib\models\schemas\table_schema.dart`
  - 在TableSchemaFactory.getSchema方法中添加patient_medical_records表支持
  - 在TableSchemaFactory.getSchema方法中添加medical_record_items表支持
  - 确保双数据源架构的兼容性
  - _需求: 表结构工厂_

### 3. 数据访问层 (D:\Data\android\dentist_app\lib\data_sources)

- [x] 3.1 创建病历数据源接口
  - 创建文件 `D:\Data\android\dentist_app\lib\data_sources\medical_record_data_source.dart`
  - 从Windows端复制 `windows_app/lib/data_sources/medical_record_data_source.dart`
  - 定义MedicalRecordDataSource抽象类
  - 包含核心查询方法接口定义
  - _需求: 数据源接口_

- [x] 3.2 实现SQLite数据源
  - 在medical_record_data_source.dart中实现SqliteMedicalRecordDataSource类
  - 继承MedicalRecordDataSource抽象类
  - 实现getPatientMedicalRecords方法
  - 实现getMedicalRecord方法
  - 实现getMedicalRecordItems方法
  - 实现getMedicalRecordWithItems方法
  - 处理SQLite特有的数据类型转换
  - _需求: SQLite数据源_

- [x] 3.3 实现MySQL数据源
  - 在medical_record_data_source.dart中实现MySqlMedicalRecordDataSource类
  - 继承MedicalRecordDataSource抽象类
  - 实现所有查询方法
  - 处理MySQL的Blob类型和编码问题
  - 实现动态连接获取机制
  - 处理中文编码和字符集问题
  - _需求: MySQL数据源_

### 4. 业务逻辑层 (D:\Data\android\dentist_app\lib\providers)

- [x] 4.1 创建病历Provider基础结构
  - 创建文件 `D:\Data\android\dentist_app\lib\providers\medical_record_provider.dart`
  - 从Windows端复制 `windows_app/lib/providers/medical_record_provider.dart`
  - 实现MedicalRecordProvider类继承ChangeNotifier
  - 实现双数据源支持（SQLite/MySQL）
  - 添加基础状态管理变量
  - _需求: Provider基础结构_

- [x] 4.2 实现核心查询方法
  - 在MedicalRecordProvider中实现getPatientMedicalRecords方法
  - 实现getMedicalRecord方法
  - 实现getMedicalRecordDetails方法
  - 实现hasMedicalRecords方法
  - 添加错误处理和状态管理
  - _需求: 核心查询功能_

- [x] 4.3 集成权限控制 (跳过 - Android端仅需查看功能)
  - 集成UserProvider获取当前用户信息
  - 实现基于医生身份的查看权限
  - 管理员可查看所有病历，医生可查看所有但有操作限制
  - 添加权限检查方法
  - _需求: 权限控制_

- [x] 4.4 实现缓存和状态管理
  - 实现病历数据的内存缓存机制
  - 提供加载状态管理（isLoading, hasError等）
  - 实现错误状态处理和用户提示
  - 添加数据刷新和缓存清理方法
  - _需求: 缓存和状态管理_

### 5. 工具类和辅助功能

- [x] 5.1 创建牙齿状况集成工具
  - 创建文件 `D:\Data\android\dentist_app\lib\utils\dental_condition_integration.dart`
  - 从Windows端复制 `windows_app/lib/utils/dental_condition_integration.dart`
  - 实现DentalConditionIntegration类
  - 实现parseDentalCondition静态方法
  - 实现getDentalConditionByDate静态方法
  - 实现getAvailableDates静态方法
  - 实现formatDateForDisplay静态方法
  - _需求: 牙齿状况集成_

- [x] 5.2 创建PDF导出工具
  - 创建文件 `D:\Data\android\dentist_app\lib\utils\medical_record_pdf_exporter.dart`
  - 从Windows端复制 `windows_app/lib/utils/medical_record_pdf_exporter.dart`
  - 实现MedicalRecordPdfExporter类
  - 实现中文字体支持和初始化
  - 实现PDF模板布局设计
  - 实现患者信息和病历内容渲染
  - 实现牙齿状况图表集成
  - 实现文件生成和保存功能
  - _需求: PDF导出功能_

- [x] 5.3 添加中文字体资源
  - 复制字体文件到 `D:\Data\android\dentist_app\assets\fonts\NotoSansSC-Regular.ttf`
  - 更新pubspec.yaml添加字体资源配置
  - 确保PDF中文字体正确显示
  - _需求: 中文字体支持_

### 6. 用户界面层 (D:\Data\android\dentist_app\lib\screens)

- [x] 6.1 修改患者详情页面添加病历标签页
  - 修改文件 `D:\Data\android\dentist_app\lib\screens\patient_detail_screen.dart`
  - 在现有TabController中添加"病历记录"标签页
  - 更新标签页数量和标题数组
  - 在TabBarView中添加病历标签页内容
  - 导入MedicalRecordProvider依赖
  - _需求: 患者详情页面集成_

- [x] 6.2 实现病历标签页内容
  - 在patient_detail_screen.dart中添加_buildMedicalRecordsTab方法
  - 实现病历列表显示逻辑
  - 添加_buildMedicalRecordCard方法构建病历卡片
  - 添加_buildEmptyMedicalRecordsState方法构建空状态显示
  - 添加_viewMedicalRecordDetails方法处理病历详情查看
  - 集成加载状态和错误处理
  - _需求: 病历标签页内容_

- [x] 6.3 创建病历详情页面
  - 创建文件 `D:\Data\android\dentist_app\lib\screens\medical_record_detail_screen.dart`
  - 实现MedicalRecordDetailScreen类
  - 创建AppBar包含标题和PDF导出按钮
  - 实现患者基本信息卡片显示
  - 实现病历基本信息显示（编号、日期、医生）
  - 实现主诉和现病史显示
  - 实现既往史信息显示（全身疾病、口腔疾病）
  - 实现过敏史信息显示
  - 实现口腔检查记录显示
  - 实现诊断和治疗方案显示
  - 实现注意事项显示
  - _需求: 病历详情页面_
