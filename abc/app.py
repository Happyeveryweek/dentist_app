import os
from flask import render_template, redirect, url_for, flash, request
from flask_login import login_user, login_required, logout_user, current_user
from datetime import datetime

# 从init.py导入Flask应用和扩展实例
from init import app, db, login_manager

# 导入模型
from models import User, Patient, Appointment

# 导入路由
from routes import register_routes

# 用户加载函数
@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# 注册路由
register_routes(app)

# 创建数据库表 - 使用with app.app_context()替代已弃用的before_first_request
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)