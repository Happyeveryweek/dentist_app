import os
import sys
import subprocess
import traceback

def run_with_debug():
    """
    运行牙科诊所管理系统并捕获可能的错误
    """
    try:
        # 获取当前目录
        current_dir = os.path.dirname(os.path.abspath(__file__))
        # 构建exe路径
        exe_path = os.path.join(current_dir, 'dist', '牙科诊所管理系统', '牙科诊所管理系统.exe')
        
        print(f"正在运行: {exe_path}")
        print("如果程序闪退，将在下方显示错误信息...")
        
        # 检查文件是否存在
        if not os.path.exists(exe_path):
            print(f"错误: 可执行文件不存在: {exe_path}")
            return
            
        # 检查数据库文件
        db_path = os.path.join(current_dir, 'dist', '牙科诊所管理系统', '_internal', 'instance', 'dental_clinic.db')
        if not os.path.exists(db_path):
            print(f"警告: 数据库文件不存在: {db_path}")
        else:
            print(f"数据库文件存在: {db_path}")
            
        # 检查环境配置文件
        env_path = os.path.join(current_dir, 'dist', '牙科诊所管理系统', '_internal', '.env')
        if not os.path.exists(env_path):
            print(f"警告: 环境配置文件不存在: {env_path}")
        else:
            print(f"环境配置文件存在: {env_path}")
            with open(env_path, 'r') as f:
                env_content = f.read()
                print(f"环境配置内容:\n{env_content}")
        
        # 运行程序并捕获输出
        result = subprocess.run([exe_path], capture_output=True, text=True)
        
        # 显示输出和错误
        if result.stdout:
            print("标准输出:")
            print(result.stdout)
            
        if result.stderr:
            print("错误输出:")
            print(result.stderr)
            
        print(f"程序退出代码: {result.returncode}")
        
    except Exception as e:
        print(f"运行时发生错误: {e}")
        print("详细错误信息:")
        traceback.print_exc()

def fix_common_issues():
    """
    修复常见问题
    """
    try:
        current_dir = os.path.dirname(os.path.abspath(__file__))
        
        # 1. 确保.env文件存在且内容正确
        env_path = os.path.join(current_dir, 'dist', '牙科诊所管理系统', '_internal', '.env')
        if not os.path.exists(env_path):
            print("正在创建.env文件...")
            with open(env_path, 'w') as f:
                f.write("DATABASE_URL=sqlite:///instance/dental_clinic.db\nSECRET_KEY=your_secret_key_here")
            print(".env文件已创建")
        else:
            # 修正.env文件中的数据库路径
            with open(env_path, 'r') as f:
                env_content = f.read()
            
            if 'sqlite:///dental_clinic.db' in env_content:
                print("正在修正.env文件中的数据库路径...")
                env_content = env_content.replace('sqlite:///dental_clinic.db', 'sqlite:///instance/dental_clinic.db')
                with open(env_path, 'w') as f:
                    f.write(env_content)
                print(".env文件已修正")
        
        # 2. 确保instance目录存在
        instance_dir = os.path.join(current_dir, 'dist', '牙科诊所管理系统', '_internal', 'instance')
        if not os.path.exists(instance_dir):
            print("正在创建instance目录...")
            os.makedirs(instance_dir, exist_ok=True)
            print("instance目录已创建")
        
        # 3. 如果数据库文件不存在，复制一个空的数据库文件
        db_path = os.path.join(instance_dir, 'dental_clinic.db')
        if not os.path.exists(db_path):
            print("数据库文件不存在，正在从源目录复制...")
            src_db_path = os.path.join(current_dir, 'instance', 'dental_clinic.db')
            if os.path.exists(src_db_path):
                import shutil
                shutil.copy2(src_db_path, db_path)
                print(f"数据库文件已从 {src_db_path} 复制到 {db_path}")
            else:
                print(f"源数据库文件不存在: {src_db_path}")
                print("正在创建空数据库文件...")
                # 创建一个空的SQLite数据库文件
                import sqlite3
                conn = sqlite3.connect(db_path)
                conn.close()
                print("空数据库文件已创建")
        
        print("常见问题修复完成，请再次运行程序")
        
    except Exception as e:
        print(f"修复过程中发生错误: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    print("牙科诊所管理系统调试工具")
    print("="*50)
    
    while True:
        print("\n请选择操作:")
        print("1. 运行程序并捕获错误")
        print("2. 尝试修复常见问题")
        print("3. 退出")
        
        choice = input("请输入选项(1-3): ")
        
        if choice == "1":
            run_with_debug()
        elif choice == "2":
            fix_common_issues()
        elif choice == "3":
            print("退出程序")
            break
        else:
            print("无效选项，请重新输入")