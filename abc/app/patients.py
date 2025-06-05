from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                          QLabel, QLineEdit, QTableWidget, QTableWidgetItem,
                          QFormLayout, QDateEdit, QTextEdit, QComboBox,
                          QMessageBox, QDialog, QSpinBox, QHeaderView, 
                          QSizePolicy, QFrame, QGridLayout, QMenu, QCheckBox,
                          QScrollArea, QApplication, QDateTimeEdit)
from PyQt6.QtCore import Qt, QDate, QSize, QTimer, QDateTime
from PyQt6.QtGui import QFont, QIcon, QColor, QCursor, QPixmap
from datetime import datetime
import logging
import functools

# 导入数据库模型和初始化
from init import db, app
from models import User, Patient, Appointment, FollowUpVisit

# 导入样式和组件
from app.styles import (Card, PrimaryButton, SecondaryButton, StyledLineEdit,
                      StyledComboBox, ACCENT_COLOR, BACKGROUND_COLOR, CARD_BACKGROUND, 
                      TEXT_COLOR, SECONDARY_TEXT_COLOR, BORDER_RADIUS, BUTTON_HEIGHT)

# 患者表单对话框
class PatientDialog(QDialog):
    def __init__(self, parent=None, patient=None, view_only=False):
        super().__init__(parent)
        self.patient = patient
        self.view_only = view_only
        self.setWindowTitle("添加患者" if not patient else ("查看患者信息" if view_only else "编辑患者信息"))
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
        main_form_layout.setSpacing(10)  # 设置垂直间距
        
        # 第一行：病历号、姓名、年龄、性别
        first_row_layout = QHBoxLayout()
        first_row_layout.setSpacing(15)  # 设置水平间距
        
        # 病历号
        medical_record_container = QWidget()
        medical_record_layout = QFormLayout(medical_record_container)
        medical_record_layout.setContentsMargins(0, 0, 0, 0)
        medical_record_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        # 获取默认的病历号（患者数量+1）
        default_record_number = 1
        try:
            with app.app_context():
                patient_count = Patient.query.count()
                default_record_number = patient_count + 1
        except:
            default_record_number = 1
            
        # 使用QSpinBox代替LineEdit，确保输入的是整数
        self.medical_record_input = QSpinBox()
        self.medical_record_input.setRange(1, 999999)  # 设置合理的范围
        self.medical_record_input.setValue(default_record_number)
        self.medical_record_input.setStyleSheet("""
            QSpinBox {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
            QSpinBox::up-button, QSpinBox::down-button {
                border-radius: 2px;
            }
        """)
        medical_record_label = QLabel("病历号:")
        medical_record_label.setStyleSheet(label_style)
        medical_record_layout.addRow(medical_record_label, self.medical_record_input)
        first_row_layout.addWidget(medical_record_container, 1)  # 病历号占1
        
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
        # 移除默认值30
        self.age_input.setStyleSheet("""
            QSpinBox {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
            QSpinBox::up-button, QSpinBox::down-button {
                border-radius: 2px;
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
        
        self.gender_combo = StyledComboBox()
        self.gender_combo.addItems(["男", "女"])
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
        
        self.first_visit_date = QDateTimeEdit()  # 使用QDateTimeEdit代替QDateEdit
        self.first_visit_date.setCalendarPopup(True)
        self.first_visit_date.setDateTime(QDateTime.currentDateTime())  # 使用QDateTime
        self.first_visit_date.setDisplayFormat("yyyy-MM-dd HH:mm")  # 显示格式包括小时和分钟
        self.first_visit_date.setStyleSheet("""
            QDateTimeEdit {
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
        address_layout = QHBoxLayout()  # 更改为水平布局，包含地址和身份证号
        
        # 地址部分
        address_container = QWidget()
        address_form_layout = QFormLayout(address_container)
        address_form_layout.setContentsMargins(0, 0, 0, 0)
        address_form_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.address_input = StyledLineEdit()
        self.address_input.setPlaceholderText("请输入地址（选填）")
        address_label = QLabel("地址:")
        address_label.setStyleSheet(label_style)
        address_form_layout.addRow(address_label, self.address_input)
        
        # 身份证号部分
        id_number_container = QWidget()
        id_number_form_layout = QFormLayout(id_number_container)
        id_number_form_layout.setContentsMargins(0, 0, 0, 0)
        id_number_form_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)  # 标签右对齐
        
        self.id_number_input = StyledLineEdit()
        self.id_number_input.setPlaceholderText("请输入身份证号（选填）")
        id_number_label = QLabel("身份证号:")
        id_number_label.setStyleSheet(label_style)
        id_number_form_layout.addRow(id_number_label, self.id_number_input)
        
        # 添加到水平布局
        address_layout.addWidget(address_container, 1)
        address_layout.addWidget(id_number_container, 1)
        
        # 添加地址行到主表单布局
        main_form_layout.addLayout(address_layout)
        
        # 牙齿状况
        dental_label = QLabel("牙齿状况:")
        dental_label.setStyleSheet(label_style)
        
        # 创建容器
        dental_container = QWidget()
        dental_layout = QVBoxLayout(dental_container)
        dental_layout.setContentsMargins(0, 0, 0, 0)
        dental_layout.setSpacing(8)  # 减小间距，使界面更紧凑
        
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
        self.dental_charts_container.setObjectName("dental_charts_container")
        self.dental_charts_layout = QVBoxLayout(self.dental_charts_container)
        self.dental_charts_layout.setContentsMargins(5, 5, 5, 5)  # 增加内边距，防止边缘显示问题
        self.dental_charts_layout.setSpacing(10)  # 增加行间距，避免行之间视觉上的混淆
        
        # 设置牙齿状况容器的大小策略和样式
        self.dental_charts_container.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.dental_charts_container.setMinimumHeight(100)
        self.dental_charts_container.setStyleSheet("""
            background-color: white;
            border: none;
        """)
        
        # 创建滚动区域 - 完全不使用框架和边框，避免重叠
        self.dental_scroll_area = QScrollArea()
        self.dental_scroll_area.setObjectName("dental_scroll_area")
        self.dental_scroll_area.setWidgetResizable(True)
        self.dental_scroll_area.setWidget(self.dental_charts_container)
        self.dental_scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.dental_scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        
        # 设置滚动区域样式 - 使用单一边框而不是框架边框
        self.dental_scroll_area.setStyleSheet("""
            QScrollArea { 
                background-color: white; 
                border: 1px solid #e0e0e0; 
                border-radius: 4px; 
            }
            QScrollBar:vertical { 
                width: 10px; 
                background: #f0f0f0; 
                margin: 0px;
            }
            QScrollBar::handle:vertical { 
                background: #c0c0c0; 
                border-radius: 5px; 
                min-height: 20px;
            }
            QScrollBar::add-line:vertical, 
            QScrollBar::sub-line:vertical { 
                height: 0px; 
            }
            QScrollBar::add-page:vertical,
            QScrollBar::sub-page:vertical {
                background: #f0f0f0;
            }
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
        self.treatment_items_input.setMaximumHeight(60)  # 减小最大高度
        treatment_label = QLabel("诊疗费用项目:")
        treatment_label.setStyleSheet(label_style)
        treatment_form_layout.addRow(treatment_label, self.treatment_items_input)
        main_form_layout.addLayout(treatment_form_layout)
        
        layout.addLayout(main_form_layout)
        
        # 按钮布局
        button_layout = QHBoxLayout()
        button_layout.setSpacing(15)  # 保持按钮之间的间距
        button_layout.setContentsMargins(0, 8, 0, 0)  # 减小上边距，使界面更紧凑
        
        if not self.view_only:
            # 非只读模式显示保存和取消按钮
            save_button = PrimaryButton("保存")
            save_button.clicked.connect(self.save_patient)
            
            cancel_button = SecondaryButton("取消")
            cancel_button.clicked.connect(self.reject)
            
            button_layout.addWidget(save_button)
            button_layout.addWidget(cancel_button)
        else:
            # 只读模式只显示关闭按钮
            close_button = PrimaryButton("关闭")
            close_button.clicked.connect(self.reject)
            button_layout.addWidget(close_button)
        
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        
        # 如果是编辑模式，填充现有数据
        if self.patient:
            self.fill_patient_data()
            
        # 如果是只读模式，禁用所有输入控件
        if self.view_only:
            self.set_all_controls_readonly()

    def add_dental_chart_row(self):
        """添加一个牙齿状况记录行"""
        row_index = self.dental_charts_layout.count()
        
        # 创建行容器
        row_widget = QWidget()
        # 使用QHBoxLayout确保更一致的水平布局
        row_layout = QHBoxLayout(row_widget)
        row_layout.setContentsMargins(0, 0, 0, 0)
        row_layout.setSpacing(10)  # 组件间距
        
        # 设置行容器的大小策略 - 水平扩展，垂直固定
        row_widget.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        row_widget.setFixedHeight(85)  # 固定高度
        row_widget.setObjectName(f"dental_row_{row_index}")
        
        # 日期选择器容器 - 固定宽度确保对齐
        date_container = QWidget()
        date_container.setFixedWidth(120)
        date_layout = QVBoxLayout(date_container)
        date_layout.setContentsMargins(0, 0, 0, 0)
        
        # 日期选择器
        date_widget = QDateEdit()
        date_widget.setCalendarPopup(True)
        date_widget.setDate(QDate.currentDate())
        date_widget.setDisplayFormat("yyyy-MM-dd")
        date_widget.setObjectName(f"dental_date_{row_index}")
        date_widget.setStyleSheet("""
            QDateEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px;
                background-color: white;
            }
        """)
        date_widget.dateChanged.connect(self.update_dental_data)
        date_layout.addWidget(date_widget, 0, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        
        # 添加日期容器到主布局
        row_layout.addWidget(date_container)
        
        # 创建十字图表1容器 - 统一大小和对齐
        chart1_container = QWidget()
        chart1_layout = QVBoxLayout(chart1_container)
        chart1_layout.setContentsMargins(0, 0, 0, 0)
        
        # 创建十字图表1
        chart1_widget = self.create_dental_cross_chart(f"chart1_{row_index}")
        chart1_layout.addWidget(chart1_widget, 0, Qt.AlignmentFlag.AlignCenter)
        
        # 添加十字图表1容器到主布局
        row_layout.addWidget(chart1_container, 1)  # 设置伸展因子为1
        
        # 创建十字图表2容器 - 统一大小和对齐
        chart2_container = QWidget()
        chart2_layout = QVBoxLayout(chart2_container)
        chart2_layout.setContentsMargins(0, 0, 0, 0)
        
        # 创建十字图表2
        chart2_widget = self.create_dental_cross_chart(f"chart2_{row_index}")
        chart2_layout.addWidget(chart2_widget, 0, Qt.AlignmentFlag.AlignCenter)
        
        # 添加十字图表2容器到主布局
        row_layout.addWidget(chart2_container, 1)  # 设置伸展因子为1
        
        # 创建操作按钮容器 - 固定宽度确保对齐
        button_container = QWidget()
        button_container.setFixedWidth(36)
        button_layout = QVBoxLayout(button_container)
        button_layout.setContentsMargins(0, 0, 0, 0)
        button_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # 删除按钮 - 所有行都使用相同的删除按钮，只是第一行的不可见
        delete_btn = QPushButton("🗑️")
        delete_btn.setObjectName(f"delete_btn_{row_index}")
        delete_btn.setToolTip("删除此记录")
        delete_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        delete_btn.setFixedSize(36, 36)
        delete_btn.setStyleSheet("""
            QPushButton {
                border: none;
                background-color: transparent;
                color: #ff3b30;
                font-size: 16px;
                padding: 5px;
                margin: 0px;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: rgba(255, 224, 224, 0.3);
            }
        """)
        
        # 第一行的删除按钮不可见，但保持相同的尺寸和位置
        if row_index == 0:
            delete_btn.setVisible(False)
            delete_btn.setEnabled(False)
        else:
            delete_btn.clicked.connect(lambda: self.delete_dental_chart_row(row_widget))
        
        # 添加删除按钮到按钮容器
        button_layout.addWidget(delete_btn, 0, Qt.AlignmentFlag.AlignCenter)
        
        # 添加按钮容器到主布局
        row_layout.addWidget(button_container)
        
        # 添加行到牙齿状况容器
        self.dental_charts_layout.addWidget(row_widget)
        
        # 调整容器大小以适应新增的行
        total_rows = self.dental_charts_layout.count()
        row_height = 85  # 每行85像素高度
        
        # 如果行数小于等于3，自适应高度；否则固定为3行高度并显示滚动条
        if total_rows <= 3:
            ideal_height = total_rows * row_height
            self.dental_charts_container.setMinimumHeight(ideal_height)
            self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            self.dental_scroll_area.setMinimumHeight(ideal_height)
            self.dental_scroll_area.setMaximumHeight(ideal_height)
        else:
            fixed_height = 3 * row_height
            self.dental_charts_container.setMinimumHeight(total_rows * row_height)
            self.dental_scroll_area.setMinimumHeight(fixed_height)
            self.dental_scroll_area.setMaximumHeight(fixed_height)
            self.dental_scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
            
        # 确保所有行的间距保持一致
        for i in range(self.dental_charts_layout.count()):
            item = self.dental_charts_layout.itemAt(i)
            if item and item.widget():
                item.widget().setFixedHeight(row_height)
        
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
        # 创建没有布局的主容器，以便我们使用绝对定位
        chart_widget = QWidget()
        chart_widget.setObjectName(chart_id)
        chart_widget.setFixedHeight(85)
        chart_widget.setFixedWidth(300)  # 固定宽度以确保一致性
        
        # 从chart_id中提取图表编号和行索引
        parts = chart_id.split('_')
        chart_num = parts[0]  # 例如 "chart1"
        row_idx = parts[1] if len(parts) > 1 else "0"  # 行索引
        
        # 定义输入框的尺寸
        input_width = 139
        input_height = 25
        
        # 设置输入框与十字线之间的距离（约0.5毫米）
        gap = 3  # 3像素的间距，视觉上约0.5毫米
        
        # 计算中心点位置
        center_x = chart_widget.width() // 2
        center_y = chart_widget.height() // 2
        
        # 创建水平线 - 确保它正好在中心
        h_line = QLabel(chart_widget)
        h_line.setObjectName(f"{chart_id}_h_line_{row_idx}")
        h_line.setFixedHeight(2)
        h_line.setFixedWidth(chart_widget.width() - 18)  # 几乎占满整个宽度
        h_line.setStyleSheet("background-color: rgba(0, 123, 255, 0.7); border: none;")
        h_line.move(9, center_y)  # 水平居中的位置
        
        # 创建垂直线 - 确保它正好在中心
        v_line = QLabel(chart_widget)
        v_line.setObjectName(f"{chart_id}_v_line_{row_idx}")
        v_line.setFixedWidth(2)
        v_line.setFixedHeight(chart_widget.height() - 25)  # 几乎占满整个高度
        v_line.setStyleSheet("background-color: rgba(0, 123, 255, 0.7); border: none;")
        v_line.move(center_x, 12)  # 垂直居中的位置
        
        # 创建四个象限的输入框 - 直接使用绝对定位确保它们与十字线保持适当距离
        input_field_positions = {
            # 格式: (位置名称, x位置, y位置, 水平对齐)
            'top-left': (center_x - input_width - gap, center_y - input_height - gap, Qt.AlignmentFlag.AlignRight),
            'top-right': (center_x + gap, center_y - input_height - gap, Qt.AlignmentFlag.AlignLeft),
            'bottom-left': (center_x - input_width - gap, center_y + gap, Qt.AlignmentFlag.AlignRight),
            'bottom-right': (center_x + gap, center_y + gap, Qt.AlignmentFlag.AlignLeft)
        }
        
        for pos, (x, y, align) in input_field_positions.items():
            # 创建输入框
            input_field = QLineEdit(chart_widget)
            
            # 设置对象名称
            obj_name = f"{chart_id}_{pos.replace('-', '_')}"
            input_field.setObjectName(obj_name)
            
            # 设置data-area属性，与web端保持一致
            input_field.setProperty("data-area", f"{chart_num}-{pos}")
            
            # 设置输入框尺寸和位置
            input_field.setFixedSize(input_width, input_height)
            input_field.move(x, y)
            
            # 设置文本对齐方式
            input_field.setAlignment(align)
            
            # 设置样式
            input_field.setStyleSheet("""
                QLineEdit {
                    border: 1px solid #e0e0e0;
                    border-radius: 4px;
                    padding: 2px;
                    background-color: white;
                    font-size: 12px;
                }
            """)
            
            # 连接信号
            input_field.textChanged.connect(self.update_dental_data)
        
        # 设置整个图表的样式
        chart_widget.setStyleSheet("""
            QWidget {
                background-color: transparent;
                border: none;
            }
        """)
        
        # 设置大小策略
        chart_widget.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Fixed)
        
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
                
            # 确保所有行的高度一致
            for i in range(self.dental_charts_layout.count()):
                item = self.dental_charts_layout.itemAt(i)
                if item and item.widget():
                    item.widget().setFixedHeight(row_height)
            
            # 使用延迟调用确保UI更新后再调整大小
            QTimer.singleShot(50, self.updateDialogSize)
        else:
            # 如果只有一行，则清空输入值
            # 查找日期控件
            date_widget = None
            for date_edit in row_widget.findChildren(QDateEdit):
                if date_edit.objectName().startswith("dental_date_"):
                    date_widget = date_edit
                    date_widget.setDate(QDate.currentDate())
                    break
            
            # 清空所有输入框
            row_index = 0  # 第一行的索引
            for chart_num in [1, 2]:
                for position in ["top_left", "top_right", "bottom_left", "bottom_right"]:
                    # 查找并清空输入框
                    for line_edit in row_widget.findChildren(QLineEdit):
                        # 检查输入框的对象名称是否匹配
                        if (line_edit.objectName() == f"chart{chart_num}_{row_index}_{position}" or
                            line_edit.objectName() == f"chart{chart_num}_{position}"):
                            line_edit.clear()
                            break
            
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
                
            # 获取日期 - 使用findChildren查找，适应新的布局结构
            date_widget = None
            for date_edit in row_widget.findChildren(QDateEdit):
                if date_edit.objectName() == f"dental_date_{i}":
                    date_widget = date_edit
                    break
                    
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
                    
                    # 查找对应的输入框 - 使用findChildren查找，适应新的布局结构
                    input_field = None
                    for line_edit in row_widget.findChildren(QLineEdit):
                        if line_edit.objectName() == input_name:
                            input_field = line_edit
                            break
                            
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
            if self.patient.medical_record_number is not None:
                self.medical_record_input.setValue(self.patient.medical_record_number)
            self.name_input.setText(self.patient.name)
            self.phone_input.setText(self.patient.phone or "")
            self.age_input.setValue(self.patient.age or 0)
            self.gender_combo.setCurrentText(self.patient.gender or "")
            self.address_input.setText(self.patient.address or "")
            self.id_number_input.setText(self.patient.identification_number or "")
            self.doctor_input.setText(self.patient.doctor or "")
            
            # 设置初诊日期
            if self.patient.first_visit_date:
                qdatetime = QDateTime(self.patient.first_visit_date)
                self.first_visit_date.setDateTime(qdatetime)
            
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
                        # 先找到并删除所有子部件，确保彻底清理
                        children = item.widget().findChildren(QWidget)
                        for child in children:
                            child.setParent(None)
                            child.deleteLater()
                        # 然后删除容器部件
                        item.widget().deleteLater()
                
                # 在完全清除后，强制应用变更
                QApplication.processEvents()
                
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
                    date_widget = None
                    for date_edit in row_widget.findChildren(QDateEdit):
                        if date_edit.objectName() == f"dental_date_{row_index}":
                            date_widget = date_edit
                            break
                    
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
                    
                    # 设置图表数据
                    for chart_num in [1, 2]:
                        for pos in ["top-left", "top-right", "bottom-left", "bottom-right"]:
                            # 构造数据键名 - 使用原始索引
                            data_key = f"chart{chart_num}-{pos}-{original_index}"
                            # 构造输入框对象名称 - 使用实际行索引
                            input_name = f"chart{chart_num}_{row_index}_{pos.replace('-', '_')}"
                            
                            # 查找输入框
                            input_field = None
                            for line_edit in row_widget.findChildren(QLineEdit):
                                if line_edit.objectName() == input_name:
                                    input_field = line_edit
                                    break
                                    
                            if input_field:
                                # 无论键是否存在都设置值，确保UI不显示旧值
                                value = self.dental_data.get(data_key, "")
                                input_field.setText(str(value))
                    
                    # 处理删除按钮 - 根据行索引判断是否显示
                    for btn in row_widget.findChildren(QPushButton):
                        if btn.objectName() == f"delete_btn_{row_index}":
                            # 第一行不显示删除按钮
                            btn.setVisible(i > 0)
                            btn.setEnabled(i > 0)
                            if i > 0:
                                # 确保非第一行删除按钮连接了删除事件
                                btn.clicked.connect(lambda checked=False, rw=row_widget: self.delete_dental_chart_row(rw))
                            break
                
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
                    
                # 确保所有行的高度一致
                for i in range(self.dental_charts_layout.count()):
                    item = self.dental_charts_layout.itemAt(i)
                    if item and item.widget():
                        item.widget().setFixedHeight(row_height)
                
            except Exception as e:
                # 创建一个默认行
                self.add_dental_chart_row()
                self.dental_condition_input.setText(self.patient.dental_condition)
        else:
            # 如果没有牙齿状况数据，创建一个默认行
            self.add_dental_chart_row()
        
        self.treatment_items_input.setText(self.patient.treatment_items or "")

    def collect_dental_data_from_ui(self):
        """从UI收集牙齿状况数据
        
        返回:
            dict: 包含牙齿状况数据的字典
        """
        # 收集牙齿状况数据
        dental_data = {}
        
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
                dental_data[date_key] = date_value
            
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
                        if value:  # 只有当输入框有值时才添加
                            dental_data[key] = value
        
        return dental_data

    def save_patient(self):
        name = self.name_input.text()
        phone = self.phone_input.text()
        medical_record_number = self.medical_record_input.value()
        
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
                        current_patient.medical_record_number = medical_record_number
                        current_patient.name = name
                        current_patient.age = self.age_input.value()
                        current_patient.gender = self.gender_combo.currentText()
                        current_patient.phone = phone
                        current_patient.address = self.address_input.text()
                        current_patient.identification_number = self.id_number_input.text()
                        current_patient.doctor = self.doctor_input.text()
                        current_patient.first_visit_date = self.first_visit_date.dateTime().toPyDateTime()
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
                        medical_record_number=medical_record_number,
                        name=name,
                        age=self.age_input.value(),
                        gender=self.gender_combo.currentText(),
                        phone=phone,
                        address=self.address_input.text(),
                        identification_number=self.id_number_input.text(),
                        doctor=self.doctor_input.text(),
                        first_visit_date=self.first_visit_date.dateTime().toPyDateTime(),
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

    def set_all_controls_readonly(self):
        """将所有输入控件设置为只读状态"""
        # 设置基本信息输入框为只读
        self.medical_record_input.setReadOnly(True)
        self.medical_record_input.setButtonSymbols(QSpinBox.ButtonSymbols.NoButtons)  # 隐藏上下按钮
        self.name_input.setReadOnly(True)
        self.phone_input.setReadOnly(True)
        self.age_input.setReadOnly(True)
        self.gender_combo.setEnabled(False)
        self.address_input.setReadOnly(True)
        self.id_number_input.setReadOnly(True)  # 设置身份证号为只读
        self.doctor_input.setReadOnly(True)
        self.first_visit_date.setEnabled(False)
        
        # 设置诊疗费用项目为只读
        self.treatment_items_input.setReadOnly(True)
        
        # 隐藏添加牙齿状况记录按钮
        for child in self.findChildren(QPushButton):
            if child.text() == "+":
                child.hide()
                break
        
        # 设置所有牙齿图表输入框为只读
        for row_index in range(self.dental_charts_layout.count()):
            row_widget = self.dental_charts_layout.itemAt(row_index).widget()
            if row_widget:
                # 设置日期为只读
                date_widget = None
                for date_edit in row_widget.findChildren(QDateEdit):
                    if date_edit.objectName() == f"dental_date_{row_index}":
                        date_widget = date_edit
                        date_widget.setEnabled(False)
                        break
                
                # 设置所有输入框为只读
                for chart_num in [1, 2]:
                    for pos in ["top-left", "top-right", "bottom-left", "bottom-right"]:
                        input_name = f"chart{chart_num}_{row_index}_{pos.replace('-', '_')}"
                        for input_field in row_widget.findChildren(QLineEdit):
                            if input_field.objectName() == input_name:
                                input_field.setReadOnly(True)
                                break
                
                # 处理删除按钮 - 对所有行（包括第一行）设置一致的逻辑
                for delete_btn in row_widget.findChildren(QPushButton):
                    if delete_btn.objectName() == f"delete_btn_{row_index}":
                        # 所有行的删除按钮在只读模式下都不可见，但保持占位
                        if row_index > 0:
                            delete_btn.setVisible(False)
                        # 确保所有按钮占用相同的空间
                        delete_btn.setFixedSize(36, 36)
                        break

# 患者管理类
class PatientsTab:
    def __init__(self, main_window):
        self.main_window = main_window
        self.patients_tab = QWidget()
        
        # 添加日期过滤相关属性
        self.is_date_filtered = False
        self.filtered_patients = []
        
        self.setup_patients_tab()

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
        self.patient_search.setPlaceholderText("搜索患者姓名、电话、地址或病历号...")
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
        
        # 添加日期范围查找功能
        # 创建一个垂直分隔线
        date_separator = QFrame()
        date_separator.setFrameShape(QFrame.Shape.VLine)
        date_separator.setStyleSheet("background-color: #e0e0e0;")
        date_separator.setFixedWidth(1)
        search_layout.addWidget(date_separator)
        
        # 添加日期范围图标和标签
        date_icon = QLabel("📅")
        date_icon.setStyleSheet("font-size: 16px; color: #86868b; margin-left: 8px;")
        search_layout.addWidget(date_icon)
        
        date_label = QLabel("初诊日期:")
        date_label.setStyleSheet("font-size: 14px; color: #86868b; margin-left: 4px;")
        search_layout.addWidget(date_label)
        
        # 添加起始日期选择器
        self.start_date = QDateEdit()
        self.start_date.setDisplayFormat("yyyy-MM-dd")
        self.start_date.setCalendarPopup(True)
        self.start_date.setDate(QDate.currentDate().addMonths(-1))  # 默认为一个月前
        self.start_date.setStyleSheet("""
            QDateEdit {
                border: none;
                padding: 8px 4px;
                font-size: 14px;
                background-color: transparent;
            }
        """)
        search_layout.addWidget(self.start_date)
        
        # 添加至标签
        to_label = QLabel("至")
        to_label.setStyleSheet("font-size: 14px; color: #86868b;")
        search_layout.addWidget(to_label)
        
        # 添加结束日期选择器
        self.end_date = QDateEdit()
        self.end_date.setDisplayFormat("yyyy-MM-dd")
        self.end_date.setCalendarPopup(True)
        self.end_date.setDate(QDate.currentDate())  # 默认为今天
        self.end_date.setStyleSheet("""
            QDateEdit {
                border: none;
                padding: 8px 4px;
                font-size: 14px;
                background-color: transparent;
            }
        """)
        search_layout.addWidget(self.end_date)
        
        # 添加应用日期过滤按钮
        self.apply_date_filter_btn = QPushButton("应用")
        self.apply_date_filter_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.apply_date_filter_btn.setStyleSheet("""
            QPushButton {
                background-color: #4a86e8;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 4px 8px;
                font-size: 12px;
                margin-left: 4px;
            }
            QPushButton:hover {
                background-color: #3a76d8;
            }
        """)
        self.apply_date_filter_btn.clicked.connect(self.apply_date_filter)
        search_layout.addWidget(self.apply_date_filter_btn)
        
        # 添加清除日期过滤按钮
        self.clear_date_filter_btn = QPushButton("清除")
        self.clear_date_filter_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.clear_date_filter_btn.setStyleSheet("""
            QPushButton {
                background-color: #f5f5f7;
                color: #666;
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 4px 8px;
                font-size: 12px;
                margin-left: 4px;
            }
            QPushButton:hover {
                background-color: #e5e5e7;
            }
        """)
        self.clear_date_filter_btn.clicked.connect(self.clear_filters)
        search_layout.addWidget(self.clear_date_filter_btn)
        
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
        from app.patient_export import create_export_button
        self.export_btn = create_export_button()
        self.export_btn.setText("导出全部")  # 设置初始文字为"导出全部"
        self.export_btn.clicked.connect(self.export_patients)
        
        action_layout.addWidget(search_container, 1)
        action_layout.addWidget(add_patient_btn)
        action_layout.addWidget(self.select_btn)
        action_layout.addWidget(self.export_btn)
        
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
        self.patients_table.setColumnCount(11)  # 增加一列用于病历号
        self.patients_table.setHorizontalHeaderLabels(["选择", "ID", "病历号", "姓名", "年龄", "性别", "电话", "初诊时间", "地址", "最近预约", "操作"])
        
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
        self.patients_table.setColumnWidth(2, int(total_width * 0.08))  # 病历号列 8%
        self.patients_table.setColumnWidth(3, int(total_width * 0.10))  # 姓名列 10%
        self.patients_table.setColumnWidth(4, int(total_width * 0.05))  # 年龄列 5%
        self.patients_table.setColumnWidth(5, int(total_width * 0.05))  # 性别列 5%
        self.patients_table.setColumnWidth(6, int(total_width * 0.12))  # 电话列 12%
        self.patients_table.setColumnWidth(7, int(total_width * 0.10))  # 初诊时间列 10%
        self.patients_table.setColumnWidth(8, int(total_width * 0.10))  # 地址列 10%
        self.patients_table.setColumnWidth(9, int(total_width * 0.10))  # 最近预约列 10%
        self.patients_table.setColumnWidth(10, int(total_width * 0.10))  # 操作列 10%
        
        # 设置表头自适应模式
        self.patients_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Fixed)  # 选择
        self.patients_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Interactive)  # ID
        self.patients_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Interactive)  # 病历号
        self.patients_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)  # 姓名
        self.patients_table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Interactive)  # 年龄
        self.patients_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.ResizeMode.Interactive)  # 性别
        self.patients_table.horizontalHeader().setSectionResizeMode(6, QHeaderView.ResizeMode.Stretch)  # 电话
        self.patients_table.horizontalHeader().setSectionResizeMode(7, QHeaderView.ResizeMode.Stretch)  # 初诊时间
        self.patients_table.horizontalHeader().setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)  # 地址
        self.patients_table.horizontalHeader().setSectionResizeMode(9, QHeaderView.ResizeMode.Stretch)  # 最近预约
        self.patients_table.horizontalHeader().setSectionResizeMode(10, QHeaderView.ResizeMode.Fixed)  # 操作
        
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

    def on_patients_tab_resize(self, event):
        """调整患者表格列宽"""
        if not hasattr(self, 'patients_table'):
            return
            
        table_width = self.patients_table.viewport().width()
        
        # 计算列数以确保我们处理正确的列
        column_count = self.patients_table.columnCount()
        if column_count < 11:  # 安全检查
            return
            
        # 设置列宽比例
        self.patients_table.setColumnWidth(0, int(table_width * 0.05))  # 选择列 5%
        self.patients_table.setColumnWidth(1, int(table_width * 0.05))  # ID列 5%
        self.patients_table.setColumnWidth(2, int(table_width * 0.08))  # 病历号列 8%
        self.patients_table.setColumnWidth(3, int(table_width * 0.10))  # 姓名列 10%
        self.patients_table.setColumnWidth(4, int(table_width * 0.05))  # 年龄列 5%
        self.patients_table.setColumnWidth(5, int(table_width * 0.05))  # 性别列 5%
        self.patients_table.setColumnWidth(6, int(table_width * 0.10))  # 电话列 10%
        self.patients_table.setColumnWidth(7, int(table_width * 0.10))  # 初诊时间列 10%
        self.patients_table.setColumnWidth(8, int(table_width * 0.10))  # 地址列 10%
        self.patients_table.setColumnWidth(9, int(table_width * 0.10))  # 最近预约列 10%
        self.patients_table.setColumnWidth(10, int(table_width * 0.12))  # 操作列 12%
        
        # 刷新表格显示
        self.patients_table.update()
    
    def load_patients(self):
        """加载患者列表"""
        try:
            with app.app_context():
                # 开始查询前清空表格
                self.patients_table.setRowCount(0)
                
                # 修改查询，按照updated_at字段降序排序
                # 移除nulls_last()函数，改用标准的desc()
                patients = Patient.query.order_by(Patient.updated_at.desc()).all()
                
                # 设置表格行数
                self.patients_table.setRowCount(len(patients))
                
                # 使用_populate_patients_table填充表格数据
                self._populate_patients_table(patients)
                
                # 重置日期过滤状态
                self.is_date_filtered = False
                self.filtered_patients = []
                
        except Exception as e:
            QMessageBox.critical(self.main_window, "错误", f"加载患者列表时出错: {str(e)}")
            print(f"加载患者列表时出错: {e}")
    
    def add_patient(self):
        """添加新患者"""
        dialog = PatientDialog(self.main_window)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.load_patients()
            # 如果主窗口有dashboard_manager，刷新仪表盘
            if hasattr(self.main_window, 'dashboard_manager'):
                self.main_window.dashboard_manager.refresh_dashboard()
    
    def edit_patient(self, patient_id):
        """编辑患者信息"""
        with app.app_context():
            patient = db.session.get(Patient, patient_id)
            dialog = PatientDialog(self.main_window, patient)
            if dialog.exec() == QDialog.DialogCode.Accepted:
                self.load_patients()
                # 如果主窗口有dashboard_manager，刷新仪表盘
                if hasattr(self.main_window, 'dashboard_manager'):
                    self.main_window.dashboard_manager.refresh_dashboard()
    
    def view_patient(self, patient_id=None):
        """查看患者详情"""
        try:
            # 如果没有提供patient_id，则尝试从表格选中的行获取
            if patient_id is None:
                selected_rows = self.patients_table.selectedItems()
                if not selected_rows:
                    QMessageBox.warning(self.main_window, "提示", "请先选择一个患者")
                    return
                
                # 获取选中行的ID列单元格（第1列）
                id_cell = self.patients_table.item(selected_rows[0].row(), 1)
                
                # 从单元格获取患者ID
                patient_id = id_cell.data(Qt.ItemDataRole.UserRole)
            
            # 查询患者信息
            with app.app_context():
                patient = db.session.get(Patient, patient_id)
                if patient:
                    # 创建只读模式的对话框
                    dialog = PatientDialog(self.main_window, patient, view_only=True)
                    # 打开对话框，不需要处理返回值，因为只读模式下没有保存操作
                    dialog.exec()
                else:
                    QMessageBox.warning(self.main_window, "提示", "找不到患者信息")
        except Exception as e:
            QMessageBox.critical(self.main_window, "错误", f"查看患者信息时出错: {str(e)}")
            print(f"查看患者信息时出错: {str(e)}")
    
    def delete_patient(self, patient_id):
        """删除患者"""
        try:
            with app.app_context():
                # 查询患者信息
                patient = db.session.get(Patient, patient_id)
                if patient:
                    # 确认删除
                    reply = QMessageBox.question(
                        self.main_window,
                        "确认删除",
                        f"确定要删除患者 {patient.name} 的所有信息吗？此操作不可撤销。",
                        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                        QMessageBox.StandardButton.No
                    )
                    
                    if reply == QMessageBox.StandardButton.Yes:
                        # 查询该患者的所有预约并删除
                        appointments = Appointment.query.filter_by(patient_id=patient.id).all()
                        for appointment in appointments:
                            db.session.delete(appointment)
                        
                        # 删除患者
                        db.session.delete(patient)
                        db.session.commit()
                        
                        # 刷新表格
                        self.load_patients()
                        
                        # 如果主窗口有dashboard_manager，刷新仪表盘
                        if hasattr(self.main_window, 'dashboard_manager'):
                            self.main_window.dashboard_manager.refresh_dashboard()
                        
                        QMessageBox.information(self.main_window, "删除成功", "患者信息已成功删除")
                else:
                    QMessageBox.warning(self.main_window, "错误", "找不到要删除的患者记录")
        except Exception as e:
            QMessageBox.critical(self.main_window, "删除失败", f"删除患者信息时出错: {str(e)}")
            print(f"删除患者信息时出错: {str(e)}")
    
    def toggle_selection_mode(self):
        """切换选择模式"""
        # 获取当前列可见性
        is_selection_visible = not self.patients_table.isColumnHidden(0)
        
        # 切换列可见性
        self.patients_table.setColumnHidden(0, is_selection_visible)
        
        # 更新按钮文本
        self.select_btn.setText("取消选择" if not is_selection_visible else "选择")
        
        # 更新导出按钮文字
        self.export_btn.setText("导出部分" if not is_selection_visible else "导出全部")
        
        # 如果进入选择模式，创建表头复选框并清除所有行的选择
        if not is_selection_visible:
            # 设置选择列的表头为"全选"
            header_item = QTableWidgetItem("全选")
            header_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setHorizontalHeaderItem(0, header_item)
            
            # 确保列宽足够显示"全选"文字
            self.patients_table.setColumnWidth(0, 60)
            
            # 连接表头点击事件（先断开已有连接防止重复）
            try:
                self.patients_table.horizontalHeader().sectionClicked.disconnect(self.header_click)
            except:
                pass
            self.patients_table.horizontalHeader().sectionClicked.connect(self.header_click)
            
            # 清除所有选择框的选中状态
            for row in range(self.patients_table.rowCount()):
                checkbox_cell = self.patients_table.cellWidget(row, 0)
                if checkbox_cell:
                    checkbox = checkbox_cell.findChild(QCheckBox)
                    if checkbox:
                        checkbox.blockSignals(True)
                        checkbox.setChecked(False)
                        checkbox.blockSignals(False)
        else:
            # 如果退出选择模式，断开表头点击事件连接
            try:
                self.patients_table.horizontalHeader().sectionClicked.disconnect(self.header_click)
            except:
                pass
            
            # 恢复原始表头
            header_item = QTableWidgetItem("选择")
            header_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setHorizontalHeaderItem(0, header_item)
    
    def header_click(self, section):
        """处理表头点击事件"""
        if section == 0:  # 如果点击的是第一列（全选列）
            print(f"表头点击: 列={section}")
            
            # 获取当前是否所有复选框都被选中
            all_checked = True
            for row in range(self.patients_table.rowCount()):
                checkbox_cell = self.patients_table.cellWidget(row, 0)
                if checkbox_cell:
                    checkbox = checkbox_cell.findChild(QCheckBox)
                    if checkbox and not checkbox.isChecked():
                        all_checked = False
                        break
            
            # 切换选中状态
            new_state = not all_checked
            print(f"设置所有复选框状态为: {new_state}")
            
            # 批量更新所有复选框
            for row in range(self.patients_table.rowCount()):
                checkbox_cell = self.patients_table.cellWidget(row, 0)
                if checkbox_cell:
                    checkbox = checkbox_cell.findChild(QCheckBox)
                    if checkbox:
                        # 阻止触发过多事件，一次性设置所有复选框
                        checkbox.blockSignals(True)
                        checkbox.setChecked(new_state)
                        # 启用最后一个复选框的信号，以触发任何需要的更新
                        if row == self.patients_table.rowCount() - 1:
                            checkbox.blockSignals(False)
                            # 手动触发一次状态变化，确保更新UI状态
                            self.handle_checkbox_state_changed(row, Qt.CheckState.Checked.value if new_state else Qt.CheckState.Unchecked.value)
    
    def get_selected_patient_rows(self):
        """获取选中的患者行
        
        返回:
            list: 包含选中患者ID的列表
        """
        selected_patient_ids = []
        
        # 如果不在选择模式下，返回空列表
        if self.patients_table.isColumnHidden(0):
            return selected_patient_ids
            
        # 遍历所有行，检查复选框状态
        for row in range(self.patients_table.rowCount()):
            checkbox_cell = self.patients_table.cellWidget(row, 0)
            if checkbox_cell:
                checkbox = checkbox_cell.findChild(QCheckBox)
                if checkbox and checkbox.isChecked():
                    # 获取患者ID
                    patient_id = self.patients_table.item(row, 1).data(Qt.ItemDataRole.UserRole)
                    selected_patient_ids.append(patient_id)
                    
        return selected_patient_ids
    
    def handle_checkbox_state_changed(self, row, state):
        """处理复选框状态变化
        
        参数:
            row: 行索引
            state: Qt.CheckState值
        """
        # 打印调试信息
        print(f"复选框状态变化: 行={row}, 状态={state}")
        
        try:
            # 复选框状态应该已经由Qt框架自动更新，无需手动更新
            # 但我们可以验证状态是否正确
            checkbox_cell = self.patients_table.cellWidget(row, 0)
            if checkbox_cell:
                checkbox = checkbox_cell.findChild(QCheckBox)
                if checkbox:
                    current_state = checkbox.isChecked()
                    print(f"当前复选框状态: 行={row}, 状态={current_state}")
        except Exception as e:
            print(f"处理复选框状态变化时出错: {str(e)}")
    
    def show_patient_context_menu(self, position):
        """显示患者右键菜单"""
        menu = QMenu()
        edit_action = menu.addAction("编辑")
        delete_action = menu.addAction("删除")
        
        action = menu.exec(self.patients_table.mapToGlobal(position))
        
        if not action:
            return
        
        selected_row = self.patients_table.currentRow()
        if selected_row < 0:
            return
        
        try:
            # 从表格获取患者ID
            patient_id = self.patients_table.item(selected_row, 1).data(Qt.ItemDataRole.UserRole)
            
            if action == edit_action:
                self.edit_patient(patient_id)
            elif action == delete_action:
                self.delete_patient(patient_id)
        except:
            QMessageBox.warning(self.main_window, "错误", "无法获取患者信息")
    
    def filter_patients(self):
        """根据搜索框内容过滤患者"""
        search_text = self.patient_search.text().strip()
        
        # 如果搜索文本为空且没有应用日期过滤，加载所有患者
        if not search_text and not self.is_date_filtered:
            self.load_patients()
            return
        
        # 如果搜索文本为空但有日期过滤，直接使用已经过滤的结果
        if not search_text and self.is_date_filtered:
            # 清空表格
            self.patients_table.setRowCount(0)
            
            # 设置表格行数
            patients = self.filtered_patients
            self.patients_table.setRowCount(len(patients))
            
            # 使用_populate_patients_table方法填充表格数据
            self._populate_patients_table(patients)
            return
        
        try:
            with app.app_context():
                # 确定基础查询集合 - 如果有日期过滤，使用已过滤的患者列表
                if self.is_date_filtered:
                    # 对已经按日期过滤的结果再次进行关键词过滤
                    # 将搜索文本拆分为多个关键词
                    keywords = search_text.lower().split()
                    
                    # 从已过滤的患者列表中进一步筛选
                    filtered_patients = []
                    for patient in self.filtered_patients:
                        # 检查患者是否匹配所有关键词
                        matches_all = True
                        for keyword in keywords:
                            # 检查关键词是否可以转换为整数
                            try:
                                search_number = int(keyword)
                                is_number = True
                            except ValueError:
                                is_number = False
                            
                            # 检查是否匹配此关键词
                            matches_keyword = False
                            if patient.name and keyword.lower() in patient.name.lower():
                                matches_keyword = True
                            elif patient.phone and keyword.lower() in patient.phone.lower():
                                matches_keyword = True
                            elif patient.address and keyword.lower() in patient.address.lower():
                                matches_keyword = True
                            elif patient.identification_number and keyword.lower() in patient.identification_number.lower():
                                matches_keyword = True
                            
                            # 如果是数字，检查ID和病历号
                            if is_number and (patient.id == search_number or 
                                             (patient.medical_record_number and 
                                              str(patient.medical_record_number) == str(search_number))):
                                matches_keyword = True
                            
                            if not matches_keyword:
                                matches_all = False
                                break
                        
                        if matches_all:
                            filtered_patients.append(patient)
                    
                    patients = filtered_patients
                else:
                    # 没有日期过滤，使用标准数据库查询
                    # 将搜索文本拆分为多个关键词
                    keywords = search_text.lower().split()
                    
                    # 初始化查询
                    query = Patient.query
                    
                    # 对每个关键词应用查询条件
                    for keyword in keywords:
                        # 检查关键词是否可以转换为整数（用于病历号搜索）
                        is_number = False
                        try:
                            search_number = int(keyword)
                            is_number = True
                        except ValueError:
                            pass
                        
                        # 构建此关键词的查询条件
                        keyword_condition = (
                            Patient.name.ilike(f"%{keyword}%") |
                            Patient.phone.ilike(f"%{keyword}%") |
                            Patient.address.ilike(f"%{keyword}%") |
                            Patient.identification_number.ilike(f"%{keyword}%")
                        )
                        
                        # 如果是数字，添加对病历号和ID的搜索
                        if is_number:
                            keyword_condition = keyword_condition | (
                                (Patient.id == search_number) |
                                (Patient.medical_record_number == search_number)
                            )
                        
                        # 将此关键词的条件应用到查询
                        query = query.filter(keyword_condition)
                    
                    # 执行查询获取患者
                    patients = query.all()
                
                # 清空表格
                self.patients_table.setRowCount(0)
                
                # 如果没有找到结果，显示提示并恢复原来的状态
                if not patients:
                    QMessageBox.information(self.main_window, "搜索结果", "没有找到匹配的患者信息")
                    if self.is_date_filtered:
                        # 如果有日期过滤，恢复到日期过滤的结果
                        self.patients_table.setRowCount(len(self.filtered_patients))
                        self._populate_patients_table(self.filtered_patients)
                    else:
                        # 否则加载所有患者
                        self.load_patients()
                    return
                
                # 设置表格行数
                self.patients_table.setRowCount(len(patients))
                
                # 使用_populate_patients_table方法填充表格数据
                self._populate_patients_table(patients)
                
                # 如果在选择模式下，确保表头显示"全选"
                if not self.patients_table.isColumnHidden(0):
                    header_item = QTableWidgetItem("全选")
                    header_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.patients_table.setHorizontalHeaderItem(0, header_item)
                    self.patients_table.setColumnWidth(0, 60)
        except Exception as e:
            QMessageBox.critical(self.main_window, "错误", f"搜索患者数据失败: {str(e)}")
            print(f"搜索患者数据失败: {str(e)}")
            # 出错时恢复显示所有患者
            self.load_patients()

    def apply_date_filter(self):
        """应用日期过滤"""
        try:
            # 正确地从QDate获取年月日，并创建Python datetime对象
            start_qdate = self.start_date.date()
            end_qdate = self.end_date.date()
            
            start_date = datetime(start_qdate.year(), start_qdate.month(), start_qdate.day())
            end_date = datetime(end_qdate.year(), end_qdate.month(), end_qdate.day(), 23, 59, 59)
            
            # 验证日期范围
            if start_date > end_date:
                QMessageBox.warning(self.main_window, "日期范围无效", "开始日期不能晚于结束日期")
                return
            
            with app.app_context():
                # 查询指定日期范围内的患者
                query = Patient.query.filter(
                    Patient.first_visit_date >= start_date,
                    Patient.first_visit_date <= end_date
                ).order_by(Patient.updated_at.desc())
                
                # 获取过滤后的患者列表
                filtered_patients = query.all()
                
                # 如果没有找到患者，显示提示
                if not filtered_patients:
                    QMessageBox.information(self.main_window, "日期过滤结果", "在选定的日期范围内没有找到患者")
                    return
                
                # 保存过滤后的患者列表和过滤状态
                self.filtered_patients = filtered_patients
                self.is_date_filtered = True
                
                # 清空表格
                self.patients_table.setRowCount(0)
                
                # 设置表格行数
                self.patients_table.setRowCount(len(filtered_patients))
                
                # 使用_populate_patients_table方法填充表格数据
                self._populate_patients_table(filtered_patients)
                
                # 显示当前状态 - 可以在UI上添加一个状态标签来显示
                QMessageBox.information(
                    self.main_window, 
                    "日期过滤结果", 
                    f"成功找到 {len(filtered_patients)} 位患者 (初诊日期在 {start_date.strftime('%Y-%m-%d')} 至 {end_date.strftime('%Y-%m-%d')} 之间)"
                )
        except Exception as e:
            QMessageBox.critical(self.main_window, "错误", f"应用日期过滤失败: {str(e)}")
            print(f"应用日期过滤失败: {str(e)}")

    def clear_filters(self):
        """清除所有过滤条件"""
        # 清空搜索框
        self.patient_search.clear()
        
        # 重置日期选择器到默认状态
        self.start_date.setDate(QDate.currentDate().addMonths(-1))
        self.end_date.setDate(QDate.currentDate())
        
        # 重置过滤状态
        self.is_date_filtered = False
        self.filtered_patients = []
        
        # 重新加载所有患者
        self.load_patients()
    
    def export_patients(self):
        """导出患者数据
        
        根据当前模式决定是导出全部还是只导出选中的患者
        """
        # 更新导入路径
        from app.patient_export import export_patients_to_excel
        
        try:
            # 确定是否处于选择模式
            is_selection_mode = not self.patients_table.isColumnHidden(0)
            
            # 获取当前显示的患者数据
            rows = self.patients_table.rowCount()
            
            # 如果没有数据，显示提示并返回
            if rows == 0:
                QMessageBox.information(self.main_window, "导出提示", "没有可导出的患者数据")
                return
            
            # 如果是选择模式
            if is_selection_mode:
                # 获取选中的患者ID
                selected_patient_ids = self.get_selected_patient_rows()
                
                # 如果没有选中的患者，提示用户并返回
                if not selected_patient_ids:
                    QMessageBox.information(self.main_window, "导出提示", "没有选中任何患者，请至少选择一个患者进行导出")
                    return
                    
                # 查询选中的患者数据
                with app.app_context():
                    patients = []
                    for patient_id in selected_patient_ids:
                        patient = db.session.get(Patient, patient_id)
                        if patient:
                            patients.append(patient)
                    
                    # 调用导出函数，只导出选中的患者
                    if patients:
                        export_patients_to_excel(self.main_window, patients, True)
                    else:
                        QMessageBox.information(self.main_window, "导出提示", "无法获取选中的患者数据")
            else:
                # 非选择模式，导出所有当前显示的患者数据
                with app.app_context():
                    # 获取所有患者或搜索结果中的患者
                    search_text = self.patient_search.text().lower()
                    if search_text:
                        # 有搜索文本，导出搜索结果
                        search_condition = (
                            Patient.name.ilike(f"%{search_text}%") |
                            Patient.phone.ilike(f"%{search_text}%") |
                            Patient.address.ilike(f"%{search_text}%") |
                            Patient.medical_record_number.ilike(f"%{search_text}%")
                        )
                        patients = Patient.query.filter(search_condition).all()
                    else:
                        # 无搜索文本，导出所有患者
                        patients = Patient.query.all()
                    
                    # 调用导出函数，导出所有患者
                    export_patients_to_excel(self.main_window, patients, False)
                    
        except Exception as e:
            QMessageBox.critical(self.main_window, "导出失败", f"导出患者数据失败: {str(e)}")
            print(f"导出患者数据失败: {str(e)}")
    
    def _populate_patients_table(self, patients):
        """填充患者表格数据"""
        # 填充表格数据
        for i, patient in enumerate(patients):
            # 选择列 - 0
            # 创建一个独立的QWidget作为容器
            checkbox_cell = QWidget()
            checkbox_cell.setStyleSheet("background-color: transparent;")
            
            # 创建复选框
            checkbox = QCheckBox()
            checkbox.setObjectName(f"checkbox_{i}")
            checkbox.setProperty("row", i)
            
            # 重要：设置样式表直接应用到复选框
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
                    background-color: white;
                }
                QCheckBox::indicator:checked {
                    background-color: #4a86e8;
                    image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='20 6 9 17 4 12'%3E%3C/polyline%3E%3C/svg%3E");
                }
            """)
            
            # 关键：确保复选框和容器都能接收鼠标事件
            checkbox.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, False)
            checkbox_cell.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, False)
            
            # 创建布局并添加复选框
            checkbox_layout = QHBoxLayout(checkbox_cell)
            checkbox_layout.setContentsMargins(0, 0, 0, 0)
            checkbox_layout.addWidget(checkbox, 0, Qt.AlignmentFlag.AlignCenter)
            
            # 使用functools.partial连接事件
            checkbox.stateChanged.connect(
                functools.partial(self.handle_checkbox_state_changed, i)
            )
            
            # 将复选框容器设置到单元格
            self.patients_table.setCellWidget(i, 0, checkbox_cell)
            
            # ID列 - 1 (因为0是复选框列)
            id_item = QTableWidgetItem(str(patient.id))
            id_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            id_item.setData(Qt.ItemDataRole.UserRole, patient.id)  # 存储患者ID
            self.patients_table.setItem(i, 1, id_item)
            
            # 病历号列 - 2
            medical_record_item = QTableWidgetItem(str(patient.medical_record_number) if patient.medical_record_number is not None else "")
            medical_record_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 2, medical_record_item)
            
            # 姓名列 - 3
            name_item = QTableWidgetItem(patient.name)
            name_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 3, name_item)
            
            # 年龄列 - 4
            age_item = QTableWidgetItem(str(patient.age) if patient.age else "")
            age_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 4, age_item)
            
            # 性别列 - 5
            gender_item = QTableWidgetItem(patient.gender or "")
            gender_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 5, gender_item)
            
            # 电话列 - 6
            phone_item = QTableWidgetItem(patient.phone if patient.phone else "")
            phone_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 6, phone_item)
            
            # 初诊时间列 - 7
            first_visit_date = patient.first_visit_date.strftime("%Y-%m-%d %H:%M") if patient.first_visit_date else ""
            first_visit_item = QTableWidgetItem(first_visit_date)
            first_visit_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 7, first_visit_item)
            
            # 地址列 - 8
            address_item = QTableWidgetItem(patient.address if patient.address else "")
            address_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.patients_table.setItem(i, 8, address_item)
            
            # 最近预约列 - 9
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
            self.patients_table.setItem(i, 9, latest_appointment_item)
            
            # 操作列 - 10 (最后一列)
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
                    color: #4CAF50;  /* 绿色，与编辑按钮的蓝色区分 */
                    font-size: 16px;
                    padding: 5px;
                    border-radius: 4px;
                    min-width: 28px;
                    max-width: 28px;
                    min-height: 28px;
                    max-height: 28px;
                }
                QPushButton:hover {
                    background-color: rgba(76, 175, 80, 0.1);  /* 淡绿色悬停效果 */
                }
                QToolTip {
                    background-color: rgba(255, 255, 255, 220);
                    color: black;
                    border: 1px solid gray;
                    padding: 3px;
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
                }
            """)
            delete_btn.clicked.connect(lambda _, pid=patient.id: self.delete_patient(pid))
            
            btn_layout.addWidget(view_btn)
            btn_layout.addWidget(edit_btn)
            btn_layout.addWidget(delete_btn)
            
            # 确保操作按钮在最后一列
            self.patients_table.setCellWidget(i, 10, btn_cell)
