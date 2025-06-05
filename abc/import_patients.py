import os
import pandas as pd
from datetime import datetime
import json

# 导入应用所需的模块
from init import db, app
from models import Patient

def format_treatment_items(items):
    """格式化诊疗项目为字符串形式"""
    if not isinstance(items, str) or not items:
        return ""
    return items.strip()

def format_dental_condition(condition):
    """格式化牙齿状况为JSON格式"""
    if not isinstance(condition, str) or not condition:
        return "{}"
    
    # 尝试将文本格式化为JSON结构
    try:
        # 简单的格式检测
        if condition.startswith("{") and condition.endswith("}"):
            # 尝试解析已有的JSON
            return condition
        
        # 如果是文本描述，创建一个简单的结构
        lines = condition.strip().split("\n")
        result = {}
        
        for i, line in enumerate(lines):
            if "日期" in line:
                date_key = f"date-{i//5}"  # 粗略估计每5行为一组数据
                date_value = line.split(":", 1)[1].strip() if ":" in line else line.strip()
                result[date_key] = date_value
            elif "图表" in line:
                chart_num = line[2]  # 提取图表编号
                pos_map = {"左上": "top-left", "右上": "top-right", "左下": "bottom-left", "右下": "bottom-right"}
                for pos_cn, pos_en in pos_map.items():
                    if pos_cn in line:
                        row_idx = i//5
                        key = f"chart{chart_num}-{pos_en}-{row_idx}"
                        value = line.split(":", 1)[1].strip() if ":" in line else ""
                        result[key] = value
        
        return json.dumps(result, ensure_ascii=False)
    except Exception as e:
        print(f"无法格式化牙齿状况: {e}")
        return "{}"

def import_patients_from_excel():
    """从Excel导入患者数据到数据库"""
    # Excel文件路径
    excel_file = os.path.join("config", "123.xls")
    
    # 检查文件是否存在
    if not os.path.exists(excel_file):
        print(f"文件不存在: {excel_file}")
        return False
    
    try:
        # 读取Excel文件
        print(f"正在从 {excel_file} 读取数据...")
        df = pd.read_excel(excel_file)
        
        # 检查读取的数据行数
        total_records = len(df)
        print(f"读取到 {total_records} 条记录")
        
        # 导入计数器
        imported_count = 0
        skipped_count = 0
        
        # 遍历每一行数据
        with app.app_context():
            for index, row in df.iterrows():
                try:
                    # 提取必要字段，处理缺失值
                    patient_id = str(row.get('ID', '')) if pd.notna(row.get('ID', '')) else None
                    # 病历号 - 确保是整数类型
                    medical_record_number = None
                    if pd.notna(row.get('病历号', '')):
                        try:
                            medical_record_number = int(str(row.get('病历号', '')).strip())
                        except:
                            print(f"警告：第 {index+1} 行的病历号 '{row.get('病历号', '')}' 不是有效的整数，将设为空")
                    
                    # 姓名
                    name = str(row.get('姓名', '')) if pd.notna(row.get('姓名', '')) else None
                    # 年龄
                    age = int(row.get('年龄', 0)) if pd.notna(row.get('年龄', 0)) else None
                    # 性别
                    gender = str(row.get('性别', '')) if pd.notna(row.get('性别', '')) else None
                    # 电话
                    phone = str(row.get('电话', '')) if pd.notna(row.get('电话', '')) else None
                    # 地址
                    address = str(row.get('地址', '')) if pd.notna(row.get('地址', '')) else None
                    # 身份证号
                    identification_number = str(row.get('身份证号', '')) if pd.notna(row.get('身份证号', '')) else None
                    # 医生
                    doctor = str(row.get('医生', '')) if pd.notna(row.get('医生', '')) else None
                    
                    # 初诊时间
                    first_visit_date = None
                    if pd.notna(row.get('初诊时间', None)):
                        # 尝试解析日期
                        if isinstance(row['初诊时间'], datetime):
                            first_visit_date = row['初诊时间']
                        else:
                            try:
                                # 尝试解析字符串日期
                                first_visit_date = datetime.strptime(str(row['初诊时间']), '%Y-%m-%d')
                            except:
                                print(f"无法解析初诊时间 '{row['初诊时间']}' 为日期，使用当前日期")
                                first_visit_date = datetime.now()
                    
                    # 牙齿状况
                    dental_condition = format_dental_condition(str(row.get('牙齿状况', ''))) if pd.notna(row.get('牙齿状况', '')) else "{}"
                    
                    # 诊疗费用项目
                    treatment_items = format_treatment_items(str(row.get('诊疗费用项目', ''))) if pd.notna(row.get('诊疗费用项目', '')) else ""
                    
                    # 总费用
                    total_cost = float(row.get('总费用', 0.0).replace('¥', '').replace(',', '')) if pd.notna(row.get('总费用', 0.0)) and isinstance(row.get('总费用', 0.0), str) else float(row.get('总费用', 0.0)) if pd.notna(row.get('总费用', 0.0)) else 0.0
                    
                    # 检查患者是否已存在（根据姓名和电话）
                    existing_patient = None
                    if medical_record_number is not None:
                        existing_patient = Patient.query.filter_by(medical_record_number=medical_record_number).first()
                    if not existing_patient and name and phone:
                        existing_patient = Patient.query.filter_by(name=name, phone=phone).first()
                    
                    if existing_patient:
                        print(f"患者已存在，跳过导入: {name} ({phone})")
                        skipped_count += 1
                        continue
                    
                    # 创建新患者记录
                    new_patient = Patient(
                        medical_record_number=medical_record_number,
                        name=name,
                        age=age,
                        gender=gender,
                        phone=phone,
                        address=address,
                        identification_number=identification_number,
                        doctor=doctor,
                        first_visit_date=first_visit_date,
                        dental_condition=dental_condition,
                        treatment_items=treatment_items,
                        total_cost=total_cost,
                        created_at=datetime.now(),
                        updated_at=datetime.now()
                    )
                    
                    # 添加到数据库
                    db.session.add(new_patient)
                    imported_count += 1
                    print(f"已导入患者 {index+1}/{total_records}: {name}")
                    
                except Exception as e:
                    print(f"导入第 {index+1} 行数据时出错: {e}")
                    skipped_count += 1
            
            # 提交所有更改
            db.session.commit()
        
        print(f"\n导入完成: 成功 {imported_count} 条，跳过 {skipped_count} 条")
        return True
        
    except Exception as e:
        print(f"导入过程中发生错误: {e}")
        return False

if __name__ == "__main__":
    print("开始导入患者数据...")
    import_patients_from_excel()
    print("导入过程完成。") 