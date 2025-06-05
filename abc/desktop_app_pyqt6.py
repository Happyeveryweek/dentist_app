import sys
import os
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                             QPushButton, QLabel, QLineEdit, QTableWidget, QTableWidgetItem,
                             QTabWidget, QFormLayout, QDateEdit, QTextEdit, QComboBox,
                             QMessageBox, QDialog, QSpinBox, QHeaderView, QStackedWidget,
                             QSizePolicy, QFrame, QGridLayout, QStatusBar, QMenu, QTimeEdit,
                             QCheckBox, QScrollArea)
from PyQt6.QtCore import Qt, QDate, QPropertyAnimation, QEasingCurve, QSize, QTimer, QDateTime, QTime, QRect, pyqtSlot
from PyQt6.QtGui import QFont, QIcon, QColor, QPalette, QCursor, QGuiApplication
from datetime import datetime
from dotenv import load_dotenv
import ast
import logging

# 导入患者导出功能
from app.patient_export import export_patients_to_excel, create_export_button

# 导入数据库模型和初始化
from init import db, app
from models import User, Patient, Appointment, FollowUpVisit
from werkzeug.security import generate_password_hash, check_password_hash

# 导入样式和组件
from app.styles import (Card, PrimaryButton, SecondaryButton, StyledLineEdit,
                      ACCENT_COLOR, BACKGROUND_COLOR, CARD_BACKGROUND, 
                      TEXT_COLOR, SECONDARY_TEXT_COLOR, BORDER_RADIUS, BUTTON_HEIGHT)

# 导入仪表盘功能
from app.dashboard import DashboardTab

# 导入预约管理功能
from app.appointments import AppointmentsTab

# 导入患者管理功能
from app.patients import PatientsTab, PatientDialog

# 导入系统管理功能
from app.system_management import SystemManagementTab

# 确保应用上下文
with app.app_context():
    db.create_all()

# 患者表单对话框
class PatientDialog(QDialog):
    def __init__(self, parent=None, patient=None):
        super().__init__(parent)
        self.patient = patient
        self.setWindowTitle("添加患者" if not patient else "编辑患者信息")
        self.setMinimumWidth(700)  # 增加最小宽度至700像素
        self.setMinimumHeight(700)  # 设置最小高度
        # 设置对话框的大小策略，允许垂直方向自动调整大小
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.dental_data = {}  # 存储牙齿状况数据
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)  # 增加外边距
        layout.setSpacing(15)  # 增加间距
        
        # 设置对话框初始大小
        self.setMinimumWidth(930)  # 设置更宽的最小宽度，确保十字图表完全显示
        self.setMinimumHeight(800)  # 增加初始最小高度，解决内容遮挡问题
        
        # 设置标签样式
        label_style = """
            QLabel {
                font-weight: 500;
                color: #333;
                font-size: 14px;
            }
        """
        
        # 创建主表单布局
        main_form_layout = QVBoxLayout()
        main_form_layout.setSpacing(15)  # 设置垂直间距
        
        # 第一行：姓名、年龄、性别
        first_row_layout = QHBoxLayout()
        first_row_layout.setSpacing(15)  # 设置水平间距
        
        # 姓名
        name_container = QWidget()
        name_layout = QFormLayout(name_container)
        name_layout.setContentsMargins(0, 0, 0, 0)
        name_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.name_input = StyledLineEdit()
        self.name_input.setPlaceholderText("请输入患者姓名")
        name_label = QLabel("姓名:")
        name_label.setStyleSheet(label_style)
        name_layout.addRow(name_label, self.name_input)
        first_row_layout.addWidget(name_container, 2)  # 姓名占比较大
        
        # 年龄
        age_container = QWidget()
        age_layout = QFormLayout(age_container)
        age_layout.setContentsMargins(0, 0, 0, 0)
        age_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.age_input = QSpinBox()
        self.age_input.setRange(0, 120)
        self.age_input.setValue(30)
        self.age_input.setStyleSheet("""
            QSpinBox {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
        """)
        age_label = QLabel("年龄:")
        age_label.setStyleSheet(label_style)
        age_layout.addRow(age_label, self.age_input)
        first_row_layout.addWidget(age_container, 1)
        
        # 性别
        gender_container = QWidget()
        gender_layout = QFormLayout(gender_container)
        gender_layout.setContentsMargins(0, 0, 0, 0)
        gender_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.gender_combo = QComboBox()
        self.gender_combo.addItems(["", "男", "女"])
        self.gender_combo.setStyleSheet("""
            QComboBox {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
            QComboBox::drop-down {
                border: none;
                width: 24px;
            }
        """)
        gender_label = QLabel("性别:")
        gender_label.setStyleSheet(label_style)
        gender_layout.addRow(gender_label, self.gender_combo)
        first_row_layout.addWidget(gender_container, 1)
        
        # 添加第一行到主表单布局
        main_form_layout.addLayout(first_row_layout)
        
        # 第二行：电话、医生、初诊时间
        second_row_layout = QHBoxLayout()
        second_row_layout.setSpacing(15)  # 设置水平间距
        
        # 电话
        phone_container = QWidget()
        phone_layout = QFormLayout(phone_container)
        phone_layout.setContentsMargins(0, 0, 0, 0)
        phone_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.phone_input = StyledLineEdit()
        self.phone_input.setPlaceholderText("请输入联系电话")
        phone_label = QLabel("电话:")
        phone_label.setStyleSheet(label_style)
        phone_layout.addRow(phone_label, self.phone_input)
        second_row_layout.addWidget(phone_container, 2)  # 电话占比较大
        
        # 医生
        doctor_container = QWidget()
        doctor_layout = QFormLayout(doctor_container)
        doctor_layout.setContentsMargins(0, 0, 0, 0)
        doctor_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.doctor_input = StyledLineEdit()
        self.doctor_input.setPlaceholderText("请输入主治医生")
        doctor_label = QLabel("医生:")
        doctor_label.setStyleSheet(label_style)
        doctor_layout.addRow(doctor_label, self.doctor_input)
        second_row_layout.addWidget(doctor_container, 1)
        
        # 初诊时间
        date_container = QWidget()
        date_layout = QFormLayout(date_container)
        date_layout.setContentsMargins(0, 0, 0, 0)
        date_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.first_visit_date = QDateEdit()
        self.first_visit_date.setCalendarPopup(True)
        self.first_visit_date.setDate(QDate.currentDate())
        self.first_visit_date.setStyleSheet("""
            QDateEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
        """)
        first_visit_label = QLabel("初诊时间:")
        first_visit_label.setStyleSheet(label_style)
        date_layout.addRow(first_visit_label, self.first_visit_date)
        second_row_layout.addWidget(date_container, 1)
        
        # 添加第二行到主表单布局
        main_form_layout.addLayout(second_row_layout)
        
        # 地址（单独一行）
        address_layout = QFormLayout()
        address_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.address_input = StyledLineEdit()
        self.address_input.setPlaceholderText("请输入地址（选填）")
        address_label = QLabel("地址:")
        address_label.setStyleSheet(label_style)
        address_layout.addRow(address_label, self.address_input)
        
        # 添加地址行到主表单布局
        main_form_layout.addLayout(address_layout)
        
        # 牙齿状况
        dental_label = QLabel("牙齿状况:")
        dental_label.setStyleSheet(label_style)
        
        # 创建容器
        dental_container = QWidget()
        dental_layout = QVBoxLayout(dental_container)
        dental_layout.setContentsMargins(0, 0, 0, 0)
        dental_layout.setSpacing(15)  # 增加间距
        
        # 创建标题和添加按钮的水平布局
        header_layout = QHBoxLayout()
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(5)
        
        # 添加标题
        status_title = QLabel("")
        status_title.setStyleSheet("font-weight: bold; color:rgb(251, 251, 252);")
        header_layout.addWidget(status_title)
        
        # 添加弹性空间，使按钮靠右
        header_layout.addStretch()
        
        # 添加一个简洁的添加按钮在右上角
        add_btn = QPushButton("+")
        add_btn.setToolTip("添加牙齿状况记录")
        add_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        add_btn.setStyleSheet("""
            QPushButton {
                background-color: #4a86e8;
                color: white;
                font-size: 18px;
                font-weight: bold;
                border: none;
                border-radius: 15px;
                min-width: 30px;
                max-width: 30px;
                min-height: 30px;
                max-height: 30px;
                padding: 0px;
            }
            QPushButton:hover {
                background-color: #3b78e7;
            }
        """)
        add_btn.clicked.connect(self.add_dental_chart_row)
        header_layout.addWidget(add_btn)
        
        # 添加标题布局到主布局
        dental_layout.addLayout(header_layout)
        
        # 创建牙齿状况容器 - 放置图表行
        self.dental_charts_container = QWidget()
        self.dental_charts_layout = QVBoxLayout(self.dental_charts_container)
        self.dental_charts_layout.setContentsMargins(0, 0, 0, 0)
        self.dental_charts_layout.setSpacing(5)  # 保持较小的行间距，使十字图表更紧凑
        
        # 设置牙齿状况容器的大小策略，允许自动调整大小
        self.dental_charts_container.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        # 设置一个更紧凑的初始固定高度
        self.dental_charts_container.setMinimumHeight(70)  # 减小初始高度，使界面更紧凑
        
        # 创建滚动区域
        self.dental_scroll_area = QScrollArea()
        self.dental_scroll_area.setWidgetResizable(True)
        self.dental_scroll_area.setWidget(self.dental_charts_container)
        self.dental_scroll_area.setFrameShape(QFrame.Shape.StyledPanel)  # 使用样式化面板
        self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.dental_scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.dental_scroll_area.setStyleSheet("""
            QScrollArea { 
                background: transparent; 
                border: 1px solid #e0e0e0; 
                border-radius: 4px; 
            }
            QScrollBar:vertical { width: 10px; background: #f0f0f0; }
            QScrollBar::handle:vertical { background: #c0c0c0; border-radius: 5px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0px; }
        """)
        
        # 添加一行十字图表作为默认
        self.add_dental_chart_row()
        
        # 添加滚动区域到布局中
        dental_layout.addWidget(self.dental_scroll_area)
        
        # 隐藏的文本框，用于存储JSON格式的牙齿状况数据
        self.dental_condition_input = QLineEdit()
        self.dental_condition_input.setVisible(False)  # 隐藏此输入框
        dental_layout.addWidget(self.dental_condition_input)
        
        # 将牙齿状况容器添加到表单中
        dental_form_layout = QFormLayout()
        dental_form_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        dental_form_layout.addRow(dental_label, dental_container)
        main_form_layout.addLayout(dental_form_layout)
        
        # 诊疗费用项目
        treatment_form_layout = QFormLayout()
        treatment_form_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.treatment_items_input = QTextEdit()
        self.treatment_items_input.setPlaceholderText("请输入诊疗费用项目（选填）")
        self.treatment_items_input.setStyleSheet("""
            QTextEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px;
                background-color: white;
            }
        """)
        self.treatment_items_input.setMaximumHeight(150)  # 限制最大高度
        treatment_label = QLabel("诊疗费用项目:")
        treatment_label.setStyleSheet(label_style)
        treatment_form_layout.addRow(treatment_label, self.treatment_items_input)
        main_form_layout.addLayout(treatment_form_layout)
        
        layout.addLayout(main_form_layout)
        
        # 按钮布局
        button_layout = QHBoxLayout()
        button_layout.setSpacing(15)  # 增加间距
        button_layout.setContentsMargins(0, 15, 0, 0)  # 增加上边距
        
        save_button = PrimaryButton("保存")
        save_button.clicked.connect(self.save_patient)
        
        cancel_button = SecondaryButton("取消")
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addWidget(save_button)
        button_layout.addWidget(cancel_button)
        
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        
        # 如果是编辑模式，填充现有数据
        if self.patient:
            self.fill_patient_data()
    
    def add_dental_chart_row(self):
        """添加一个牙齿状况记录行"""
        row_index = self.dental_charts_layout.count()
        
        # 创建行容器
        row_widget = QWidget()
        row_layout = QHBoxLayout(row_widget)
        row_layout.setContentsMargins(0, 0, 0, 0)
        row_layout.setSpacing(15)  # 调整组件间距
        
        # 设置行容器的大小策略 - 水平扩展，垂直固定
        row_widget.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        row_widget.setMinimumHeight(85)  # 稍微增加最小高度以确保完全显示
        row_widget.setObjectName(f"dental_row_{row_index}")
        
        # 日期选择器
        date_widget = QDateEdit()
        date_widget.setCalendarPopup(True)
        date_widget.setDate(QDate.currentDate())
        date_widget.setDisplayFormat("yyyy-MM-dd")  # 与web端保持一致的日期格式
        date_widget.setObjectName(f"dental_date_{row_index}")
        date_widget.setFixedWidth(120)  # 设置固定宽度
        date_widget.setStyleSheet("""
            QDateEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px;
                background-color: white;
            }
        """)
        date_widget.dateChanged.connect(self.update_dental_data)
        
        # 创建两个十字图表
        chart1_widget = self.create_dental_cross_chart(f"chart1_{row_index}")
        chart2_widget = self.create_dental_cross_chart(f"chart2_{row_index}")
        
        # 删除按钮
        delete_btn = QPushButton("🗑️")
        delete_btn.setObjectName(f"delete_btn_{row_index}")
        delete_btn.setToolTip("删除此记录")
        delete_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        delete_btn.setFixedSize(36, 36)  # 设置固定大小
        delete_btn.setStyleSheet("""
            QPushButton {
                border: none;
                background-color: transparent;
                color: #ff3b30;
                font-size: 16px;
                padding: 5px;  /* 减小内边距 */
                border-radius: 4px;
                min-width: 28px;
                max-width: 28px;
                min-height: 28px;
                max-height: 28px;
            }
            QPushButton:hover {
                background-color: rgba(255, 224, 224, 0.3);
            }
        """)
        delete_btn.clicked.connect(lambda: self.delete_dental_chart_row(row_widget))
        
        # 添加组件到行布局，调整布局以确保组件不会被挤压
        row_layout.addWidget(date_widget, 0, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)  # 左对齐
        row_layout.addWidget(chart1_widget, 1, Qt.AlignmentFlag.AlignCenter)  # 添加拉伸因子
        row_layout.addWidget(chart2_widget, 1, Qt.AlignmentFlag.AlignCenter)  # 添加拉伸因子
        row_layout.addWidget(delete_btn, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)  # 右对齐
        
        # 添加行到容器
        self.dental_charts_layout.addWidget(row_widget)
        
        # 调整容器大小以适应新增的行
        total_rows = self.dental_charts_layout.count()
        
        # 每行85像素高度，与row_widget.setMinimumHeight(85)保持一致
        row_height = 85
        
        # 如果行数小于等于3，自适应高度；否则固定为3行高度并显示滚动条
        if total_rows <= 3:
            # 自适应高度，不显示滚动条
            ideal_height = total_rows * row_height
            self.dental_charts_container.setMinimumHeight(ideal_height)
            self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            self.dental_scroll_area.setFixedHeight(ideal_height)  # 滚动区域高度与容器一致
        else:
            # 固定为3行高度，显示滚动条
            fixed_height = 3 * row_height
            self.dental_charts_container.setMinimumHeight(total_rows * row_height)  # 容器实际高度仍然是所有行的高度
            self.dental_scroll_area.setFixedHeight(fixed_height)  # 滚动区域固定为3行高度
            self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
            
        # 确保所有行的间距保持一致
        for i in range(self.dental_charts_layout.count()):
            item = self.dental_charts_layout.itemAt(i)
            if item and item.widget():
                item.widget().setMinimumHeight(row_height)
                item.widget().setMaximumHeight(row_height)
        
        # 更新对话框大小
        self.updateDialogSize()
        
        return row_widget
        
    def updateDialogSize(self):
        """强制更新对话框大小以适应内容"""
        # 获取牙齿图表容器当前高度
        chart_height = self.dental_charts_container.height()
        
        # 获取当前对话框高度
        current_height = self.height()
        
        # 确保对话框有足够高度显示所有内容
        row_count = self.dental_charts_layout.count()
        
        # 基础高度700像素，不再根据行数动态增加高度
        # 因为超过3行时使用滚动条，所以对话框高度应该保持稳定
        min_height = 700
        if row_count <= 3:
            # 如果行数少于等于3，适当调整高度
            min_height = 700 + (row_count - 1) * 20  # 减少每行的额外高度，避免间距过大
        
        # 设置对话框高度 - 无论是增加还是减少
        self.setMinimumHeight(min_height)
        
        # 如果当前高度大于计算的最小高度，则缩小对话框
        if current_height > min_height + 50:  # 添加一些余量
            self.resize(self.width(), min_height)
        
        # 强制刷新
        self.update()
    
    def create_dental_cross_chart(self, chart_id):
        """创建牙齿十字图表"""
        chart_widget = QWidget()
        chart_widget.setObjectName(chart_id)
        chart_layout = QGridLayout(chart_widget)
        chart_layout.setContentsMargins(2, 2, 2, 2)  # 减小内边距，使图表更紧凑
        chart_layout.setSpacing(2)  # 减小间距，使图表更紧凑
        
        # 从chart_id中提取图表编号和行索引
        # 例如：从"chart1_0"中提取"chart1"和"0"
        parts = chart_id.split('_')
        chart_num = parts[0]  # 例如 "chart1"
        row_idx = parts[1] if len(parts) > 1 else "0"  # 行索引
        
        # 定义输入框的尺寸，确保一致性
        input_width = 130
        input_height = 25
        padding = 6  # 容器内边距
        
        # 计算所需的十字横线长度(2倍input_width + 一些额外空间)
        h_line_width = 2 * input_width + 15
        
        # 创建十字线 - 先创建十字线，确保它们在输入框的下层
        h_line = QFrame()
        h_line.setObjectName(f"{chart_id}_h_line")
        h_line.setFrameShape(QFrame.Shape.HLine)
        h_line.setFrameShadow(QFrame.Shadow.Sunken)
        h_line.setStyleSheet("background-color: rgba(0, 123, 255, 0.7); min-height: 2px;")  # 稍微增加粗细以提高可见性
        h_line.setFixedWidth(h_line_width)  # 设置固定宽度，与输入框匹配
        h_line.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Fixed)  # 设置为固定大小

        v_line = QFrame()
        v_line.setObjectName(f"{chart_id}_v_line")
        v_line.setFrameShape(QFrame.Shape.VLine)
        v_line.setFrameShadow(QFrame.Shadow.Sunken)
        v_line.setStyleSheet("background-color: rgba(0, 123, 255, 0.7); min-width: 2px;")  # 稍微增加粗细以提高可见性
        v_line.setMinimumHeight(65)  # 调整竖线高度
        v_line.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Expanding)  # 允许垂直扩展

        # 创建四个象限的输入框位置
        positions = {
            'top-left': (0, 0),
            'top-right': (0, 2),
            'bottom-left': (2, 0),
            'bottom-right': (2, 2)
        }
        
        # 添加十字线
        chart_layout.addWidget(h_line, 1, 0, 1, 3, Qt.AlignmentFlag.AlignCenter)
        chart_layout.addWidget(v_line, 0, 1, 3, 1, Qt.AlignmentFlag.AlignCenter)
        
        # 创建四个象限的输入框 - 在十字线之后创建，确保它们在上层
        for pos, grid_pos in positions.items():
            input_field = QLineEdit()
            # 设置对象名称，确保格式为: chart1_0_top_left
            obj_name = f"{chart_id}_{pos.replace('-', '_')}"
            input_field.setObjectName(obj_name)
            
            # 设置data-area属性，与web端保持一致
            input_field.setProperty("data-area", f"{chart_num}-{pos}")
            
            input_field.setPlaceholderText("")
            input_field.setFixedSize(input_width, input_height)  # 使用固定尺寸，确保所有输入框大小一致
            
            # 为左侧输入框设置右对齐，让文字从最右边开始输入（靠近中间的竖线）
            if pos == 'top-left' or pos == 'bottom-left':
                input_field.setAlignment(Qt.AlignmentFlag.AlignRight)
            
            # 创建一个容器来放置输入框，给输入框添加内边距避免遮挡十字线
            input_container = QWidget()
            # 设置容器透明背景，去除边框
            input_container.setStyleSheet("background-color: transparent; border: none;")
            input_container_layout = QVBoxLayout(input_container)
            input_container_layout.setContentsMargins(padding, padding, padding, padding)  # 统一内边距
            input_container_layout.addWidget(input_field)
            
            input_field.setStyleSheet("""
                QLineEdit {
                    border: 1px solid #e0e0e0;
                    border-radius: 4px;
                    padding: 4px;
                    background-color: white;
                    font-size: 12px;
                }
            """)
            input_field.textChanged.connect(self.update_dental_data)
            
            # 添加容器而不是直接添加输入框
            chart_layout.addWidget(input_container, grid_pos[0], grid_pos[1], 1, 1, Qt.AlignmentFlag.AlignCenter)
        
        # 设置整个图表的样式 - 去除图表边框
        chart_widget.setStyleSheet("""
            QWidget {
                background-color: transparent;
                border: none;
                border-radius: 0px;
            }
        """)
        
        # 设置图表的固定高度，确保多行显示时不会变形
        chart_widget.setMinimumHeight(80)
        chart_widget.setMaximumHeight(85)
        
        # 设置大小策略
        chart_widget.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        
        return chart_widget
    
    def delete_dental_chart_row(self, row_widget):
        """删除牙齿状况记录行"""
        # 确保至少保留一行
        if self.dental_charts_layout.count() > 1:
            # 获取要删除的行的索引
            row_index = -1
            for i in range(self.dental_charts_layout.count()):
                if self.dental_charts_layout.itemAt(i).widget() == row_widget:
                    row_index = i
                    break
            
            # 从布局中移除并删除行
            self.dental_charts_layout.removeWidget(row_widget)
            row_widget.deleteLater()
            
            # 从dental_data中删除对应行的数据
            if hasattr(self, 'dental_data') and row_index >= 0:
                keys_to_remove = []
                for key in list(self.dental_data.keys()):
                    # 检查是否是该行的数据
                    if key == f"date-{row_index}" or key.endswith(f"-{row_index}"):
                        keys_to_remove.append(key)
                
                # 删除对应的键
                for key in keys_to_remove:
                    if key in self.dental_data:
                        del self.dental_data[key]
            
            # 更新数据
            self.update_dental_data()
            
            # 调整容器大小以适应内容减少
            total_rows = self.dental_charts_layout.count()
            row_height = 85  # 每行85像素高度，与add_dental_chart_row保持一致
            
            # 如果行数小于等于3，自适应高度；否则固定为3行高度并显示滚动条
            if total_rows <= 3:
                # 自适应高度，不显示滚动条
                ideal_height = total_rows * row_height
                self.dental_charts_container.setMinimumHeight(ideal_height)
                self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                self.dental_scroll_area.setFixedHeight(ideal_height)  # 滚动区域高度与容器一致
            else:
                # 固定为3行高度，显示滚动条
                fixed_height = 3 * row_height
                self.dental_charts_container.setMinimumHeight(total_rows * row_height)  # 容器实际高度仍然是所有行的高度
                self.dental_scroll_area.setFixedHeight(fixed_height)  # 滚动区域固定为3行高度
                self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                
            # 确保所有行的间距保持一致
            for i in range(self.dental_charts_layout.count()):
                item = self.dental_charts_layout.itemAt(i)
                if item and item.widget():
                    item.widget().setMinimumHeight(row_height)
                    item.widget().setMaximumHeight(row_height)
            
            # 使用延迟调用确保UI更新后再调整大小
            QTimer.singleShot(50, self.updateDialogSize)
        else:
            # 如果只有一行，则清空输入值
            date_widget = row_widget.findChild(QDateEdit)
            date_widget.setDate(QDate.currentDate())
            
            row_index = 0  # 第一行的索引
            for chart_num in [1, 2]:
                chart_id = f"chart{chart_num}_{row_index}"
                for position in ["top_left", "top_right", "bottom_left", "bottom_right"]:
                    # 尝试两种可能的对象名称格式
                    input_widget = row_widget.findChild(QLineEdit, f"{chart_id}_{position}")
                    if not input_widget:
                        input_widget = row_widget.findChild(QLineEdit, f"chart{chart_num}_{position}")
                    if input_widget:
                        input_widget.clear()
            
            # 更新数据
            self.update_dental_data()
    
    def update_dental_data(self):
        """更新牙齿状况数据"""
        # 先备份一份旧数据用于比较
        old_data = self.dental_data.copy() if hasattr(self, 'dental_data') else {}
        
        # 保留旧数据，只更新有变化的部分
        if not hasattr(self, 'dental_data'):
            self.dental_data = {}
        # 不再清空字典，而是保留原有数据
        
        # 遍历所有行
        for i in range(self.dental_charts_layout.count()):
            row_widget = self.dental_charts_layout.itemAt(i).widget()
            if not row_widget:
                continue
                
            # 获取日期
            date_widget = row_widget.findChild(QDateEdit, f"dental_date_{i}")
            if date_widget:
                # 使用与web端一致的键名格式: date-0, date-1, ...
                date_key = f"date-{i}"
                date_value = date_widget.date().toString("yyyy-MM-dd")
                self.dental_data[date_key] = date_value
            
            # 获取所有输入框
            for chart_num in [1, 2]:
                # 遍历四个位置
                positions = ["top-left", "top-right", "bottom-left", "bottom-right"]
                for pos in positions:
                    # 构造输入框的对象名称
                    input_name = f"chart{chart_num}_{i}_{pos.replace('-', '_')}"
                    # 查找对应的输入框
                    input_field = row_widget.findChild(QLineEdit, input_name)
                    if input_field:
                        # 构造与web端一致的键名格式: chart1-top-left-0, chart1-top-right-0, ... (连字符分隔)
                        key = f"chart{chart_num}-{pos}-{i}"
                        value = input_field.text()
                        # 只有当输入框有值时才更新，否则保留原有值
                        if value or key not in old_data:
                            self.dental_data[key] = value
                        else:
                            # 保留原有值
                            self.dental_data[key] = old_data.get(key, '')
        
        # 更新隐藏的文本框
        import json
        json_data = json.dumps(self.dental_data)
        self.dental_condition_input.setText(json_data)
        
        # 检查添加的键
        added_keys = set(self.dental_data.keys()) - set(old_data.keys())
            
        # 检查移除的键
        removed_keys = set(old_data.keys()) - set(self.dental_data.keys())
            
        # 检查值变化的键
        changed_keys = [k for k in old_data.keys() & self.dental_data.keys() 
                        if old_data[k] != self.dental_data[k]]
    
    def fill_patient_data(self):
        """填充患者数据到表单"""
        if self.patient:
            # 填充基本信息
            self.name_input.setText(self.patient.name)
            self.phone_input.setText(self.patient.phone or "")
            self.age_input.setValue(self.patient.age or 0)
            self.gender_combo.setCurrentText(self.patient.gender or "")
            self.address_input.setText(self.patient.address or "")
            self.doctor_input.setText(self.patient.doctor or "")
            
            # 设置初诊日期
            if self.patient.first_visit_date:
                qdate = QDate.fromString(self.patient.first_visit_date.strftime("%Y-%m-%d"), "yyyy-MM-dd")
                self.first_visit_date.setDate(qdate)
            
            # 填充牙齿状况数据
            try:
                # 根据类型处理数据
                if isinstance(self.patient.dental_condition, dict):
                    # 如果已经是字典类型，直接使用
                    self.dental_data = self.patient.dental_condition.copy()  # 创建副本避免相互影响
                elif isinstance(self.patient.dental_condition, str):
                    # 如果是字符串，尝试解析
                    try:
                        import json
                        self.dental_data = json.loads(self.patient.dental_condition)
                    except json.JSONDecodeError as je:
                        # 如果JSON解析失败，尝试使用ast.literal_eval
                        import ast
                        try:
                            self.dental_data = ast.literal_eval(self.patient.dental_condition)
                        except Exception as e:
                            # 如果解析失败，记录错误并使用默认值
                            self.dental_data = {"date-0": QDate.currentDate().toString("yyyy-MM-dd")}
                else:
                    # 其他类型，使用默认值
                    self.dental_data = {"date-0": QDate.currentDate().toString("yyyy-MM-dd")}
                
                # 清除默认行
                while self.dental_charts_layout.count() > 0:
                    item = self.dental_charts_layout.takeAt(0)
                    if item.widget():
                        item.widget().deleteLater()
                
                # 获取所有日期键并排序
                date_keys = sorted([k for k in self.dental_data.keys() if k.startswith('date-')],
                                  key=lambda x: int(x.split('-')[1]))
                
                # 如果没有日期键，创建一个默认行
                if not date_keys:
                    self.add_dental_chart_row()
                    self.update_dental_data()
                    return
                
                # 为每个日期创建一个图表行
                for i, date_key in enumerate(date_keys):
                    # 提取原始索引
                    original_index = int(date_key.split('-')[1])
                    
                    # 直接创建新行，因为之前已经清空了所有行
                    row_widget = self.add_dental_chart_row()
                    
                    # 获取这个新行的实际索引（当前行数-1）
                    row_index = self.dental_charts_layout.count() - 1
                    
                    # 获取日期值
                    date_value = self.dental_data.get(date_key, "")
                    
                    # 设置日期
                    date_widget = row_widget.findChild(QDateEdit, f"dental_date_{row_index}")
                    if date_widget and date_value:
                        try:
                            qdate = QDate.fromString(date_value, "yyyy-MM-dd")
                            if qdate.isValid():
                                date_widget.setDate(qdate)
                            else:
                                # 尝试其他日期格式
                                formats = ["yyyy/MM/dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy.MM.dd"]
                                for fmt in formats:
                                    qdate = QDate.fromString(date_value, fmt)
                                    if qdate.isValid():
                                        date_widget.setDate(qdate)
                                        break
                        except Exception as e:
                            # 日期转换错误，使用当前日期
                            pass
                    
                    # 设置图表数据 - 直接遍历所有可能的键
                    for chart_num in [1, 2]:
                        for pos in ["top-left", "top-right", "bottom-left", "bottom-right"]:
                            # 构造数据键名 - 使用原始索引
                            data_key = f"chart{chart_num}-{pos}-{original_index}"
                            # 构造输入框对象名称 - 使用实际行索引
                            input_name = f"chart{chart_num}_{row_index}_{pos.replace('-', '_')}"
                            
                            # 查找输入框
                            input_field = row_widget.findChild(QLineEdit, input_name)
                            if input_field:
                                # 无论键是否存在都设置值，确保UI不显示旧值
                                value = self.dental_data.get(data_key, "")
                                input_field.setText(str(value))
                
                # 更新一次数据，确保所有输入框的值都被保存
                self.update_dental_data()
                
                # 调整容器大小以适应所有行
                total_rows = self.dental_charts_layout.count()
                row_height = 85  # 每行85像素高度，与add_dental_chart_row保持一致
                
                # 如果行数小于等于3，自适应高度；否则固定为3行高度并显示滚动条
                if total_rows <= 3:
                    # 自适应高度，不显示滚动条
                    ideal_height = total_rows * row_height
                    self.dental_charts_container.setMinimumHeight(ideal_height)
                    self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                    self.dental_scroll_area.setFixedHeight(ideal_height)  # 滚动区域高度与容器一致
                else:
                    # 固定为3行高度，显示滚动条
                    fixed_height = 3 * row_height
                    self.dental_charts_container.setMinimumHeight(total_rows * row_height)  # 容器实际高度仍然是所有行的高度
                    self.dental_scroll_area.setFixedHeight(fixed_height)  # 滚动区域固定为3行高度
                    self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                    
                # 确保所有行的间距保持一致
                for i in range(self.dental_charts_layout.count()):
                    item = self.dental_charts_layout.itemAt(i)
                    if item and item.widget():
                        item.widget().setMinimumHeight(row_height)
                        item.widget().setMaximumHeight(row_height)
                
            except Exception as e:
                # 创建一个默认行
                self.add_dental_chart_row()
                self.dental_condition_input.setText(self.patient.dental_condition)
        else:
            # 如果没有牙齿状况数据，创建一个默认行
            self.add_dental_chart_row()
        
        self.treatment_items_input.setText(self.patient.treatment_items or "")
    
    def save_patient(self):
        name = self.name_input.text()
        phone = self.phone_input.text()
        
        if not name or not phone:
            QMessageBox.warning(self, "输入错误", "姓名和电话不能为空")
            return
        
        try:
            # 确保牙齿状况数据以JSON格式保存
            import json
            
            # 对于编辑场景，直接从UI收集数据
            if self.patient:  # 编辑现有患者
                # 直接从UI收集牙齿状况数据
                dental_data = self.collect_dental_data_from_ui()
                print("编辑患者 - 从UI收集的牙齿状况数据:", dental_data)
                
                dental_condition_json = json.dumps(dental_data)
                print("编辑患者 - 转换为JSON格式:", dental_condition_json)
                
                with app.app_context():
                    # 先获取最新的患者数据，确保更新的是当前数据
                    current_patient = db.session.get(Patient, self.patient.id)
                    if current_patient:
                        # 更新患者信息
                        current_patient.name = name
                        current_patient.age = self.age_input.value()
                        current_patient.gender = self.gender_combo.currentText()
                        current_patient.phone = phone
                        current_patient.address = self.address_input.text()
                        current_patient.doctor = self.doctor_input.text()
                        current_patient.first_visit_date = self.first_visit_date.date().toPyDate()
                        current_patient.dental_condition = dental_condition_json
                        current_patient.treatment_items = self.treatment_items_input.toPlainText()
                        
                        print("编辑患者 - 更新前:", current_patient.dental_condition)
                        
                        # 确保显式地更新
                        db.session.add(current_patient)
                        # 提交事务
                        db.session.commit()
                        db.session.flush()
                        
                        # 验证更新结果
                        updated_patient = db.session.get(Patient, self.patient.id)
                        print("编辑患者 - 更新后:", updated_patient.dental_condition)
                        
                        # 更新本地对象，保持一致性
                        self.patient = current_patient
                    else:
                        print("错误: 无法找到要编辑的患者记录")
                        QMessageBox.critical(self, "保存失败", "无法找到要编辑的患者记录")
                        return
            else:  # 添加新患者
                # 使用update_dental_data方法收集数据
                self.update_dental_data()
                print("添加患者 - 收集的牙齿状况数据:", self.dental_data)
                
                dental_condition_json = json.dumps(self.dental_data)
                print("添加患者 - 转换为JSON格式:", dental_condition_json)
                
                with app.app_context():
                    new_patient = Patient(
                        name=name,
                        age=self.age_input.value(),
                        gender=self.gender_combo.currentText(),
                        phone=phone,
                        address=self.address_input.text(),
                        doctor=self.doctor_input.text(),
                        first_visit_date=self.first_visit_date.date().toPyDate(),
                        dental_condition=dental_condition_json,
                        treatment_items=self.treatment_items_input.toPlainText()
                    )
                    db.session.add(new_patient)
                    db.session.commit()
                    db.session.flush()
                    print("添加患者 - 新患者ID:", new_patient.id)
            
            self.accept()
            print("保存患者数据成功！")
        except Exception as e:
            print(f"保存患者信息时发生错误: {str(e)}")
            import traceback
            traceback.print_exc()
            QMessageBox.critical(self, "保存失败", f"保存患者信息时发生错误: {str(e)}")

    def collect_dental_data_from_ui(self):
        """直接从UI收集牙齿状况数据，适用于编辑场景"""
        # 创建一个新的数据字典
        dental_data = {}
        
        # 遍历所有行
        for i in range(self.dental_charts_layout.count()):
            row_widget = self.dental_charts_layout.itemAt(i).widget()
            if not row_widget:
                continue
            
            print(f"处理第 {i} 行的数据")
            
            # 获取日期
            date_widget = row_widget.findChild(QDateEdit, f"dental_date_{i}")
            if date_widget:
                date_key = f"date-{i}"
                date_value = date_widget.date().toString("yyyy-MM-dd")
                dental_data[date_key] = date_value
                print(f"设置日期: {date_key} = {date_value}")
            
            # 获取所有输入框的值
            for chart_num in [1, 2]:
                for pos in ["top-left", "top-right", "bottom-left", "bottom-right"]:
                    # 尝试多种可能的命名格式
                    input_name = f"chart{chart_num}_{i}_{pos.replace('-', '_')}"
                    alt_input_name = f"chart{chart_num}_{pos.replace('-', '_')}"
                    
                    print(f"尝试查找输入框: {input_name} 或 {alt_input_name}")
                    
                    # 先尝试使用主要命名格式
                    input_field = row_widget.findChild(QLineEdit, input_name)
                    
                    # 如果找不到，尝试替代命名格式
                    if not input_field:
                        input_field = row_widget.findChild(QLineEdit, alt_input_name)
                    
                    if input_field:
                        key = f"chart{chart_num}-{pos}-{i}"
                        value = input_field.text()
                        dental_data[key] = value
                        print(f"找到输入框: {input_field.objectName()}, 设置数据: {key} = {value}")
        
        # 不再从原始数据中添加缺失的键，只保留当前UI中存在的行的数据
        
        return dental_data

# 主窗口
class MainWindow(QMainWindow):
    def __init__(self, current_user):
        super().__init__()
        self.current_user = current_user
        self.setWindowTitle("牙科诊所管理系统")
        self.setMinimumSize(1200, 700)  # 设置最小尺寸
        self.resize(1400, 800)  # 默认尺寸
        self.setup_ui()
        
    def logout(self):
        """注销登录并关闭窗口"""
        self.close()
    
    def setup_ui(self):
        # 创建中央部件
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # 主布局
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)  # 移除边距
        main_layout.setSpacing(0)  # 移除间距
        
        # 顶部导航栏
        nav_bar = QWidget()
        nav_bar.setFixedHeight(60)  # 增加高度
        nav_bar.setStyleSheet("""
            background-color: white;
            border-bottom: 1px solid #d0d0d0;
        """)
        nav_layout = QHBoxLayout(nav_bar)
        nav_layout.setContentsMargins(25, 0, 25, 0)
        nav_layout.setSpacing(20)
        
        # 左侧Logo和系统名称
        logo_layout = QHBoxLayout()
        logo_layout.setSpacing(8)
        
        logo_label = QLabel("🦷")
        logo_label.setStyleSheet("""
            font-size: 20px;
            color: #4a86e8;
        """)
        
        system_name = QLabel("牙科诊所管理系统")
        system_name.setStyleSheet("""
            font-size: 16px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        
        logo_layout.addWidget(logo_label)
        logo_layout.addWidget(system_name)
        
        # 右侧导航菜单和退出按钮
        nav_menu = QHBoxLayout()
        nav_menu.setSpacing(30)  # 增加间距
        
        # 导航菜单项样式
        menu_style = """
            QPushButton {
                border: none;
                color: #86868b;
                font-size: 14px;
                padding: 5px 10px;
                background: transparent;
            }
            QPushButton:hover {
                color: #4a86e8;
            }
            QPushButton[selected="true"] {
                color: #4a86e8;
                font-weight: 600;
            }
        """
        
        # 创建导航按钮
        self.dashboard_btn = QPushButton("仪表盘")
        self.dashboard_btn.setProperty("selected", True)
        self.dashboard_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.dashboard_btn.setStyleSheet(menu_style)
        self.dashboard_btn.clicked.connect(lambda: self.switch_tab(0))
        
        self.patients_btn = QPushButton("患者管理")
        self.patients_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.patients_btn.setStyleSheet(menu_style)
        self.patients_btn.clicked.connect(lambda: self.switch_tab(1))
        
        self.appointments_btn = QPushButton("预约管理")
        self.appointments_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.appointments_btn.setStyleSheet(menu_style)
        self.appointments_btn.clicked.connect(lambda: self.switch_tab(2))
        
        # 添加系统管理按钮
        self.system_management_btn = QPushButton("系统管理")
        self.system_management_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.system_management_btn.setStyleSheet(menu_style)
        self.system_management_btn.clicked.connect(lambda: self.switch_tab(3))
        
        # 添加用户名和退出按钮
        welcome_label = QLabel(f"欢迎, {self.current_user.username}")
        welcome_label.setStyleSheet("""
            color: #86868b;
            font-size: 14px;
        """)
        
        logout_btn = QPushButton("退出登录")
        logout_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        logout_btn.setStyleSheet("""
            QPushButton {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                color: #86868b;
                font-size: 14px;
                padding: 5px 15px;
                background: white;
            }
            QPushButton:hover {
                background: #f5f5f7;
                border-color: #d1d1d6;
            }
        """)
        logout_btn.clicked.connect(self.logout)
        
        # 添加到导航菜单布局
        nav_menu.addWidget(self.dashboard_btn)
        nav_menu.addWidget(self.patients_btn)
        nav_menu.addWidget(self.appointments_btn)
        nav_menu.addWidget(self.system_management_btn)
        nav_menu.addStretch()  # 添加弹性空间
        nav_menu.addWidget(welcome_label)
        nav_menu.addWidget(logout_btn)
        
        # 将左右两侧添加到导航栏布局
        nav_layout.addLayout(logo_layout)
        nav_layout.addLayout(nav_menu)
        
        # 添加导航栏到主布局
        main_layout.addWidget(nav_bar)
        
        # 内容区域
        content_widget = QWidget()
        content_widget.setStyleSheet(f"background-color: {BACKGROUND_COLOR};")
        content_layout = QVBoxLayout(content_widget)
        content_layout.setContentsMargins(20, 20, 20, 20)
        
        # 选项卡部件 - 移除标签栏
        self.tabs = QTabWidget()
        self.tabs.setStyleSheet("""
            QTabWidget::pane { 
                border: none;
                background-color: transparent;
            }
            QTabBar {
                height: 0px;
            }
            QTabBar::tab {
                height: 0px;
                width: 0px;
                padding: 0px;
                margin: 0px;
            }
        """)
        
        # 添加选项卡
        self.dashboard_tab = QWidget()
        self.dashboard_manager = DashboardTab(self)
        self.dashboard_tab = self.dashboard_manager.dashboard_tab
        self.tabs.addTab(self.dashboard_tab, "")
        
        self.patients_tab = QWidget()
        self.patients_manager = PatientsTab(self)
        self.patients_tab = self.patients_manager.patients_tab
        self.tabs.addTab(self.patients_tab, "")
        
        self.appointments_tab = QWidget()
        self.appointments_manager = AppointmentsTab(self)
        self.appointments_tab = self.appointments_manager.appointments_tab
        self.tabs.addTab(self.appointments_tab, "")
        
        # 添加系统管理选项卡
        self.system_management_tab = QWidget()
        self.system_management_manager = SystemManagementTab(self)
        self.system_management_tab = self.system_management_manager.system_management_tab
        self.tabs.addTab(self.system_management_tab, "")
        
        content_layout.addWidget(self.tabs)
        main_layout.addWidget(content_widget)
    
    def setup_patients_tab(self):
        """设置患者管理选项卡"""
        # 创建主布局
        main_layout = QVBoxLayout(self.patients_tab)
        main_layout.setContentsMargins(10, 10, 10, 10)  # 减少外边距，让内容更充分利用空间
        main_layout.setSpacing(15)
        
        # 页面标题区域
        title_layout = QHBoxLayout()
        
        # 图标和标题
        icon_label = QLabel("👥")
        icon_label.setStyleSheet("font-size: 28px; color: #4a86e8;")
        
        title_label = QLabel("患者管理")
        title_label.setStyleSheet("""
            font-size: 24px; 
            font-weight: bold; 
            color: #1d1d1f;
            margin-left: 10px;
        """)
        
        title_layout.addWidget(icon_label)
        title_layout.addWidget(title_label)
        title_layout.addStretch()
        
        main_layout.addLayout(title_layout)
        
        # 搜索和添加区域
        action_layout = QHBoxLayout()
        action_layout.setContentsMargins(0, 0, 0, 0)  # 减少内边距
        
        # 搜索框
        search_container = QWidget()
        search_container.setStyleSheet("""
            background-color: white;
            border-radius: 8px;
            border: 1px solid #e0e0e0;
        """)
        search_layout = QHBoxLayout(search_container)
        search_layout.setContentsMargins(15, 8, 15, 8)
        
        search_icon = QLabel("🔍")
        search_icon.setStyleSheet("font-size: 16px; color: #86868b;")
        
        self.patient_search = QLineEdit()
        self.patient_search.setPlaceholderText("搜索患者姓名、电话或地址...")
        self.patient_search.setStyleSheet("""
            QLineEdit {
                border: none;
                padding: 8px 0;
                font-size: 14px;
                background-color: transparent;
            }
        """)
        
        search_layout.addWidget(search_icon)
        search_layout.addWidget(self.patient_search)
        
        # 添加患者按钮
        add_patient_btn = QPushButton("+ 添加患者")
        add_patient_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        add_patient_btn.setStyleSheet("""
            QPushButton {
                background-color: #4a86e8;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 12px 24px;
                font-weight: 600;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #3a76d8;
            }
            QPushButton:pressed {
                background-color: #2a66c8;
            }
        """)
        add_patient_btn.clicked.connect(self.add_patient)
        
        # 添加选择按钮
        self.select_btn = QPushButton("选择")
        self.select_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.select_btn.setStyleSheet("""
            QPushButton {
                background-color: #f5f5f7;
                color: #1d1d1f;
                border: 1px solid #e0e0e0;
                border-radius: 8px;
                padding: 12px 24px;
                font-weight: 600;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #e5e5e7;
            }
            QPushButton:pressed {
                background-color: #d5d5d7;
            }
        """)
        self.select_btn.clicked.connect(self.toggle_selection_mode)
        
        # 添加导出按钮
        export_btn = create_export_button()
        export_btn.clicked.connect(self.export_patients)
        
        action_layout.addWidget(search_container, 1)
        action_layout.addWidget(add_patient_btn)
        action_layout.addWidget(self.select_btn)
        action_layout.addWidget(export_btn)
        
        main_layout.addLayout(action_layout)
        
        # 患者表格区域 - 使用QFrame代替QWidget以获得更好的边框控制
        table_container = QFrame()
        table_container.setFrameShape(QFrame.Shape.StyledPanel)
        table_container.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 10px;
                border: none;
            }
        """)
        table_container.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        
        # 使用网格布局让表格充满整个容器
        table_layout = QGridLayout(table_container)
        table_layout.setContentsMargins(0, 0, 0, 0)
        table_layout.setSpacing(0)
        
        # 创建表格
        self.patients_table = QTableWidget()
        self.patients_table.setColumnCount(10)  # 增加一列用于复选框
        self.patients_table.setHorizontalHeaderLabels(["选择", "ID", "姓名", "年龄", "性别", "电话", "初诊时间", "总费用", "最近预约", "操作"])
        
        # 设置表格自适应策略
        self.patients_table.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.patients_table.horizontalHeader().setStretchLastSection(False)
        
        # 设置表格样式
        self.patients_table.setStyleSheet("""
            QTableWidget {
                border: none;
                background-color: white;
                gridline-color: #f0f0f0;
                border-radius: 10px;
                selection-background-color: #f2f9ff;
            }
            QTableWidget::item {
                padding: 12px;
                border-bottom: 1px solid #f0f0f0;
                color: #333;
            }
            QTableWidget::item:selected {
                background-color: #f2f9ff;
                color: #333;
            }
            QHeaderView::section {
                background-color: #f8f8fa;
                padding: 15px 12px;
                border: none;
                border-bottom: 2px solid #e0e0e0;
                font-weight: bold;
                color: #333;
                text-align: left;
                font-size: 14px;
            }
            QTableWidget QTableCornerButton::section {
                background-color: #f8f8fa;
                border: none;
            }
        """)
        
        # 设置表格属性
        self.patients_table.setShowGrid(True)
        self.patients_table.setGridStyle(Qt.PenStyle.SolidLine)
        self.patients_table.setSortingEnabled(False)
        self.patients_table.setCornerButtonEnabled(False)
        self.patients_table.horizontalHeader().setHighlightSections(False)
        self.patients_table.verticalHeader().setVisible(False)
        self.patients_table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.patients_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.patients_table.setAlternatingRowColors(True)
        self.patients_table.setStyleSheet(self.patients_table.styleSheet() + """
            QTableWidget {
                alternate-background-color: #f9f9f9;
            }
        """)
        
        # 设置列宽比例
        total_width = self.patients_table.viewport().width()
        self.patients_table.setColumnWidth(0, int(total_width * 0.05))  # 选择列 5%
        self.patients_table.setColumnWidth(1, int(total_width * 0.05))  # ID列 5%
        self.patients_table.setColumnWidth(2, int(total_width * 0.10))  # 姓名列 10%
        self.patients_table.setColumnWidth(3, int(total_width * 0.05))  # 年龄列 5%
        self.patients_table.setColumnWidth(4, int(total_width * 0.05))  # 性别列 5%
        self.patients_table.setColumnWidth(5, int(total_width * 0.12))  # 电话列 12%
        self.patients_table.setColumnWidth(6, int(total_width * 0.12))  # 初诊时间列 12%
        self.patients_table.setColumnWidth(7, int(total_width * 0.10))  # 总费用列 10%
        self.patients_table.setColumnWidth(8, int(total_width * 0.12))  # 最近预约列 12%
        self.patients_table.setColumnWidth(9, int(total_width * 0.14))  # 操作列 14%
        
        # 设置表头自适应模式
        self.patients_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Fixed)  # 选择
        self.patients_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Interactive)  # ID
        self.patients_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)  # 姓名
        self.patients_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Interactive)  # 年龄
        self.patients_table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Interactive)  # 性别
        self.patients_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.ResizeMode.Stretch)  # 电话
        self.patients_table.horizontalHeader().setSectionResizeMode(6, QHeaderView.ResizeMode.Stretch)  # 初诊时间
        self.patients_table.horizontalHeader().setSectionResizeMode(7, QHeaderView.ResizeMode.Stretch)  # 总费用
        self.patients_table.horizontalHeader().setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)  # 最近预约
        self.patients_table.horizontalHeader().setSectionResizeMode(9, QHeaderView.ResizeMode.Fixed)  # 操作
        
        # 默认隐藏选择列，只有在点击选择按钮时才显示
        self.patients_table.setColumnHidden(0, True)
        
        # 设置行高
        self.patients_table.verticalHeader().setDefaultSectionSize(60)
        
        # 设置表头固定
        self.patients_table.horizontalHeader().setFixedHeight(50)
        
        # 右键菜单
        self.patients_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.patients_table.customContextMenuRequested.connect(self.show_patient_context_menu)
        
        # 双击查看患者详情
        self.patients_table.doubleClicked.connect(self.view_patient)
        
        # 添加表格到布局
        table_layout.addWidget(self.patients_table, 0, 0)
        
        # 添加表格容器到主布局，并设置为可伸展
        main_layout.addWidget(table_container, 1)
        
        # 加载患者数据
        self.load_patients()
        
        # 连接搜索信号
        self.patient_search.textChanged.connect(self.filter_patients)
        
        # 连接窗口大小变化信号，以便调整列宽
        self.patients_tab.resizeEvent = self.on_patients_tab_resize
    
    def setup_appointments_tab(self):
        """设置预约管理标签页"""
        # 使用AppointmentsTab类代替自定义实现
        self.appointments_manager = AppointmentsTab(self)
        self.appointments_tab = self.appointments_manager.appointments_tab
    
    def switch_tab(self, index):
        """切换选项卡"""
        self.tabs.setCurrentIndex(index)
        
        # 更新按钮状态
        self.dashboard_btn.setProperty("selected", index == 0)
        self.patients_btn.setProperty("selected", index == 1)
        self.appointments_btn.setProperty("selected", index == 2)
        self.system_management_btn.setProperty("selected", index == 3)
        
        # 刷新样式
        self.dashboard_btn.style().unpolish(self.dashboard_btn)
        self.dashboard_btn.style().polish(self.dashboard_btn)
        self.patients_btn.style().unpolish(self.patients_btn)
        self.patients_btn.style().polish(self.patients_btn)
        self.appointments_btn.style().unpolish(self.appointments_btn)
        self.appointments_btn.style().polish(self.appointments_btn)
        self.system_management_btn.style().unpolish(self.system_management_btn)
        self.system_management_btn.style().polish(self.system_management_btn)
        
        # 切换到患者页面时自动刷新数据并调整列宽
        if index == 1:
            if hasattr(self, 'patients_manager'):
                self.patients_manager.load_patients()  # 刷新患者数据
            else:
                self.load_patients()  # 使用主窗口的方法加载患者数据
            self.on_patients_tab_resize(None)
        # 切换到预约页面时自动刷新数据并调整列宽
        elif index == 2:
            if hasattr(self, 'appointments_manager'):
                self.appointments_manager.load_appointments()  # 刷新预约数据
                self.appointments_manager.on_appointments_tab_resize(None)
        # 切换到仪表盘页面时刷新仪表盘数据
        elif index == 0:
            if hasattr(self, 'dashboard_manager'):
                self.dashboard_manager.refresh_dashboard()  # 刷新仪表盘数据
    
    def load_patients(self):
        """加载患者列表"""
        try:
            with app.app_context():
                # 开始查询前清空表格
                self.patients_table.setRowCount(0)
                
                # 查询所有患者
                patients = Patient.query.order_by(Patient.id).all()
                
                # 设置表格行数
                self.patients_table.setRowCount(len(patients))
                
                # 填充表格数据
                for i, patient in enumerate(patients):
                    # 选择列 - 0
                    from PyQt6.QtWidgets import QCheckBox
                    checkbox = QCheckBox()
                    checkbox.setStyleSheet("""
                        QCheckBox {
                            margin-left: 10px;
                            background-color: transparent;
                        }
                        QCheckBox::indicator {
                            width: 18px;
                            height: 18px;
                            border: 2px solid #4a86e8;
                            border-radius: 3px;
                            background-color: transparent;
                        }
                        QCheckBox::indicator:checked {
                            background-color: transparent;
                            image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='#4a86e8' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='20 6 9 17 4 12'%3E%3C/polyline%3E%3C/svg%3E");
                        }
                    """)
                    checkbox_cell = QWidget()
                    checkbox_cell.setStyleSheet("background-color: transparent;")
                    checkbox_layout = QHBoxLayout(checkbox_cell)
                    checkbox_layout.addWidget(checkbox)
                    checkbox_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
                    checkbox_layout.setContentsMargins(0, 0, 0, 0)
                    # 为每个复选框连接独立的状态变化处理函数
                    # 使用不同的变量名(current_row)避免与外部row变量冲突
                    checkbox.stateChanged.connect(lambda state, current_row=i: self.handle_checkbox_state_changed(current_row, state))
                    self.patients_table.setCellWidget(i, 0, checkbox_cell)
                    # ID列 - 1 (因为0是复选框列)
                    id_item = QTableWidgetItem(str(patient.id))
                    id_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    id_item.setData(Qt.ItemDataRole.UserRole, patient.id)  # 存储患者ID
                    self.patients_table.setItem(i, 1, id_item)
                    
                    # 姓名列 - 2
                    name_item = QTableWidgetItem(patient.name)
                    name_item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
                    self.patients_table.setItem(i, 2, name_item)
                    
                    # 年龄列 - 3
                    age_item = QTableWidgetItem(str(patient.age) if patient.age else "")
                    age_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.patients_table.setItem(i, 3, age_item)
                    
                    # 性别列 - 4
                    gender_text = {"M": "男", "F": "女"}.get(patient.gender, "")
                    gender_item = QTableWidgetItem(gender_text)
                    gender_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.patients_table.setItem(i, 4, gender_item)
                    
                    # 电话列 - 5
                    phone_item = QTableWidgetItem(patient.phone if patient.phone else "")
                    phone_item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
                    self.patients_table.setItem(i, 5, phone_item)
                    
                    # 初诊时间列 - 6
                    first_visit_date = patient.first_visit_date.strftime("%Y-%m-%d") if patient.first_visit_date else ""
                    first_visit_item = QTableWidgetItem(first_visit_date)
                    first_visit_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.patients_table.setItem(i, 6, first_visit_item)
                    
                    # 总费用列 - 7
                    total_fee = f"¥{patient.total_cost:.2f}" if patient.total_cost else "¥0.00"
                    fee_item = QTableWidgetItem(total_fee)
                    fee_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.patients_table.setItem(i, 7, fee_item)
                    
                    # 最近预约列 - 8
                    latest_appointment = ""
                    try:
                        # 获取最近的预约
                        appointment = Appointment.query.filter_by(patient_id=patient.id).order_by(Appointment.appointment_date.desc()).first()
                        if appointment:
                            latest_appointment = appointment.appointment_date.strftime("%Y-%m-%d")
                    except:
                        pass
                    
                    latest_appointment_item = QTableWidgetItem(latest_appointment)
                    latest_appointment_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.patients_table.setItem(i, 8, latest_appointment_item)
                    
                    # 操作列 - 9 (最后一列)
                    btn_cell = QWidget()
                    btn_cell.setStyleSheet("background-color: transparent;")
                    btn_layout = QHBoxLayout(btn_cell)
                    btn_layout.setContentsMargins(10, 5, 10, 5)
                    btn_layout.setSpacing(15)
                    btn_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
                    
                    # 设置按钮容器为透明背景
                    btn_cell.setStyleSheet("""
                        background-color: transparent;
                        QToolTip {
                            background-color: rgba(255, 255, 255, 220);
                            color: black;
                            border: 1px solid gray;
                            padding: 3px;
                        }
                    """)
                    
                    # 查看按钮
                    view_btn = QPushButton()
                    view_btn.setText("👁️")  # 使用emoji作为图标
                    view_btn.setToolTip("查看")
                    view_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                    view_btn.setStyleSheet("""
                        QPushButton {
                            border: none;
                            background-color: transparent;
                            color: #4a86e8;
                            font-size: 16px;
                            padding: 5px;  /* 减小内边距 */
                            border-radius: 4px;
                            min-width: 28px;
                            max-width: 28px;
                            min-height: 28px;
                            max-height: 28px;
                        }
                        QPushButton:hover {
                            background-color: rgba(204, 238, 255, 0.3);
                        }
                        QToolTip {
                            background-color: rgba(255, 255, 255, 220);
                            color: black;
                            border: 1px solid gray;
                            padding: 3px;
                            font-size: 12px;
                        }
                    """)
                    view_btn.clicked.connect(lambda _, pid=patient.id: self.view_patient(pid))
                    
                    # 编辑按钮
                    edit_btn = QPushButton()
                    edit_btn.setText("✏️")  # 使用emoji作为图标
                    edit_btn.setToolTip("编辑")
                    edit_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                    edit_btn.setStyleSheet("""
                        QPushButton {
                            border: none;
                            background-color: transparent;
                            color: #4a86e8;
                            font-size: 16px;
                            padding: 5px;  /* 减小内边距 */
                            border-radius: 4px;
                            min-width: 28px;
                            max-width: 28px;
                            min-height: 28px;
                            max-height: 28px;
                        }
                        QPushButton:hover {
                            background-color: rgba(212, 230, 255, 0.3);
                        }
                        QToolTip {
                            background-color: rgba(255, 255, 255, 220);
                            color: black;
                            border: 1px solid gray;
                            padding: 3px;
                            font-size: 12px;
                        }
                    """)
                    edit_btn.clicked.connect(lambda _, pid=patient.id: self.edit_patient(pid))
                    
                    # 删除按钮
                    delete_btn = QPushButton()
                    delete_btn.setText("🗑️")  # 使用emoji作为图标
                    delete_btn.setToolTip("删除")
                    delete_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                    delete_btn.setStyleSheet("""
                        QPushButton {
                            border: none;
                            background-color: transparent;
                            color: #ff3b30;
                            font-size: 16px;
                            padding: 5px;  /* 减小内边距 */
                            border-radius: 4px;
                            min-width: 28px;
                            max-width: 28px;
                            min-height: 28px;
                            max-height: 28px;
                        }
                        QPushButton:hover {
                            background-color: rgba(255, 224, 224, 0.3);
                        }
                        QToolTip {
                            background-color: rgba(255, 255, 255, 220);
                            color: black;
                            border: 1px solid gray;
                            padding: 3px;
                            font-size: 12px;
                        }
                    """)
                    delete_btn.clicked.connect(lambda _, pid=patient.id: self.delete_patient(pid))
                    
                    btn_layout.addWidget(view_btn)
                    btn_layout.addWidget(edit_btn)
                    btn_layout.addWidget(delete_btn)
                    
                    # 确保操作按钮在最后一列（第9列）
                    op_column = 9
                    self.patients_table.setCellWidget(i, op_column, btn_cell)
                
                # 调整表格列宽
                self.on_patients_tab_resize(None)
                
        except Exception as e:
            QMessageBox.critical(self, "错误", f"加载患者列表时出错: {e}")
            print(f"加载患者列表时出错: {e}")
    
    def filter_patients(self):
        """过滤患者列表"""
        search_text = self.patient_search.text().lower()
        for row in range(self.patients_table.rowCount()):
            show_row = False
            for col in range(self.patients_table.columnCount()):
                item = self.patients_table.item(row, col)
                if item and search_text in item.text().lower():
                    show_row = True
                    break
            self.patients_table.setRowHidden(row, not show_row)
    
    def show_patient_context_menu(self, position):
        """显示患者右键菜单"""
        menu = QMenu()
        view_action = menu.addAction("查看详情")
        edit_action = menu.addAction("编辑")
        delete_action = menu.addAction("删除")
        menu.addSeparator()
        export_action = menu.addAction("导出所选患者")
        
        action = menu.exec(self.patients_table.mapToGlobal(position))
        
        if not action:
            return
        
        selected_row = self.patients_table.currentRow()
        if selected_row < 0:
            return
        
        try:
            patient_id = int(self.patients_table.item(selected_row, 0).text())
            
            if action == view_action:
                self.view_patient()
            elif action == edit_action:
                self.edit_patient(patient_id)
            elif action == delete_action:
                self.delete_patient(patient_id)
            elif action == export_action:
                self.export_patients(selected_only=True)
        except:
            QMessageBox.warning(self, "错误", "无法获取患者信息")
    
    def add_patient(self):
        """添加新患者 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.add_patient()
    
    def edit_patient(self, patient_id):
        """编辑患者信息 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.edit_patient(patient_id)
            
    def view_patient(self, patient_id=None):
        """查看患者信息 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.view_patient(patient_id)
            
    def delete_patient(self, patient_id):
        """删除患者 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.delete_patient(patient_id)
            
    def get_selected_patient_rows(self):
        """获取选中的患者行 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            return self.patients_manager.get_selected_patient_rows()
        return []
            
    def load_patients(self):
        """加载患者列表 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.load_patients()
            
    def filter_patients(self):
        """过滤患者列表 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.filter_patients()
            
    def export_patients(self, selected_only=False):
        """导出患者 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.export_patients(selected_only)
            
    def on_patients_tab_resize(self, event):
        """调整患者表格列宽 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.on_patients_tab_resize(event)
    
    def toggle_selection_mode(self):
        """切换患者选择模式 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.toggle_selection_mode()
    
    def show_patient_context_menu(self, position):
        """显示患者右键菜单 - 代理到patients_manager"""
        if hasattr(self, 'patients_manager'):
            self.patients_manager.show_patient_context_menu(position)
    
    def on_appointments_tab_resize(self, event):
        """调整预约表格列宽"""
        self.appointments_table.setColumnWidth(0, int(self.appointments_table.viewport().width() * 0.05))  # ID列 5%
        self.appointments_table.setColumnWidth(1, int(self.appointments_table.viewport().width() * 0.15))  # 患者姓名列 15%
        self.appointments_table.setColumnWidth(2, int(self.appointments_table.viewport().width() * 0.15))  # 预约日期列 15%
        self.appointments_table.setColumnWidth(3, int(self.appointments_table.viewport().width() * 0.15))  # 治疗类型列 15%
        self.appointments_table.setColumnWidth(4, int(self.appointments_table.viewport().width() * 0.10))  # 状态列 10%
        self.appointments_table.setColumnWidth(5, int(self.appointments_table.viewport().width() * 0.10))  # 费用列 10%
        self.appointments_table.setColumnWidth(6, int(self.appointments_table.viewport().width() * 0.15))  # 备注列 15%
        self.appointments_table.setColumnWidth(7, int(self.appointments_table.viewport().width() * 0.15))  # 操作列 15%

    # 主窗口大小改变事件
    def resizeEvent(self, event):
        """窗口大小变化时的事件处理"""
        super().resizeEvent(event)
        
        # 根据当前活动的标签页调整表格
        current_tab = self.tabs.currentWidget()
        
        if current_tab == self.patients_tab:
            self.on_patients_tab_resize(event)
        elif current_tab == self.appointments_tab and hasattr(self, 'appointments_manager'):
            self.appointments_manager.on_appointments_tab_resize(event)
        elif current_tab == self.dashboard_tab and hasattr(self, 'dashboard_manager'):
            self.dashboard_manager.on_dashboard_tab_resize(event)

    # 窗口首次显示事件
    def showEvent(self, event):
        """窗口首次显示时的事件处理"""
        # 调用父类的事件处理
        super().showEvent(event)
        
        # 使用定时器确保在窗口完全加载后调整表格大小
        QTimer.singleShot(200, self.adjust_all_tables)
    
    def adjust_all_tables(self):
        """调整所有表格的大小"""
        # 调整今日预约表格
        self.dashboard_manager.adjust_today_appointments_table()
        
        # 调整患者表格
        if hasattr(self, 'patients_table'):
            self.on_patients_tab_resize(None)
            
        # 调整预约表格
        if hasattr(self, 'appointments_manager'):
            self.appointments_manager.on_appointments_tab_resize(None)

    def view_patient_by_row(self, row):
        """查看患者详情"""
        selected_row = row
        if selected_row < 0:
            return
        
        try:
            patient_id = int(self.patients_table.item(selected_row, 0).text())
            self.edit_patient(patient_id)
        except:
            QMessageBox.warning(self, "错误", "无法获取患者信息")

    def view_appointment(self, appointment_id):
        """查看预约详情"""
        if hasattr(self, 'appointments_manager'):
            self.appointments_manager.view_appointment(appointment_id)
    
    def edit_appointment(self, appointment_id):
        """编辑预约详情"""
        if hasattr(self, 'appointments_manager'):
            self.appointments_manager.edit_appointment(appointment_id)

    def delete_appointment(self, appointment_id):
        """编辑预约详情"""
        if hasattr(self, 'appointments_manager'):
            self.appointments_manager.delete_appointment(appointment_id)
        