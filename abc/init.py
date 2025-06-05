from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from flask_migrate import Migrate
import os
import json
from dotenv import load_dotenv
import re
import configparser

# 加载环境变量
load_dotenv()

# 读取数据库配置
def load_db_config():
    # 首先尝试从config.ini读取配置
    config_ini = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'config.ini')
    default_db_url = os.getenv('DATABASE_URL', 'sqlite:///instance/dental_clinic.db')
    
    if os.path.exists(config_ini):
        try:
            config = configparser.ConfigParser()
            config.read(config_ini)
            
            if 'DATABASE' in config and 'type' in config['DATABASE']:
                db_type = config['DATABASE']['type']
                
                if db_type == 'sqlite' and 'SQLITE' in config:
                    # 处理SQLite配置
                    db_path = config['SQLITE'].get('path', 'instance/dental_clinic.db')
                    
                    # 构建SQLite连接URL
                    # 如果路径是相对路径，则使用instance目录
                    if not os.path.isabs(db_path):
                        db_url = f"sqlite:///{db_path}"
                    else:
                        db_url = f"sqlite:///{db_path}"
                    
                    print(f"使用SQLite数据库: {db_url}")
                    return db_url
                
                elif db_type == 'mysql' and 'MYSQL' in config:
                    # 处理MySQL配置
                    host = config['MYSQL'].get('host', 'localhost')
                    port = config['MYSQL'].get('port', '3306')
                    database = config['MYSQL'].get('database', 'dental_clinic')
                    username = config['MYSQL'].get('user', 'root')
                    password = config['MYSQL'].get('password', '')
                    
                    # 构建MySQL连接URL
                    db_url = f"mysql+pymysql://{username}:{password}@{host}:{port}/{database}"
                    print(f"使用MySQL数据库: mysql+pymysql://{username}:******@{host}:{port}/{database}")
                    return db_url
        except Exception as e:
            print(f"从config.ini加载数据库配置时出错: {str(e)}")
            print(f"将使用默认数据库配置: {default_db_url}")
    
    # 如果没有找到新的配置文件，尝试使用旧的配置方式
    legacy_config_file = "config/database_settings.json"
    if os.path.exists(legacy_config_file):
        try:
            with open(legacy_config_file, 'r') as f:
                # 尝试读取加密的配置文件
                try:
                    from cryptography.fernet import Fernet
                    key_file = "config/encryption.key"
                    if os.path.exists(key_file):
                        with open(key_file, "rb") as kf:
                            key = kf.read()
                        cipher = Fernet(key)
                        encrypted_data = f.read()
                        if encrypted_data:
                            decrypted_data = cipher.decrypt(encrypted_data.encode()).decode()
                            legacy_config = json.loads(decrypted_data)
                        else:
                            legacy_config = json.load(f)
                    else:
                        legacy_config = json.load(f)
                except Exception as e:
                    print(f"解密配置文件时出错，尝试直接读取: {str(e)}")
                    # 如果解密失败，尝试直接读取JSON
                    f.seek(0)  # 重置文件指针到开头
                    legacy_config = json.load(f)
            
            db_type = legacy_config.get('db_type', 'sqlite')
            
            if db_type == 'sqlite':
                # 处理SQLite配置
                sqlite_config = legacy_config.get('sqlite', {})
                db_path = sqlite_config.get('path', 'dental_clinic.db')
                
                # 构建SQLite连接URL
                # 如果路径是相对路径，则使用instance目录
                if not os.path.isabs(db_path):
                    db_url = f"sqlite:///{db_path}"
                else:
                    db_url = f"sqlite:///{db_path}"
                
                return db_url
            elif db_type == 'mysql':
                mysql_config = legacy_config.get('mysql', {})
                host = mysql_config.get('host', 'localhost')
                port = mysql_config.get('port', '3306')
                database = mysql_config.get('database', 'dental_clinic')
                username = mysql_config.get('username', 'root')
                
                # 处理加密的密码
                password = mysql_config.get('password', '')
                if password:
                    # 尝试从加密密钥文件解密密码
                    try:
                        from cryptography.fernet import Fernet
                        key_file = "config/encryption.key"
                        if os.path.exists(key_file):
                            with open(key_file, "rb") as f:
                                key = f.read()
                            cipher = Fernet(key)
                            password = cipher.decrypt(password.encode()).decode()
                    except Exception as e:
                        print(f"解密密码时出错: {str(e)}")
                
                # 构建MySQL连接URL
                db_url = f"mysql+pymysql://{username}:{password}@{host}:{port}/{database}"
                return db_url
        except Exception as e:
            print(f"加载旧数据库配置时出错: {str(e)}")
    
    # 如果没有配置文件或读取失败，使用默认配置
    print(f"未找到有效的数据库配置，使用默认配置: {default_db_url}")
    return default_db_url

# 创建Flask应用
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = load_db_config()
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['WTF_CSRF_ENABLED'] = False  # 禁用CSRF保护

# 初始化数据库
db = SQLAlchemy(app)
migrate = Migrate(app, db)

# 初始化登录管理器
login_manager = LoginManager(app)
login_manager.login_view = 'login'
login_manager.login_message = '请先登录'

# 注册自定义过滤器
@app.template_filter('nl2br')
def nl2br(value):
    if value:
        return value.replace('\n', '<br>')
    return value