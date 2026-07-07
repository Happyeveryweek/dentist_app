# CRLF to LF Execution Guide

## Goal

将 `D:\Data\android_project\dentist_app` 仓库内仍然使用 `CRLF` 的文本文件，按受控批次修复为 `LF`，不改业务逻辑，不改二进制文件，不混入无关重构。

本指南是直接执行版，不是讨论版。另一个模型按本文命令逐步执行即可。

## Preconditions

1. 工作目录固定为：

```powershell
Set-Location D:\Data\android_project\dentist_app
```

2. 必须先确认当前工作区是否干净：

```powershell
git status --short
```

3. 如果存在未提交业务改动，不要直接全仓改行尾。
当前策略是：

- 先提交或暂存已有业务改动。
- 再单独做一轮“纯 LF 标准化”提交。

4. 仓库应保留以下规则文件：

`.gitattributes`

```gitattributes
* text=auto eol=lf

*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.db binary
*.sqlite binary
*.zip binary
```

`.editorconfig`

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
```

## Step 1: Inventory CRLF Files

执行下面的 PowerShell，统计当前已跟踪文本文件里仍含 `CRLF` 的文件：

```powershell
$files = git ls-files
$total = 0
$crlfFiles = New-Object System.Collections.Generic.List[string]
foreach ($file in $files) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $file).Path)
  if ($bytes.Length -eq 0) { continue }
  $nulIndex = [Array]::IndexOf($bytes, [byte]0)
  if ($nulIndex -ge 0) { continue }
  $hasCrlf = $false
  for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
    if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) {
      $hasCrlf = $true
      break
    }
  }
  if ($hasCrlf) {
    $total++
    $crlfFiles.Add($file) | Out-Null
  }
}
"CRLF_COUNT=$total"
$crlfFiles | Set-Content -LiteralPath .\tmp_crlf_file_list.txt -Encoding utf8
```

预期结果：

- 控制台打印 `CRLF_COUNT=...`
- 根目录生成 `tmp_crlf_file_list.txt`

## Step 2: Split Into Batches

不要一次性全仓改。按下面批次执行，每批一个提交：

1. 根目录文档和配置
2. `windows_app` 非生成代码
3. `android_app` 非生成代码
4. 必要时再处理零散遗漏

先生成每批文件清单：

```powershell
Get-Content .\tmp_crlf_file_list.txt | Where-Object {
  $_ -match '^(README\.md|LICENSE|ROADMAP\.md|.*\.ya?ml|.*\.md|.*\.gitignore)$'
} | Set-Content .\tmp_batch_root.txt -Encoding utf8

Get-Content .\tmp_crlf_file_list.txt | Where-Object {
  $_ -like 'windows_app/*'
} | Set-Content .\tmp_batch_windows.txt -Encoding utf8

Get-Content .\tmp_crlf_file_list.txt | Where-Object {
  $_ -like 'android_app/*'
} | Set-Content .\tmp_batch_android.txt -Encoding utf8
```

## Step 3: Convert One Batch to LF

下面命令用于把一个批次的文件统一改为 `LF`，保持 `UTF-8 without BOM`：

```powershell
$listFile = '.\tmp_batch_windows.txt'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$files = Get-Content -LiteralPath $listFile | Where-Object { $_.Trim() -ne '' }
foreach ($file in $files) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
  $path = (Resolve-Path -LiteralPath $file).Path
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $text = $text -replace "`r`n", "`n"
  $text = $text -replace "`r", "`n"
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}
```

每次只替换一个 `listFile`：

- 根目录批次：`.\\tmp_batch_root.txt`
- Windows 端批次：`.\\tmp_batch_windows.txt`
- Android 端批次：`.\\tmp_batch_android.txt`

## Step 4: Validate Batch

每一批转完后，立即执行：

```powershell
git diff --check
```

然后仅扫描当前批次确认不存在 `CRLF`：

```powershell
$listFile = '.\tmp_batch_windows.txt'
$files = Get-Content -LiteralPath $listFile | Where-Object { $_.Trim() -ne '' }
foreach ($file in $files) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $file).Path)
  $hasCrlf = $false
  for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
    if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) {
      $hasCrlf = $true
      break
    }
  }
  if ($hasCrlf) { "CRLF $file" }
}
```

预期结果：

- `git diff --check` 无输出
- CRLF 扫描无输出

## Step 5: Run Project Validation

### 处理 `windows_app` 批次后

```powershell
Set-Location D:\Data\android_project\dentist_app\windows_app
flutter analyze
Set-Location D:\Data\android_project\dentist_app
```

### 处理 `android_app` 批次后

```powershell
Set-Location D:\Data\android_project\dentist_app\android_app
flutter analyze
Set-Location D:\Data\android_project\dentist_app
```

说明：

- 纯行尾修复通常不需要 `flutter test`
- 如果该批次恰好覆盖到正在改的业务文件，可按项目规则追加测试

## Step 6: Commit Each Batch Separately

每批独立提交，提交信息必须明确写是行尾标准化，不得伪装成业务改动。

示例：

```powershell
git add --pathspec-from-file=.\\tmp_batch_windows.txt
git add .gitattributes .editorconfig
git commit -m "统一 windows_app 文本文件行尾为 LF"
```

根目录批次示例：

```powershell
git add --pathspec-from-file=.\\tmp_batch_root.txt
git add .gitattributes .editorconfig
git commit -m "统一根目录文档和配置文件行尾为 LF"
```

Android 端批次示例：

```powershell
git add --pathspec-from-file=.\\tmp_batch_android.txt
git commit -m "统一 android_app 文本文件行尾为 LF"
```

## Step 7: Final Global Verification

全部批次完成后，重新执行全仓扫描：

```powershell
$files = git ls-files
$total = 0
foreach ($file in $files) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $file).Path)
  if ($bytes.Length -eq 0) { continue }
  $nulIndex = [Array]::IndexOf($bytes, [byte]0)
  if ($nulIndex -ge 0) { continue }
  $hasCrlf = $false
  for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
    if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) {
      $hasCrlf = $true
      break
    }
  }
  if ($hasCrlf) { $total++ }
}
"CRLF_COUNT=$total"
```

预期结果：

```text
CRLF_COUNT=0
```

然后执行：

```powershell
git diff --check
git status --short
```

预期结果：

- `git diff --check` 无输出
- `git status --short` 只剩你预期中的已提交或待提交内容

## Do Not Do

不要做下面这些事：

- 不要把二进制文件一起转行尾
- 不要在有大批未提交业务改动时直接全仓改
- 不要把 LF 修复和业务修改混在一个提交里
- 不要用 `git add .` 粗暴全加
- 不要用 `git reset --hard`

## Recommended Execution Order For This Repo

这次仓库建议直接按这个顺序执行：

1. 先完成当前业务提交
2. 单独执行根目录批次
3. 单独执行 `windows_app` 批次
4. 单独执行 `android_app` 批次
5. 做全仓 CRLF 复扫

## Cleanup

全部完成后删除临时文件：

```powershell
Remove-Item -LiteralPath .\tmp_crlf_file_list.txt -Force
Remove-Item -LiteralPath .\tmp_batch_root.txt -Force
Remove-Item -LiteralPath .\tmp_batch_windows.txt -Force
Remove-Item -LiteralPath .\tmp_batch_android.txt -Force
```
