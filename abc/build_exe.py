import PyInstaller.__main__
import os
import shutil

# 确保输出目录存在
if os.path.exists('dist'):
    shutil.rmtree('dist')

# 使用PyInstaller打包应用
PyInstaller.__main__.run([
    'app.py',                      # 主脚本
    '--name=牙科诊所管理系统',      # 应用名称
    '--onedir',                   # 创建单个文件夹
    '--windowed',                 # 无控制台窗口
    '--add-data=templates;templates',  # 包含模板文件夹
    '--add-data=.env;.',          # 包含环境配置文件
    '--add-data=instance/dental_clinic.db;instance',  # 包含SQLite数据库文件
    '--hidden-import=flask',
    '--hidden-import=flask_sqlalchemy',
    '--hidden-import=flask_login',
    '--hidden-import=flask_migrate',
    '--hidden-import=sqlite3',     # 替换pymysql为sqlite3
    '--hidden-import=wtforms',
    '--hidden-import=flask_wtf',
    '--hidden-import=python-dotenv',
])

print("打包完成！可执行文件在dist文件夹中。")