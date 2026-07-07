@echo off
echo 正在清除牙医应用的所有数据...

REM 1. 删除文档目录下的应用数据
echo 删除应用数据目录...
if exist "%USERPROFILE%\Documents\DentistApp" (
    rmdir /s /q "%USERPROFILE%\Documents\DentistApp"
    echo 已删除: %USERPROFILE%\Documents\DentistApp
) else (
    echo 未找到应用数据目录
)

REM 2. 删除可能的缓存目录
echo 删除缓存目录...
if exist "%LOCALAPPDATA%\DentistApp" (
    rmdir /s /q "%LOCALAPPDATA%\DentistApp"
    echo 已删除: %LOCALAPPDATA%\DentistApp
)

if exist "%APPDATA%\DentistApp" (
    rmdir /s /q "%APPDATA%\DentistApp"
    echo 已删除: %APPDATA%\DentistApp
)

REM 3. 清除注册表中的SharedPreferences（需要管理员权限）
echo 清除注册表配置...
reg delete "HKEY_CURRENT_USER\Software\flutter_windows_app" /f 2>nul
reg delete "HKEY_CURRENT_USER\Software\com.example.dentist_app" /f 2>nul

echo.
echo 数据清除完成！
echo 注意：如果应用仍然显示旧数据，请检查以下位置：
echo 1. %USERPROFILE%\Documents\DentistApp
echo 2. 注册表中的 SharedPreferences 数据
echo.
pause