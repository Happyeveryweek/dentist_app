#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
SQLite到MySQL患者数据同步脚本
将患者数据从SQLite数据库同步到MySQL数据库
"""

import os
import sys
import sqlite3
import pymysql
import json
import datetime
from pathlib import Path
import configparser
import logging

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

def create_default_config():
    """创建默认配置文件"""
    config = configparser.ConfigParser()
    
    config['sqlite'] = {
        'path': SQLITE_DATABASE_PATH,
    }
    
    config['mysql'] = {
        'host': MYSQL_HOST,
        'port': str(MYSQL_PORT),
        'user': MYSQL_USER,
        'password': MYSQL_PASSWORD,
        'database': MYSQL_DATABASE
    }
    
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        config.write(f)
    
    logger.info(f"已创建默认配置文件: {CONFIG_FILE}")
    logger.info("请编辑配置文件，设置正确的数据库连接信息")

def load_config():
    """加载配置文件"""
    if not os.path.exists(CONFIG_FILE):
        create_default_config()
        sys.exit(1)
    
    config = configparser.ConfigParser()
    config.read(CONFIG_FILE, encoding='utf-8')
    return config

def get_sqlite_connection(db_path):
    """连接到SQLite数据库"""
    try:
        if not os.path.exists(db_path):
            logger.error(f"SQLite数据库文件不存在: {db_path}")
            return None
        
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
            charset='utf8mb4'
        )
        logger.info(f"已连接到MySQL数据库: {database}")
        return conn
    except Exception as e:
        logger.error(f"连接MySQL数据库失败: {e}")
        return None

def get_patient_table_structure(sqlite_conn):
    """获取SQLite数据库中patients表的结构"""
    cursor = sqlite_conn.cursor()
    cursor.execute("PRAGMA table_info(patients)")
    columns = cursor.fetchall()
    return columns

def check_mysql_table_exists(mysql_conn):
    """检查MySQL中是否存在patients表"""
    cursor = mysql_conn.cursor()
    cursor.execute("SHOW TABLES LIKE 'patients'")
    return cursor.fetchone() is not None

def create_mysql_table(mysql_conn, sqlite_columns):
    """在MySQL中创建patients表"""
    # SQLite类型到MySQL类型的映射
    type_mapping = {
        'INTEGER': 'INT',
        'REAL': 'DOUBLE',
        'TEXT': 'TEXT',
        'BLOB': 'BLOB',
        'NULL': 'NULL',
        'DATETIME': 'DATETIME',
        'FLOAT': 'FLOAT'
    }
    
    # 创建表的SQL语句
    create_table_sql = "CREATE TABLE IF NOT EXISTS patients (\n"
    
    # 添加列定义
    for i, col in enumerate(sqlite_columns):
        name = col['name']
        type_name = col['type'].upper()
        mysql_type = type_mapping.get(type_name, 'TEXT')
        
        # 处理主键
        if col['pk'] == 1:
            create_table_sql += f"  {name} {mysql_type} PRIMARY KEY"
            # 如果是自增主键
            if name.lower() == 'id':
                create_table_sql += " AUTO_INCREMENT"
        else:
            nullable = "NULL" if col['notnull'] == 0 else "NOT NULL"
            create_table_sql += f"  {name} {mysql_type} {nullable}"
        
        # 如果不是最后一列，添加逗号
        if i < len(sqlite_columns) - 1:
            create_table_sql += ",\n"
    
    create_table_sql += "\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
    
    try:
        cursor = mysql_conn.cursor()
        cursor.execute(create_table_sql)
        mysql_conn.commit()
        logger.info("已在MySQL中创建patients表")
        return True
    except Exception as e:
        logger.error(f"创建MySQL表失败: {e}")
        logger.debug(f"SQL语句: {create_table_sql}")
        return False

def truncate_mysql_table(mysql_conn):
    """清空MySQL中的patients表"""
    try:
        cursor = mysql_conn.cursor()
        cursor.execute("TRUNCATE TABLE patients")
        mysql_conn.commit()
        logger.info("已清空MySQL中的patients表")
        return True
    except Exception as e:
        logger.error(f"清空MySQL表失败: {e}")
        return False

def serialize_datetime(obj):
    """序列化datetime对象为字符串"""
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")

def get_patients_from_sqlite(sqlite_conn):
    """从SQLite中获取所有患者数据"""
    cursor = sqlite_conn.cursor()
    cursor.execute("SELECT * FROM patients")
    patients = cursor.fetchall()
    logger.info(f"从SQLite中获取了 {len(patients)} 条患者记录")
    return patients

def insert_patients_to_mysql(mysql_conn, patients, sqlite_columns):
    """将患者数据插入到MySQL"""
    if not patients:
        logger.warning("没有患者数据需要同步")
        return True
    
    # 获取列名
    column_names = [col['name'] for col in sqlite_columns]
    
    # 构建INSERT语句
    placeholders = ", ".join(["%s"] * len(column_names))
    columns_str = ", ".join(column_names)
    insert_sql = f"INSERT INTO patients ({columns_str}) VALUES ({placeholders})"
    
    cursor = mysql_conn.cursor()
    
    try:
        # 批量插入数据
        for patient in patients:
            # 将Row对象转换为元组，处理datetime类型
            patient_data = []
            for col in column_names:
                val = patient[col]
                if isinstance(val, (datetime.datetime, datetime.date)):
                    val = val.isoformat()
                patient_data.append(val)
            
            cursor.execute(insert_sql, patient_data)
        
        mysql_conn.commit()
        logger.info(f"已成功同步 {len(patients)} 条患者记录到MySQL")
        return True
    except Exception as e:
        mysql_conn.rollback()
        logger.error(f"插入患者数据到MySQL失败: {e}")
        return False

def find_sqlite_db_path(sqlite_path):
    """查找SQLite数据库文件的路径"""
    # 如果是绝对路径，直接使用
    if os.path.isabs(sqlite_path):
        if os.path.exists(sqlite_path):
            return sqlite_path
        else:
            logger.error(f"SQLite数据库文件不存在: {sqlite_path}")
            return None
    
    # 如果是相对路径，尝试查找
    # 首先检查当前目录
    if os.path.exists(sqlite_path):
        return os.path.abspath(sqlite_path)
    
    # 然后检查instance目录
    instance_path = os.path.join('instance', sqlite_path)
    if os.path.exists(instance_path):
        return os.path.abspath(instance_path)
    
    # 如果都找不到，返回None
    logger.error(f"找不到SQLite数据库文件: {sqlite_path}")
    return None

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
    
    # 查找SQLite数据库文件
    sqlite_db_path = find_sqlite_db_path(sqlite_path)
    if not sqlite_db_path:
        return False
    
    # 连接数据库
    sqlite_conn = get_sqlite_connection(sqlite_db_path)
    if not sqlite_conn:
        return False
    
    mysql_conn = get_mysql_connection(
        host=mysql_host,
        port=mysql_port,
        user=mysql_user,
        password=mysql_password,
        database=mysql_database
    )
    
    if not mysql_conn:
        sqlite_conn.close()
        return False
    
    try:
        # 获取SQLite表结构
        sqlite_columns = get_patient_table_structure(sqlite_conn)
        
        # 检查MySQL表是否存在，如不存在则创建
        table_exists = check_mysql_table_exists(mysql_conn)
        if not table_exists:
            if not create_mysql_table(mysql_conn, sqlite_columns):
                return False
        else:
            # 表存在则清空表
            if not truncate_mysql_table(mysql_conn):
                return False
        
        # 获取患者数据
        patients = get_patients_from_sqlite(sqlite_conn)
        
        # 插入数据到MySQL
        result = insert_patients_to_mysql(mysql_conn, patients, sqlite_columns)
        
        if result:
            logger.info("SQLite到MySQL同步完成！")
            return True
        else:
            logger.error("SQLite到MySQL同步失败！")
            return False
    
    finally:
        # 关闭连接
        if sqlite_conn:
            sqlite_conn.close()
        if mysql_conn:
            mysql_conn.close()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 