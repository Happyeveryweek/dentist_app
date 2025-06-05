#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os

# 添加当前目录到Python路径
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

try:
    from PyQt6.QtWidgets import QApplication, QDialog, QMessageBox, QWidget
    from app.auth import LoginWindow
    from desktop_app_pyqt6 import MainWindow
except ImportError as e:
    print(f"导入错误: {e}")
    sys.exit(1)

# 主程序入口
if __name__ == "__main__":
    app_instance = QApplication(sys.argv)
    
    # 设置应用样式
    app_instance.setStyle("Fusion")
    
    # 设置tooltip样式，使文字更清晰可见
    app_instance.setStyleSheet("""
        QToolTip {
            background-color: rgba(255, 255, 255, 220) !important;
            color: black !important;
            border: 1px solid #76797C !important;
            border-radius: 4px !important;
            padding: 5px !important;
            font-size: 12px !important;
            font-weight: bold !important;
            opacity: 255 !important;
        }
    """)
    
    try:
        # 显示登录窗口
        login_window = LoginWindow()
        if login_window.exec() == QDialog.DialogCode.Accepted:
            # 登录成功，显示主窗口
            main_window = MainWindow(login_window.current_user)
            main_window.show()
            sys.exit(app_instance.exec())
    except Exception as e:
        QMessageBox.critical(None, "错误", f"程序启动时发生错误: {str(e)}")
        print(f"错误: {e}")
        sys.exit(1) 