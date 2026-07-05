# Windows 牙科管理系统五套主题设计方案

## 1. 设计目标

本方案用于 `windows_app` 的多主题扩展，整体保持当前系统的清爽桌面后台风格：左侧导航、顶部欢迎卡片、统计卡片、管理模块卡片、弹窗表单、状态标签、表格、筛选栏、详情页等组件结构不变，只替换主题色、背景色、边框、阴影与强调色。

本方案是后期主题扩展的视觉草案，不代表当前立即实现。真正落地时必须先保证普通业务 UI 已接入统一主题 token，不能让新增主题放大 `DentalColors`、`Colors.xxx`、`Color(0x...)` 等残留颜色来源。

设计原则：

- 页面大背景不使用纯白，避免长时间使用刺眼。
- 主色使用低饱和色，不使用高亮荧光色。
- 卡片背景接近白色，但不大面积使用纯白。
- 导航选中、按钮、标题栏、重点数字使用主题主色。
- 成功、警告、错误、信息等状态色保持独立，不完全跟随主题变化。
- 保持医疗系统应有的专业、清晰、柔和、可信感。
- Windows 端高密度页面优先于首页观感，表格、筛选栏、弹窗、详情页必须边界清楚、状态明确、长时间使用不疲劳。
- 主题色不能抢业务语义色：绿色主题要避开成功色混淆，粉杏主题要避开错误/欠费色混淆。

---

## 2. 全局组件设计规范

### 2.1 页面结构

| 区域 | 设计建议 |
|---|---|
| 页面背景 | 使用柔和灰白、蓝灰白、紫灰白、暖灰白，不用 `#FFFFFF` |
| 侧边栏 | 比页面背景略浅，保持干净分区 |
| 内容卡片 | 使用接近白的背景，如 `#FEFEFE`、`#FEFEFF`、`#FEFDFC` |
| 顶部欢迎卡 | 使用主题主色渐变，但降低饱和度 |
| 模块卡片 | 白色/近白底，主题浅色图标底 |
| 弹窗 | 标题栏使用主题浅色底，正文近白，按钮用主题主色 |
| 表格 | 表头浅灰底，悬浮行使用主题极浅底 |
| 输入框 | 白色或近白底，边框浅灰，聚焦边框使用主题色 |

### 2.2 Windows 端 Token 覆盖规则

当前 `windows_app` 的主题系统不是简单的 `primary + background`。后期每套主题必须完整覆盖当前 `AppThemeTokens` 的语义，否则会出现只有首页换色、深层业务页面仍沿用默认色的问题。

| Token | 用途 | 设计要求 |
|---|---|---|
| `pageBackground` | 页面大背景 | 低刺激灰白，不用纯白 |
| `shellBackground` | 侧边栏、顶部栏、页面壳层 | 比页面背景略亮，和内容区有轻微分区 |
| `panelBackground` | 弹窗、面板、浮层正文 | 接近白色，保证表单可读 |
| `cardBackground` | 普通卡片 | 接近白色，不能和页面背景粘连 |
| `elevatedCardBackground` | 高层级卡片、浮起卡片 | 可略亮于普通卡片 |
| `mutedBackground` | 次级块、说明块、空态底 | 主题低饱和浅色或中性浅灰 |
| `inputBackground` | 输入框、搜索框、筛选控件 | 可读性优先，聚焦态用主题主色 |
| `border` / `divider` | 卡片、表格、分割线 | 低对比但可见，不能过浅到消失 |
| `shadow` / `cardShadow` / `elevatedShadow` | 阴影 | 后台系统轻阴影，透明度控制在 `0.04` 到 `0.10` |
| `focusRing` | 输入框、按钮、键盘焦点 | 由主色派生，必须明显但不刺眼 |
| `primaryAccent` | 主按钮、导航选中、重点数字 | 当前主题核心识别色 |
| `secondaryAccent` | 次强调、渐变辅助色 | 默认医疗蓝使用低饱和青蓝，绿色只作为成功等业务状态色 |
| `dangerAccent` / `warningAccent` | 删除、风险、提醒强调 | 不随主题主色漂移 |
| `iconMuted` / `textMuted` | 次级图标和文字 | 保证灰阶可读，不跟主题过度染色 |
| `success` / `warning` / `error` / `info` | 业务状态前景色 | 跨主题保持稳定语义 |
| `successContainer` / `warningContainer` / `errorContainer` / `infoContainer` | 状态标签、提示块背景 | 必须和前景状态色成套设计 |
| `hoverBackground` / `selectedBackground` | 悬浮、选中态 | 由主色低透明度派生，选中态必须比 hover 更明确 |
| `disabledBackground` / `disabledText` | 禁用态 | 中性灰，不使用主题主色 |
| `tableHeaderBackground` / `listItemHoverBackground` | 表格和列表 | 高密度页面优先，不能过彩 |
| `overlayScrim` | 弹窗遮罩 | 保持中性黑透明，不跟随主题 |
| `primaryHeaderGradient` / `subtleHeaderGradient` | 欢迎卡、头部装饰 | 低饱和，不能成为页面唯一视觉中心 |
| `chartPalette` | 图表调色板 | 需要多色区分，不应全部跟随主色 |
| `borderRadius` / `smallBorderRadius` / `cardElevation` | 形态 token | 多主题默认保持一致，不通过主题改变信息架构 |

### 2.3 状态色固定规则

为了避免多主题下信息混乱，业务状态色建议固定：

| 状态 | 颜色 | 用途 |
|---|---|---|
| 成功 / 已完成 | `#36B37E` | 已完成、正常、启用 |
| 警告 / 待处理 | `#F5A623` | 待处理、提醒、库存预警 |
| 危险 / 错误 | `#E85D75` | 删除、欠费、异常、失败 |
| 信息 / 查看 | `#5B8DEF` | 查看详情、普通信息 |

配套容器色建议：

| 状态容器 | 颜色 | 用途 |
|---|---|---|
| `successContainer` | `#EAF7F1` | 成功标签、启用状态背景 |
| `warningContainer` | `#FFF4E0` | 库存预警、待处理背景 |
| `errorContainer` | `#FDECEF` | 欠费、删除、异常背景 |
| `infoContainer` | `#EAF2FF` | 查看、说明、普通信息背景 |

绿色主题必须避免把主按钮和成功状态做成同一视觉强度；粉杏主题必须避免把主按钮和错误/欠费状态混在一起。

### 2.4 模块用色规则

当前系统中模块入口较多，如果每个模块都使用不同颜色，页面会显得杂。建议统一：

| 模块 | 用色建议 |
|---|---|
| 仪表盘 | 使用主题主色 |
| 患者管理 | 主题浅色图标底 + 主题主色图标 |
| 预约管理 | 主题浅色图标底 + 主题主色图标 |
| 财务管理 | 主题浅色图标底 + 主题主色图标 |
| 材料管理 | 主题浅色图标底 + 主题主色图标 |
| 采购管理 | 主题浅色图标底 + 主题主色图标 |
| 病历管理 | 主题浅色图标底 + 主题主色图标 |
| 用户管理 | 主题浅色图标底 + 主题主色图标 |
| 系统设置 | 中性灰色 |

### 2.5 阴影建议

后台系统不适合强阴影，建议使用轻阴影：

```css
box-shadow: 0 8px 24px rgba(31, 41, 55, 0.06);
```

紫色、蓝色、绿色等主题可以略带主题色，但透明度不要超过 `0.10`。

### 2.6 Windows 高密度页面验收

每套主题进入实现前，至少检查以下页面类型：

| 页面类型 | 验收重点 |
|---|---|
| 首页 / 仪表盘 | 欢迎卡不刺眼，统计卡重点数字清楚 |
| 患者列表 / 预约列表 | hover、selected、分页、筛选栏边界明确 |
| 财务详情 / 财务列表 | 金额、欠费、删除、警告状态不能被主题主色干扰 |
| 材料 / 采购 | 库存预警、采购状态、数量信息保持清楚 |
| 病历 / 牙位 | 医疗语义色和主题色不冲突 |
| 弹窗 / 表单 | 标题栏、输入框、错误提示、主按钮层级清楚 |
| 统计图表 | `chartPalette` 至少提供 5 个可区分颜色，不能只用同一主题色深浅 |

---

# 3. 主题一：医疗蓝主题

## 3.1 定位

默认推荐主题。专业、清晰、医疗感强，适合大部分诊所日常使用。

默认主题不建议使用过亮的互联网 SaaS 蓝，也不建议使用大面积绿色辅助色，否则会和绿色清新主题、成功状态混在一起。医疗蓝应保持“蓝 + 低饱和青蓝”的专业医疗感，绿色只保留给成功、启用、已完成等业务状态。

## 3.2 配色方案

| Token | 色值 | 说明 |
|---|---|---|
| `pageBackground` | `#F4F7FA` | 页面大背景，蓝灰白，不刺眼 |
| `shellBackground` | `#F8FAFC` | 侧边栏、顶部栏背景 |
| `panelBackground` | `#FEFEFE` | 弹窗和面板背景 |
| `cardBackground` | `#FEFEFE` | 卡片背景 |
| `elevatedCardBackground` | `#FFFFFF` | 浮起卡片背景 |
| `mutedBackground` | `#EEF4F8` | 次级说明块背景 |
| `inputBackground` | `#F6F9FC` | 输入框背景 |
| `primaryAccent` | `#2E7DB8` | 主色，贴近当前系统 |
| `secondaryAccent` | `#5BA8D6` | 辅助青蓝，避免和绿色清新主题混淆 |
| `primaryHover` | `#246A9D` | 按钮悬浮色 |
| `primaryLight` | `#EAF4FB` | 选中项、图标底色 |
| `textPrimary` | `#1F2937` | 主文字 |
| `textSecondary` | `#6B7280` | 次级文字 |
| `border` | `#E1EAF5` | 边框 |
| `divider` | `#EEF3F8` | 分割线 |
| `focusRing` | `rgba(46, 125, 184, 0.20)` | 聚焦态 |
| `tableHeaderBackground` | `#F0F5FA` | 表头背景 |
| `listItemHoverBackground` | `#F7FBFF` | 列表 hover 背景 |
| `chartPalette` | `#2E7DB8`, `#5BA8D6`, `#7DA7C7`, `#F5A623`, `#E85D75` | 图表色板 |

## 3.3 组件应用

### 顶部欢迎栏

```css
background: linear-gradient(135deg, #2E7DB8 0%, #5BA8D6 100%);
color: #FFFFFF;
```

如果希望更稳，可以使用更低饱和版本：

```css
background: linear-gradient(135deg, #3F7FA8 0%, #7DA7C7 100%);
```

### 左侧导航

```css
.nav-item.active {
  background: #EAF4FB;
  color: #2E7DB8;
  border-left: 3px solid #2E7DB8;
}
```

### 模块卡片

```css
.module-icon {
  background: #EAF4FB;
  color: #2E7DB8;
}

.module-card {
  background: #FEFEFE;
  border: 1px solid #E1EAF5;
  box-shadow: 0 8px 24px rgba(46, 125, 184, 0.08);
}
```

### 弹窗

```css
.dialog-header {
  background: #EAF4FB;
  color: #1F2937;
}

.dialog-primary-button {
  background: #2E7DB8;
  color: #FFFFFF;
}
```

### 表格

```css
table thead {
  background: #F0F5FA;
}

table tr:hover {
  background: #F7FBFF;
}
```

---

# 4. 主题二：紫粉灰主题

## 4.1 定位

个性化主题。柔和、高级、有个人风格，但仍保持医疗后台的专业感。

此主题适合作为第二套个性化主题，不适合作为默认主题。紫色应服务于导航、按钮和重点数字，不要大面积染色表格和弹窗正文。主色不使用高亮亮紫，而是使用灰紫并加入少量玫粉，让主题更温和、不刺眼。

## 4.2 配色方案

| Token | 色值 | 说明 |
|---|---|---|
| `pageBackground` | `#F8F5F9` | 页面大背景，紫粉灰 |
| `shellBackground` | `#FBF9FC` | 侧边栏、顶部栏背景 |
| `panelBackground` | `#FEFDFE` | 弹窗和面板背景 |
| `cardBackground` | `#FEFDFE` | 卡片背景 |
| `elevatedCardBackground` | `#FFFFFF` | 浮起卡片背景 |
| `mutedBackground` | `#F6F0F6` | 次级说明块背景 |
| `inputBackground` | `#FBF9FC` | 输入框背景 |
| `primaryAccent` | `#9A78A8` | 主色，灰紫偏玫粉 |
| `secondaryAccent` | `#C99AAD` | 辅助玫粉，降低亮紫刺激感 |
| `primaryHover` | `#846792` | 按钮悬浮色 |
| `primaryLight` | `#F5EEF7` | 选中项、图标底色 |
| `textPrimary` | `#332B38` | 主文字，深灰紫 |
| `textSecondary` | `#7D7185` | 次级文字 |
| `border` | `#E9DFEA` | 边框 |
| `divider` | `#F0E8F1` | 分割线 |
| `focusRing` | `rgba(154, 120, 168, 0.20)` | 聚焦态 |
| `tableHeaderBackground` | `#F3EDF4` | 表头背景 |
| `listItemHoverBackground` | `#FCF8FC` | 列表 hover 背景 |
| `chartPalette` | `#9A78A8`, `#C99AAD`, `#7DA7C7`, `#F5A623`, `#E85D75` | 图表色板 |

## 4.3 组件应用

### 顶部欢迎栏

```css
background: linear-gradient(135deg, #8F76A3 0%, #B48AA8 58%, #C9B6CF 100%);
color: #FFFFFF;
```

### 左侧导航

```css
.nav-item.active {
  background: #F5EEF7;
  color: #9A78A8;
  border-left: 3px solid #9A78A8;
}
```

### 模块卡片

```css
.module-icon {
  background: #F5EEF7;
  color: #9A78A8;
}

.module-card {
  background: #FEFEFF;
  border: 1px solid #E9DFEA;
  box-shadow: 0 8px 24px rgba(51, 43, 56, 0.08);
}
```

### 弹窗

```css
.dialog-header {
  background: #F5EEF7;
  color: #332B38;
}

.dialog-primary-button {
  background: #9A78A8;
  color: #FFFFFF;
}
```

### 表格

```css
table thead {
  background: #F3EDF4;
}

table tr:hover {
  background: #FCF8FC;
}
```

---

# 5. 主题三：灰蓝专业主题

## 5.1 定位

耐看办公主题。比医疗蓝更稳重，比纯灰更有层次，适合长时间使用。

这是 Windows 端最适合高密度后台工作的主题。财务、材料、采购、患者列表等页面优先用它验证，因为它对表格和详情页最友好。

## 5.2 配色方案

| Token | 色值 | 说明 |
|---|---|---|
| `pageBackground` | `#F3F5F7` | 页面大背景，中性灰白 |
| `shellBackground` | `#F6F8FA` | 侧边栏、顶部栏背景 |
| `panelBackground` | `#FEFEFE` | 弹窗和面板背景 |
| `cardBackground` | `#FEFEFE` | 卡片背景 |
| `elevatedCardBackground` | `#FFFFFF` | 浮起卡片背景 |
| `mutedBackground` | `#EEF2F6` | 次级说明块背景 |
| `inputBackground` | `#F8FAFC` | 输入框背景 |
| `primaryAccent` | `#4F7CAC` | 主色，灰蓝 |
| `secondaryAccent` | `#6A9A8B` | 辅助灰绿，保持医疗气质 |
| `primaryHover` | `#3D638A` | 按钮悬浮色 |
| `primaryLight` | `#EEF5FB` | 选中项、图标底色 |
| `textPrimary` | `#263238` | 主文字 |
| `textSecondary` | `#6B7A88` | 次级文字 |
| `border` | `#DFE7EF` | 边框 |
| `divider` | `#E9EEF3` | 分割线 |
| `focusRing` | `rgba(79, 124, 172, 0.20)` | 聚焦态 |
| `tableHeaderBackground` | `#EEF2F6` | 表头背景 |
| `listItemHoverBackground` | `#F7FAFC` | 列表 hover 背景 |
| `chartPalette` | `#4F7CAC`, `#6A9A8B`, `#7DA7C7`, `#F5A623`, `#E85D75` | 图表色板 |

## 5.3 组件应用

### 顶部欢迎栏

```css
background: linear-gradient(135deg, #4F7CAC 0%, #7DA7C7 100%);
color: #FFFFFF;
```

### 左侧导航

```css
.nav-item.active {
  background: #EEF5FB;
  color: #3D638A;
  border-left: 3px solid #4F7CAC;
}
```

### 模块卡片

```css
.module-icon {
  background: #EEF5FB;
  color: #3D638A;
}

.module-card {
  background: #FEFEFE;
  border: 1px solid #DFE7EF;
  box-shadow: 0 8px 22px rgba(38, 50, 56, 0.07);
}
```

### 弹窗

```css
.dialog-header {
  background: #EEF5FB;
  color: #263238;
}

.dialog-primary-button {
  background: #4F7CAC;
  color: #FFFFFF;
}
```

### 表格

```css
table thead {
  background: #EEF2F6;
}

table tr:hover {
  background: #F7FAFC;
}
```

---

# 6. 主题四：绿色清新主题

## 6.1 定位

健康、自然、清新。适合保留当前系统蓝绿风格，但需要降低饱和度，避免过亮。

此主题最大风险是和“成功 / 已完成 / 启用”状态混淆。绿色主色必须偏蓝绿或深绿，成功状态仍使用固定成功色和容器色，并通过标签文案、图标、边框区分。

## 6.2 配色方案

| Token | 色值 | 说明 |
|---|---|---|
| `pageBackground` | `#F5F8F6` | 页面大背景，浅绿灰白 |
| `shellBackground` | `#FAFBFA` | 侧边栏、顶部栏背景 |
| `panelBackground` | `#FEFEFD` | 弹窗和面板背景 |
| `cardBackground` | `#FEFEFD` | 卡片背景 |
| `elevatedCardBackground` | `#FFFFFF` | 浮起卡片背景 |
| `mutedBackground` | `#EEF6F2` | 次级说明块背景 |
| `inputBackground` | `#F8FAF8` | 输入框背景 |
| `primaryAccent` | `#2F8F72` | 主色，偏蓝绿，避开成功绿 |
| `secondaryAccent` | `#2E7DB8` | 辅助蓝色，降低成功色混淆 |
| `primaryHover` | `#24745D` | 按钮悬浮色 |
| `primaryLight` | `#E7F4EF` | 选中项、图标底色 |
| `textPrimary` | `#26352D` | 主文字 |
| `textSecondary` | `#6D7F73` | 次级文字 |
| `border` | `#DDECE4` | 边框 |
| `divider` | `#EAF1ED` | 分割线 |
| `focusRing` | `rgba(47, 143, 114, 0.20)` | 聚焦态 |
| `tableHeaderBackground` | `#EFF6F2` | 表头背景 |
| `listItemHoverBackground` | `#F7FBF8` | 列表 hover 背景 |
| `chartPalette` | `#2F8F72`, `#2E7DB8`, `#76A66F`, `#F5A623`, `#E85D75` | 图表色板 |

## 6.3 组件应用

### 顶部欢迎栏

推荐保留当前类似的蓝绿方向：

```css
background: linear-gradient(135deg, #2E7DB8 0%, #2F8F72 100%);
color: #FFFFFF;
```

如果想更偏绿色：

```css
background: linear-gradient(135deg, #2F8F72 0%, #6FBF8D 100%);
```

### 左侧导航

```css
.nav-item.active {
  background: #E7F4EF;
  color: #2F8F72;
  border-left: 3px solid #2F8F72;
}
```

### 模块卡片

```css
.module-icon {
  background: #E7F4EF;
  color: #2F8F72;
}

.module-card {
  background: #FEFEFD;
  border: 1px solid #DDECE4;
  box-shadow: 0 8px 24px rgba(47, 143, 114, 0.08);
}
```

### 弹窗

```css
.dialog-header {
  background: #E7F4EF;
  color: #26352D;
}

.dialog-primary-button {
  background: #2F8F72;
  color: #FFFFFF;
}
```

### 表格

```css
table thead {
  background: #EFF6F2;
}

table tr:hover {
  background: #F7FBF8;
}
```

---

# 7. 主题五：粉杏柔和主题

## 7.1 定位

温和、亲和、轻医美感。适合前台、护士、患者回访、会员管理等场景。不要做成高饱和粉色，要使用灰粉、杏粉、暖灰白。

此主题不适合作为重后台默认主题。财务、欠费、删除、异常等页面必须防止粉杏主色和错误红、欠费红混淆。主色应偏灰粉杏，错误状态继续使用固定 `error`。

## 7.2 配色方案

| Token | 色值 | 说明 |
|---|---|---|
| `pageBackground` | `#F9F6F4` | 页面大背景，暖灰白 |
| `shellBackground` | `#FCFAF9` | 侧边栏、顶部栏背景 |
| `panelBackground` | `#FEFDFC` | 弹窗和面板背景 |
| `cardBackground` | `#FEFDFC` | 卡片背景 |
| `elevatedCardBackground` | `#FFFFFF` | 浮起卡片背景 |
| `mutedBackground` | `#F6EFEC` | 次级说明块背景 |
| `inputBackground` | `#FCFAF8` | 输入框背景 |
| `primaryAccent` | `#C97888` | 主色，灰粉杏 |
| `secondaryAccent` | `#8FA7A0` | 辅助灰绿，平衡粉色亲和感 |
| `primaryHover` | `#B96878` | 按钮悬浮色 |
| `primaryLight` | `#FBECEF` | 选中项、图标底色 |
| `textPrimary` | `#3A2F33` | 主文字 |
| `textSecondary` | `#7D6F73` | 次级文字 |
| `border` | `#EADDE0` | 边框 |
| `divider` | `#F0E6E8` | 分割线 |
| `focusRing` | `rgba(201, 120, 136, 0.20)` | 聚焦态 |
| `tableHeaderBackground` | `#F6EEF0` | 表头背景 |
| `listItemHoverBackground` | `#FFF8F9` | 列表 hover 背景 |
| `chartPalette` | `#C97888`, `#8FA7A0`, `#7DA7C7`, `#F5A623`, `#E85D75` | 图表色板 |

## 7.3 组件应用

### 顶部欢迎栏

```css
background: linear-gradient(135deg, #C97888 0%, #DDA0AA 55%, #E8C4C0 100%);
color: #FFFFFF;
```

### 左侧导航

```css
.nav-item.active {
  background: #FBECEF;
  color: #C97888;
  border-left: 3px solid #D88C9A;
}
```

### 模块卡片

```css
.module-icon {
  background: #FBECEF;
  color: #C97888;
}

.module-card {
  background: #FEFDFC;
  border: 1px solid #EADDE0;
  box-shadow: 0 8px 24px rgba(58, 47, 51, 0.07);
}
```

### 弹窗

```css
.dialog-header {
  background: #FBECEF;
  color: #3A2F33;
}

.dialog-primary-button {
  background: #D88C9A;
  color: #FFFFFF;
}
```

### 表格

```css
table thead {
  background: #F6EEF0;
}

table tr:hover {
  background: #FFF8F9;
}
```

---

# 8. 推荐主题排序

| 顺序 | 主题 | 适合作为 | 推荐程度 |
|---|---|---|---|
| 1 | 医疗蓝主题 | 默认主题 | 最高 |
| 2 | 灰蓝专业主题 | 长时间办公主题 | 很高 |
| 3 | 紫粉灰主题 | 个性化主题 | 很高 |
| 4 | 绿色清新主题 | 保留当前风格 | 中高 |
| 5 | 粉杏柔和主题 | 前台/亲和主题 | 中高 |

如果优先服务 Windows 端后台效率，灰蓝专业主题的工程优先级可以高于紫粉灰主题。紫粉灰更适合个性化，灰蓝更适合长时间处理财务、采购、材料和患者列表。

---

# 9. Windows Flutter 实现建议

建议不要把颜色散落写在各个页面中，而是全部进入 `AppThemeTokens`。后期新增主题时，不能新建页面级 `if theme == xxx` 分支，也不能在页面中直接写主题色。

## 9.1 当前应覆盖的 Theme Token

```dart
class AppThemeTokens {
  final Color pageBackground;
  final Color shellBackground;
  final Color panelBackground;
  final Color cardBackground;
  final Color elevatedCardBackground;
  final Color mutedBackground;
  final Color inputBackground;
  final Color border;
  final Color divider;
  final Color shadow;
  final Color focusRing;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color dangerAccent;
  final Color warningAccent;
  final Color iconMuted;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color successContainer;
  final Color warningContainer;
  final Color errorContainer;
  final Color infoContainer;
  final Color hoverBackground;
  final Color selectedBackground;
  final Color disabledBackground;
  final Color disabledText;
  final Color tableHeaderBackground;
  final Color listItemHoverBackground;
  final Color overlayScrim;
  final LinearGradient primaryHeaderGradient;
  final LinearGradient subtleHeaderGradient;
  final List<Color> chartPalette;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> elevatedShadow;
  final double borderRadius;
  final double smallBorderRadius;
  final double cardElevation;
}
```

## 9.2 医疗蓝默认主题方向示例

```dart
const primary = Color(0xFF2E7DB8);
const secondary = Color(0xFF5BA8D6);

// 示例只表达色彩方向，实际实现必须完整填写 AppThemeTokens 的所有字段。
```

## 9.3 状态色单独维护

```dart
class AppStatusColors {
  static const success = Color(0xFF36B37E);
  static const warning = Color(0xFFF5A623);
  static const danger = Color(0xFFE85D75);
  static const info = Color(0xFF5B8DEF);
}
```

状态色不能因为主题切换而失去业务含义。绿色主题只改变 `primaryAccent`，不改变“成功”的语义；粉杏主题只改变 `primaryAccent`，不改变“错误 / 欠费 / 删除”的语义。

## 9.4 实现顺序建议

1. 先完成当前 Windows 端普通颜色来源统一，确保业务页面都走 `context.tokens` / `context.colors`。
2. 再扩展 `AppThemeTokens` 的多套工厂或配置表，五套主题必须一次性覆盖全部 token。
3. 最后在设置页开放主题切换，主题切换只改变 token，不改变页面组件逻辑。

## 9.5 阶段 7 完成后的快速接入条件

如果 `windows_app` 按 `windows_app_theme_unification_overview_2026_07_02.md` 完成到阶段 7，并通过最终验收，五套主题可以较快接入。判断依据不是“文档里有五套配色”，而是代码必须满足以下条件：

| 条件 | 验收方式 | 目的 |
|---|---|---|
| 普通业务 UI 都从 `context.tokens` / `context.colors` / `ThemeData` 读取颜色 | 抽查首页、患者、预约、财务、材料、采购、病历、设置、弹窗和表单 | 新主题不需要逐页改色 |
| `DentalColors` 不再承担普通主题职责 | 剩余命中只允许是医学识别色、状态语义色、头像/图片兜底或历史兼容 | 避免深层页面仍显示旧蓝绿 |
| `Colors.xxx` / `Color(0x...)` 直接命中已分类处理 | 普通背景、边框、文字、hover、selected、disabled 必须退出直接硬编码 | 避免局部区域不跟主题变化 |
| `AppThemeTokens` 字段已覆盖真实 UI 场景 | 背景、卡片、面板、输入、边框、状态容器、图表、阴影、渐变都能在 token 中表达 | 五套主题只需填 token |
| 公共组件默认读主题 | 搜索框、分页、Toast、Dialog、表格、卡片、状态标签不要求调用方传固定颜色 | 新增页面自动适配主题 |

满足上述条件后，五套主题的实现主要是配置工作：

1. 在 `AppThemeTokens` 中新增五个完整工厂或配置映射：
   - `medicalBlue()`
   - `purplePinkGray()`
   - `slateBlue()`
   - `freshGreen()`
   - `peachPink()`
2. 新增 Windows 端主题枚举，例如 `WindowsThemeVariant`，枚举值只表达主题身份，不在页面中参与颜色判断。
3. 在 `AppTheme` 中增加统一解析入口，例如 `AppTheme.resolve(WindowsThemeVariant variant)`，内部选择对应 token 并构建 `ThemeData`。
4. `MaterialApp.theme` 只接收解析后的 `ThemeData`，业务页面不允许写 `if (theme == ...)`。
5. 用五套 HTML 预览页作为视觉基准，对 Flutter 实际界面做页面级验收。

不满足阶段 7 验收前，不建议先接五套主题。否则会形成“首页和公共组件已换色，深层详情页、弹窗、业务组件仍旧色”的混合状态。

## 9.6 主题切换接入设计

五套主题不是只新增 token，还必须设计主题切换入口、持久化和兼容策略。建议按以下方式接入。

### 9.6.1 主题枚举

```dart
enum WindowsThemeVariant {
  medicalBlue,
  slateBlue,
  purplePinkGray,
  freshGreen,
  peachPink,
}
```

枚举命名使用产品语义，不使用 `blue1`、`purple2` 这种色号式命名。默认值建议为 `medicalBlue`。

### 9.6.2 Token 解析入口

```dart
extension WindowsThemeVariantTokens on WindowsThemeVariant {
  AppThemeTokens get tokens {
    switch (this) {
      case WindowsThemeVariant.medicalBlue:
        return AppThemeTokens.medicalBlue();
      case WindowsThemeVariant.slateBlue:
        return AppThemeTokens.slateBlue();
      case WindowsThemeVariant.purplePinkGray:
        return AppThemeTokens.purplePinkGray();
      case WindowsThemeVariant.freshGreen:
        return AppThemeTokens.freshGreen();
      case WindowsThemeVariant.peachPink:
        return AppThemeTokens.peachPink();
    }
  }
}
```

`AppTheme` 只负责把 token 转成 `ThemeData`，例如：

```dart
class AppTheme {
  static ThemeData resolve(WindowsThemeVariant variant) {
    return _buildTheme(variant.tokens);
  }
}
```

### 9.6.3 设置页入口

设置页可以新增“外观主题”区域，但必须遵守以下规则：

| 项目 | 建议 |
|---|---|
| 展示方式 | 使用主题卡片或紧凑列表，显示主题名称、适用场景和 3 到 5 个色块 |
| 默认主题 | 医疗蓝 |
| 排序 | 医疗蓝、灰蓝专业、紫粉灰、绿色清新、粉杏柔和 |
| 预览 | 点击主题卡片时可以即时预览，但保存前不改变持久配置 |
| 保存 | 用户确认后写入配置，并触发全局主题刷新 |
| 回退 | 配置缺失、非法值、旧值无法识别时回退医疗蓝 |

主题卡片只负责选择 `WindowsThemeVariant`，不传递具体颜色到业务页面。

### 9.6.4 持久化和旧配置兼容

主题配置建议保存稳定字符串，而不是保存枚举 index：

```json
{
  "windowsThemeVariant": "medicalBlue"
}
```

原因是后续如果调整枚举顺序，字符串不会导致旧配置读错主题。

兼容规则：

| 旧配置 / 异常配置 | 处理方式 |
|---|---|
| 没有 `windowsThemeVariant` | 使用 `medicalBlue` |
| 保存了旧 `grey` / 柔和灰值 | 映射到 `medicalBlue` |
| 保存了未知字符串 | 使用 `medicalBlue`，不抛出启动错误 |
| 后续删除某个主题 | 将该值映射到 `medicalBlue` 或最近似主题，并在变更说明中记录 |

### 9.6.5 切换刷新链路

主题切换链路建议保持单向：

1. 设置页选择 `WindowsThemeVariant`。
2. `SettingsProvider` 保存并通知监听者。
3. `MaterialApp` 根据当前 variant 调用 `AppTheme.resolve(...)`。
4. `ThemeData.extensions` 注入对应 `AppThemeTokens`。
5. 页面通过 `context.tokens` / `context.colors` 自动刷新。

不允许在业务页面、业务组件或公共组件中写主题枚举判断。确实需要因主题调整的，只能新增 token 表达该语义。

### 9.6.6 主题切换验收

五套主题接入后至少做以下验收：

| 验收项 | 标准 |
|---|---|
| 启动默认值 | 首次启动进入医疗蓝 |
| 配置持久化 | 切换主题、重启应用后仍保持选择 |
| 旧配置兼容 | 旧柔和灰、非法值不会导致启动失败 |
| 页面覆盖 | 首页、列表、详情、弹窗、表单、统计图表都随主题变化 |
| 语义色稳定 | 成功、警告、错误、信息不因主题切换失去业务含义 |
| 无页面级主题判断 | 搜索业务页面中不应新增 `if (themeVariant == ...)` 颜色分支 |
| 静态检查 | `flutter analyze` 通过 |

---

## 9.7 给后续大模型的严格实施协议

本节是后续真正编码时的唯一执行口径。前文 CSS 代码块只说明视觉方向，不能直接照搬成 Flutter 页面内硬编码。实现五套主题时，必须按本节指定的文件、类型、字段、配置键和验收命令执行。

### 9.7.1 当前方案是否足够直接实施

如果只看到 9.6 之前的内容，另一个大模型不能稳定完成五套主题整改。它可能只新增配色表，不会把 `MaterialApp`、`SettingsProvider`、持久化和设置页完整接起来；也可能只改 `primaryAccent`，导致深层业务页面仍沿用旧色。

本节把方案收口为文件级和字段级要求。后续实施时，不允许自由发挥成另一个主题架构。

### 9.7.2 必须修改的文件清单

| 文件 | 必须改什么 | 不允许做什么 |
|---|---|---|
| `lib/theme/app_theme_tokens.dart` | 新增 `AppThemeTokens.medicalBlue()`、`slateBlue()`、`purplePinkGray()`、`freshGreen()`、`peachPink()` 五个 factory；保留 `standard()` 并让它返回 `medicalBlue()` | 不删除现有 token 字段；不新增页面专用字段；不让状态色随主题漂移 |
| `lib/theme/app_theme.dart` | 新增 `WindowsThemeVariant` 枚举、字符串解析、`AppTheme.resolve(WindowsThemeVariant variant)`；`standardTheme()` 返回医疗蓝 | 不恢复柔和灰；不恢复历史紫色运行链路；不在页面里判断主题 |
| `lib/providers/settings_provider.dart` | 新增 `_windowsThemeVariant` 字段、getter、`setWindowsThemeVariant(...)`；保存和加载 `windowsThemeVariant` 字符串 | 不继续用 `ExtendedThemeMode` 表达五套主题；不保存枚举 index |
| `lib/features/settings/services/config_storage_service.dart` | `loadSettings()` 读取 `prefs.getString('windowsThemeVariant')`；`saveSettings()` 写入 `windowsThemeVariant` | 不删除旧 `extendedThemeMode` / `themeMode` 读取，旧字段只做兼容 |
| `lib/main.dart` | 在 `AppWithProviders.build` 中监听 `SettingsProvider`，把 `theme: AppTheme.standardTheme()` 改成 `theme: AppTheme.resolve(settings.windowsThemeVariant)` | 不把主题存在局部全局变量；不让业务页面主动刷新颜色 |
| `lib/features/settings/widgets/theme_section.dart` | 从“当前使用标准主题”改为五套主题选择区；点击调用 `setWindowsThemeVariant(...)` | 不把具体颜色传给业务页面；不恢复旧 `ExtendedThemeMode` UI |
| `lib/features/settings/widgets/theme_card.dart` | 参数改为 `WindowsThemeVariant variant`、`String subtitle`、`List<Color> swatches`；卡片内部只展示色块和选中态 | 不再依赖 `ExtendedThemeMode`；不在卡片里构造业务主题 |
| `ROADMAP.md` | 实现完成并通过验证后同步记录五套主题接入状态和验证结果 | 未运行验证时不得写“已完成” |

### 9.7.3 五套主题的完整 token 定义

以下字段必须逐项填入五个 `AppThemeTokens` factory。不得只覆盖 `primaryAccent`、`pageBackground` 这类少数字段。

公共固定值如下，五套主题都必须一致：

```dart
const success = Color(0xFF36B37E);
const warning = Color(0xFFF5A623);
const error = Color(0xFFE85D75);
const info = Color(0xFF5B8DEF);
const successContainer = Color(0xFFEAF7F1);
const warningContainer = Color(0xFFFFF4E0);
const errorContainer = Color(0xFFFDECEF);
const infoContainer = Color(0xFFEAF2FF);
const overlayScrim = Color(0x59000000);
const borderRadius = 12.0;
const smallBorderRadius = 8.0;
const cardElevation = 0.0;
```

五套主题专属字段如下：

| Token | 医疗蓝 `medicalBlue` | 灰蓝专业 `slateBlue` | 紫粉灰 `purplePinkGray` | 绿色清新 `freshGreen` | 粉杏柔和 `peachPink` |
|---|---|---|---|---|---|
| `pageBackground` | `0xFFF4F7FA` | `0xFFF3F5F7` | `0xFFF8F5F9` | `0xFFF5F8F6` | `0xFFF9F6F4` |
| `shellBackground` | `0xFFF8FAFC` | `0xFFF6F8FA` | `0xFFFBF9FC` | `0xFFFAFBFA` | `0xFFFCFAF9` |
| `panelBackground` | `0xFFFEFEFE` | `0xFFFEFEFE` | `0xFFFEFDFE` | `0xFFFEFEFD` | `0xFFFEFDFC` |
| `cardBackground` | `0xFFFEFEFE` | `0xFFFEFEFE` | `0xFFFEFDFE` | `0xFFFEFEFD` | `0xFFFEFDFC` |
| `elevatedCardBackground` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0xFFFFFFFF` | `0xFFFFFFFF` |
| `mutedBackground` | `0xFFEEF4F8` | `0xFFEEF2F6` | `0xFFF6F0F6` | `0xFFEEF6F2` | `0xFFF6EFEC` |
| `inputBackground` | `0xFFF6F9FC` | `0xFFF8FAFC` | `0xFFFBF9FC` | `0xFFF8FAF8` | `0xFFFCFAF8` |
| `border` | `0xFFE1EAF5` | `0xFFDFE7EF` | `0xFFE9DFEA` | `0xFFDDECE4` | `0xFFEADDE0` |
| `divider` | `0xFFEEF3F8` | `0xFFE9EEF3` | `0xFFF0E8F1` | `0xFFEAF1ED` | `0xFFF0E6E8` |
| `primaryAccent` | `0xFF2E7DB8` | `0xFF4F7CAC` | `0xFF9A78A8` | `0xFF2F8F72` | `0xFFC97888` |
| `secondaryAccent` | `0xFF5BA8D6` | `0xFF6A9A8B` | `0xFFC99AAD` | `0xFF2E7DB8` | `0xFF8FA7A0` |
| `dangerAccent` | `0xFFE85D75` | `0xFFE85D75` | `0xFFE85D75` | `0xFFE85D75` | `0xFFE85D75` |
| `warningAccent` | `0xFFF5A623` | `0xFFF5A623` | `0xFFF5A623` | `0xFFF5A623` | `0xFFF5A623` |
| `iconMuted` | `0xFF667085` | `0xFF657484` | `0xFF7D7185` | `0xFF6D7F73` | `0xFF7D6F73` |
| `textMuted` | `0xFF7A8796` | `0xFF6B7A88` | `0xFF7D7185` | `0xFF6D7F73` | `0xFF7D6F73` |
| `hoverBackground` | `0xFFEAF4FB` | `0xFFEEF5FB` | `0xFFF5EEF7` | `0xFFE7F4EF` | `0xFFFBECEF` |
| `selectedBackground` | `0xFFDCECF8` | `0xFFE1EEF8` | `0xFFEFE3F3` | `0xFFD9EEE6` | `0xFFF7DDE3` |
| `disabledBackground` | `0xFFE8ECF1` | `0xFFE6EAEE` | `0xFFEDE7EE` | `0xFFE5ECE8` | `0xFFEEE7E5` |
| `disabledText` | `0xFF98A2B3` | `0xFF9AA6B2` | `0xFFA69BAA` | `0xFF9EABA3` | `0xFFA99EA1` |
| `tableHeaderBackground` | `0xFFF0F5FA` | `0xFFEEF2F6` | `0xFFF3EDF4` | `0xFFEFF6F2` | `0xFFF6EEF0` |
| `listItemHoverBackground` | `0xFFF7FBFF` | `0xFFF7FAFC` | `0xFFFCF8FC` | `0xFFF7FBF8` | `0xFFFFF8F9` |

`shadow`、`focusRing`、`cardShadow`、`elevatedShadow` 的规则：

| 主题 | `shadow` | `cardShadow` | `elevatedShadow` |
|---|---|---|---|
| 医疗蓝 | `primaryAccent.withValues(alpha: 0.08)` | 同色 8%，blur 24，offset `(0, 8)` | 同色 10%，blur 28，offset `(0, 12)` |
| 灰蓝专业 | `Color(0xFF263238).withValues(alpha: 0.07)` | 同色 7%，blur 22，offset `(0, 8)` | 同色 10%，blur 28，offset `(0, 12)` |
| 紫粉灰 | `Color(0xFF332B38).withValues(alpha: 0.08)` | 同色 8%，blur 24，offset `(0, 8)` | 同色 10%，blur 28，offset `(0, 12)` |
| 绿色清新 | `primaryAccent.withValues(alpha: 0.08)` | 同色 8%，blur 24，offset `(0, 8)` | 同色 10%，blur 28，offset `(0, 12)` |
| 粉杏柔和 | `Color(0xFF3A2F33).withValues(alpha: 0.07)` | 同色 7%，blur 24，offset `(0, 8)` | 同色 10%，blur 28，offset `(0, 12)` |

`focusRing` 五套主题都必须为 `primaryAccent.withValues(alpha: 0.20)`。

`primaryHeaderGradient.colors` 固定为：

| 主题 | 色值 |
|---|---|
| 医疗蓝 | `[Color(0xFF2E7DB8), Color(0xFF5BA8D6)]` |
| 灰蓝专业 | `[Color(0xFF4F7CAC), Color(0xFF7DA7C7)]` |
| 紫粉灰 | `[Color(0xFF8F76A3), Color(0xFFB48AA8), Color(0xFFC9B6CF)]` |
| 绿色清新 | `[Color(0xFF2E7DB8), Color(0xFF2F8F72)]` |
| 粉杏柔和 | `[Color(0xFFC97888), Color(0xFFDDA0AA), Color(0xFFE8C4C0)]` |

`subtleHeaderGradient` 五套主题都必须从 `primaryAccent.withValues(alpha: 0.08)` 到 `secondaryAccent.withValues(alpha: 0.04)`。

`chartPalette` 固定为：

| 主题 | 色值 |
|---|---|
| 医疗蓝 | `[0xFF2E7DB8, 0xFF5BA8D6, 0xFF7DA7C7, 0xFFF5A623, 0xFFE85D75]` |
| 灰蓝专业 | `[0xFF4F7CAC, 0xFF6A9A8B, 0xFF7DA7C7, 0xFFF5A623, 0xFFE85D75]` |
| 紫粉灰 | `[0xFF9A78A8, 0xFFC99AAD, 0xFF7DA7C7, 0xFFF5A623, 0xFFE85D75]` |
| 绿色清新 | `[0xFF2F8F72, 0xFF2E7DB8, 0xFF76A66F, 0xFFF5A623, 0xFFE85D75]` |
| 粉杏柔和 | `[0xFFC97888, 0xFF8FA7A0, 0xFF7DA7C7, 0xFFF5A623, 0xFFE85D75]` |

### 9.7.4 `app_theme.dart` 必须定义的类型和入口

在 `lib/theme/app_theme.dart` 中新增枚举，位置放在 `AppTheme` class 前：

```dart
enum WindowsThemeVariant {
  medicalBlue,
  slateBlue,
  purplePinkGray,
  freshGreen,
  peachPink,
}
```

同文件必须新增解析扩展。字符串必须稳定，不能保存枚举 index：

```dart
extension WindowsThemeVariantParsing on WindowsThemeVariant {
  String get storageValue {
    switch (this) {
      case WindowsThemeVariant.medicalBlue:
        return 'medicalBlue';
      case WindowsThemeVariant.slateBlue:
        return 'slateBlue';
      case WindowsThemeVariant.purplePinkGray:
        return 'purplePinkGray';
      case WindowsThemeVariant.freshGreen:
        return 'freshGreen';
      case WindowsThemeVariant.peachPink:
        return 'peachPink';
    }
  }

  AppThemeTokens get tokens {
    switch (this) {
      case WindowsThemeVariant.medicalBlue:
        return AppThemeTokens.medicalBlue();
      case WindowsThemeVariant.slateBlue:
        return AppThemeTokens.slateBlue();
      case WindowsThemeVariant.purplePinkGray:
        return AppThemeTokens.purplePinkGray();
      case WindowsThemeVariant.freshGreen:
        return AppThemeTokens.freshGreen();
      case WindowsThemeVariant.peachPink:
        return AppThemeTokens.peachPink();
    }
  }

  static WindowsThemeVariant fromStorageValue(String? value) {
    switch (value) {
      case 'medicalBlue':
      case 'standard':
      case 'light':
      case 'grey':
      case 'gray':
      case null:
      case '':
        return WindowsThemeVariant.medicalBlue;
      case 'slateBlue':
        return WindowsThemeVariant.slateBlue;
      case 'purplePinkGray':
        return WindowsThemeVariant.purplePinkGray;
      case 'freshGreen':
        return WindowsThemeVariant.freshGreen;
      case 'peachPink':
        return WindowsThemeVariant.peachPink;
      default:
        return WindowsThemeVariant.medicalBlue;
    }
  }
}
```

`AppTheme` class 内必须新增：

```dart
static ThemeData resolve(WindowsThemeVariant variant) {
  return _buildTheme(variant.tokens);
}

static ThemeData standardTheme() => resolve(WindowsThemeVariant.medicalBlue);
```

### 9.7.5 设置和持久化必须定义的字段

在 `lib/providers/settings_provider.dart` 中：

1. 导入 `../theme/app_theme.dart`。
2. 新增字段：

```dart
WindowsThemeVariant _windowsThemeVariant = WindowsThemeVariant.medicalBlue;
WindowsThemeVariant get windowsThemeVariant => _windowsThemeVariant;
```

3. `_applyLoadedSettings(...)` 中加入：

```dart
_windowsThemeVariant = WindowsThemeVariantParsing.fromStorageValue(
  settings['windowsThemeVariant']?.toString(),
);
_extendedThemeMode = ExtendedThemeMode.light;
```

4. `_saveSettings()` 的 map 中加入：

```dart
'windowsThemeVariant': _windowsThemeVariant.storageValue,
```

5. 新增 setter：

```dart
Future<void> setWindowsThemeVariant(WindowsThemeVariant variant) async {
  _windowsThemeVariant = variant;
  _extendedThemeMode = ExtendedThemeMode.light;
  _themeMode = ThemeMode.light;
  await _saveSettings();
  notifyListeners();
}
```

6. `setExtendedThemeMode(...)` 和 `setThemeMode(...)` 继续保留，但必须把 `_windowsThemeVariant` 设回 `WindowsThemeVariant.medicalBlue`。

在 `lib/features/settings/services/config_storage_service.dart` 中：

```dart
'windowsThemeVariant': prefs.getString('windowsThemeVariant') ?? 'medicalBlue',
```

并在 `saveSettings(...)` 中加入：

```dart
if (settings.containsKey('windowsThemeVariant')) {
  await prefs.setString(
    'windowsThemeVariant',
    settings['windowsThemeVariant'].toString(),
  );
}
```

配置兼容规则固定如下：

| 输入配置 | 最终主题 |
|---|---|
| 无 `windowsThemeVariant` | `medicalBlue` |
| `medicalBlue` / `standard` / `light` / `grey` / `gray` | `medicalBlue` |
| `slateBlue` | `slateBlue` |
| `purplePinkGray` | `purplePinkGray` |
| `freshGreen` | `freshGreen` |
| `peachPink` | `peachPink` |
| 未知字符串 | `medicalBlue` |
| 旧 `extendedThemeMode` 或 `themeMode` 任意值 | 不决定新主题，只保留兼容读取 |

### 9.7.6 `main.dart` 和设置页必须这样接入

`lib/main.dart` 中 `AppWithProviders.build` 必须读取设置：

```dart
final appState = Provider.of<AppState>(context);
final settings = Provider.of<SettingsProvider>(context);
```

`MaterialApp` 必须使用：

```dart
theme: AppTheme.resolve(settings.windowsThemeVariant),
```

文件底部 `getThemeData(BuildContext context)` 必须同步使用当前设置：

```dart
ThemeData getThemeData(BuildContext context) {
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  return AppTheme.resolve(settings.windowsThemeVariant);
}
```

`theme_section.dart` 的主题排序固定为：

```dart
const variants = [
  WindowsThemeVariant.medicalBlue,
  WindowsThemeVariant.slateBlue,
  WindowsThemeVariant.purplePinkGray,
  WindowsThemeVariant.freshGreen,
  WindowsThemeVariant.peachPink,
];
```

每张卡片点击时调用：

```dart
settingsProvider.setWindowsThemeVariant(variant);
```

`theme_card.dart` 构造参数固定为：

```dart
final WindowsThemeVariant variant;
final String title;
final String subtitle;
final IconData icon;
final List<Color> swatches;
final bool isSelected;
```

五套卡片色块固定如下：

| 主题 | `swatches` |
|---|---|
| 医疗蓝 | `[0xFF2E7DB8, 0xFF5BA8D6, 0xFFF4F7FA]` |
| 灰蓝专业 | `[0xFF4F7CAC, 0xFF6A9A8B, 0xFFF3F5F7]` |
| 紫粉灰 | `[0xFF9A78A8, 0xFFC99AAD, 0xFFF8F5F9]` |
| 绿色清新 | `[0xFF2F8F72, 0xFF2E7DB8, 0xFFF5F8F6]` |
| 粉杏柔和 | `[0xFFC97888, 0xFF8FA7A0, 0xFFF9F6F4]` |

### 9.7.7 禁止自由发挥的边界

- 不允许在 `lib/screens/**` 或 `lib/features/**` 新增 `if (theme == ...)`、`switch (theme)`、`WindowsThemeVariant.xxx` 页面级颜色分支。
- 不允许在业务页面新增五套主题色常量。
- 不允许把 `primaryAccent` 当作成功、欠费、删除、警告等业务状态色。
- 不允许恢复 `grey` / 柔和灰主题入口。
- 不允许恢复历史紫色运行链路。
- 不允许把主题配置保存为枚举 index。
- 不允许新增全局依赖。
- 不允许为了通过分析删除业务逻辑、注释报错代码或加 `// ignore`。

允许保留的例外：

| 例外 | 条件 |
|---|---|
| `Colors.transparent` | 透明语义明确，且不是主题视觉来源 |
| 医学识别色 | 牙位、疾病、病历模板等医学语义，不表达页面主题 |
| 性别识别色 | 患者性别头像或标签 |
| 图表局部派生色 | 必须来自 `context.tokens.chartPalette` 或明确业务语义 |
| 旧 `ExtendedThemeMode` | 仅用于兼容旧配置，不作为新主题系统入口 |

### 9.7.8 最终验收命令和搜索标准

实现完成后必须在 `windows_app/` 下运行：

```powershell
flutter analyze
```

如果改动了可测试逻辑，再运行：

```powershell
flutter test
```

实现后必须做以下搜索复核：

```powershell
Select-String -Path lib\screens\*.dart,lib\features\**\*.dart -Pattern "WindowsThemeVariant|themeVariant|windowsThemeVariant"
Select-String -Path lib\screens\*.dart,lib\features\**\*.dart -Pattern "DentalColors\.|AppTheme\.primaryColor|AppTheme\.secondaryColor|AppTheme\.primaryGradient"
Select-String -Path lib\screens\*.dart,lib\features\**\*.dart -Pattern "Colors\.white|Colors\.grey|Color\(0x"
Select-String -Path lib\theme\*.dart,lib\providers\settings_provider.dart,lib\features\settings\services\config_storage_service.dart,lib\main.dart -Pattern "windowsThemeVariant|WindowsThemeVariant"
```

验收标准：

| 项目 | 必须达到 |
|---|---|
| `flutter analyze` | `No issues found!` |
| 主题枚举命中 | 只允许出现在 `app_theme.dart`、`settings_provider.dart`、设置页主题组件、`main.dart` |
| 业务页面主题分支 | 0 个新增命中 |
| `DentalColors` 普通主题用途 | 0 个；剩余必须属于医学/性别/状态例外 |
| 直接颜色硬编码 | 普通背景、卡片、边框、hover、selected、disabled、按钮主题色不得新增 |
| 设置持久化 | `windowsThemeVariant` 写入字符串并能回读 |
| 旧配置兼容 | `grey`、未知字符串、缺失配置都回退医疗蓝 |
| 页面覆盖 | 首页、患者、预约、财务、材料、采购、病历、设置、弹窗、表单、统计图表随主题变化 |
| 文档同步 | 根目录 `ROADMAP.md` 记录实现状态和验证结果 |

### 9.7.9 实施顺序

1. 在 `app_theme_tokens.dart` 新增五套完整 token factory，并让 `standard()` 指向 `medicalBlue()`。
2. 在 `app_theme.dart` 新增 `WindowsThemeVariant`、解析扩展和 `AppTheme.resolve(...)`。
3. 在 `settings_provider.dart` 和 `config_storage_service.dart` 接入 `windowsThemeVariant` 字符串配置。
4. 在 `main.dart` 用 `AppTheme.resolve(settings.windowsThemeVariant)` 驱动 `MaterialApp.theme`。
5. 改造 `theme_section.dart` 和 `theme_card.dart`，只做主题选择和色块展示。
6. 运行 `flutter analyze`，修复所有错误和新增 lint。
7. 做 9.7.8 的搜索复核，确认没有页面级主题分支和普通颜色硬编码回流。
8. 更新 `ROADMAP.md`，只记录已实现且已验证的结果。

---

# 10. 最终建议

如果只先实现两套，建议先做：

1. 医疗蓝主题：作为默认主题，使用蓝 + 低饱和青蓝，绿色只保留给业务状态。
2. 灰蓝专业主题：作为长时间办公主题，优先服务 Windows 端高密度后台。

如果要做完整主题系统，建议五套全部保留，但所有主题都遵守同一套组件规则：

- 页面背景不要纯白。
- 卡片接近白但柔和。
- 主色低饱和。
- 状态色固定。
- 模块卡片不要五颜六色。
- 弹窗标题栏用主题浅色，确认按钮用主题主色。
- 表格、筛选栏、详情页优先保证清晰，不追求装饰感。
- 绿色主题必须避开成功状态混淆。
- 粉杏主题必须避开错误/欠费状态混淆。
- 图表色板独立维护，不能只用主题主色深浅变化。

这样能保证系统在多主题下仍然统一、清晰、耐看。
