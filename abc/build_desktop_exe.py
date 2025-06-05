import PyInstaller.__main__
import os
import shutil

# 确保输出目录存在
if os.path.exists('dist/牙科诊所管理系统_桌面版'):
    shutil.rmtree('dist/牙科诊所管理系统_桌面版')

# 使用PyInstaller打包应用
PyInstaller.__main__.run([
    'desktop_app.py',              # 主脚本
    '--name=牙科诊所管理系统_桌面版',  # 应用名称
    '--onedir',                   # 创建单个文件夹
    '--windowed',                 # 无控制台窗口
    '--add-data=templates;templates',  # 包含模板文件夹
    '--add-data=.env;.',          # 包含环境配置文件
    '--add-data=instance/dental_clinic.db;instance',  # 包含SQLite数据库文件
    '--hidden-import=PyQt5',
    '--hidden-import=PyQt5.QtWidgets',
    '--hidden-import=PyQt5.QtCore',
    '--hidden-import=PyQt5.QtGui',
    '--hidden-import=flask',
    '--hidden-import=flask_sqlalchemy',
    '--hidden-import=flask_login',
    '--hidden-import=flask_migrate',
    '--hidden-import=sqlite3',
    '--hidden-import=wtforms',
    '--hidden-import=flask_wtf',
    '--hidden-import=python-dotenv',
])

print("打包完成！桌面版可执行文件在dist/牙科诊所管理系统_桌面版文件夹中。")