#!/bin/bash

echo "清理项目中的数据库文件..."

# 删除所有.db文件
find . -name "*.db" -type f -exec rm -f {} \; -print

# 删除所有.sqlite文件
find . -name "*.sqlite" -type f -exec rm -f {} \; -print

# 删除所有.sqlite3文件
find . -name "*.sqlite3" -type f -exec rm -f {} \; -print

# 删除build目录
if [ -d "build" ]; then
    echo "删除build目录..."
    rm -rf build
fi

# 删除配置文件
if [ -f "config/database_settings.json" ]; then
    echo "删除数据库配置文件..."
    rm -f config/database_settings.json
fi

echo "数据库文件清理完成！"