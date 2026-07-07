@echo off
echo 清理项目中的数据库文件...

REM 删除所有.db文件
for /r . %%f in (*.db) do (
    echo 删除: %%f
    del "%%f" 2>nul
)

REM 删除所有.sqlite文件
for /r . %%f in (*.sqlite) do (
    echo 删除: %%f
    del "%%f" 2>nul
)

REM 删除所有.sqlite3文件
for /r . %%f in (*.sqlite3) do (
    echo 删除: %%f
    del "%%f" 2>nul
)

REM 删除build目录
if exist build (
    echo 删除build目录...
    rmdir /s /q build
)

REM 删除配置文件
if exist config\database_settings.json (
    echo 删除数据库配置文件...
    del config\database_settings.json
)

echo 数据库文件清理完成！
pause