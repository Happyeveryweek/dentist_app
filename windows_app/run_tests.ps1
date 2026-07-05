# 运行 Flutter 单元测试并打印清晰总览
# 用法：.\run_tests.ps1

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host "错误：未找到 flutter 命令" -ForegroundColor Red
    exit 1
}

# 运行测试并捕获输出
$result = & flutter test --reporter expanded 2>&1
$exitCode = $LASTEXITCODE

# 打印完整测试输出
$result | ForEach-Object { Write-Host $_ }

# 解析输出中的最大通过数（更稳健）
$maxPassed = 0
foreach ($line in $result) {
    if ($line -match '\+(\d+):') {
        $num = [int]$Matches[1]
        if ($num -gt $maxPassed) {
            $maxPassed = $num
        }
    }
}
$totalTests = $maxPassed

# 打印醒目标题总览
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($exitCode -eq 0) {
    Write-Host "  测试结果：全部通过" -ForegroundColor Green
    Write-Host "  通过数量：$totalTests" -ForegroundColor Green
    Write-Host "  失败数量：0" -ForegroundColor Green
} else {
    Write-Host "  测试结果：存在失败" -ForegroundColor Red
    Write-Host "  总测试数：$totalTests" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan

exit $exitCode
