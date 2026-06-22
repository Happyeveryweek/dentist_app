@echo off
echo ========================================
echo MySQL工具验证脚本
echo ========================================
echo.

set TOOLS_DIR=%~dp0tools

echo 检查MySQL工具安装状态...
echo 工具目录: %TOOLS_DIR%
echo.

if exist "%TOOLS_DIR%\mysql.exe" (
    echo [OK] mysql.exe 已安装
) else (
    echo [ERROR] mysql.exe 缺失
)

if exist "%TOOLS_DIR%\mysqldump.exe" (
    echo [OK] mysqldump.exe 已安装
) else (
    echo [ERROR] mysqldump.exe 缺失
)

if exist "%TOOLS_DIR%\libmysql.dll" (
    echo [OK] libmysql.dll 已安装
) else (
    echo [ERROR] libmysql.dll 缺失
)

echo.
echo ========================================
echo 验证完成
echo ========================================
pause