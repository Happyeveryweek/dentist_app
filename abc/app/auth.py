import sys
import os
from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, 
                            QGridLayout, QComboBox, QPushButton, QWidget, QMessageBox)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont
from werkzeug.security import generate_password_hash, check_password_hash

# 导入数据库模型和初始化
from init import db, app
from models import User

# 从styles导入必要的样式和组件
from app.styles import Card, PrimaryButton, SecondaryButton, StyledLineEdit
from app.styles import BACKGROUND_COLOR, TEXT_COLOR, ACCENT_COLOR, BORDER_RADIUS

# 登录窗口
class LoginWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("牙科诊所管理系统 - 登录")
        self.setFixedSize(500, 500)  # 调整窗口大小
        self.setStyleSheet(f"background-color: {BACKGROUND_COLOR};")
        self.setup_ui()
        
    def setup_ui(self):
        # 使用简单的垂直布局
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(30, 30, 30, 30)
        main_layout.setSpacing(20)
        
        # 标题
        title_label = QLabel("牙科诊所管理系统")
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title_font = QFont("Microsoft YaHei", 22)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setStyleSheet(f"color: {TEXT_COLOR};")
        main_layout.addWidget(title_label)
        
        # 登录卡片
        login_card = Card()
        card_layout = QVBoxLayout(login_card)
        card_layout.setContentsMargins(30, 30, 30, 30)
        
        # 标题行
        title_layout = QHBoxLayout()
        title_layout.setContentsMargins(0, 0, 0, 20)
        
        # 图标
        icon_label = QLabel("🔐")
        icon_label.setFont(QFont("Microsoft YaHei", 24))
        icon_label.setStyleSheet(f"color: {ACCENT_COLOR};")
        
        # 标题
        login_title = QLabel("用户登录")
        login_title.setFont(QFont("Microsoft YaHei", 18, QFont.Weight.Bold))
        login_title.setStyleSheet(f"color: {TEXT_COLOR};")
        
        title_layout.addWidget(icon_label)
        title_layout.addWidget(login_title)
        title_layout.addStretch()
        
        card_layout.addLayout(title_layout)
        
        # 输入框布局 - 使用垂直布局
        inputs_layout = QVBoxLayout()
        inputs_layout.setSpacing(20)
        inputs_layout.setContentsMargins(0, 0, 0, 20)
        
        # 用户名输入框
        self.username_input = StyledLineEdit()
        self.username_input.setPlaceholderText("请输入用户名")
        self.username_input.setFixedHeight(40)
        self.username_input.setText("admin")  # 设置默认用户名为admin
        inputs_layout.addWidget(self.username_input)
        
        # 密码输入框
        self.password_input = StyledLineEdit()
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setPlaceholderText("请输入密码")
        self.password_input.setFixedHeight(40)
        inputs_layout.addWidget(self.password_input)
        
        card_layout.addLayout(inputs_layout)
        
        # 按钮布局
        button_layout = QHBoxLayout()
        button_layout.setSpacing(20)
        button_layout.setContentsMargins(0, 10, 0, 0)  # 增加上边距
        
        self.login_button = PrimaryButton("登录")
        self.login_button.setFixedSize(150, 40)  # 设置固定大小
        self.login_button.clicked.connect(self.login)
        
        self.register_button = SecondaryButton("立即注册")
        self.register_button.setFixedSize(150, 40)  # 设置固定大小
        self.register_button.clicked.connect(self.register)
        
        button_layout.addStretch(1)  # 添加弹性空间
        button_layout.addWidget(self.login_button)
        button_layout.addWidget(self.register_button)
        button_layout.addStretch(1)  # 添加弹性空间
        
        card_layout.addLayout(button_layout)
        
        # 添加卡片到主布局
        main_layout.addWidget(login_card)
        main_layout.addStretch()
    
    def login(self):
        username = self.username_input.text()
        password = self.password_input.text()
        
        if not username or not password:
            QMessageBox.warning(self, "输入错误", "用户名和密码不能为空")
            return
        
        with app.app_context():
            user = User.query.filter_by(username=username).first()
            
            if user and (user.password == password or check_password_hash(user.password, password)):
                self.accept()  # 登录成功
                self.current_user = user
            else:
                QMessageBox.warning(self, "登录失败", "用户名或密码错误")
    
    def register(self):
        # 打开注册窗口
        register_dialog = RegisterWindow(self)
        if register_dialog.exec() == QDialog.DialogCode.Accepted:
            QMessageBox.information(self, "注册成功", "账号创建成功，现在可以登录了")

# 注册窗口
class RegisterWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("牙科诊所管理系统 - 注册")
        self.setFixedSize(550, 650)  # 增加窗口大小以确保内容完整显示
        self.setStyleSheet(f"background-color: {BACKGROUND_COLOR};")
        self.setup_ui()
        
    def setup_ui(self):
        # 使用网格布局替代垂直布局
        main_layout = QGridLayout(self)
        main_layout.setContentsMargins(30, 30, 30, 30)  # 增加外边距
        main_layout.setSpacing(20)  # 增加组件间距
        
        # 标题 - 放在第0行，跨越所有列
        title_label = QLabel("牙科诊所管理系统")
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title_font = QFont("Microsoft YaHei", 22)  # 使用更常见的中文字体，增大字号
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setStyleSheet(f"color: {TEXT_COLOR}; margin-bottom: 15px;")
        main_layout.addWidget(title_label, 0, 0, 1, 3)  # 第0行，第0列，跨1行3列
        
        # 注册卡片 - 放在第1行，跨越所有列
        register_card = Card()
        card_layout = QGridLayout(register_card)
        card_layout.setContentsMargins(30, 30, 30, 30)  # 增加卡片内边距
        card_layout.setSpacing(20)  # 增加卡片内组件间距
        
        # 注册图标和标题 - 放在卡片的第0行
        register_icon = QLabel("📝")
        register_icon.setFont(QFont("Microsoft YaHei", 24))
        register_icon.setStyleSheet(f"color: {ACCENT_COLOR}; margin-right: 10px;")
        register_icon.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        
        register_title = QLabel("创建新账号")
        register_title_font = QFont("Microsoft YaHei", 18)
        register_title_font.setBold(True)
        register_title.setFont(register_title_font)
        register_title.setStyleSheet(f"color: {TEXT_COLOR};")
        register_title.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        
        card_layout.addWidget(register_icon, 0, 0, 1, 1)
        card_layout.addWidget(register_title, 0, 1, 1, 2)
        
        # 用户名标签和输入框 - 放在卡片的第1行
        username_label = QLabel("用户名:")
        username_label.setStyleSheet(f"font-size: 14px; font-weight: 500; color: {TEXT_COLOR};")
        username_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        
        self.username_input = StyledLineEdit()
        self.username_input.setFixedHeight(40)   # 设置固定高度
        self.username_input.setPlaceholderText("请输入用户名")
        
        card_layout.addWidget(username_label, 1, 0, 1, 1)
        card_layout.addWidget(self.username_input, 1, 1, 1, 2)
        
        # 邮箱标签和输入框 - 放在卡片的第2行
        email_label = QLabel("邮箱:")
        email_label.setStyleSheet(f"font-size: 14px; font-weight: 500; color: {TEXT_COLOR};")
        email_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        
        self.email_input = StyledLineEdit()
        self.email_input.setFixedHeight(40)   # 设置固定高度
        self.email_input.setPlaceholderText("请输入邮箱")
        
        card_layout.addWidget(email_label, 2, 0, 1, 1)
        card_layout.addWidget(self.email_input, 2, 1, 1, 2)
        
        # 密码标签和输入框 - 放在卡片的第3行
        password_label = QLabel("密码:")
        password_label.setStyleSheet(f"font-size: 14px; font-weight: 500; color: {TEXT_COLOR};")
        password_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        
        self.password_input = StyledLineEdit()
        self.password_input.setFixedHeight(40)   # 设置固定高度
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setPlaceholderText("请输入密码")
        
        card_layout.addWidget(password_label, 3, 0, 1, 1)
        card_layout.addWidget(self.password_input, 3, 1, 1, 2)
        
        # 角色标签和下拉框 - 放在卡片的第4行
        role_label = QLabel("角色:")
        role_label.setStyleSheet(f"font-size: 14px; font-weight: 500; color: {TEXT_COLOR};")
        role_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        
        self.role_combo = QComboBox()
        self.role_combo.addItems(["管理员", "员工"])
        self.role_combo.setFixedHeight(40)   # 设置固定高度
        self.role_combo.setStyleSheet(f"""
            QComboBox {{
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                padding: 8px 12px;
                background-color: white;
                font-size: 14px;
            }}
            QComboBox:focus {{
                border: 1px solid {ACCENT_COLOR};
            }}
            QComboBox::drop-down {{
                border: none;
                width: 20px;
            }}
        """)
        
        card_layout.addWidget(role_label, 4, 0, 1, 1)
        card_layout.addWidget(self.role_combo, 4, 1, 1, 2)
        
        # 按钮 - 放在卡片的第5行
        button_container = QWidget()
        button_layout = QHBoxLayout(button_container)
        button_layout.setSpacing(15)  # 增加按钮间距
        button_layout.setContentsMargins(0, 10, 0, 0)  # 增加上边距
        
        self.register_button = PrimaryButton("注册")
        self.register_button.setFixedSize(120, 40)  # 设置固定大小
        self.register_button.clicked.connect(self.register)
        
        cancel_button = SecondaryButton("取消")
        cancel_button.setFixedSize(120, 40)  # 设置固定大小
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addStretch()
        button_layout.addWidget(self.register_button)
        button_layout.addWidget(cancel_button)
        button_layout.addStretch()
        
        card_layout.addWidget(button_container, 5, 0, 1, 3)  # 跨越所有列
        
        # 设置列的拉伸因子
        card_layout.setColumnStretch(0, 1)  # 标签列
        card_layout.setColumnStretch(1, 4)  # 输入框列
        
        main_layout.addWidget(register_card, 1, 0, 1, 3)  # 第1行，第0列，跨1行3列
    
    def register(self):
        username = self.username_input.text()
        email = self.email_input.text()
        password = self.password_input.text()
        role = "admin" if self.role_combo.currentText() == "管理员" else "staff"
        
        if not username or not email or not password:
            QMessageBox.warning(self, "输入错误", "所有字段都必须填写")
            return
        
        with app.app_context():
            # 检查用户名是否已存在
            existing_user = User.query.filter_by(username=username).first()
            if existing_user:
                QMessageBox.warning(self, "注册失败", "该用户名已被使用")
                return
            
            # 检查邮箱是否已存在
            existing_email = User.query.filter_by(email=email).first()
            if existing_email:
                QMessageBox.warning(self, "注册失败", "该邮箱已被注册")
                return
            
            # 创建新用户
            hashed_password = generate_password_hash(password)
            new_user = User(username=username, email=email, password=hashed_password, role=role)
            db.session.add(new_user)
            db.session.commit()
            
            self.accept()  # 注册成功 