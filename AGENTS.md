# AGENTS.md

## 项目范围

- 此仓库包含安卓端项目代码 `android_app/` 和 Windows 端项目代码 `windows_app/`。
- 用户未明确说明时，默认是windows端 `windows_app`。
- `android_app` 只有在用户明确说明是安卓端的时候才需要。
- 子目录内的 `AGENTS.md` 优先生效；根目录规则适用于两个子项目。

## 项目边界

- 只做用户明确要求的改动，不顺手扩大范围。
- 较大重构、跨平台改动、数据库迁移、CI/CD、密钥配置、发布部署，先给方案并等待确认。
- 删除文件、目录或 Git 回滚前必须先问用户；只允许清理本次任务中自己创建的临时文件。
- 涉及跨平台验证时，只完成当前目标平台代码修改，并说明另一端需要用户如何验证。
- Git 提交信息必须准确体现本次提交的实际内容，并统一使用中文；禁止使用空泛、看不出改动范围的描述。

## 共享编码规范

- Dart/Flutter 代码保持现有风格；小范围修改不做无关格式化或重构。
- 不新增非必要的 `!` 空断言；Map、JSON、数据库、文件等外部输入必须先校验再使用。
- 已有 `MapParser` 的项目优先使用它处理 `Map<String, dynamic>` 解析。
- 不用 `// ignore`、默认值或宽泛类型掩盖真实错误；需要降级时写清业务语义。
- 不要在业务代码中硬编码接口地址、颜色值、分页大小、用户角色、文件路径、环境标识等可配置值；这类内容必须放到统一配置、常量、主题 token 或环境变量入口集中管理。
- 主题、颜色、渐变、阴影、圆角、间距、字号等视觉值默认从现有主题 token、`Theme.of(context)`、`context.tokens`、`context.colors` 或统一语义常量读取，不在业务页面/组件里直接写死；确需例外时，只允许明确业务语义色或医学识别色，并且要集中到统一入口，不能在背景、边框、标题、正文上重复叠加同一强调色导致对比度问题。
- 分页、鼠标悬停/输入状态、添加/编辑/删除提示等可复用 UI 能力，不要散落在业务模块各写一套；应优先沉淀到共用组件或共用交互入口统一复用。
- 密钥、token、密码、个人路径不写入代码、日志或提交内容。

## 命令执行

- 当前 Flutter 环境在 Windows 下；直接在 Windows shell 中执行 Flutter 命令时使用 `flutter ...`，只有从 WSL 执行时才统一使用 `cmd.exe /c flutter ...`。
- 当前仓库涉及 Flutter/Android 工具链命令时，默认按全局沙箱规则执行；在本机 Windows 环境下通常需要显式走非沙箱审批。
- 新克隆仓库或新建 worktree 后，先在仓库根目录执行 `git config --local core.hooksPath .githooks`，启用仓库内的提交前行尾检查 hook。
- 修改 Windows 端时在 `windows_app/` 目录执行命令；修改 Android 端时在 `android_app/` 目录执行命令。
- 常用验证命令：
  - Windows shell 获取依赖：`flutter pub get`
  - Windows shell 静态检查：`flutter analyze`
  - Windows shell 单元测试：`flutter test`
  - WSL 获取依赖：`cmd.exe /c flutter pub get`
  - WSL 静态检查：`cmd.exe /c flutter analyze`
  - WSL 单元测试：`cmd.exe /c flutter test`
- 运行或构建应用只在用户明确要求时执行。

## 格式化要求

- Dart 代码修改后，默认只格式化本次改动过的文件，不执行全仓 `dart format .`。
- 建议使用定向命令，如 `dart format path/to/file.dart`。
- 除非用户明确要求或任务目标就是全仓整理格式，否则不要扩大格式化范围，避免引入无关 diff。

## Bug 修复规则

- 处理 Bug 默认采用两阶段流程：先复现和定位，再修复。
- 第一阶段输出复现结果、实际现象、相关日志、疑似原因和涉及文件。
- 业务逻辑、数据、权限、登录、支付、状态流转等重要问题，必须等待用户确认复现正确后再修复。
- 拼写错误、空指针、布局溢出、明显编译错误等低风险问题，可在复现后按最小改动原则直接修复。
- 修复后必须运行相关验证；适合自动化验证的 Bug，应补充回归测试。
- 不允许顺手重构、扩大范围或修改无关逻辑。

## 测试要求

- 新增功能或新增代码时，应优先补充对应测试；确实不适合自动化测试时，说明原因和手动验证步骤。
- Bug 修复能用测试复现的，先补失败测试或等价回归测试，再修复到通过。
- 项目历史缺少测试不是继续不写测试的理由；后续改动按“改到哪里，覆盖哪里”逐步补。

## 验证要求

- 代码修改后至少在对应子项目目录运行 Flutter 静态检查；Windows shell 使用 `flutter analyze`，WSL 使用 `cmd.exe /c flutter analyze`。
- 涉及测试逻辑或新增/修复可测试行为时，再运行 Flutter 测试；Windows shell 使用 `flutter test`，WSL 使用 `cmd.exe /c flutter test`。
- 默认执行顺序为：先对改动过的 Dart 文件运行 `dart format`，再运行 `flutter analyze`；只有在改动涉及可测试逻辑、Bug 修复或已有测试覆盖点时再运行 `flutter test`。
- 修改或新增文本文件后，提交前先检查本次改动文件的行尾；若 `git ls-files --eol -- <file>` 出现 `w/crlf` 或 `w/mixed`，必须先转回 `LF` 再提交。
- 如果本地环境无法运行验证，说明失败原因和用户可执行的命令。
- 完成开发、修复、文档补齐或重要调研后，同步更新根目录 `ROADMAP.md`。
