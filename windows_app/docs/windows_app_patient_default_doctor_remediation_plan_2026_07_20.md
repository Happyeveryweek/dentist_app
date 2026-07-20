# Windows 端患者默认医生硬编码整改实施方案

方案日期：2026-07-20。

状态：待实施。本文是后续代码实施和进度维护的唯一依据；当前仅完成需求确认与调用链核对，尚未修改业务代码或数据库 schema。

## 1. 已确认决策

1. 删除 Windows 端 SQLite 患者表中固定医生 `申向歌` 的默认值，任何新建数据库都不得再把具体医生姓名写入 schema 配置。
2. 新增患者时，默认医生来自当前登录用户已配置的医生姓名，即 `User.doctor`；不得使用全局固定姓名。
3. 当前用户的医生姓名为空时，不得回退到 `申向歌`，也不得把用户名自动当作医生姓名；页面应明确提示先补充或填写医生姓名，不能静默保存空医生。
4. 编辑已有患者时保留患者当前医生，不因打开编辑弹窗而改成当前登录用户的医生姓名。
5. 用户在有权限的情况下仍可修改新增患者表单中的主治医生；“当前用户医生姓名”只负责初始化默认值，不覆盖用户明确填写的非空值。
6. SQLite、MySQL 以及 SQLite → MySQL 同步都必须显式传递患者对象中的医生字段，不能依赖数据库默认值。
7. 登录页继续预填用户名和密码，保留现有“记住用户名密码”及保存后自动回填行为。
8. 不增加首次登录强制改密状态，不修改默认管理员首次登录规则。
9. 不修改 Android 端。

## 2. 当前实现与问题证据

### 2.1 SQLite schema 写死具体医生

`lib/models/schemas/sqlite_schema.dart` 的 `SQLitePatientsTableSchema.columnDefinitions` 当前包含：

```dart
'doctor': 'VARCHAR(100) DEFAULT \'申向歌\'',
```

该定义会进入新数据库的 `CREATE TABLE patients`。只要任一写入遗漏 `doctor`，SQLite 就会静默写入固定医生，造成患者归属、权限过滤和统计口径错误。

MySQL 患者表当前使用 `DEFAULT NULL`，没有写入 `申向歌`，本轮不修改 MySQL schema。

### 2.2 表单已有动态赋值，但规则不完整

`lib/features/patients/widgets/patient_form_dialog.dart` 的新增患者路径已经调用 `_setDefaultDoctor()`：

1. 优先读取 `currentUser.doctor`。
2. 当前用户角色为医生且 `doctor` 为空时，回退到 `currentUser.username`。
3. 解析失败或没有当前用户时写入空字符串。

这与已确认规则仍有两处差异：用户名不等于医生姓名，且空医生仍可能进入保存链路。

同文件的 `_getCurrentDoctorName()` 也存在用户名回退，牙齿状况创建医生与患者默认医生可能继续使用不同来源，需要在同一批次统一。

### 2.3 数据层没有最终兜底

当前新增链路为：

```text
PatientFormDialog
  → PatientProvider.addPatient
  → PatientCoreService.addPatient
  → SQLite/MySQL PatientDataSource.createPatient
```

表单会把空医生转换为 `null`，Provider 和 CoreService 随后直接透传。SQLite 现有固定默认值会掩盖这个问题；删除 schema 默认值后，如果表单初始化失败或未来增加非 UI 写入入口，就可能保存空医生。

因此不能只删除 schema 默认值，还必须在患者业务入口增加可测试的赋值与拒绝规则。

### 2.4 既有 SQLite 数据库不会自动移除默认约束

当前数据库结构检测只报告 SQLite 默认值约束差异，并明确保留现有约束。修改 `sqlite_schema.dart` 只能保证新数据库不再带固定默认值，不能清除用户现有数据库中 `patients.doctor` 已保存的 `DEFAULT '申向歌'`。

SQLite 不能直接修改字段默认值；彻底清理既有约束通常需要事务化重建 `patients` 表。这属于数据库 schema 变更／数据迁移，实施前必须单独向主人说明备份、影响和风险并取得确认。

## 3. 目标行为与验收标准

### 3.1 新增患者

1. 打开新增患者弹窗时，等待当前用户信息解析完成后再允许保存。
2. 读取 `currentUser.doctor?.trim()` 作为默认医生。
3. 默认医生非空时写入表单；用户有权限时可以修改。
4. 用户明确填写了非空医生时保留其填写内容，Provider 不覆盖。
5. 表单提交时医生仍为空，则显示明确错误并停止保存。
6. 即使绕过表单直接调用 `PatientProvider.addPatient`，也必须按同一规则补齐医生或拒绝写入。

### 3.2 编辑患者

1. 编辑弹窗继续加载患者已有 `doctor`。
2. 不调用新增患者默认医生初始化，不用当前用户覆盖已有归属。
3. 既有权限规则保持不变，本轮不扩大谁可以编辑患者医生字段。

### 3.3 数据库存储

1. 新建 SQLite 数据库执行 `PRAGMA table_info(patients)` 后，`doctor` 的 `dflt_value` 必须为 `NULL`。
2. 新增患者的 `doctor` 必须由应用显式写入，SQLite 和 MySQL 结果一致。
3. SQLite → MySQL 同步继续携带同一个医生姓名，不二次推断或覆盖。
4. 源码、schema、初始化脚本和新增患者链路中不再出现 `申向歌`。

### 3.4 登录功能不变

1. 登录页仍保留 `admin / 123456` 初始预填。
2. 勾选“记住密码”后，重启应用仍自动回填已保存的用户名和密码。
3. 不新增首次登录标志、强制改密页面或认证状态分支。
4. 本轮差异中不得包含 `login_screen.dart`、`credential_storage_helper.dart`、`password_service.dart` 和用户认证服务的行为修改。

## 4. 实施进度

状态使用：`待实施`、`进行中`、`待确认`、`待人工回归`、`已完成`、`阻塞`、`暂缓`。

| 编号 | 整改项 | 当前状态 | 自动验证 | 人工回归 | 最近更新 | 备注 |
|------|--------|----------|----------|----------|----------|------|
| 0 | 需求边界与现有调用链确认 | 已完成 | 只读检索 schema、表单、Provider、CoreService、SQLite/MySQL 数据源和结构检测逻辑 | 不适用 | 2026-07-20 | 已确认登录预填与记住密码保持不变；尚未运行 Flutter 验证 |
| 1 | 删除新建 SQLite schema 的固定医生默认值 | 待人工回归 | schema 专项测试通过；新建临时 SQLite 表的 `doctor.dflt_value == null` | 未执行 | 2026-07-20 | MySQL schema 专项断言保持可空定义 |
| 2 | 统一新增患者默认医生解析与数据层兜底 | 待人工回归 | 默认医生解析、表单校验专项测试通过；`flutter analyze --no-pub` 待本批最终复核 | 未执行 | 2026-07-20 | 使用当前用户 `doctor`，不回退固定姓名或用户名 |
| 3 | 清理既有 SQLite 数据库的固定默认约束 | 暂缓 | 不适用 | 不适用 | 2026-07-20 | 主人明确要求不迁移既有数据库内容；仅处理新建数据库 schema |
| 4 | 补充 schema、赋值和保存回归测试 | 已完成 | schema、默认医生解析及表单校验专项 16 项通过 | 不适用 | 2026-07-20 | 覆盖 schema 无默认值、医生姓名裁剪及缺失医生拒绝保存 |
| 5 | 静态检查、全量测试与 SQLite/MySQL 人工回归 | 待人工回归 | `flutter analyze --no-pub` 通过；`flutter test --no-pub` 94 项通过 | 未执行 | 2026-07-20 | SQLite／MySQL／登录回归需要在实际运行环境执行 |
| 6 | 进度文档和 ROADMAP 收口 | 已完成 | 本方案与根目录 ROADMAP 已按验证结果同步 | 不适用 | 2026-07-20 | 未将未执行的人工回归标记为完成 |

每完成一个批次，必须在同一次任务中更新本表的状态、验证结果、最近更新和备注，并在第 10 节追加实施记录。

## 5. 批次 0：实施前基线

### 已完成的只读确认

1. 固定姓名仅在 Windows SQLite 患者 schema 中发现一处。
2. 新增患者目前只有 `PatientFormDialog → PatientProvider.addPatient` 这一条现用入口。
3. 编辑患者已经与新增初始化分开，现有患者医生不会被 `_setDefaultDoctor()` 覆盖。
4. SQLite 和 MySQL 数据源都会显式写入 `Patient.toMap()['doctor']`。
5. 结构检测服务不会自动移除既有 SQLite 默认约束。

### 实施当日必须重新执行

```bash
git status --short
rg -n "申向歌|DEFAULT.*doctor|_setDefaultDoctor|_getCurrentDoctorName|addPatient\(|createPatient\(" lib test
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
```

若基线测试仍受既有 `build/test_cache` 冲突影响，先报告实际错误；不得通过删除目录、绕过测试或修改无关代码继续实施。

## 6. 批次 1：删除新建 SQLite schema 固定默认值

### 预计改动

文件：`lib/models/schemas/sqlite_schema.dart`。

将患者医生定义从：

```dart
'doctor': 'VARCHAR(100) DEFAULT \'申向歌\'',
```

改为不包含具体姓名和默认值的类型定义：

```dart
'doctor': 'VARCHAR(100)',
```

不添加新的固定医生常量，不把姓名移动到其他配置、初始化服务或迁移脚本中。

### 测试

新增或补充 schema 专项测试，至少断言：

1. `doctor` 字段定义不包含 `DEFAULT`。
2. `createTableSql` 不包含 `申向歌`。
3. 使用 schema 创建临时 SQLite 数据库后，`PRAGMA table_info(patients)` 中 `doctor.dflt_value == null`。
4. MySQL 患者 schema 仍为现有可空定义，本轮没有意外变化。

### 退出条件

- 新数据库不再写入固定医生默认约束。
- 全仓检索业务源码不再出现 `申向歌`。
- 专项测试通过。

## 7. 批次 2：新增患者按当前用户医生姓名赋值

### 7.1 统一解析规则

在患者模块现有 service/helper 范围内建立一个可测试的解析入口，输入当前 `User`，输出经过 `trim()` 的 `User.doctor`。不要在多个 Widget、Provider 中复制判断。

规则固定为：

```text
currentUser == null                  → 无可用默认医生
currentUser.doctor == null           → 无可用默认医生
currentUser.doctor.trim().isEmpty    → 无可用默认医生
其他情况                             → currentUser.doctor.trim()
```

禁止回退到用户名、`系统管理员`、`申向歌` 或其他全局默认值。

### 7.2 表单初始化

预计修改 `lib/features/patients/widgets/patient_form_dialog.dart`：

1. 仅新增患者时解析默认医生；编辑患者继续读取原数据。
2. 异步解析期间阻止提前保存，避免默认值尚未回填就提交。
3. 默认值写入医生输入框，但不覆盖用户随后明确填写的内容。
4. `_getCurrentDoctorName()` 与新增患者使用同一解析规则，牙齿状况创建医生不得继续回退用户名。
5. 医生字段为空时显示明确校验提示，不提交数据库。
6. 将主治医生字段的“选填”提示调整为符合实际保存规则的文案。

### 7.3 Provider 兜底

预计修改 `lib/providers/patient_provider.dart`：

1. `addPatient` 收到非空 `patient.doctor` 时保留该值。
2. 收到空医生时，使用 Provider 当前绑定的 `UserProvider.currentUser` 解析医生姓名。
3. 当前用户或医生姓名仍不可用时抛出业务语义明确的异常，不能让数据源依赖数据库默认值。
4. 只处理新增患者；`updatePatient` 不自动改写医生。

数据源继续只负责持久化，不把 `UserProvider` 下沉到 SQLite/MySQL 数据源。

### 7.4 同步一致性

复核 `PatientCoreService` 的 SQLite → MySQL 同步 map：

- 新增时使用已经解析并保存的医生字段。
- 同步失败重试不能重新根据当前会话推断医生，避免用户切换后改变患者归属。

## 8. 批次 3：既有 SQLite 默认约束迁移

### 8.1 为什么需要单独迁移

现有数据库即使升级应用，`patients.doctor` 的 `DEFAULT '申向歌'` 仍保存在 SQLite schema 中。应用正常写入显式医生后该默认值不会再触发，但它仍违反“数据库配置中不保留固定医生”的目标。

### 8.2 确认门槛

本批次涉及数据库 schema 变更和表重建。执行前必须停下来向主人说明：

- 修改目标：仅移除 `patients.doctor` 的默认约束。
- 数据范围：保留所有患者行、主键和现有医生值，不批量改写历史患者归属。
- 关键风险：表重建中断、外键引用、索引或触发器遗漏、磁盘空间不足。
- 恢复方式：迁移前生成可验证备份，失败时回滚并保留原库。

未取得确认时，只能完成新库 schema 与应用显式赋值，不得执行旧库迁移。

### 8.3 推荐迁移策略

1. 迁移前检查 `PRAGMA table_info(patients)`；只有默认值确实为 `申向歌` 时才执行。
2. 使用现有备份能力创建迁移前备份，并验证备份文件存在且非空。
3. 根据当前正式 schema 生成临时患者表，`doctor` 不带默认值。
4. 显式列出全部字段复制数据，保留患者 `id` 和历史 `doctor` 原值。
5. 在受控事务和外键策略下完成表替换；不在异常路径遗留关闭的外键检查。
6. 重建患者表相关索引和触发器；当前 schema 没有患者索引，但实施时必须重新核对真实数据库。
7. 校验迁移前后行数、主键集合、每行医生值和外键一致性。
8. 成功后再次检查 `doctor.dflt_value == null`；失败则回滚并报告，不继续启动写入。
9. 迁移应幂等：无固定默认值的数据库直接跳过。

不得把历史上医生值等于 `申向歌` 的患者批量清空或改成当前用户。历史行中的医生姓名是业务数据，不等同于 schema 默认约束。

## 9. 批次 4～6：测试、验证与收口

### 9.1 自动测试

至少覆盖：

1. schema 不包含固定医生默认值。
2. 用户甲的 `doctor = 医生甲` 时，新增患者默认保存 `医生甲`。
3. 用户乙登录后新增患者默认保存 `医生乙`，不会沿用用户甲缓存。
4. 用户名与医生姓名不同，只保存医生姓名，不保存用户名。
5. 当前用户医生姓名前后有空格时，保存裁剪后的值。
6. 当前用户或医生姓名缺失时，新增失败且数据库没有新记录。
7. 表单中明确填写其他非空医生时，Provider 不覆盖。
8. 编辑患者时保留原医生，不被当前用户覆盖。
9. SQLite 与 MySQL 创建参数都收到同一个显式医生字段。
10. SQLite → MySQL 同步保留首次保存的医生姓名。

优先先写能够复现固定默认值和空医生透传的失败测试，再实施代码。

### 9.2 自动验证

在 `windows_app/` 执行：

```bash
cmd.exe /c dart format <本轮改动的 Dart 文件>
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub <新增或相关患者专项测试>
cmd.exe /c flutter test --no-pub
git diff --check
git ls-files --eol -- <本轮修改和新增的文本文件>
```

只格式化本轮改动文件。所有改动文本必须保持 `LF`。

### 9.3 人工回归

1. 新建 SQLite 数据库，确认患者表医生默认值为空。
2. 以两名医生姓名不同的用户分别新增患者，确认默认值随当前用户变化。
3. 用户切换后不沿用上一位用户的默认医生。
4. 编辑其他医生的既有患者，确认医生归属不会被打开弹窗时自动覆盖。
5. 使用 MySQL 数据源重复新增验证。
6. SQLite 新增后执行同步，确认 MySQL 医生字段一致。
7. 若批准旧库迁移，验证迁移前后患者数量、医生字段和关联数据一致。
8. 勾选“记住密码”登录并重启，确认用户名、密码继续自动回填。

### 9.4 文档收口

1. 每批完成后更新第 4 节进度表和第 10 节实施记录。
2. 代码完成但未通过自动验证时不得标记完成。
3. 自动验证通过但规定的人工回归未执行时，状态只能是 `待人工回归`。
4. 同步更新根目录 `ROADMAP.md` 的 Windows 当前状态、待办与最近验证。

## 10. 实施记录

- 2026-07-20：创建本方案。完成需求边界、schema、表单、Provider、CoreService、SQLite/MySQL 数据源与结构检测逻辑的只读核对；未修改业务代码、数据库 schema 或登录行为，未运行 Flutter 验证。
- 2026-07-20：完成批次 1～2 的代码与专项测试。新建 SQLite schema 移除固定医生默认值；新增患者只使用当前用户已配置且裁剪后的 `doctor`，空值由表单提示并由 Provider 拒绝写入。批次 3 经主人确认暂缓：既有 SQLite 数据库不做 schema 迁移，不修改其中任何内容。专项 16 项通过，`flutter analyze --no-pub` 无问题；待人工 SQLite／MySQL／登录回归。
- 2026-07-20：完成任务 4～6。schema、默认医生解析和表单校验专项 16 项通过；`flutter analyze --no-pub` 通过，`flutter test --no-pub` 全量 94 项通过。SQLite／MySQL／登录人工回归未执行，批次 5 保持“待人工回归”。
