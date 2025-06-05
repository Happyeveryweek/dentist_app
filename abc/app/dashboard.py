import sys
import os
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget,
                            QTableWidgetItem, QHeaderView, QFrame, QPushButton, QGridLayout,
                            QGraphicsDropShadowEffect)
from PyQt6.QtCore import Qt, QDate, QDateTime, QTimer, QEvent, QObject, QTime
from PyQt6.QtGui import QFont, QIcon, QColor
from datetime import datetime

# 导入数据库模型和初始化
from init import db, app
from models import User, Patient, Appointment, FollowUpVisit

# 从styles.py导入共享的样式和组件
from app.styles import Card, ACCENT_COLOR, TEXT_COLOR

class DashboardTab(QObject):
    """仪表盘选项卡类"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.dashboard_tab = QWidget()
        self.setup_dashboard_tab()
        
        # 连接窗口大小变化事件
        self.dashboard_tab.resizeEvent = self.on_dashboard_tab_resize
    
    def setup_dashboard_tab(self):
        """设置仪表盘选项卡"""
        layout = QVBoxLayout(self.dashboard_tab)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(20)
        
        # 统计卡片行
        stats_layout = QHBoxLayout()
        stats_layout.setSpacing(20)
        
        # 患者总数卡片
        patients_card = Card()
        patients_layout = QVBoxLayout(patients_card)
        patients_layout.setContentsMargins(15, 15, 15, 15)
        
        # 图标和标题行
        patients_header = QHBoxLayout()
        patients_header.setSpacing(10)
        patients_icon = QLabel("👤")
        patients_icon.setStyleSheet("font-size: 24px; color: #4a86e8;")
        patients_title = QLabel("患者总数")
        patients_title.setStyleSheet("font-size: 16px; font-weight: 500; color: #1d1d1f;")
        
        patients_header.addWidget(patients_icon)
        patients_header.addWidget(patients_title)
        patients_header.addStretch()
        
        self.total_patients_label = QLabel("1")
        self.total_patients_label.setStyleSheet("font-size: 32px; font-weight: bold; color: #1d1d1f; margin: 15px 0;")
        self.total_patients_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        patients_detail_btn = QPushButton("查看患者档案")
        patients_detail_btn.setStyleSheet("""
            QPushButton {
                border: none;
                color: #4a86e8;
                font-size: 14px;
                padding: 5px 0;
                text-align: center;
            }
            QPushButton:hover {
                text-decoration: underline;
            }
        """)
        patients_detail_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        patients_detail_btn.clicked.connect(lambda: self.parent.switch_tab(1) if self.parent else None)  # 跳转到患者管理页面
        
        patients_layout.addLayout(patients_header)
        patients_layout.addWidget(self.total_patients_label)
        patients_layout.addWidget(patients_detail_btn)
        
        # 预约总数卡片
        appointments_card = Card()
        appointments_layout = QVBoxLayout(appointments_card)
        appointments_layout.setContentsMargins(15, 15, 15, 15)
        
        # 图标和标题行
        appointments_header = QHBoxLayout()
        appointments_header.setSpacing(10)
        appointments_icon = QLabel("📅")
        appointments_icon.setStyleSheet("font-size: 24px; color: #4a86e8;")
        appointments_title = QLabel("预约总数")
        appointments_title.setStyleSheet("font-size: 16px; font-weight: 500; color: #1d1d1f;")
        
        appointments_header.addWidget(appointments_icon)
        appointments_header.addWidget(appointments_title)
        appointments_header.addStretch()
        
        self.total_appointments_label = QLabel("1")
        self.total_appointments_label.setStyleSheet("font-size: 32px; font-weight: bold; color: #1d1d1f; margin: 15px 0;")
        self.total_appointments_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        appointments_detail_btn = QPushButton("查看所有预约")
        appointments_detail_btn.setStyleSheet("""
            QPushButton {
                border: none;
                color: #4a86e8;
                font-size: 14px;
                padding: 5px 0;
                text-align: center;
            }
            QPushButton:hover {
                text-decoration: underline;
            }
        """)
        appointments_detail_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        appointments_detail_btn.clicked.connect(lambda: self.parent.switch_tab(2) if self.parent else None)  # 跳转到预约管理页面
        
        appointments_layout.addLayout(appointments_header)
        appointments_layout.addWidget(self.total_appointments_label)
        appointments_layout.addWidget(appointments_detail_btn)
        
        # 今日预约卡片
        today_card = Card()
        today_layout = QVBoxLayout(today_card)
        today_layout.setContentsMargins(15, 15, 15, 15)
        
        # 图标和标题行
        today_header = QHBoxLayout()
        today_header.setSpacing(10)
        today_icon = QLabel("📋")
        today_icon.setStyleSheet("font-size: 24px; color: #4a86e8;")
        today_title = QLabel("今日预约")
        today_title.setStyleSheet("font-size: 16px; font-weight: 500; color: #1d1d1f;")
        
        today_header.addWidget(today_icon)
        today_header.addWidget(today_title)
        today_header.addStretch()
        
        self.today_count_label = QLabel("1")
        self.today_count_label.setStyleSheet("font-size: 32px; font-weight: bold; color: #1d1d1f; margin: 15px 0;")
        self.today_count_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        today_layout.addLayout(today_header)
        today_layout.addWidget(self.today_count_label)
        
        # 添加一个空白占位元素，使今日预约卡片与其他卡片垂直对齐
        spacer_label = QLabel("")
        spacer_label.setFixedHeight(30)  # 与其他卡片按钮高度相似
        today_layout.addWidget(spacer_label)
        
        # 添加卡片到统计布局
        stats_layout.addWidget(patients_card)
        stats_layout.addWidget(appointments_card)
        stats_layout.addWidget(today_card)
        
        layout.addLayout(stats_layout)
        
        # 今日预约列表卡片
        today_frame = QFrame()
        today_frame.setFrameShape(QFrame.Shape.StyledPanel)
        # 设置样式，模拟Card的外观，但不设置padding
        today_frame.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 8px;
                border: 1px solid #e0e0e0;
            }
        """)
        
        # 添加阴影效果
        shadow = QGraphicsDropShadowEffect(today_frame)
        shadow.setBlurRadius(15)
        shadow.setColor(QColor(0, 0, 0, 30))
        shadow.setOffset(0, 2)
        today_frame.setGraphicsEffect(shadow)
        
        # 主布局 - 注意不设置内边距
        main_layout = QVBoxLayout(today_frame)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # 标题区域 - 独立设置内边距
        title_area = QWidget()
        title_area.setStyleSheet("background-color: white; border-top-left-radius: 8px; border-top-right-radius: 8px;")
        title_layout = QHBoxLayout(title_area)
        title_layout.setContentsMargins(15, 15, 15, 10)
        
        title_icon = QLabel("📆")
        title_icon.setStyleSheet("font-size: 24px; color: #4a86e8;")
        
        title_text = QLabel("今日预约列表")
        title_text.setStyleSheet("font-size: 18px; font-weight: bold; color: #1d1d1f;")
        
        title_layout.addWidget(title_icon)
        title_layout.addWidget(title_text)
        title_layout.addStretch()
        
        # 添加时间挂件
        self.clock_label = QLabel()
        self.clock_label.setStyleSheet("""
            font-family: 'SF Pro Display', 'Helvetica Neue', Arial, sans-serif;
            font-size: 14px; 
            font-weight: 500; 
            color: #4a86e8;
            background-color: #f8f9fa;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 8px 12px;
            min-width: 140px;
        """)
        self.update_clock()  # 初始设置时间
        title_layout.addWidget(self.clock_label)
        
        # 创建并启动时钟定时器
        self.clock_timer = QTimer(self)
        self.clock_timer.timeout.connect(self.update_clock)
        self.clock_timer.start(1000)  # 每秒更新一次
        
        # 添加分隔线
        separator = QFrame()
        separator.setFrameShape(QFrame.Shape.HLine)
        separator.setStyleSheet("background-color: #e0e0e0; max-height: 1px;")
        
        # 表格区域 - 不设置上边距
        self.today_appointments_table = QTableWidget()
        self.today_appointments_table.setContentsMargins(15, 0, 15, 15)
        self.today_appointments_table.setColumnCount(5)
        
        # 设置原生表头
        self.today_appointments_table.setHorizontalHeaderLabels(["时间", "患者", "预约类型", "备注", "操作"])
        self.today_appointments_table.horizontalHeader().setVisible(True)
        self.today_appointments_table.horizontalHeader().setStyleSheet("""
            QHeaderView::section {
                background-color: #f8f8fa;
                padding: 10px 5px;
                border: none;
                border-bottom: 2px solid #e0e0e0;
                font-weight: bold;
                color: #1d1d1f;
                font-size: 14px;
                text-align: center;
            }
        """)
        
        # 基本表格设置
        self.today_appointments_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.today_appointments_table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.today_appointments_table.setSelectionMode(QTableWidget.SelectionMode.SingleSelection)
        self.today_appointments_table.setAlternatingRowColors(True)
        self.today_appointments_table.verticalHeader().setVisible(False)
        self.today_appointments_table.setShowGrid(True)
        self.today_appointments_table.setMinimumHeight(300)
        self.today_appointments_table.setFrameStyle(QFrame.Shape.NoFrame)
        self.today_appointments_table.horizontalHeader().setHighlightSections(False)
        
        # 点击空白区域清除选中状态
        self.today_appointments_table.viewport().installEventFilter(self)
        
        # 确保表头高度足够
        self.today_appointments_table.horizontalHeader().setFixedHeight(45)
        
        # 设置列宽
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)  # 时间列自适应内容
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)  # 患者名称可伸展
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)  # 治疗类型可伸展
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)  # 备注可伸展
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed)  # 操作列固定宽度
        self.today_appointments_table.setColumnWidth(4, 120)  # 设置操作列宽度
        
        # 表格样式
        self.today_appointments_table.setStyleSheet("""
            QTableWidget {
                border: none;
                background-color: white;
                gridline-color: #f0f0f0;
                alternate-background-color: #f9f9f9;
                selection-background-color: #f2f9ff;
                selection-color: #1d1d1f;
            }
            QTableWidget::item {
                padding: 10px 5px;
                border-bottom: 1px solid #f0f0f0;
                text-align: center;
            }
            QScrollBar:vertical {
                border: none;
                background: #f0f0f0;
                width: 8px;
                margin: 0px;
            }
            QScrollBar::handle:vertical {
                background: #c0c0c0;
                min-height: 20px;
                border-radius: 4px;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                border: none;
                background: none;
                height: 0px;
            }
        """)
        
        # 设置滚动条
        self.today_appointments_table.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.today_appointments_table.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        
        # 设置行高
        self.today_appointments_table.verticalHeader().setDefaultSectionSize(50)
        
        # 组装布局
        main_layout.addWidget(title_area)
        main_layout.addWidget(separator)
        
        # 创建表格容器以控制内边距
        table_container = QWidget()
        table_container_layout = QVBoxLayout(table_container)
        table_container_layout.setContentsMargins(15, 15, 15, 15)
        table_container_layout.addWidget(self.today_appointments_table)
        
        main_layout.addWidget(table_container)
        
        # 添加到主布局
        layout.addWidget(today_frame)
        
        # 加载仪表盘数据
        self.refresh_dashboard()
    
    def refresh_dashboard(self):
        """刷新仪表板数据"""
        try:
            with app.app_context():
                # 获取今日预约数
                today = datetime.now().date()
                today_appointments = Appointment.query.filter(
                    Appointment.appointment_date >= today,
                    Appointment.appointment_date < today.replace(day=today.day + 1)
                ).all()
                self.today_count_label.setText(str(len(today_appointments)))
                
                # 获取总患者数
                total_patients = Patient.query.count()
                self.total_patients_label.setText(str(total_patients))
                
                # 获取预约总数
                total_appointments = Appointment.query.count()
                self.total_appointments_label.setText(str(total_appointments))
                
                # 更新今日预约表格
                self.today_appointments_table.setRowCount(len(today_appointments))
                for i, appointment in enumerate(today_appointments):
                    patient = db.session.get(Patient, appointment.patient_id)
                    
                    # 预约时间 - 美化时间显示
                    # 只显示小时:分钟，使用更优雅的格式
                    if hasattr(appointment, 'appointment_date') and appointment.appointment_date:
                        time_str = appointment.appointment_date.strftime("%H:%M")
                        # 创建自定义显示的时间项
                        time_item = QTableWidgetItem(time_str)
                        time_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                        # 设置字体加粗
                        font = time_item.font()
                        font.setBold(True)
                        time_item.setFont(font)
                        # 设置文本颜色为深蓝色
                        time_item.setForeground(QColor("#2b5797"))
                    else:
                        time_item = QTableWidgetItem("未设置")
                        time_item.setForeground(QColor("#999999"))
                        time_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    
                    self.today_appointments_table.setItem(i, 0, time_item)
                    
                    # 患者姓名
                    patient_name = patient.name if patient else "未知患者"
                    patient_item = QTableWidgetItem(patient_name)
                    patient_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    patient_item.setData(Qt.ItemDataRole.UserRole, appointment.id)  # 存储预约ID
                    self.today_appointments_table.setItem(i, 1, patient_item)
                    
                    # 预约类型
                    treatment_type = appointment.treatment_type or "未指定"
                    treatment_item = QTableWidgetItem(treatment_type)
                    treatment_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.today_appointments_table.setItem(i, 2, treatment_item)
                    
                    # 备注
                    notes = appointment.notes or ""
                    notes_item = QTableWidgetItem(notes)
                    notes_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    self.today_appointments_table.setItem(i, 3, notes_item)
                    
                    # 操作按钮
                    btn_cell = QWidget()
                    btn_cell.setStyleSheet("background-color: transparent;")
                    btn_layout = QHBoxLayout(btn_cell)
                    btn_layout.setContentsMargins(5, 0, 5, 0)  # 减小上下边距
                    btn_layout.setSpacing(10)  # 减小按钮间距
                    btn_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)  # 居中对齐
                    
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
                            padding: 3px;
                            border-radius: 3px;
                            min-width: 24px;
                            max-width: 24px;
                            min-height: 24px;
                            max-height: 24px;
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
                    
                    # 连接查看预约详情的信号
                    view_btn.clicked.connect(lambda _, aid=appointment.id: 
                                           self.parent.view_appointment(aid) if self.parent else None)
                    
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
                            padding: 3px;
                            border-radius: 3px;
                            min-width: 24px;
                            max-width: 24px;
                            min-height: 24px;
                            max-height: 24px;
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
                    
                    # 连接编辑预约的信号
                    edit_btn.clicked.connect(lambda _, aid=appointment.id: 
                                          self.parent.edit_appointment(aid) if self.parent else None)
                    
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
                            padding: 3px;
                            border-radius: 3px;
                            min-width: 24px;
                            max-width: 24px;
                            min-height: 24px;
                            max-height: 24px;
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
                    
                    # 连接删除预约的信号
                    delete_btn.clicked.connect(lambda _, aid=appointment.id: 
                                            self.parent.delete_appointment(aid) if self.parent else None)
                    
                    btn_layout.addWidget(view_btn)
                    btn_layout.addWidget(edit_btn)
                    btn_layout.addWidget(delete_btn)
                    
                    self.today_appointments_table.setCellWidget(i, 4, btn_cell)
                
                # 调整表格列宽
                self.adjust_today_appointments_table()
                
        except Exception as e:
            from PyQt6.QtWidgets import QMessageBox
            QMessageBox.critical(None, "错误", f"刷新仪表板时出错: {e}")
            print(f"刷新仪表板时出错: {e}")
    
    def adjust_today_appointments_table(self, event=None):
        """调整今日预约表格的大小"""
        if not hasattr(self, 'today_appointments_table'):
            return
            
        # 设置行高
        self.today_appointments_table.verticalHeader().setDefaultSectionSize(45)
        
        # 重新应用列宽设置 - 确保表头显示正常
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Interactive)  # 先重置所有列
        
        # 然后应用具体的列宽设置
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)  # 时间列自适应内容
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)  # 患者名称可伸展
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)  # 治疗类型可伸展
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)  # 备注可伸展
        self.today_appointments_table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed)  # 操作列固定宽度
        self.today_appointments_table.setColumnWidth(4, 120)  # 设置操作列宽度
        
        # 确保表头高度设置正确
        self.today_appointments_table.horizontalHeader().setFixedHeight(45)
    
    def eventFilter(self, source, event):
        """实现事件过滤器，处理点击空白区域取消选中的功能"""
        try:
            # 检查对象是否仍然有效，防止访问已删除的对象
            if (hasattr(self, 'today_appointments_table') and 
                    self.today_appointments_table and 
                    not self.today_appointments_table.isDestroyed() if hasattr(self.today_appointments_table, 'isDestroyed') else True and
                    source is self.today_appointments_table.viewport() and 
                    event.type() == QEvent.Type.MouseButtonPress):
                # 获取点击位置的项
                item = self.today_appointments_table.itemAt(event.position().toPoint())
                # 如果点击的是空白区域（没有项）
                if item is None:
                    # 清除所有选中
                    self.today_appointments_table.clearSelection()
        except RuntimeError:
            # 对象可能已被删除，静默忽略错误
            pass
        except Exception as e:
            # 记录其他类型的错误但不中断程序
            print(f"事件过滤器错误: {e}")
        
        # 继续处理其他事件
        return super().eventFilter(source, event) if hasattr(super(), 'eventFilter') else False

    def on_dashboard_tab_resize(self, event):
        """响应窗口大小变化，调整表格"""
        if hasattr(self, 'today_appointments_table'):
            self.adjust_today_appointments_table()
        
        # 调用原始的resizeEvent
        if event:
            QWidget.resizeEvent(self.dashboard_tab, event) 
    
    def update_clock(self):
        """更新时钟显示"""
        current_time = QTime.currentTime()
        time_text = current_time.toString("HH:mm:ss")
        current_date = QDate.currentDate()
        date_text = current_date.toString("yyyy-MM-dd")
        
        # 使用HTML格式化文本，调整视觉效果
        formatted_text = f"""
        <div style='text-align: center;'>
            <span style='color: #444444; font-size: 16px; font-weight: 600;'>{date_text}</span><br>
            <span style='color: #4a86e8; font-size: 15px; font-weight: 600;'>{time_text}</span>
        </div>
        """
        self.clock_label.setText(formatted_text)