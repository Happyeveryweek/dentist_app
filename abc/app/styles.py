from PyQt6.QtWidgets import QFrame, QPushButton, QLineEdit, QGraphicsDropShadowEffect, QComboBox, QListView
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QCursor, QPalette, QPainter, QBrush, QPen
from PyQt6.QtWidgets import QStyledItemDelegate, QStyle

# 全局样式变量
ACCENT_COLOR = "#4a86e8"  # 更柔和的蓝色
BACKGROUND_COLOR = "#f5f5f7"  # 浅灰色背景
CARD_BACKGROUND = "#ffffff"  # 卡片背景色
TEXT_COLOR = "#1d1d1f"  # 主文本颜色
SECONDARY_TEXT_COLOR = "#86868b"  # 次要文本颜色
BORDER_RADIUS = "8px"  # 边框圆角
BUTTON_HEIGHT = "36px"  # 按钮高度

# 自定义卡片组件
class Card(QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFrameShape(QFrame.Shape.StyledPanel)
        self.setStyleSheet(f"""
            background-color: {CARD_BACKGROUND};
            border-radius: {BORDER_RADIUS};
            border: none;
            padding: 15px;
        """)
        # 添加阴影效果
        self.setGraphicsEffect(self.create_shadow())
        # 移除默认布局，让布局由使用者控制
        
    def create_shadow(self):
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(15)
        shadow.setColor(QColor(0, 0, 0, 30))
        shadow.setOffset(0, 2)
        return shadow

# 自定义按钮样式
class PrimaryButton(QPushButton):
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: {ACCENT_COLOR};
                color: white;
                border: none;
                border-radius: {BORDER_RADIUS};
                padding: 10px 20px;
                font-weight: 600;
                font-size: 15px;
                min-width: 140px;
            }}
            QPushButton:hover {{
                background-color: #3a76d8;
            }}
            QPushButton:pressed {{
                background-color: #2a66c8;
            }}
        """)
        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))

class SecondaryButton(QPushButton):
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: transparent;
                color: {ACCENT_COLOR};
                border: 1px solid {ACCENT_COLOR};
                border-radius: {BORDER_RADIUS};
                padding: 10px 20px;
                font-weight: 600;
                font-size: 15px;
                min-width: 140px;
            }}
            QPushButton:hover {{
                background-color: rgba(74, 134, 232, 0.1);
            }}
            QPushButton:pressed {{
                background-color: rgba(74, 134, 232, 0.2);
            }}
        """)
        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))

# 自定义输入框样式
class StyledLineEdit(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet(f"""
            QLineEdit {{
                border: 1px solid #d1d1d6;
                border-radius: {BORDER_RADIUS};
                padding: 8px 12px;
                background-color: white;
                font-size: 14px;
                min-width: 250px;
            }}
            QLineEdit:focus {{
                border: 1px solid {ACCENT_COLOR};
            }}
        """)
        # 确保占位文本完全显示
        self.setAttribute(Qt.WidgetAttribute.WA_MacShowFocusRect, False)

# 自定义下拉框样式
class StyledComboBox(QComboBox):
    def __init__(self, parent=None):
        super().__init__(parent)
        # 基本ComboBox样式
        self.setStyleSheet(f"""
            QComboBox {{
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                padding: 8px 15px;
                background-color: white;
            }}
            QComboBox::drop-down {{
                border: none;
                width: 24px;
            }}
        """)
        
        # 修改下拉列表视图
        self.setView(QListView())
        self.view().window().setWindowFlags(Qt.WindowType.Popup | Qt.WindowType.FramelessWindowHint | Qt.WindowType.NoDropShadowWindowHint)
        self.view().window().setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        
        # 为视图设置代理样式表
        self.view().setItemDelegate(CustomItemDelegate(self.view()))
        
        # 使用固定方法确保样式被应用
        self.view().setStyleSheet("""
            QListView {
                outline: 0px;
                border: 1px solid #e0e0e0;
                border-radius: 4px;
                background-color: white;
            }
            QListView::item {
                height: 30px;
                padding-left: 10px;
                color: #333333;
            }
            QListView::item:hover {
                font-weight: bold;
                color: #000000;
                background-color: #d1e5ff;
            }
            QListView::item:selected {
                background-color: #f0f0f0;
                color: #333333;
            }
        """)
    
    def showPopup(self):
        # 显示弹出菜单前重新应用样式
        self.view().setStyleSheet(self.view().styleSheet())
        super().showPopup()

# 自定义委托，控制项目的渲染
class CustomItemDelegate(QStyledItemDelegate):
    def __init__(self, parent=None):
        super().__init__(parent)
        
    def paint(self, painter, option, index):
        # 自定义绘制逻辑
        if option.state & QStyle.StateFlag.State_MouseOver:
            # 鼠标悬停状态
            painter.save()
            painter.fillRect(option.rect, QBrush(QColor("#d1e5ff")))
            
            # 设置加粗字体
            font = painter.font()
            font.setBold(True)
            painter.setFont(font)
            
            painter.setPen(QPen(QColor("#000000")))
            painter.drawText(option.rect.adjusted(10, 0, -10, 0), Qt.AlignmentFlag.AlignVCenter, index.data())
            painter.restore()
        else:
            # 使用默认绘制
            super().paint(painter, option, index) 