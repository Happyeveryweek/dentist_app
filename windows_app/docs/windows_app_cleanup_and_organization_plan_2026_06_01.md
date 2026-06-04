# Windows App 代码残留清理与目录整理方案

日期：2026-06-01

范围：`D:\Data\android_project\dentist_app\windows_app`

## 目标

1. 清掉 `windows_app` 内部真正无引用、无职责、只剩历史残影的代码。
2. 让 `features/` 里的小文件按职责簇收口，而不是按行数机械合并。
3. 让 `data_sources/` 从“按文件平铺”变成“按模块分类”，但保留 SQLite / MySQL 分离。
4. 不改 UI、不改数据库 schema、不做大重构。

## 总原则

### 1. 不用行数当硬标准

- 小于 100 行不等于应该合并。
- 小于 50 行也不等于应该删除。
- 只有满足下面至少一条，才进入“合并或收口”候选：
  - 和同一页面/同一职责簇总是一起修改。
  - 只是很薄的 wrapper / barrel / 转发层。
  - 独立存在没有明显复用价值。
  - 只是把同一组 UI 组件拆成了过多同级小文件。

### 2. 先看职责，再看长度

优先保留这些文件类型：

- `service`
- `helper`
- `model`
- 数据源接口文件
- 能通过构造函数清楚表达依赖的独立 widget

优先合并这些文件类型：

- 纯 export 文件
- 单一页面内部的轻量 UI 片段
- 只服务同一职责簇的 wrapper 文件
- 只为了拆行数而拆出的碎片 widget

### 3. 只清理 `windows_app` 内部代码

- 不处理根目录的安卓端旧工程。
- 不处理你手动保留的 `windows_app22`、`android_lib_bak`、`windows_lib_bak`、`backups`。
- 只判断 `windows_app` 内部是否存在无引用残留、重复实现、过细碎片。

## 历史残留清理流程

### 第 1 步：先列候选

候选来源只看三类：

- 文件名明显像备份、副本、示例、临时文件。
- 被 barrel/export 文件转发但外部已经不再引用的文件。
- 和现有主流程重复、但已经没有实际入口的旧实现。

### 第 2 步：查引用

每个候选文件必须先确认：

- 是否仍被 `import`。
- 是否仍被某个 `export` 转发。
- 是否仍被页面入口、Provider、Service、Data Source 实际调用。
- 是否只是注释、历史文档、备份文件里的残留名字。

### 第 3 步：分类处理

分成三类：

- **保留**：仍被引用，或者职责清楚。
- **合并**：职责过细，但仍在当前主流程里有用。
- **删除**：无引用、无入口、无独立职责，且确认不是备份用途。

### 第 4 步：删除前确认

删除只在满足下面条件时进行：

- `windows_app` 内没有实际引用。
- 不是文档说明中还保留的兼容层。
- 不是用户明确保留的备份副本。
- 删除后不会引发 import / export 断链。

## `features/` 整理方案

### 总体策略

`features/` 不做“全部合并成大文件”，而是做“职责簇收口”。

也就是：

- 同一页面同一块区域里的小组件，可以合并成一个更清楚的 section 文件。
- 不同职责的组件不要因为行数少就硬合并。
- service / helper / model 保持分层，不要为了“文件少”塞回主 screen。

### 建议收口规则

#### 应该优先合并的情况

- 一个模块里出现多个 20-60 行的小 widget，且它们只用于同一页面同一区域。
- 多个文件只是标题、按钮、空状态、简单 cell、简单卡片的分拆。
- 一个 barrel 文件旁边还有同类薄 wrapper，可以合并成更少的 section 文件。

#### 应该保留的情况

- 逻辑明确的 service。
- 负责状态计算、缓存、权限、校验的 helper。
- 明显可复用的 widget。
- 跟主页面解耦后依赖关系更清楚的独立 dialog / section。

### 当前最值得收口的模块

1. `features/patients`
2. `features/financial`
3. `features/settings`

### 当前不建议大动的模块

1. `features/appointments`
2. `features/purchases`
3. `features/users`
4. `features/medical_records`
5. `features/materials`

原因：

- 这些模块里很多小文件已经是单职责文件，不是纯碎片。
- 强行合并容易把清晰边界弄乱。
- 真正该收的是同一职责簇，不是同一目录下所有小文件。

### 具体执行口径

#### `features/patients`

- 合并方向：详情页相关的过细展示碎片、小的装饰型 widget、只服务单一 detail 区域的 wrapper。
- 保留方向：service、state、query、表单状态、材料服务、搜索条件服务。

#### `features/financial`

- 合并方向：表格 cell、compact tag、统计块、空状态、分页按钮这类高度同类的小 UI。
- 保留方向：权限、缓存、连接、聚合、数据计算 helper。

#### `features/settings`

- 合并方向：备份/恢复相关的 UI 小块、数据源设置相关的 UI 小块、几乎只做外壳的 wrapper。
- 保留方向：备份 service、结构检测 service、数据源同步 service、状态 helper。

## `data_sources/` 整理方案

### 结论

`data_sources` **不应该合并成更少的大文件**，应该改成**按模块分类**。

SQLite 和 MySQL 继续分开，不能为了“文件数少”揉成一个条件分支巨型文件。

### 推荐目录结构

```text
lib/data_sources/
  common/
    base_mysql_data_source.dart

  patients/
    patient_data_source.dart
    sqlite_patient_data_source.dart
    mysql_patient_data_source.dart

  financial/
    financial_data_source.dart
    sqlite_financial_data_source.dart
    mysql_financial_data_source.dart

  medical_records/
    medical_record_data_source.dart
    sqlite_medical_record_data_source.dart
    mysql_medical_record_data_source.dart

  appointments/
    appointment_data_source.dart
    sqlite_appointment_data_source.dart
    mysql_appointment_data_source.dart

  materials/
    material_data_source.dart
    sqlite_material_data_source.dart
    mysql_material_data_source.dart

  purchases/
    purchase_data_source.dart
    sqlite_purchase_data_source.dart
    mysql_purchase_data_source.dart

  users/
    user_data_source.dart
    sqlite_user_data_source.dart
    mysql_user_data_source.dart
```

### 数据源整理规则

- 接口文件保留在模块目录下。
- SQLite 实现和 MySQL 实现保留为独立文件。
- 公共基础能力放到 `common/`。
- 共享查询片段优先抽成私有 builder 方法，不优先抽成更细碎的独立文件。

### 不建议的做法

- 不要把所有模块的数据源继续堆在同一层目录。
- 不要把 SQLite / MySQL 合并成一个大文件。
- 不要为了减少文件数，把查询语义又拉回 Provider。

## 建议执行顺序

### 第 1 阶段：历史残留确认

1. 只检查 `windows_app/lib` 内的文件引用。
2. 找出无引用候选。
3. 区分“可删”、“可合并”、“保留”。

### 第 2 阶段：`features/` 收口

1. 先处理 `patients`。
2. 再处理 `financial`。
3. 再处理 `settings`。
4. 其他模块只在发现明显碎片时再处理。

### 第 3 阶段：`data_sources/` 分目录

1. 先建模块目录。
2. 再移动接口与实现文件。
3. 更新 import。
4. 保持 SQLite / MySQL 物理分离不变。

## 验收标准

### 代码层

- `windows_app/lib` 内没有明显无引用残留。
- 不再存在明显“只为拆分而拆分”的碎片文件。
- `features/` 目录的文件命名和职责更集中。
- `data_sources/` 不再平铺成一个大杂烩目录。

### 结构层

- 一个模块应该优先在一个目录里完成定位。
- 同类 UI 文件数量减少，但职责不混乱。
- 数据源层的模块边界比现在清楚。

### 约束层

- 不改 UI 行为。
- 不改数据库 schema。
- 不删除用户明确保留的备份目录。
- 不把“文件少”当作唯一目标。

## 最近进展

### 2026-06-01：`patients` 目录入口收口第一轮

已完成：

- 新增 4 个患者目录聚合入口：
  - `patient_screen_components.dart`
  - `patient_detail_components.dart`
  - `patient_form_components.dart`
  - `patient_material_components.dart`
- 收口了三张主入口页的 import：
  - `patients_screen.dart`
  - `patient_detail_screen.dart`
  - `patient_form_dialog.dart`
- 这轮只做“入口聚合 + import 收口”，不删除旧文件，不改 UI 行为，不改数据库逻辑

下一步：

- 用户先手动执行 `flutter analyze`
- 通过后再继续 `patients` 目录里的下一轮收口
