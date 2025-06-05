# 数据库同步工具

这个工具提供了两个Python脚本，用于在SQLite和MySQL数据库之间同步患者数据表。

## 功能特点

1. **双向同步**：
   - 从SQLite同步到MySQL（`sqlite_to_mysql.py`）
   - 从MySQL同步到SQLite（`mysql_to_sqlite.py`）

2. **自动表结构映射**：
   - 根据源数据库的表结构自动创建目标数据库的表
   - 智能类型转换，确保数据类型正确映射

3. **完整的错误处理**：
   - 详细的日志记录
   - 事务支持，确保数据一致性

4. **灵活的配置**：
   - 通过配置文件管理数据库连接参数
   - 支持自动寻找SQLite数据库文件

## 准备工作

### 安装依赖

运行以下命令安装必要的Python包：

```bash
pip install pymysql configparser
```

### MySQL准备

1. 确保您的MySQL服务器已运行
2. 创建用于同步的数据库：

```sql
CREATE DATABASE dental_clinic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

3. 创建具有适当权限的用户（可选）：

```sql
CREATE USER 'dental_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON dental_clinic.* TO 'dental_user'@'localhost';
FLUSH PRIVILEGES;
```

## 使用方法

### 第一步：配置

首次运行 `sqlite_to_mysql.py` 会创建配置文件 `db_sync_config.ini`。编辑该文件设置正确的数据库连接信息：

```ini
[sqlite]
path = dental_clinic.db

[mysql]
host = localhost
port = 3306
user = dental_user
password = your_password
database = dental_clinic
```

### 从SQLite同步到MySQL

```bash
python sqlite_to_mysql.py
```

这个脚本会：
1. 读取SQLite数据库中的患者表结构
2. 在MySQL中创建对应的表（如果不存在）或清空已有表
3. 将患者数据从SQLite复制到MySQL

### 从MySQL同步到SQLite

```bash
python mysql_to_sqlite.py
```

这个脚本会：
1. 读取MySQL数据库中的患者表结构
2. 在SQLite中重新创建患者表
3. 将患者数据从MySQL复制到SQLite

## 特别说明

- 这些脚本仅同步 `patients` 表，不会同步其他表
- 同步过程会替换目标数据库中的现有数据
- 首次使用请先运行 `sqlite_to_mysql.py` 创建配置文件

## 故障排除

### 找不到SQLite数据库文件

脚本会自动在以下位置查找SQLite数据库文件：
1. 配置文件中指定的路径
2. 当前目录
3. `instance` 子目录

如果仍然找不到，请确保在配置文件中提供正确的绝对路径。

### MySQL连接错误

确保：
1. MySQL服务器正在运行
2. 配置文件中的连接信息正确
3. 指定的用户有足够的权限
4. 指定的数据库已存在

## 数据安全

- 建议在执行同步前备份目标数据库
- 脚本使用事务处理，确保数据完整性
- 密码仅存储在本地配置文件中，不会上传到任何远程服务器 