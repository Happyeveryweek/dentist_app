#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
MySQL到SQLite患者数据同步脚本
将患者数据从MySQL数据库同步到SQLite数据库
"""

import os
import sys
import sqlite3
import pymysql
import datetime
import configparser
import logging
from pathlib import Path

#=====================================================
# 用户配置区域 - 请在此处修改SQLite和MySQL的配置
#=====================================================

# SQLite数据库路径配置 - 请修改此路径指向您的SQLite数据库文件
# 路径示例:
# Windows系统:
#   - 相对路径: "data/dental_clinic.db" 或 "dental_clinic.db"
#   - 绝对路径: "C:/DentalClinic/data/dental_clinic.db" 或 "D:/Projects/DentalApp/dental_clinic.db"
# Linux/Mac系统:
#   - 相对路径: "data/dental_clinic.db" 或 "dental_clinic.db"
#   - 绝对路径: "/var/data/dental_clinic.db" 或 "/home/user/dental/dental_clinic.db"
SQLITE_DATABASE_PATH = "dental_clinic.db"  # 可以是相对路径或绝对路径

# MySQL数据库连接配置
MYSQL_HOST = "localhost"
MYSQL_PORT = 3306
MYSQL_USER = "root"
MYSQL_PASSWORD = "password"
MYSQL_DATABASE = "dental_clinic"

# 是否使用配置文件 (True/False)
# 如果设为True，将使用db_sync_config.ini中的设置
# 如果设为False，将使用上面的直接配置
USE_CONFIG_FILE = False  

#=====================================================
# 脚本配置结束
#=====================================================

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# 默认配置文件路径
CONFIG_FILE = "db_sync_config.ini"

def load_config():
    """加载配置文件"""
    if not os.path.exists(CONFIG_FILE):
        logger.error(f"配置文件不存在: {CONFIG_FILE}")
        logger.info("请先运行 sqlite_to_mysql.py 创建配置文件")
        sys.exit(1)
    
    config = configparser.ConfigParser()
    config.read(CONFIG_FILE, encoding='utf-8')
    return config

def get_sqlite_connection(db_path):
    """连接到SQLite数据库"""
    try:
        db_dir = os.path.dirname(db_path)
        if db_dir and not os.path.exists(db_dir):
            os.makedirs(db_dir)
        
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row  # 使查询结果可以通过列名访问
        logger.info(f"已连接到SQLite数据库: {db_path}")
        return conn
    except Exception as e:
        logger.error(f"连接SQLite数据库失败: {e}")
        return None

def get_mysql_connection(host, port, user, password, database):
    """连接到MySQL数据库，使用直接传入的参数"""
    try:
        conn = pymysql.connect(
            host=host,
            port=int(port),
            user=user,
            password=password,
            database=database,
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor  # 使查询结果以字典形式返回
        )
        logger.info(f"已连接到MySQL数据库: {database}")
        return conn
    except Exception as e:
        logger.error(f"连接MySQL数据库失败: {e}")
        return None

def check_tables_exist(mysql_conn, sqlite_conn):
    """检查两个数据库中是否都存在patients表"""
    # 检查MySQL表
    mysql_cursor = mysql_conn.cursor()
    mysql_cursor.execute("SHOW TABLES LIKE 'patients'")
    mysql_table_exists = mysql_cursor.fetchone() is not None
    
    if not mysql_table_exists:
        logger.error("MySQL中不存在patients表")
        return False
    
    # 检查SQLite表
    sqlite_cursor = sqlite_conn.cursor()
    sqlite_cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='patients'")
    sqlite_table_exists = sqlite_cursor.fetchone() is not None
    
    return mysql_table_exists and sqlite_table_exists

def get_mysql_table_structure(mysql_conn):
    """获取MySQL中patients表的结构"""
    cursor = mysql_conn.cursor()
    cursor.execute("DESCRIBE patients")
    columns = cursor.fetchall()
    return columns

def create_sqlite_table(sqlite_conn, mysql_columns):
    """在SQLite中创建patients表"""
    # MySQL类型到SQLite类型的映射
    type_mapping = {
        'INT': 'INTEGER',
        'TINYINT': 'INTEGER',
        'SMALLINT': 'INTEGER',
        'MEDIUMINT': 'INTEGER',
        'BIGINT': 'INTEGER',
        'FLOAT': 'REAL',
        'DOUBLE': 'REAL',
        'DECIMAL': 'REAL',
        'CHAR': 'TEXT',
        'VARCHAR': 'TEXT',
        'TEXT': 'TEXT',
        'LONGTEXT': 'TEXT',
        'BLOB': 'BLOB',
        'DATETIME': 'DATETIME',
        'DATE': 'DATE',
        'TIME': 'TEXT'
    }
    
    # 创建表的SQL语句
    create_table_sql = "CREATE TABLE IF NOT EXISTS patients (\n"
    
    # 添加列定义
    for i, col in enumerate(mysql_columns):
        field = col['Field']
        type_str = col['Type'].upper()
        
        # 提取基本类型（去除长度）
        base_type = type_str.split('(')[0]
        sqlite_type = type_mapping.get(base_type, 'TEXT')
        
        # 处理主键
        if col['Key'] == 'PRI':
            create_table_sql += f"  {field} {sqlite_type} PRIMARY KEY"
            # 如果是自增主键
            if col['Extra'] == 'auto_increment':
                create_table_sql += " AUTOINCREMENT"
        else:
            nullable = "" if col['Null'] == 'YES' else "NOT NULL"
            create_table_sql += f"  {field} {sqlite_type} {nullable}"
        
        # 如果不是最后一列，添加逗号
        if i < len(mysql_columns) - 1:
            create_table_sql += ",\n"
    
    create_table_sql += "\n);"
    
    try:
        cursor = sqlite_conn.cursor()
        cursor.execute("DROP TABLE IF EXISTS patients")
        cursor.execute(create_table_sql)
        sqlite_conn.commit()
        logger.info("已在SQLite中创建patients表")
        return True
    except Exception as e:
        logger.error(f"创建SQLite表失败: {e}")
        logger.debug(f"SQL语句: {create_table_sql}")
        return False

def get_patients_from_mysql(mysql_conn):
    """从MySQL中获取所有患者数据"""
    cursor = mysql_conn.cursor()
    cursor.execute("SELECT * FROM patients")
    patients = cursor.fetchall()
    logger.info(f"从MySQL中获取了 {len(patients)} 条患者记录")
    return patients

def convert_mysql_datetime(mysql_datetime):
    """将MySQL中的datetime转换为SQLite兼容格式"""
    if not mysql_datetime:
        return None
    
    if isinstance(mysql_datetime, (datetime.datetime, datetime.date)):
        return mysql_datetime.isoformat()
    
    # 如果是字符串，尝试解析成标准ISO格式
    if isinstance(mysql_datetime, str):
        try:
            date_obj = datetime.datetime.fromisoformat(mysql_datetime)
            return date_obj.isoformat()
        except ValueError:
            return mysql_datetime
    
    return str(mysql_datetime)

def insert_patients_to_sqlite(sqlite_conn, patients, mysql_columns):
    """将患者数据插入到SQLite"""
    if not patients:
        logger.warning("没有患者数据需要同步")
        return True
    
    # 获取列名
    column_names = [col['Field'] for col in mysql_columns]
    
    # 构建INSERT语句
    placeholders = ", ".join(["?"] * len(column_names))
    columns_str = ", ".join(column_names)
    insert_sql = f"INSERT INTO patients ({columns_str}) VALUES ({placeholders})"
    
    cursor = sqlite_conn.cursor()
    
    try:
        # 批量插入数据
        for patient in patients:
            # 处理数据类型
            patient_data = []
            for col in column_names:
                val = patient[col]
                # 特殊处理日期时间类型
                if isinstance(val, (datetime.datetime, datetime.date)) or (col.lower().endswith('_at') or col.lower().endswith('_date')):
                    val = convert_mysql_datetime(val)
                patient_data.append(val)
            
            cursor.execute(insert_sql, patient_data)
        
        sqlite_conn.commit()
        logger.info(f"已成功同步 {len(patients)} 条患者记录到SQLite")
        return True
    except Exception as e:
        sqlite_conn.rollback()
        logger.error(f"插入患者数据到SQLite失败: {e}")
        return False

def find_or_create_sqlite_path(sqlite_path):
    """确定SQLite数据库文件路径，如果需要则创建目录"""
    if os.path.isabs(sqlite_path):
        # 如果是绝对路径
        db_dir = os.path.dirname(sqlite_path)
        if db_dir and not os.path.exists(db_dir):
            try:
                os.makedirs(db_dir)
                logger.info(f"已创建目录: {db_dir}")
            except Exception as e:
                logger.error(f"创建目录失败: {e}")
                return None
        return sqlite_path
    else:
        # 如果是相对路径
        # 首先尝试当前目录
        if os.path.exists(sqlite_path):
            return os.path.abspath(sqlite_path)
            
        # 然后尝试在instance目录中
        if os.path.exists('instance'):
            instance_path = os.path.join('instance', sqlite_path)
            if os.path.exists(instance_path):
                return os.path.abspath(instance_path)
            else:
                # 如果instance目录存在但文件不存在，在instance中创建
                db_dir = os.path.dirname(instance_path)
                if db_dir and not os.path.exists(db_dir):
                    try:
                        os.makedirs(db_dir)
                    except Exception as e:
                        logger.error(f"创建目录失败: {e}")
                        return None
                return os.path.abspath(instance_path)
        
        # 如果都不存在，使用当前目录的相对路径
        db_dir = os.path.dirname(sqlite_path)
        if db_dir and not os.path.exists(db_dir):
            try:
                os.makedirs(db_dir)
            except Exception as e:
                logger.error(f"创建目录失败: {e}")
                return None
        return os.path.abspath(sqlite_path)

def main():
    """主函数"""
    # 根据配置方式确定数据库连接参数
    if USE_CONFIG_FILE:
        logger.info("使用配置文件中的连接信息")
        config = load_config()
        sqlite_path = config['sqlite']['path']
        mysql_host = config['mysql']['host']
        mysql_port = config['mysql']['port']
        mysql_user = config['mysql']['user']
        mysql_password = config['mysql']['password']
        mysql_database = config['mysql']['database']
    else:
        logger.info("使用脚本中直接配置的连接信息")
        sqlite_path = SQLITE_DATABASE_PATH
        mysql_host = MYSQL_HOST
        mysql_port = MYSQL_PORT
        mysql_user = MYSQL_USER
        mysql_password = MYSQL_PASSWORD
        mysql_database = MYSQL_DATABASE
    
    # 确定SQLite数据库路径
    sqlite_db_path = find_or_create_sqlite_path(sqlite_path)
    if not sqlite_db_path:
        logger.error("无法确定SQLite数据库路径")
        return False
    
    # 连接数据库
    mysql_conn = get_mysql_connection(
        host=mysql_host,
        port=mysql_port,
        user=mysql_user,
        password=mysql_password,
        database=mysql_database
    )
    
    if not mysql_conn:
        return False
    
    sqlite_conn = get_sqlite_connection(sqlite_db_path)
    if not sqlite_conn:
        mysql_conn.close()
        return False
    
    try:
        # 检查MySQL中是否存在patients表
        mysql_cursor = mysql_conn.cursor()
        mysql_cursor.execute("SHOW TABLES LIKE 'patients'")
        if not mysql_cursor.fetchone():
            logger.error(f"MySQL数据库 {mysql_database} 中不存在patients表")
            return False
        
        # 获取MySQL表结构
        mysql_columns = get_mysql_table_structure(mysql_conn)
        
        # 在SQLite中创建表（先删除再创建）
        if not create_sqlite_table(sqlite_conn, mysql_columns):
            return False
        
        # 获取患者数据
        patients = get_patients_from_mysql(mysql_conn)
        
        # 插入数据到SQLite
        result = insert_patients_to_sqlite(sqlite_conn, patients, mysql_columns)
        
        if result:
            logger.info("MySQL到SQLite同步完成！")
            return True
        else:
            logger.error("MySQL到SQLite同步失败！")
            return False
    
    finally:
        # 关闭连接
        if mysql_conn:
            mysql_conn.close()
        if sqlite_conn:
            sqlite_conn.close()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 