import os
import json
import base64
import hashlib
import shutil
from datetime import datetime
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, 
                           QGridLayout, QComboBox, QPushButton, QMessageBox,
                           QFileDialog, QTabWidget, QGroupBox, QRadioButton, QDialog)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont, QIcon
from cryptography.fernet import Fernet
import sqlite3
import pymysql

# 导入数据库模型和初始化
from init import db, app
from models import User, Patient, Appointment, FollowUpVisit

# 从styles导入必要的样式和组件
from app.styles import (Card, PrimaryButton, SecondaryButton, StyledLineEdit,
                      BACKGROUND_COLOR, TEXT_COLOR, ACCENT_COLOR, BORDER_RADIUS, SECONDARY_TEXT_COLOR)

# 配置文件路径
CONFIG_FILE = "config/database_settings.json"

class SystemManagementTab:
    def __init__(self, main_window):
        self.main_window = main_window
        self.system_management_tab = QWidget()
        
        # 确保配置目录存在
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        
        # 创建加密密钥或加载现有密钥
        self.encryption_key = self.get_or_create_key()
        
        # 加载现有配置或创建默认配置
        self.config = self.load_config()
        
        self.setup_system_management_tab()
        
    def get_or_create_key(self):
        """创建新的加密密钥或加载现有密钥"""
        key_file = "config/encryption.key"
        try:
            # 检查密钥文件是否存在
            if os.path.exists(key_file):
                # 加载现有密钥
                with open(key_file, "rb") as f:
                    key = f.read()
                return key
            else:
                # 创建新密钥
                key = Fernet.generate_key()
                # 保存密钥到文件
                os.makedirs(os.path.dirname(key_file), exist_ok=True)
                with open(key_file, "wb") as f:
                    f.write(key)
                return key
        except Exception as e:
            print(f"创建或加载加密密钥时出错: {str(e)}")
            # 如果出错，生成一个临时密钥（不会保存）
            return Fernet.generate_key()
        
    def load_config(self):
        """加载配置或创建默认配置"""
        try:
            if os.path.exists(CONFIG_FILE):
                with open(CONFIG_FILE, "r") as f:
                    encrypted_data = f.read()
                    
                if encrypted_data:
                    # 解密数据
                    cipher = Fernet(self.encryption_key)
                    decrypted_data = cipher.decrypt(encrypted_data.encode()).decode()
                    config = json.loads(decrypted_data)
                    return config
        except Exception as e:
            print(f"加载配置时出错: {str(e)}")
        
        # 返回默认配置
        return {
            "db_type": "sqlite",
            "sqlite": {
                "path": "dental_clinic.db"
            },
            "mysql": {
                "host": "localhost",
                "port": "3306",
                "database": "dental_clinic",
                "username": "root",
                "password": ""
            }
        }
        
    def save_settings(self):
        """保存数据库设置"""
        try:
            # 获取当前设置
            db_type = "sqlite" if self.sqlite_radio.isChecked() else "mysql"
            
            config = {
                "db_type": db_type,
                "sqlite": {
                    "path": self.db_path_input.text()  # 使用用户选择的SQLite路径
                },
                "mysql": {
                    "host": self.host_input.text(),
                    "port": self.port_input.text(),
                    "database": self.db_name_input.text(),
                    "username": self.username_input.text(),
                    "password": ""  # 先不保存密码，后面会处理
                }
            }
            
            # 如果有密码，则加密后存储
            if self.password_input.text():
                cipher = Fernet(self.encryption_key)
                encrypted_password = cipher.encrypt(self.password_input.text().encode()).decode()
                config["mysql"]["password"] = encrypted_password
            
            # 加密整个配置
            encrypted_config = json.dumps(config).encode()
            cipher = Fernet(self.encryption_key)
            encrypted_data = cipher.encrypt(encrypted_config).decode()
            
            # 保存到文件
            with open(CONFIG_FILE, "w") as f:
                f.write(encrypted_data)
            
            QMessageBox.information(self.main_window, "成功", "配置已成功保存！需要重启应用以应用新配置。")
            
            # 更新当前配置
            self.config = config
            
        except Exception as e:
            QMessageBox.critical(self.main_window, "错误", f"保存配置时出错: {str(e)}")
            print(f"保存配置时出错: {str(e)}")
            
    def test_connection(self):
        """测试数据库连接"""
        try:
            if self.sqlite_radio.isChecked():
                # 测试SQLite连接
                db_path = self.db_path_input.text()
                conn = sqlite3.connect(db_path)
                conn.close()
                QMessageBox.information(self.main_window, "成功", "SQLite数据库连接测试成功！")
            else:
                # 测试MySQL连接
                host = self.host_input.text()
                port = int(self.port_input.text())
                database = self.db_name_input.text()
                username = self.username_input.text()
                password = self.password_input.text()
                
                # 尝试连接
                conn = pymysql.connect(
                    host=host,
                    port=port,
                    user=username,
                    password=password,
                    database=database
                )
                conn.close()
                
                QMessageBox.information(self.main_window, "成功", "MySQL数据库连接测试成功！")
        except Exception as e:
            QMessageBox.critical(self.main_window, "错误", f"连接数据库失败: {str(e)}")
            print(f"连接数据库失败: {str(e)}")
            
    def toggle_db_settings(self):
        """根据选择的数据库类型切换配置面板"""
        if self.sqlite_radio.isChecked():
            self.mysql_config_group.setVisible(False)
            self.sqlite_config_group.setVisible(True)
        else:
            self.mysql_config_group.setVisible(True)
            self.sqlite_config_group.setVisible(False)
    
    def create_backup(self):
        """创建数据库备份"""
        try:
            # 默认备份目录 - 使用绝对路径
            default_backup_dir = os.path.abspath(os.path.join(os.getcwd(), "backups"))
            if not os.path.exists(default_backup_dir):
                os.makedirs(default_backup_dir)
            
            # 获取当前日期时间作为默认文件名
            now = datetime.now().strftime("%Y%m%d_%H%M%S")
            
            # 根据数据库类型确定文件扩展名
            is_sqlite = self.config["db_type"] == "sqlite"
            ext = ".db" if is_sqlite else ".sql"
            default_filename = f"dental_clinic_backup_{now}{ext}"
            default_path = os.path.join(default_backup_dir, default_filename)
            
            # 选择保存路径
            file_dialog = QFileDialog(self.main_window)
            file_dialog.setAcceptMode(QFileDialog.AcceptMode.AcceptSave)
            file_dialog.setFileMode(QFileDialog.FileMode.AnyFile)
            file_dialog.setDirectory(default_backup_dir)
            file_dialog.selectFile(default_filename)
            
            filter_string = "SQLite数据库 (*.db)" if is_sqlite else "SQL文件 (*.sql)"
            file_dialog.setNameFilter(filter_string)
            
            if file_dialog.exec() != QDialog.DialogCode.Accepted:
                return
                
            backup_path = file_dialog.selectedFiles()[0]
            
            # 确保文件扩展名正确
            if not backup_path.endswith(ext):
                backup_path += ext
            
            # 根据数据库类型执行不同的备份逻辑
            if is_sqlite:
                # 对于SQLite，复制数据库文件
                # 获取数据库文件的完整路径
                db_filename = self.config["sqlite"]["path"]
                # 首先检查instance目录下是否存在数据库文件
                instance_db_path = os.path.abspath(os.path.join(os.getcwd(), "instance", db_filename))
                # 如果instance目录下不存在，则尝试使用项目根目录下的数据库文件
                root_db_path = os.path.abspath(os.path.join(os.getcwd(), db_filename))
                
                # 确定使用哪个路径
                if os.path.exists(instance_db_path) and os.path.getsize(instance_db_path) > 0:
                    source_db = instance_db_path
                elif os.path.exists(root_db_path) and os.path.getsize(root_db_path) > 0:
                    source_db = root_db_path
                else:
                    raise FileNotFoundError(f"找不到有效的数据库文件: {db_filename}")
                
                # 复制数据库文件
                shutil.copy2(source_db, backup_path)
                QMessageBox.information(self.main_window, "备份成功", f"SQLite数据库已成功备份为:\n{backup_path}\n\n源文件: {source_db}")
            else:
                # 对于MySQL，使用pymysql直接备份数据
                mysql_config = self.config.get("mysql", {})
                host = mysql_config.get("host", "localhost")
                port = int(mysql_config.get("port", "3306"))
                database = mysql_config.get("database", "dental_clinic")
                username = mysql_config.get("username", "root")
                
                # 从加密配置中获取密码
                password = ""
                if mysql_config.get("password"):
                    try:
                        cipher = Fernet(self.encryption_key)
                        password = cipher.decrypt(mysql_config["password"].encode()).decode()
                    except Exception as e:
                        print(f"解密密码时出错: {str(e)}")
                
                try:
                    # 连接到MySQL数据库
                    conn = pymysql.connect(
                        host=host,
                        port=port,
                        user=username,
                        password=password,
                        database=database
                    )
                    
                    # 创建游标
                    cursor = conn.cursor()
                    
                    # 获取所有表名
                    cursor.execute("SHOW TABLES")
                    tables = cursor.fetchall()
                    
                    # 打开文件准备写入
                    with open(backup_path, 'w', encoding='utf-8') as f:
                        # 写入SQL文件头部
                        f.write(f"-- MySQL数据库备份 - {database}\n")
                        f.write(f"-- 备份时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
                        
                        # 为每个表生成创建表和插入数据的SQL语句
                        for table in tables:
                            table_name = table[0]
                            f.write(f"\n-- 表结构: {table_name}\n")
                            
                            # 获取创建表的SQL
                            cursor.execute(f"SHOW CREATE TABLE {table_name}")
                            create_table_sql = cursor.fetchone()[1]
                            f.write(f"{create_table_sql};\n\n")
                            
                            # 获取表数据
                            cursor.execute(f"SELECT * FROM {table_name}")
                            rows = cursor.fetchall()
                            
                            if rows:
                                f.write(f"-- 表数据: {table_name}\n")
                                
                                # 获取列名
                                cursor.execute(f"DESCRIBE {table_name}")
                                columns = [column[0] for column in cursor.fetchall()]
                                
                                # 生成INSERT语句
                                for row in rows:
                                    values = []
                                    for value in row:
                                        if value is None:
                                            values.append("NULL")
                                        elif isinstance(value, (int, float)):
                                            values.append(str(value))
                                        else:
                                            # 转义字符串中的单引号
                                            escaped_value = str(value).replace("'", "\\'") if value else ""
                                            values.append(f"'{escaped_value}'")
                                    
                                    f.write(f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES ({', '.join(values)});\n")
                    
                    # 关闭连接
                    cursor.close()
                    conn.close()
                    
                    QMessageBox.information(self.main_window, "备份成功", f"MySQL数据库已成功备份为:\n{backup_path}")
                    
                except Exception as e:
                    error_msg = str(e)
                    QMessageBox.critical(self.main_window, "备份失败", f"备份MySQL数据库时出错: {error_msg}")
                    print(f"备份MySQL数据库时出错: {error_msg}")
                
        except Exception as e:
            QMessageBox.critical(self.main_window, "备份失败", f"备份数据库时出错: {str(e)}")
            print(f"备份数据库时出错: {str(e)}")
            
    def restore_from_backup(self):
        """从备份还原数据库"""
        # 警告用户此操作不可撤销
        reply = QMessageBox.warning(self.main_window, "警告", 
                                    "还原操作将覆盖当前数据库中的所有数据，此操作不可撤销！\n\n确定要继续吗？",
                                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        
        if reply != QMessageBox.StandardButton.Yes:
            return
        
        # 默认备份目录 - 使用绝对路径
        default_backup_dir = os.path.abspath(os.path.join(os.getcwd(), "backups"))
        if not os.path.exists(default_backup_dir):
            os.makedirs(default_backup_dir)
            
        # 根据数据库类型确定要选择的文件类型
        is_sqlite = self.config["db_type"] == "sqlite"
        filter_string = "SQLite数据库 (*.db)" if is_sqlite else "SQL文件 (*.sql)"
        
        # 选择备份文件
        file_dialog = QFileDialog(self.main_window)
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        file_dialog.setNameFilter(filter_string)
        file_dialog.setDirectory(default_backup_dir)
        
        if file_dialog.exec() != QDialog.DialogCode.Accepted:
            return
            
        selected_files = file_dialog.selectedFiles()
        if not selected_files:
            return
            
        backup_file = selected_files[0]
        
        try:
            if is_sqlite:
                # 对于SQLite，先关闭所有连接，然后替换文件
                target_db = self.config["sqlite"]["path"]
                
                # 二次确认
                reply = QMessageBox.warning(self.main_window, "最终确认", 
                                          f"您即将用 {os.path.basename(backup_file)} 替换当前数据库。\n\n此操作将永久覆盖现有数据且不可撤销！确定要继续吗？",
                                          QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
                
                if reply != QMessageBox.StandardButton.Yes:
                    return
                
                # 复制备份文件到目标位置
                shutil.copy2(backup_file, target_db)
                QMessageBox.information(self.main_window, "还原成功", "数据库已成功还原！请重启应用以应用更改。")
            else:
                # MySQL还原需要更复杂的处理
                mysql_config = self.config.get("mysql", {})
                host = mysql_config.get("host", "localhost")
                port = mysql_config.get("port", "3306")
                database = mysql_config.get("database", "dental_clinic")
                username = mysql_config.get("username", "root")
                
                # 构建mysql命令
                if password:
                    # 如果有密码，生成包含密码的命令（更方便用户）
                    command = f"""
                    你可以使用以下命令还原MySQL数据库:
                    
                    mysql -h{host} -P{port} -u{username} -p{password} {database} < "{backup_file}"
                    
                    或者使用以下命令（需要手动输入密码）:
                    
                    mysql -h{host} -P{port} -u{username} -p {database} < "{backup_file}"
                    
                    如需帮助，请联系系统管理员协助进行还原。
                    """
                else:
                    # 没有密码的情况
                    command = f"""
                    你可以使用以下命令还原MySQL数据库:
                    
                    mysql -h{host} -P{port} -u{username} -p {database} < "{backup_file}"
                    
                    请在命令行中执行此命令，然后输入数据库密码。
                    
                    或者联系系统管理员协助进行还原。
                    """
                
                # 显示命令行信息
                msg_box = QMessageBox(self.main_window)
                msg_box.setWindowTitle("MySQL还原指南")
                msg_box.setText("MySQL数据库还原需要使用命令行工具。")
                msg_box.setDetailedText(command)
                msg_box.setIcon(QMessageBox.Icon.Information)
                msg_box.setStandardButtons(QMessageBox.StandardButton.Ok)
                msg_box.exec()
        except Exception as e:
            QMessageBox.critical(self.main_window, "还原失败", f"还原数据库时出错: {str(e)}")
            print(f"还原数据库时出错: {str(e)}")

    def init_ui_from_config(self):
        """根据配置初始化UI状态"""
        try:
            # 设置数据库类型
            if self.config["db_type"] == "sqlite":
                self.sqlite_radio.setChecked(True)
                self.mysql_config_group.setVisible(False)
                self.sqlite_config_group.setVisible(True)
            else:
                self.mysql_radio.setChecked(True)
                self.mysql_config_group.setVisible(True)
                self.sqlite_config_group.setVisible(False)
            
            # 设置SQLite配置
            sqlite_config = self.config.get("sqlite", {})
            self.db_path_input.setText(sqlite_config.get("path", "dental_clinic.db"))
            
            # 设置MySQL配置
            mysql_config = self.config.get("mysql", {})
            self.host_input.setText(mysql_config.get("host", "localhost"))
            self.port_input.setText(mysql_config.get("port", "3306"))
            self.db_name_input.setText(mysql_config.get("database", "dental_clinic"))
            self.username_input.setText(mysql_config.get("username", "root"))
            
            # 密码不会自动填充，出于安全考虑
        except Exception as e:
            print(f"初始化UI状态时出错: {str(e)}")

    def setup_system_management_tab(self):
        main_layout = QVBoxLayout(self.system_management_tab)
        main_layout.setContentsMargins(8, 8, 8, 8)
        main_layout.setSpacing(15)
        
        # 页面标题区域
        title_layout = QHBoxLayout()
        
        # 图标和标题
        icon_label = QLabel("⚙️")
        icon_label.setStyleSheet("font-size: 22px; color: #4a86e8;")
        
        title_label = QLabel("系统管理")
        title_label.setStyleSheet("""
            font-size: 20px; 
            font-weight: bold; 
            color: #1d1d1f;
            margin-left: 8px;
        """)
        
        title_layout.addWidget(icon_label)
        title_layout.addWidget(title_label)
        title_layout.addStretch()
        
        main_layout.addLayout(title_layout)
        
        # 创建选项卡
        self.tabs = QTabWidget()
        self.tabs.setStyleSheet(f"""
            QTabWidget::pane {{
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                background-color: white;
                top: 4px; /* 修改：增加顶部间距，使面板与选项卡有间隔 */
                padding-top: 15px; /* 增加顶部内边距，避免内容被选项卡遮挡 */
            }}
            QTabBar {{
                font-size: 14px;
            }}
            QTabBar::tab {{
                background-color: #f5f5f7;
                color: {TEXT_COLOR};
                border: 1px solid #d1d1d6;
                border-bottom: none;
                border-top-left-radius: {BORDER_RADIUS};
                border-top-right-radius: {BORDER_RADIUS};
                padding: 10px 20px;
                min-width: 140px;
                font-weight: 500;
                margin-right: 5px; /* 增加标签之间的间距 */
                height: 40px; /* 增加高度使按钮更显眼 */
            }}
            QTabBar::tab:selected {{
                background-color: white;
                border-bottom-color: white;
                color: {ACCENT_COLOR};
                font-weight: bold;
            }}
            QTabBar::tab:hover:!selected {{
                background-color: #e9e9eb;
            }}
        """)
        
        # 数据库设置选项卡
        db_settings_tab = QWidget()
        db_tabs_layout = QVBoxLayout(db_settings_tab)
        db_tabs_layout.setContentsMargins(16, 45, 16, 16)  # 修改：增加顶部边距，确保不遮挡标签
        db_tabs_layout.setSpacing(15)  # 修改：增加间距
        
        # 数据库类型选择
        db_type_group = QGroupBox("数据库类型")
        db_type_group.setStyleSheet(f"""
            QGroupBox {{
                font-weight: bold;
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                margin-top: 20px;  /* 增加上边距 */
                padding-top: 20px;  /* 增加内边距 */
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: 10px;  /* 稍微增加标题左边距 */
                padding: 0 6px;  /* 增加标题内边距 */
                color: {TEXT_COLOR};
                font-size: 14px;  /* 增加标题字体大小 */
            }}
        """)
        
        db_type_layout = QHBoxLayout(db_type_group)
        db_type_layout.setContentsMargins(20, 20, 20, 20)  # 增加内边距
        db_type_layout.setSpacing(25)  # 增加元素间距
        
        # SQLite 选项
        self.sqlite_radio = QRadioButton("SQLite (本地文件数据库)")
        self.sqlite_radio.setStyleSheet(f"""
            QRadioButton {{
                color: {TEXT_COLOR};
                font-size: 13px;
                spacing: 8px;
            }}
            QRadioButton::indicator {{
                width: 16px;
                height: 16px;
                border-radius: 8px;
                border: 2px solid #d1d1d6;
            }}
            QRadioButton::indicator:checked {{
                background-color: {ACCENT_COLOR};
                border: 2px solid {ACCENT_COLOR};
                image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='8' height='8' viewBox='0 0 24 24' fill='white'%3E%3Ccircle cx='12' cy='12' r='6'/%3E%3C/svg%3E");
            }}
        """)
        self.sqlite_radio.toggled.connect(self.toggle_db_settings)
        
        # MySQL 选项
        self.mysql_radio = QRadioButton("MySQL (远程数据库)")
        self.mysql_radio.setStyleSheet(f"""
            QRadioButton {{
                color: {TEXT_COLOR};
                font-size: 13px;
                spacing: 8px;
            }}
            QRadioButton::indicator {{
                width: 16px;
                height: 16px;
                border-radius: 8px;
                border: 2px solid #d1d1d6;
            }}
            QRadioButton::indicator:checked {{
                background-color: {ACCENT_COLOR};
                border: 2px solid {ACCENT_COLOR};
                image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='8' height='8' viewBox='0 0 24 24' fill='white'%3E%3Ccircle cx='12' cy='12' r='6'/%3E%3C/svg%3E");
            }}
        """)
        self.mysql_radio.toggled.connect(self.toggle_db_settings)
        
        db_type_layout.addWidget(self.sqlite_radio)
        db_type_layout.addWidget(self.mysql_radio)
        db_type_layout.addStretch()
        
        db_tabs_layout.addWidget(db_type_group)
        
        # SQLite 配置选项
        self.sqlite_config_group = QGroupBox("SQLite 配置")
        self.sqlite_config_group.setStyleSheet(f"""
            QGroupBox {{
                font-weight: bold;
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                margin-top: 25px;  /* 增加上边距 */
                padding-top: 20px;  /* 增加内边距 */
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: 10px;  /* 稍微增加标题左边距 */
                padding: 0 6px;  /* 增加标题内边距 */
                color: {TEXT_COLOR};
                font-size: 14px;  /* 增加标题字体大小 */
            }}
        """)
        
        sqlite_config_layout = QVBoxLayout(self.sqlite_config_group)
        sqlite_config_layout.setContentsMargins(20, 20, 20, 20)  # 增加内边距
        sqlite_config_layout.setSpacing(15)  # 增加元素间距
        
        # 数据库文件路径
        db_path_layout = QHBoxLayout()
        self.db_path_input = StyledLineEdit()
        self.db_path_input.setPlaceholderText("数据库文件路径")
        self.db_path_input.setText(self.config["sqlite"]["path"])
        self.db_path_input.setReadOnly(True)
        
        browse_btn = QPushButton("浏览...")
        browse_btn.setStyleSheet("""
            QPushButton {
                background-color: #f5f5f7;
                color: #333;
                border: 1px solid #d1d1d6;
                border-radius: 4px;
                padding: 8px 12px;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #e9e9eb;
            }
        """)
        browse_btn.clicked.connect(self.browse_db_file)
        
        db_path_layout.addWidget(self.db_path_input)
        db_path_layout.addWidget(browse_btn)
        
        sqlite_info_label = QLabel("SQLite是一个轻量级的本地文件数据库，适合单机应用。\n数据库文件会保存在应用程序所在目录中。")
        sqlite_info_label.setStyleSheet(f"color: {SECONDARY_TEXT_COLOR}; font-size: 13px;")
        sqlite_info_label.setWordWrap(True)
        
        sqlite_config_layout.addLayout(db_path_layout)
        sqlite_config_layout.addWidget(sqlite_info_label)
        sqlite_config_layout.addStretch()
        
        db_tabs_layout.addWidget(self.sqlite_config_group)
        
        # MySQL 配置选项
        self.mysql_config_group = QGroupBox("MySQL 配置")
        self.mysql_config_group.setStyleSheet(f"""
            QGroupBox {{
                font-weight: bold;
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                margin-top: 25px;  /* 增加上边距 */
                padding-top: 20px;  /* 增加内边距 */
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: 10px;  /* 稍微增加标题左边距 */
                padding: 0 6px;  /* 增加标题内边距 */
                color: {TEXT_COLOR};
                font-size: 14px;  /* 增加标题字体大小 */
            }}
        """)
        
        mysql_config_layout = QGridLayout(self.mysql_config_group)
        mysql_config_layout.setContentsMargins(20, 20, 20, 20)  # 增加内边距
        mysql_config_layout.setSpacing(16)  # 增加元素间距
        mysql_config_layout.setColumnStretch(1, 1)
        
        # 主机名/IP地址
        host_label = QLabel("主机名/IP地址:")
        host_label.setStyleSheet(f"color: {TEXT_COLOR}; font-size: 13px;")
        self.host_input = StyledLineEdit()
        self.host_input.setPlaceholderText("例如: localhost 或 127.0.0.1")
        
        # 端口
        port_label = QLabel("端口:")
        port_label.setStyleSheet(f"color: {TEXT_COLOR}; font-size: 13px;")
        self.port_input = StyledLineEdit()
        self.port_input.setPlaceholderText("MySQL 默认端口: 3306")
        
        # 数据库名称
        db_name_label = QLabel("数据库名称:")
        db_name_label.setStyleSheet(f"color: {TEXT_COLOR}; font-size: 13px;")
        self.db_name_input = StyledLineEdit()
        self.db_name_input.setPlaceholderText("例如: dental_clinic")
        
        # 用户名
        username_label = QLabel("用户名:")
        username_label.setStyleSheet(f"color: {TEXT_COLOR}; font-size: 13px;")
        self.username_input = StyledLineEdit()
        self.username_input.setPlaceholderText("MySQL 用户名")
        
        # 密码
        password_label = QLabel("密码:")
        password_label.setStyleSheet(f"color: {TEXT_COLOR}; font-size: 13px;")
        self.password_input = StyledLineEdit()
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setPlaceholderText("MySQL 密码")
        
        # 添加到网格布局
        mysql_config_layout.addWidget(host_label, 0, 0)
        mysql_config_layout.addWidget(self.host_input, 0, 1)
        mysql_config_layout.addWidget(port_label, 1, 0)
        mysql_config_layout.addWidget(self.port_input, 1, 1)
        mysql_config_layout.addWidget(db_name_label, 2, 0)
        mysql_config_layout.addWidget(self.db_name_input, 2, 1)
        mysql_config_layout.addWidget(username_label, 3, 0)
        mysql_config_layout.addWidget(self.username_input, 3, 1)
        mysql_config_layout.addWidget(password_label, 4, 0)
        mysql_config_layout.addWidget(self.password_input, 4, 1)
        
        db_tabs_layout.addWidget(self.mysql_config_group)
        db_tabs_layout.addStretch()
        
        # 按钮区域
        buttons_layout = QHBoxLayout()
        buttons_layout.setSpacing(10)
        buttons_layout.setContentsMargins(0, 20, 0, 0)  # 添加上边距，确保按钮与上方内容有足够间距
        
        # 测试连接按钮
        test_conn_btn = PrimaryButton("测试连接")
        test_conn_btn.setFixedHeight(36)  # 增加按钮高度
        test_conn_btn.setStyleSheet(test_conn_btn.styleSheet() + """
            QPushButton {
                padding: 8px 16px;
                font-size: 13px;
            }
        """)
        test_conn_btn.clicked.connect(self.test_connection)
        
        # 保存设置按钮
        save_settings_btn = PrimaryButton("保存设置")
        save_settings_btn.setFixedHeight(36)  # 增加按钮高度
        save_settings_btn.setStyleSheet(save_settings_btn.styleSheet() + """
            QPushButton {
                padding: 8px 16px;
                font-size: 13px;
            }
        """)
        save_settings_btn.clicked.connect(self.save_settings)
        
        buttons_layout.addWidget(test_conn_btn)
        buttons_layout.addWidget(save_settings_btn)
        buttons_layout.addStretch()
        
        # 增加一个垂直间距，让按钮与上方内容保持距离
        db_tabs_layout.addSpacing(10)
        db_tabs_layout.addLayout(buttons_layout)
        
        # 备份与还原选项卡
        backup_restore_tab = QWidget()
        backup_layout = QVBoxLayout(backup_restore_tab)
        backup_layout.setContentsMargins(16, 45, 16, 16)  # 修改：增加顶部边距，确保不遮挡标签
        backup_layout.setSpacing(15)  # 修改：增加间距
        
        # 备份部分
        backup_group = QGroupBox("数据库备份")
        backup_group.setStyleSheet(f"""
            QGroupBox {{
                font-weight: bold;
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                margin-top: 20px;  /* 增加上边距 */
                padding-top: 20px;  /* 增加内边距 */
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: 10px;  /* 稍微增加标题左边距 */
                padding: 0 6px;  /* 增加标题内边距 */
                color: {TEXT_COLOR};
                font-size: 14px;  /* 增加标题字体大小 */
            }}
        """)
        
        backup_group_layout = QVBoxLayout(backup_group)
        backup_group_layout.setContentsMargins(20, 20, 20, 20)  # 增加内边距
        backup_group_layout.setSpacing(15)  # 增加元素间距
        
        backup_info = QLabel("备份会将当前数据库中的所有数据保存到指定的文件中。建议定期备份以防数据丢失。")
        backup_info.setWordWrap(True)
        backup_info.setStyleSheet(f"color: {TEXT_COLOR}; font-size: 13px;")
        
        backup_btn = PrimaryButton("创建备份")
        backup_btn.setFixedHeight(36)  # 增加按钮高度
        backup_btn.setFixedWidth(140)  # 稍微增加按钮宽度
        backup_btn.setStyleSheet(backup_btn.styleSheet() + """
            QPushButton {
                padding: 8px 16px;
                font-size: 13px;
            }
        """)
        backup_btn.clicked.connect(self.create_backup)
        
        backup_btn_layout = QHBoxLayout()
        backup_btn_layout.setContentsMargins(0, 10, 0, 0)  # 添加上边距
        backup_btn_layout.addWidget(backup_btn)
        backup_btn_layout.addStretch()
        
        backup_group_layout.addWidget(backup_info)
        backup_group_layout.addLayout(backup_btn_layout)
        
        # 还原部分
        restore_group = QGroupBox("数据库还原")
        restore_group.setStyleSheet(f"""
            QGroupBox {{
                font-weight: bold;
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                margin-top: 25px;  /* 增加上边距 */
                padding-top: 20px;  /* 增加内边距 */
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: 10px;  /* 稍微增加标题左边距 */
                padding: 0 6px;  /* 增加标题内边距 */
                color: {TEXT_COLOR};
                font-size: 14px;  /* 增加标题字体大小 */
            }}
        """)
        
        restore_group_layout = QVBoxLayout(restore_group)
        restore_group_layout.setContentsMargins(20, 20, 20, 20)  # 增加内边距
        restore_group_layout.setSpacing(15)  # 增加元素间距
        
        restore_info = QLabel("警告: 还原操作将使用备份文件中的数据覆盖当前数据库中的所有数据。此操作不可撤销！")
        restore_info.setWordWrap(True)
        restore_info.setStyleSheet(f"color: #FF3B30; font-size: 13px; font-weight: bold;")
        
        restore_btn = SecondaryButton("从备份还原")
        restore_btn.setFixedHeight(36)  # 增加按钮高度
        restore_btn.setFixedWidth(140)  # 稍微增加按钮宽度
        restore_btn.setStyleSheet(restore_btn.styleSheet() + """
            QPushButton {
                padding: 8px 16px;
                font-size: 13px;
            }
        """)
        restore_btn.clicked.connect(self.restore_from_backup)
        
        restore_btn_layout = QHBoxLayout()
        restore_btn_layout.setContentsMargins(0, 10, 0, 0)  # 添加上边距
        restore_btn_layout.addWidget(restore_btn)
        restore_btn_layout.addStretch()
        
        restore_group_layout.addWidget(restore_info)
        restore_group_layout.addLayout(restore_btn_layout)
        
        backup_layout.addWidget(backup_group)
        backup_layout.addWidget(restore_group)
        backup_layout.addStretch()
        
        # 添加选项卡
        self.tabs.addTab(db_settings_tab, "数据库设置")
        self.tabs.addTab(backup_restore_tab, "备份与还原")
        
        main_layout.addWidget(self.tabs)
        
        # 初始化UI状态
        self.init_ui_from_config()

    def browse_db_file(self):
        """浏览选择SQLite数据库文件"""
        current_path = self.db_path_input.text()
        start_dir = os.path.dirname(current_path) if current_path else "."
        
        file_dialog = QFileDialog()
        file_dialog.setFileMode(QFileDialog.FileMode.ExistingFile)
        file_dialog.setNameFilter("SQLite数据库 (*.db *.sqlite)")
        file_dialog.setDirectory(start_dir)
        
        if file_dialog.exec() == QDialog.DialogCode.Accepted:
            selected_files = file_dialog.selectedFiles()
            if selected_files:
                self.db_path_input.setText(selected_files[0])