import sys
import os
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget,
                            QTableWidgetItem, QHeaderView, QFrame, QPushButton, QDialog,
                            QFormLayout, QDateEdit, QTextEdit, QComboBox, QLineEdit, 
                            QMessageBox, QSizePolicy, QMenu, QTimeEdit)
from PyQt6.QtCore import Qt, QDate, QDateTime, QTime
from PyQt6.QtGui import QFont, QIcon, QColor
from datetime import datetime

# 导入数据库模型和初始化
from init import db, app
from models import User, Patient, Appointment

# 导入样式和组件
from app.styles import (PrimaryButton, SecondaryButton, StyledLineEdit, 
                     StyledComboBox, ACCENT_COLOR, TEXT_COLOR)

# 预约表单对话框
class AppointmentDialog(QDialog):
    def __init__(self, parent=None, appointment=None):
        super().__init__(parent)
        self.appointment = appointment
        self.setWindowTitle("添加预约" if not appointment else "编辑预约信息")
        self.setMinimumWidth(500)
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # 表单布局
        form_layout = QFormLayout()
        
        # 患者选择
        self.patient_combo = StyledComboBox()
        with app.app_context():
            patients = Patient.query.all()
            for patient in patients:
                self.patient_combo.addItem(patient.name, patient.id)
        form_layout.addRow("患者:", self.patient_combo)
        
        # 预约日期
        self.appointment_date = QDateEdit()
        self.appointment_date.setCalendarPopup(True)
        self.appointment_date.setDate(QDate.currentDate())
        self.appointment_date.setStyleSheet("""
            QDateEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
        """)
        form_layout.addRow("预约日期:", self.appointment_date)
        
        # 预约时间
        self.appointment_time = QTimeEdit()
        self.appointment_time.setTime(QTime(9, 0))
        self.appointment_time.setStyleSheet("""
            QTimeEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
        """)
        form_layout.addRow("预约时间:", self.appointment_time)
        
        # 治疗类型
        self.treatment_type_input = StyledLineEdit()
        self.treatment_type_input.setPlaceholderText("例如：洗牙、补牙、拔牙等")
        form_layout.addRow("治疗类型:", self.treatment_type_input)
        
        # 备注
        self.notes_input = QTextEdit()
        self.notes_input.setMaximumHeight(100)
        self.notes_input.setPlaceholderText("请输入备注信息（选填）")
        self.notes_input.setStyleSheet("""
            QTextEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px;
                background-color: white;
            }
        """)
        form_layout.addRow("备注:", self.notes_input)
        
        # 费用
        self.cost_input = QLineEdit()
        self.cost_input.setPlaceholderText("0.00")
        self.cost_input.setStyleSheet("""
            QLineEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }
        """)
        form_layout.addRow("费用 (¥):", self.cost_input)
        
        # 状态
        self.status_combo = StyledComboBox()
        self.status_combo.addItems(["已预约", "已完成", "已取消"])
        form_layout.addRow("状态:", self.status_combo)
        
        layout.addLayout(form_layout)
        
        # 按钮布局
        button_layout = QHBoxLayout()
        
        save_button = PrimaryButton("保存")
        save_button.clicked.connect(self.save_appointment)
        self.save_button = save_button  # 保存引用以便后续访问
        
        cancel_button = SecondaryButton("取消")
        cancel_button.clicked.connect(self.reject)
        self.cancel_button = cancel_button  # 保存引用以便后续访问
        
        button_layout.addWidget(save_button)
        button_layout.addWidget(cancel_button)
        
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        
        # 如果是编辑模式，填充现有数据
        if self.appointment:
            self.fill_appointment_data()
    
    def fill_appointment_data(self):
        # 设置患者
        index = self.patient_combo.findData(self.appointment.patient_id)
        if index >= 0:
            self.patient_combo.setCurrentIndex(index)
        
        # 设置预约日期和时间
        appointment_date = self.appointment.appointment_date
        self.appointment_date.setDate(QDate(appointment_date.year, appointment_date.month, appointment_date.day))
        self.appointment_time.setTime(QTime(appointment_date.hour, appointment_date.minute))
        
        # 设置其他字段
        self.treatment_type_input.setText(self.appointment.treatment_type or "")
        self.notes_input.setText(self.appointment.notes or "")
        self.cost_input.setText(str(self.appointment.cost) if self.appointment.cost else "")
        
        # 设置状态
        status_map = {"scheduled": "已预约", "completed": "已完成", "cancelled": "已取消"}
        self.status_combo.setCurrentText(status_map.get(self.appointment.status, "已预约"))
    
    def save_appointment(self):
        patient_id = self.patient_combo.currentData()
        
        if not patient_id:
            QMessageBox.warning(self, "输入错误", "请选择患者")
            return
        
        # 获取日期和时间
        date = self.appointment_date.date()
        time = self.appointment_time.time()
        appointment_datetime = datetime(date.year(), date.month(), date.day(), 
                                       time.hour(), time.minute())
        
        # 获取费用
        try:
            cost = float(self.cost_input.text()) if self.cost_input.text() else 0.0
        except ValueError:
            QMessageBox.warning(self, "输入错误", "费用必须是有效的数字")
            return
        
        # 状态映射
        status_map = {"已预约": "scheduled", "已完成": "completed", "已取消": "cancelled"}
        status = status_map.get(self.status_combo.currentText(), "scheduled")
        
        try:
            with app.app_context():
                if self.appointment:  # 编辑现有预约
                    # 先从数据库中获取最新的预约对象
                    appointment = db.session.get(Appointment, self.appointment.id)
                    if appointment:
                        appointment.patient_id = patient_id
                        appointment.appointment_date = appointment_datetime
                        appointment.treatment_type = self.treatment_type_input.text()
                        appointment.notes = self.notes_input.toPlainText()
                        appointment.cost = cost
                        appointment.status = status
                        db.session.add(appointment)  # 将修改后的对象添加到会话中
                else:  # 添加新预约
                    new_appointment = Appointment(
                        patient_id=patient_id,
                        appointment_date=appointment_datetime,
                        treatment_type=self.treatment_type_input.text(),
                        notes=self.notes_input.toPlainText(),
                        cost=cost,
                        status=status
                    )
                    db.session.add(new_appointment)
                
                db.session.commit()
                self.accept()
        except Exception as e:
            QMessageBox.critical(self, "保存失败", f"保存预约信息时发生错误: {str(e)}")

# 预约管理选项卡
class AppointmentsTab:
    """预约管理选项卡类"""
    
    def __init__(self, parent=None):
        """初始化预约管理选项卡"""
        self.parent = parent
        self.appointments_tab = QWidget()
        self.setup_appointments_tab()
    
    def setup_appointments_tab(self):
        """设置预约管理标签页"""
        # 创建主布局
        main_layout = QVBoxLayout(self.appointments_tab)
        main_layout.setContentsMargins(10, 10, 10, 10)  # 减少外边距，让内容更充分利用空间
        main_layout.setSpacing(15)
        
        # 页面标题区域
        title_layout = QHBoxLayout()
        
        # 图标和标题
        icon_label = QLabel("📅")
        icon_label.setStyleSheet("font-size: 28px; color: #4a86e8;")
        
        title_label = QLabel("预约管理")
        title_label.setStyleSheet("""
            font-size: 24px; 
            font-weight: bold; 
            color: #1d1d1f;
            margin-left: 10px;
        """)
        
        title_layout.addWidget(icon_label)
        title_layout.addWidget(title_label)
        title_layout.addStretch()
        
        # 添加预约按钮
        add_button = QPushButton("+ 添加预约")
        add_button.setCursor(Qt.CursorShape.PointingHandCursor)
        add_button.setStyleSheet("""
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
        add_button.clicked.connect(self.add_appointment)
        title_layout.addWidget(add_button)
        
        main_layout.addLayout(title_layout)
        
        # 过滤卡片
        filter_card = QFrame()
        filter_card.setFrameShape(QFrame.Shape.StyledPanel)
        filter_card.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 8px;
                border: 1px solid #e0e0e0;
            }
        """)
        
        filter_layout = QHBoxLayout(filter_card)
        filter_layout.setSpacing(20)
        filter_layout.setContentsMargins(15, 15, 15, 15)

        # 日期范围过滤
        date_range_layout = QHBoxLayout()
        date_label = QLabel("日期范围:")
        date_label.setStyleSheet("color: #1d1d1f; font-weight: 500;")
        date_range_layout.addWidget(date_label)
        
        self.start_date = QDateEdit()
        self.start_date.setCalendarPopup(True)
        self.start_date.setDate(QDate.currentDate().addDays(-7))
        self.start_date.setStyleSheet("""
            QDateEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 12px;
                background: white;
                min-width: 120px;
            }
        """)
        
        date_separator = QLabel("-")
        date_separator.setStyleSheet("color: #1d1d1f; margin: 0 5px;")
        
        self.end_date = QDateEdit()
        self.end_date.setCalendarPopup(True)
        self.end_date.setDate(QDate.currentDate())
        self.end_date.setStyleSheet("""
            QDateEdit {
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 12px;
                background: white;
                min-width: 120px;
            }
        """)
        
        date_range_layout.addWidget(self.start_date)
        date_range_layout.addWidget(date_separator)
        date_range_layout.addWidget(self.end_date)
        filter_layout.addLayout(date_range_layout)

        # 状态过滤
        status_layout = QHBoxLayout()
        status_label = QLabel("状态:")
        status_label.setStyleSheet("color: #1d1d1f; font-weight: 500;")
        status_layout.addWidget(status_label)
        
        self.status_combo = StyledComboBox()
        self.status_combo.addItems(["全部", "待就诊", "已完成", "已取消"])
        status_layout.addWidget(self.status_combo)
        filter_layout.addLayout(status_layout)

        # 过滤和重置按钮
        filter_button = QPushButton("筛选")
        filter_button.setCursor(Qt.CursorShape.PointingHandCursor)
        filter_button.setStyleSheet("""
            QPushButton {
                background-color: #f5f5f7;
                color: #1d1d1f;
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 16px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #e5e5e7;
            }
        """)
        filter_button.clicked.connect(self.filter_appointments)
        
        reset_button = QPushButton("重置")
        reset_button.setCursor(Qt.CursorShape.PointingHandCursor)
        reset_button.setStyleSheet("""
            QPushButton {
                background-color: white;
                color: #1d1d1f;
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 16px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #f5f5f7;
            }
        """)
        reset_button.clicked.connect(self.reset_appointment_filters)
        
        filter_layout.addWidget(filter_button)
        filter_layout.addWidget(reset_button)
        filter_layout.addStretch()

        main_layout.addWidget(filter_card)

        # 预约表格区域
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
        table_layout = QVBoxLayout(table_container)
        table_layout.setContentsMargins(0, 0, 0, 0)
        table_layout.setSpacing(0)
        
        # 预约表格
        self.appointments_table = QTableWidget()
        self.appointments_table.setColumnCount(8)
        self.appointments_table.setHorizontalHeaderLabels([
            "ID", "患者姓名", "预约日期", "治疗类型", "状态", "费用", "备注", "操作"
        ])
        
        # 设置表格样式
        self.appointments_table.setStyleSheet("""
            QTableWidget {
                border: none;
                background-color: white;
                gridline-color: #f0f0f0;
            }
            QTableWidget::item {
                padding: 12px;
                border-bottom: 1px solid #f0f0f0;
                text-align: center;
            }
            QHeaderView::section {
                background-color: #f8f9fa;
                padding: 15px;
                border: none;
                border-bottom: 2px solid #e0e0e0;
                font-weight: bold;
                color: #1d1d1f;
                text-align: center;
            }
            QTableWidget::item:selected {
                background-color: #f2f9ff;
                color: #1d1d1f;
            }
        """)
        
        # 设置表格属性
        self.appointments_table.setShowGrid(True)
        self.appointments_table.setGridStyle(Qt.PenStyle.SolidLine)
        self.appointments_table.verticalHeader().setVisible(False)
        self.appointments_table.horizontalHeader().setHighlightSections(False)
        self.appointments_table.horizontalHeader().setStretchLastSection(False)
        self.appointments_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.appointments_table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.appointments_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.appointments_table.customContextMenuRequested.connect(self.show_appointment_context_menu)
        
        # 设置行高和表头高度
        self.appointments_table.verticalHeader().setDefaultSectionSize(60)
        self.appointments_table.horizontalHeader().setFixedHeight(50)
        
        # 设置初始列宽
        self.on_appointments_tab_resize(None)
        
        # 连接窗口大小变化信号
        self.appointments_tab.resizeEvent = self.on_appointments_tab_resize
        
        # 双击查看预约详情
        self.appointments_table.doubleClicked.connect(self.view_appointment)
        
        table_layout.addWidget(self.appointments_table)
        main_layout.addWidget(table_container, 1)  # 1表示伸展因子，让表格区域占据更多空间

        # 加载预约数据
        self.load_appointments()

    # 数据操作和UI交互方法将在此处继续添加
    def add_appointment(self):
        """添加新预约"""
        dialog = AppointmentDialog(self.parent)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.load_appointments()
            if hasattr(self.parent, 'dashboard_manager'):
                self.parent.dashboard_manager.refresh_dashboard()
    
    def view_appointment(self, appointment_id=None):
        """查看预约信息"""
        try:
            if appointment_id is None:
                # 从表格中获取选中的行
                selected_rows = self.appointments_table.selectedItems()
                if not selected_rows:
                    QMessageBox.warning(self.parent, "提示", "请先选择一个预约")
                    return
                
                # 获取选中行的ID列的值
                row = selected_rows[0].row()
                appointment_id = int(self.appointments_table.item(row, 0).text())
            
            # 从数据库获取预约信息
            with app.app_context():
                appointment = db.session.get(Appointment, appointment_id)
                if not appointment:
                    QMessageBox.warning(self.parent, "错误", "预约不存在")
                    return
                
                # 创建对话框并设置为只读模式
                dialog = AppointmentDialog(self.parent, appointment)
                dialog.setWindowTitle("查看预约")
                
                # 设置为只读模式
                for widget in dialog.findChildren(QLineEdit) + dialog.findChildren(QTextEdit) + \
                              dialog.findChildren(QComboBox) + dialog.findChildren(QDateEdit) + \
                              dialog.findChildren(QTimeEdit):  # 添加QTimeEdit控件
                    widget.setEnabled(False)
                
                # 处理按钮状态
                try:
                    # 尝试隐藏保存按钮
                    if hasattr(dialog, 'save_button'):
                        dialog.save_button.setVisible(False)
                    
                    # 尝试设置取消按钮文本为"关闭"
                    if hasattr(dialog, 'cancel_button'):
                        dialog.cancel_button.setText("关闭")
                except Exception as e:
                    print(f"设置按钮状态时出错: {e}")
                
                dialog.exec()
                
        except Exception as e:
            QMessageBox.critical(self.parent, "错误", f"查看预约信息时出错: {e}")
            print(f"查看预约信息时出错: {e}")
    
    def load_appointments(self):
        """加载预约数据"""
        with app.app_context():
            # 修改查询排序，优先按updated_at降序排序，然后按appointment_date降序排序
            appointments = Appointment.query.order_by(
                Appointment.updated_at.desc(),  
                Appointment.appointment_date.desc()
            ).all()
            
            self.appointments_table.setRowCount(len(appointments))
            
            for i, appointment in enumerate(appointments):
                # ID
                id_item = QTableWidgetItem(str(appointment.id))
                id_item.setData(Qt.ItemDataRole.UserRole, appointment.id)  # 存储ID值
                id_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 0, id_item)
                
                # 患者姓名
                patient = db.session.get(Patient, appointment.patient_id)
                name_item = QTableWidgetItem(patient.name if patient else "未知患者")
                name_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 1, name_item)
                
                # 预约日期
                date_str = appointment.appointment_date.strftime("%Y-%m-%d %H:%M")
                date_item = QTableWidgetItem(date_str)
                date_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 2, date_item)
                
                # 治疗类型
                treatment_item = QTableWidgetItem(appointment.treatment_type or "")
                treatment_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 3, treatment_item)
                
                # 状态
                status_text = {
                    "scheduled": "已预约",
                    "completed": "已完成",
                    "cancelled": "已取消"
                }.get(appointment.status, "未知")
                
                status_item = QTableWidgetItem(status_text)
                status_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                if appointment.status == "scheduled":
                    status_item.setForeground(QColor("#0d6efd"))
                elif appointment.status == "completed":
                    status_item.setForeground(QColor("#198754"))
                elif appointment.status == "cancelled":
                    status_item.setForeground(QColor("#dc3545"))
                
                self.appointments_table.setItem(i, 4, status_item)
                
                # 费用
                cost_str = f"¥{appointment.cost:.2f}" if appointment.cost else "¥0.00"
                cost_item = QTableWidgetItem(cost_str)
                cost_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 5, cost_item)
                
                # 备注
                notes_item = QTableWidgetItem(appointment.notes or "")
                notes_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 6, notes_item)
                
                # 操作按钮
                btn_widget = QWidget()
                btn_widget.setStyleSheet("background-color: transparent;")
                btn_layout = QHBoxLayout(btn_widget)
                btn_layout.setContentsMargins(10, 0, 10, 0)  # 增加水平边距
                btn_layout.setSpacing(15)  # 增加按钮间距
                btn_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)  # 居中对齐
                
                # 设置按钮容器为透明背景
                btn_widget.setStyleSheet("""
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
                    }
                """)
                view_btn.clicked.connect(lambda _, aid=appointment.id: self.view_appointment(aid))
                
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
                edit_btn.clicked.connect(lambda _, aid=appointment.id: self.edit_appointment(aid))
                
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
                delete_btn.clicked.connect(lambda _, aid=appointment.id: self.delete_appointment(aid))
                
                btn_layout.addWidget(view_btn)
                btn_layout.addWidget(edit_btn)
                btn_layout.addWidget(delete_btn)
                
                self.appointments_table.setCellWidget(i, 7, btn_widget)
    
    def reset_appointment_filters(self):
        """重置预约过滤条件"""
        self.start_date.setDate(QDate.currentDate().addDays(-30))
        self.end_date.setDate(QDate.currentDate())
        self.status_combo.setCurrentText("全部")
        self.load_appointments()

    def show_appointment_context_menu(self, position):
        """显示预约右键菜单"""
        menu = QMenu()
        edit_action = menu.addAction("编辑")
        delete_action = menu.addAction("删除")
        
        action = menu.exec(self.appointments_table.mapToGlobal(position))
        
        if not action:
            return
        
        selected_row = self.appointments_table.currentRow()
        if selected_row < 0:
            return
        
        try:
            appointment_id = int(self.appointments_table.item(selected_row, 0).text())
            
            if action == edit_action:
                self.edit_appointment(appointment_id)
            elif action == delete_action:
                self.delete_appointment(appointment_id)
        except:
            QMessageBox.warning(self.parent, "错误", "无法获取预约信息")

    def edit_appointment(self, appointment_id):
        """编辑预约"""
        with app.app_context():
            appointment = db.session.get(Appointment, appointment_id)
            dialog = AppointmentDialog(self.parent, appointment)
            if dialog.exec() == QDialog.DialogCode.Accepted:
                self.load_appointments()
                if hasattr(self.parent, 'dashboard_manager'):
                    self.parent.dashboard_manager.refresh_dashboard()
    
    def delete_appointment(self, appointment_id):
        """删除预约"""
        try:
            with app.app_context():
                appointment = db.session.get(Appointment, appointment_id)
                if appointment:
                    reply = QMessageBox.question(
                        self.parent,
                        "确认删除",
                        f"确定要删除此预约吗？此操作不可撤销。",
                        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                        QMessageBox.StandardButton.No
                    )
                    
                    if reply == QMessageBox.StandardButton.Yes:
                        db.session.delete(appointment)
                        db.session.commit()
                        
                        self.load_appointments()
                        if hasattr(self.parent, 'dashboard_manager'):
                            self.parent.dashboard_manager.refresh_dashboard()
                        QMessageBox.information(self.parent, "删除成功", "预约信息已成功删除")
                else:
                    QMessageBox.warning(self.parent, "错误", "找不到该预约")
        except Exception as e:
            QMessageBox.critical(self.parent, "删除失败", f"删除预约信息时发生错误: {str(e)}")
    
    def filter_appointments(self):
        """根据日期范围和状态过滤预约"""
        start_date = self.start_date.date().toPyDate()
        end_date = self.end_date.date().toPyDate()
        status = self.status_combo.currentText()
        
        # 状态映射
        status_map = {
            "待就诊": "scheduled",
            "已完成": "completed",
            "已取消": "cancelled"
        }
        
        with app.app_context():
            query = Appointment.query
            
            # 添加日期过滤
            query = query.filter(
                Appointment.appointment_date >= datetime.combine(start_date, datetime.min.time()),
                Appointment.appointment_date <= datetime.combine(end_date, datetime.max.time())
            )
            
            # 添加状态过滤
            if status != "全部":
                query = query.filter(Appointment.status == status_map.get(status))
            
            # 执行查询，保持与load_appointments相同的排序逻辑
            appointments = query.order_by(
                Appointment.updated_at.desc(),
                Appointment.appointment_date.desc()
            ).all()
            
            # 更新表格
            self.appointments_table.setRowCount(len(appointments))
            
            for i, appointment in enumerate(appointments):
                # ID
                id_item = QTableWidgetItem(str(appointment.id))
                id_item.setData(Qt.ItemDataRole.UserRole, appointment.id)  # 存储ID值
                id_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 0, id_item)
                
                # 患者姓名
                patient = db.session.get(Patient, appointment.patient_id)
                name_item = QTableWidgetItem(patient.name if patient else "未知患者")
                name_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 1, name_item)
                
                # 预约日期
                date_str = appointment.appointment_date.strftime("%Y-%m-%d %H:%M")
                date_item = QTableWidgetItem(date_str)
                date_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 2, date_item)
                
                # 治疗类型
                treatment_item = QTableWidgetItem(appointment.treatment_type or "")
                treatment_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 3, treatment_item)
                
                # 状态
                status_text = {
                    "scheduled": "待就诊",
                    "completed": "已完成",
                    "cancelled": "已取消"
                }.get(appointment.status, "未知")
                
                status_item = QTableWidgetItem(status_text)
                status_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                if appointment.status == "scheduled":
                    status_item.setForeground(QColor("#0d6efd"))
                elif appointment.status == "completed":
                    status_item.setForeground(QColor("#198754"))
                elif appointment.status == "cancelled":
                    status_item.setForeground(QColor("#dc3545"))
                
                self.appointments_table.setItem(i, 4, status_item)
                
                # 费用
                cost_str = f"¥{appointment.cost:.2f}" if appointment.cost else "¥0.00"
                cost_item = QTableWidgetItem(cost_str)
                cost_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 5, cost_item)
                
                # 备注
                notes_item = QTableWidgetItem(appointment.notes or "")
                notes_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self.appointments_table.setItem(i, 6, notes_item)
                
                # 添加操作按钮
                btn_widget = QWidget()
                btn_layout = QHBoxLayout(btn_widget)
                btn_layout.setContentsMargins(10, 0, 10, 0)
                btn_layout.setSpacing(15)
                btn_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
                
                # 设置按钮容器为透明背景
                btn_widget.setStyleSheet("""
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
                view_btn.setText("👁️")
                view_btn.setToolTip("查看")
                view_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                view_btn.setStyleSheet("""
                    QPushButton {
                        border: none;
                        background-color: transparent;
                        color: #4a86e8;
                        font-size: 16px;
                        padding: 5px;
                        border-radius: 4px;
                        min-width: 28px;
                        max-width: 28px;
                        min-height: 28px;
                        max-height: 28px;
                    }
                    QPushButton:hover {
                        background-color: rgba(204, 238, 255, 0.3);
                    }
                """)
                view_btn.clicked.connect(lambda _, aid=appointment.id: self.view_appointment(aid))
                
                # 编辑按钮
                edit_btn = QPushButton()
                edit_btn.setText("✏️")
                edit_btn.setToolTip("编辑")
                edit_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                edit_btn.setStyleSheet("""
                    QPushButton {
                        border: none;
                        background-color: transparent;
                        color: #4a86e8;
                        font-size: 16px;
                        padding: 5px;
                        border-radius: 4px;
                        min-width: 28px;
                        max-width: 28px;
                        min-height: 28px;
                        max-height: 28px;
                    }
                    QPushButton:hover {
                        background-color: rgba(212, 230, 255, 0.3);
                    }
                """)
                edit_btn.clicked.connect(lambda _, aid=appointment.id: self.edit_appointment(aid))
                
                # 删除按钮
                delete_btn = QPushButton()
                delete_btn.setText("🗑️")
                delete_btn.setToolTip("删除")
                delete_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                delete_btn.setStyleSheet("""
                    QPushButton {
                        border: none;
                        background-color: transparent;
                        color: #ff3b30;
                        font-size: 16px;
                        padding: 5px;
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
                delete_btn.clicked.connect(lambda _, aid=appointment.id: self.delete_appointment(aid))
                
                btn_layout.addWidget(view_btn)
                btn_layout.addWidget(edit_btn)
                btn_layout.addWidget(delete_btn)
                
                self.appointments_table.setCellWidget(i, 7, btn_widget)
    
    def on_appointments_tab_resize(self, event):
        """调整预约表格列宽"""
        if hasattr(self, 'appointments_table') and self.appointments_table:
            self.appointments_table.setColumnWidth(0, int(self.appointments_table.viewport().width() * 0.05))  # ID列 5%
            self.appointments_table.setColumnWidth(1, int(self.appointments_table.viewport().width() * 0.15))  # 患者姓名列 15%
            self.appointments_table.setColumnWidth(2, int(self.appointments_table.viewport().width() * 0.15))  # 预约日期列 15%
            self.appointments_table.setColumnWidth(3, int(self.appointments_table.viewport().width() * 0.15))  # 治疗类型列 15%
            self.appointments_table.setColumnWidth(4, int(self.appointments_table.viewport().width() * 0.10))  # 状态列 10%
            self.appointments_table.setColumnWidth(5, int(self.appointments_table.viewport().width() * 0.10))  # 费用列 10%
            self.appointments_table.setColumnWidth(6, int(self.appointments_table.viewport().width() * 0.15))  # 备注列 15%
            self.appointments_table.setColumnWidth(7, int(self.appointments_table.viewport().width() * 0.15))  # 操作列 15% 