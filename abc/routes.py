from flask import render_template, redirect, url_for, flash, request, jsonify, make_response, send_file
from flask_login import login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from models import User, Patient, Appointment, FollowUpVisit
from init import db
from datetime import datetime
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField, SelectField, DateField, TextAreaField, FloatField, IntegerField, FieldList, FormField
from wtforms.validators import DataRequired, Email, Length, ValidationError
from wtforms.fields import DateTimeField
import pandas as pd
import io
import os
from tempfile import NamedTemporaryFile
import json
import configparser

# 表单类定义
class LoginForm(FlaskForm):
    username = StringField('用户名', validators=[DataRequired()])
    password = PasswordField('密码', validators=[DataRequired()])
    submit = SubmitField('登录')

class RegistrationForm(FlaskForm):
    username = StringField('用户名', validators=[DataRequired(), Length(min=2, max=20)])
    email = StringField('邮箱', validators=[DataRequired(), Email()])
    password = PasswordField('密码', validators=[DataRequired(), Length(min=6)])
    role = SelectField('角色', choices=[('admin', '管理员'), ('staff', '员工')], validators=[DataRequired()])
    submit = SubmitField('注册')
    
    def validate_username(self, username):
        user = User.query.filter_by(username=username.data).first()
        if user:
            raise ValidationError('该用户名已被使用，请选择其他用户名')
    
    def validate_email(self, email):
        user = User.query.filter_by(email=email.data).first()
        if user:
            raise ValidationError('该邮箱已被注册，请使用其他邮箱')

class FollowUpVisitForm(FlaskForm):
    follow_up_date = DateField('复诊日期', format='%Y-%m-%d', validators=[DataRequired()])
    notes = TextAreaField('备注')

class PatientForm(FlaskForm):
    medical_record_number = IntegerField('病历号')
    identification_number = StringField('身份证号')
    name = StringField('姓名', validators=[DataRequired()])
    age = IntegerField('年龄', validators=[DataRequired()])
    gender = SelectField('性别', choices=[('男', '男'), ('女', '女')], validators=[DataRequired()])
    phone = StringField('电话', validators=[DataRequired()])
    address = StringField('地址')
    doctor = StringField('主治医生')
    first_visit_date = DateField('初诊时间', format='%Y-%m-%d', validators=[DataRequired()])
    dental_condition = TextAreaField('牙齿状况')
    treatment_items = TextAreaField('诊疗费用项目')
    follow_up_visits = FieldList(FormField(FollowUpVisitForm), min_entries=1, max_entries=10)
    submit = SubmitField('保存')

class AppointmentForm(FlaskForm):
    patient_id = SelectField('患者', coerce=int, validators=[DataRequired()])
    appointment_date = DateTimeField('预约日期时间', format='%Y-%m-%d %H:%M', validators=[DataRequired()])
    treatment_type = StringField('治疗类型')
    notes = TextAreaField('备注')
    cost = FloatField('费用', default=0.0)
    status = SelectField('状态', choices=[('scheduled', '已预约'), ('completed', '已完成'), ('cancelled', '已取消')], default='scheduled')
    submit = SubmitField('保存')

class SystemConfigForm(FlaskForm):
    db_type = SelectField('数据库类型', choices=[('sqlite', 'SQLite'), ('mysql', 'MySQL')], validators=[DataRequired()])
    
    # SQLite 配置
    sqlite_path = StringField('数据库文件路径')
    
    # MySQL 配置
    mysql_host = StringField('主机地址')
    mysql_port = StringField('端口')
    mysql_user = StringField('用户名')
    mysql_password = PasswordField('密码')
    mysql_database = StringField('数据库名')
    
    submit = SubmitField('保存配置')

# 路由注册函数
def register_routes(app):
    
    @app.route('/')
    @app.route('/home')
    def home():
        if current_user.is_authenticated:
            return redirect(url_for('dashboard'))
        return render_template('home.html')
    
    @app.route('/login', methods=['GET', 'POST'])
    def login():
        if current_user.is_authenticated:
            return redirect(url_for('dashboard'))
        
        form = LoginForm()
        if form.validate_on_submit():
            user = User.query.filter_by(username=form.username.data).first()
            # 支持明文密码和哈希密码两种验证方式
            if user and (user.password == form.password.data or check_password_hash(user.password, form.password.data)):
                login_user(user)
                next_page = request.args.get('next')
                return redirect(next_page) if next_page else redirect(url_for('dashboard'))
            else:
                flash('登录失败，请检查用户名和密码', 'danger')
        
        return render_template('login.html', form=form)
    
    @app.route('/register', methods=['GET', 'POST'])
    def register():
        if current_user.is_authenticated:
            return redirect(url_for('dashboard'))
        
        form = RegistrationForm()
        if form.validate_on_submit():
            hashed_password = generate_password_hash(form.password.data)
            user = User(username=form.username.data, email=form.email.data, password=hashed_password, role=form.role.data)
            db.session.add(user)
            db.session.commit()
            flash('账号创建成功，现在可以登录了', 'success')
            return redirect(url_for('login'))
        
        return render_template('register.html', form=form)
    
    @app.route('/logout')
    @login_required
    def logout():
        logout_user()
        return redirect(url_for('home'))
    
    @app.route('/dashboard')
    @login_required
    def dashboard():
        # 获取今日预约
        today = datetime.now().date()
        today_appointments = Appointment.query.filter(
            db.func.date(Appointment.appointment_date) == today
        ).order_by(Appointment.appointment_date).all()
        
        # 获取患者总数
        patient_count = Patient.query.count()
        
        # 获取预约总数
        appointment_count = Appointment.query.count()
        
        return render_template('dashboard.html', 
                              today_appointments=today_appointments,
                              patient_count=patient_count,
                              appointment_count=appointment_count)
    
    # 患者管理路由
    @app.route('/patients')
    @login_required
    def patients():
        search = request.args.get('search', '')
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        query = Patient.query
        
        # 处理文本搜索
        if search:
            search_term = f'%{search}%'
            query = query.filter(
                db.or_(
                    Patient.name.like(search_term),
                    Patient.phone.like(search_term),
                    Patient.address.like(search_term),
                    Patient.medical_record_number.like(search_term),
                    Patient.identification_number.like(search_term)
                )
            )
        
        # 处理日期范围搜索
        if start_date:
            query = query.filter(Patient.first_visit_date >= datetime.strptime(start_date, '%Y-%m-%d'))
        if end_date:
            # 将结束日期加一天，以包含结束日期当天
            end_date = datetime.strptime(end_date, '%Y-%m-%d')
            query = query.filter(Patient.first_visit_date < end_date.replace(day=end_date.day+1))
        
        patients = query.all()
        return render_template('patients/index.html', patients=patients)
    
    @app.route('/patients/new', methods=['GET', 'POST'])
    @login_required
    def new_patient():
        form = PatientForm()
        if form.validate_on_submit():
            try:
                # 处理牙齿状况数据，确保是有效的JSON格式
                dental_condition = form.dental_condition.data
                if dental_condition:
                    try:
                        # 尝试解析JSON，如果成功则保持原样
                        import json
                        json.loads(dental_condition)
                    except:
                        # 如果不是有效的JSON，则尝试转换为JSON
                        dental_condition = json.dumps(dental_condition)
                
                patient = Patient(
                    name=form.name.data,
                    age=form.age.data,
                    gender=form.gender.data,
                    phone=form.phone.data,
                    address=form.address.data,
                    doctor=form.doctor.data,
                    first_visit_date=form.first_visit_date.data,
                    dental_condition=dental_condition,
                    treatment_items=form.treatment_items.data
                )
                db.session.add(patient)
                db.session.commit()
                
                # 添加复诊时间记录
                for follow_up_form in form.follow_up_visits.entries:
                    if follow_up_form.form.follow_up_date.data:
                        follow_up = FollowUpVisit(
                            patient_id=patient.id,
                            follow_up_date=follow_up_form.form.follow_up_date.data,
                            notes=follow_up_form.form.notes.data
                        )
                        db.session.add(follow_up)
                
                db.session.commit()
                flash('患者信息添加成功', 'success')
                return redirect(url_for('patients'))
            except Exception as e:
                db.session.rollback()
                flash(f'保存数据时发生错误：{str(e)}', 'danger')
        else:
            # 输出表单验证错误信息
            for field, errors in form.errors.items():
                for error in errors:
                    flash(f'{getattr(form, field).label.text}：{error}', 'danger')
        
        return render_template('patients/new.html', form=form, title='添加患者')
    
    @app.route('/patients/<int:patient_id>')
    @login_required
    def patient(patient_id):
        patient = Patient.query.get_or_404(patient_id)
        appointments = Appointment.query.filter_by(patient_id=patient_id).order_by(Appointment.appointment_date.desc()).all()
        
        # 处理牙齿状况数据，确保前端能够正确显示
        if patient.dental_condition:
            try:
                import json
                # 尝试解析JSON
                json.loads(patient.dental_condition)
            except:
                # 如果不是有效的JSON，则转换为JSON
                patient.dental_condition = json.dumps(patient.dental_condition)
        
        return render_template('patients/show.html', patient=patient, appointments=appointments)
    
    @app.route('/patients/<int:patient_id>/edit', methods=['GET', 'POST'])
    @login_required
    def edit_patient(patient_id):
        patient = Patient.query.get_or_404(patient_id)
        form = PatientForm()
        
        if form.validate_on_submit():
            try:
                # 处理牙齿状况数据，确保是有效的JSON格式
                dental_condition = form.dental_condition.data
                if dental_condition:
                    try:
                        # 尝试解析JSON，如果成功则保持原样
                        import json
                        json.loads(dental_condition)
                    except:
                        # 如果不是有效的JSON，则尝试转换为JSON
                        dental_condition = json.dumps(dental_condition)
                
                patient.name = form.name.data
                patient.age = form.age.data
                patient.gender = form.gender.data
                patient.phone = form.phone.data
                patient.address = form.address.data
                patient.doctor = form.doctor.data
                patient.first_visit_date = form.first_visit_date.data
                patient.dental_condition = dental_condition
                patient.treatment_items = form.treatment_items.data
                
                # 删除现有的复诊记录
                FollowUpVisit.query.filter_by(patient_id=patient.id).delete()
                
                # 添加新的复诊记录
                for follow_up_form in form.follow_up_visits.entries:
                    if follow_up_form.form.follow_up_date.data:
                        follow_up = FollowUpVisit(
                            patient_id=patient.id,
                            follow_up_date=follow_up_form.form.follow_up_date.data,
                            notes=follow_up_form.form.notes.data
                        )
                        db.session.add(follow_up)
                
                db.session.commit()
                flash('患者信息更新成功', 'success')
                return redirect(url_for('patient', patient_id=patient.id))
            except Exception as e:
                db.session.rollback()
                flash(f'保存数据时发生错误：{str(e)}', 'danger')
        
        elif request.method == 'GET':
            form.name.data = patient.name
            form.age.data = patient.age
            form.gender.data = patient.gender
            form.phone.data = patient.phone
            form.address.data = patient.address
            form.doctor.data = patient.doctor
            form.first_visit_date.data = patient.first_visit_date
            
            # 处理牙齿状况数据，确保前端能够正确显示
            if patient.dental_condition:
                try:
                    import json
                    # 尝试解析JSON
                    json.loads(patient.dental_condition)
                    form.dental_condition.data = patient.dental_condition
                except:
                    # 如果不是有效的JSON，则转换为JSON
                    form.dental_condition.data = json.dumps(patient.dental_condition)
            else:
                form.dental_condition.data = patient.dental_condition
                
            form.treatment_items.data = patient.treatment_items
            
            # 加载现有的复诊记录
            follow_ups = FollowUpVisit.query.filter_by(patient_id=patient.id).all()
            if follow_ups:
                # 清除默认的空表单
                while len(form.follow_up_visits) > 0:
                    form.follow_up_visits.pop_entry()
                
                # 添加现有的复诊记录
                for follow_up in follow_ups:
                    follow_up_form = FollowUpVisitForm()
                    follow_up_form.follow_up_date.data = follow_up.follow_up_date
                    follow_up_form.notes.data = follow_up.notes
                    form.follow_up_visits.append_entry(follow_up_form.data)
        
        return render_template('patients/edit.html', form=form, title='编辑患者信息')
    
    @app.route('/patients/<int:patient_id>/delete', methods=['POST'])
    @login_required
    def delete_patient(patient_id):
        try:
            patient = Patient.query.get_or_404(patient_id)
            db.session.delete(patient)
            db.session.commit()
            flash('患者已删除', 'success')
        except Exception as e:
            db.session.rollback()
            flash('删除患者失败，请确保没有关联的预约记录', 'danger')
        return redirect(url_for('patients'))
    
    # 预约管理路由
    @app.route('/appointments')
    @login_required
    def appointments():
        appointments = Appointment.query.order_by(Appointment.appointment_date.desc()).all()
        return render_template('appointments/index.html', appointments=appointments)
    
    @app.route('/appointments/new', methods=['GET', 'POST'])
    @login_required
    def new_appointment():
        form = AppointmentForm()
        # 获取所有患者作为下拉选项
        form.patient_id.choices = [(p.id, p.name) for p in Patient.query.all()]
        
        if form.validate_on_submit():
            appointment = Appointment(
                patient_id=form.patient_id.data,
                appointment_date=form.appointment_date.data,
                treatment_type=form.treatment_type.data,
                notes=form.notes.data,
                cost=form.cost.data,
                status=form.status.data
            )
            db.session.add(appointment)
            
            # 更新患者总费用
            patient = Patient.query.get(form.patient_id.data)
            patient.total_cost += form.cost.data
            
            db.session.commit()
            flash('预约添加成功', 'success')
            return redirect(url_for('appointments'))
        
        return render_template('appointments/new.html', form=form, title='添加预约')
    
    @app.route('/appointments/<int:appointment_id>')
    @login_required
    def appointment(appointment_id):
        appointment = Appointment.query.get_or_404(appointment_id)
        return render_template('appointments/show.html', appointment=appointment)
    
    @app.route('/appointments/<int:appointment_id>/edit', methods=['GET', 'POST'])
    @login_required
    def edit_appointment(appointment_id):
        appointment = Appointment.query.get_or_404(appointment_id)
        form = AppointmentForm()
        form.patient_id.choices = [(p.id, p.name) for p in Patient.query.all()]
        
        if form.validate_on_submit():
            # 如果费用有变化，更新患者总费用
            if appointment.cost != form.cost.data:
                patient = Patient.query.get(appointment.patient_id)
                patient.total_cost = patient.total_cost - appointment.cost + form.cost.data
            
            appointment.patient_id = form.patient_id.data
            appointment.appointment_date = form.appointment_date.data
            appointment.treatment_type = form.treatment_type.data
            appointment.notes = form.notes.data
            appointment.cost = form.cost.data
            appointment.status = form.status.data
            
            db.session.commit()
            flash('预约信息更新成功', 'success')
            return redirect(url_for('appointment', appointment_id=appointment.id))
        
        elif request.method == 'GET':
            form.patient_id.data = appointment.patient_id
            form.appointment_date.data = appointment.appointment_date
            form.treatment_type.data = appointment.treatment_type
            form.notes.data = appointment.notes
            form.cost.data = appointment.cost
            form.status.data = appointment.status
        
        return render_template('appointments/edit.html', form=form, title='编辑预约')
    
    @app.route('/appointments/<int:appointment_id>/delete', methods=['POST'])
    @login_required
    def delete_appointment(appointment_id):
        appointment = Appointment.query.get_or_404(appointment_id)
        
        # 更新患者总费用
        if appointment.cost > 0:
            patient = Patient.query.get(appointment.patient_id)
            patient.total_cost -= appointment.cost
        
        db.session.delete(appointment)
        db.session.commit()
        flash('预约已删除', 'success')
        return redirect(url_for('appointments'))

    @app.route('/patients/export', methods=['POST'])
    @login_required
    def export_patients():
        # 获取请求中的患者ID列表（如果有）
        selected_ids = request.form.getlist('patient_ids')
        export_all = request.form.get('export_all') == 'true'
        
        # 查询患者数据
        if export_all or not selected_ids:
            # 导出全部患者
            patients = Patient.query.all()
        else:
            # 导出选中的患者
            patient_ids = [int(id) for id in selected_ids]
            patients = Patient.query.filter(Patient.id.in_(patient_ids)).all()
        
        # 创建DataFrame
        data = []
        for patient in patients:
            # 格式化牙齿状况信息
            dental_condition_text = ""
            if patient.dental_condition:
                try:
                    dental_data = json.loads(patient.dental_condition)
                    
                    # 格式化输出
                    result_lines = []
                    
                    # 获取所有日期键并排序
                    date_keys = sorted([k for k in dental_data.keys() if k.startswith('date-')],
                                      key=lambda x: int(x.split('-')[1]))
                                      
                    # 遍历每个日期键
                    for date_key in date_keys:
                        # 获取行索引
                        row_idx = int(date_key.split('-')[1])
                        # 获取日期值
                        date_value = dental_data.get(date_key, "")
                        
                        # 添加日期行
                        result_lines.append(f"日期-{row_idx}: {date_value}")
                        
                        # 遍历十字图表数据
                        for chart_num in [1, 2]:
                            result_lines.append(f"  图表{chart_num}:")
                            
                            # 定义位置映射
                            position_map = {
                                "top-left": "左上",
                                "top-right": "右上",
                                "bottom-left": "左下",
                                "bottom-right": "右下"
                            }
                            
                            # 遍历四个位置
                            for pos, pos_cn in position_map.items():
                                # 构造键名
                                key = f"chart{chart_num}-{pos}-{row_idx}"
                                # 获取值
                                value = dental_data.get(key, "")
                                # 如果有值，添加到结果
                                if value:
                                    result_lines.append(f"    {pos_cn}-{row_idx}: {value}")
                    
                    # 合并所有行
                    dental_condition_text = "\n".join(result_lines)
                except Exception as e:
                    print(f"格式化牙齿状况时出错: {e}")
                    dental_condition_text = str(patient.dental_condition)  # 失败时返回原始数据
            
            data.append({
                'ID': patient.id,
                '病历号': patient.medical_record_number or '',
                '姓名': patient.name,
                '身份证号': patient.identification_number or '',
                '年龄': patient.age,
                '性别': patient.gender,
                '电话': patient.phone,
                '地址': patient.address or '',
                '主治医生': patient.doctor or '',
                '首次就诊': patient.first_visit_date.strftime('%Y-%m-%d'),
                '总费用': patient.total_cost,
                '牙齿状况': dental_condition_text
            })
        
        df = pd.DataFrame(data)
        
        # 创建临时文件
        with NamedTemporaryFile(delete=False, suffix='.xlsx') as tmp:
            # 写入Excel文件
            df.to_excel(tmp.name, index=False, engine='openpyxl')
            
            # 使用openpyxl调整Excel格式
            try:
                from openpyxl import load_workbook
                from openpyxl.styles import Alignment
                
                # 加载工作簿
                wb = load_workbook(tmp.name)
                ws = wb.active
                
                # 设置列宽和样式
                for col in ws.columns:
                    max_length = 0
                    column = col[0].column_letter  # 获取列字母
                    column_name = df.columns[col[0].column - 1]  # 获取列名
                    
                    # 牙齿状况列特殊处理
                    if column_name == "牙齿状况":
                        # 设置固定宽度
                        adjusted_width = 60
                        # 设置文本换行和垂直对齐
                        for cell in col:
                            if cell.row > 1:  # 跳过表头
                                cell.alignment = Alignment(wrap_text=True, vertical="top")
                    else:
                        # 计算其他列的宽度
                        for cell in col:
                            if cell.value:
                                max_length = max(max_length, len(str(cell.value)))
                        adjusted_width = (max_length + 2) * 1.2
                    
                    # 设置列宽
                    ws.column_dimensions[column].width = adjusted_width
                
                # 保存调整后的Excel
                wb.save(tmp.name)
            except Exception as e:
                print(f"调整Excel格式时出错: {str(e)}")
                
            tmp_path = tmp.name
        
        # 发送文件
        response = send_file(
            tmp_path,
            as_attachment=True,
            download_name=f'患者数据_{datetime.now().strftime("%Y%m%d%H%M%S")}.xlsx',
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
        
        # 设置回调以在请求完成后删除临时文件
        @response.call_on_close
        def remove_file():
            try:
                os.unlink(tmp_path)
            except:
                pass
                
        return response

    @app.route('/system-config', methods=['GET', 'POST'])
    @login_required
    def system_config():
        # 检查用户是否是管理员
        if current_user.role != 'admin':
            flash('您没有访问系统管理页面的权限', 'danger')
            return redirect(url_for('dashboard'))
        
        form = SystemConfigForm()
        config_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'config.ini')
        
        # 如果表单提交且验证通过
        if form.validate_on_submit():
            try:
                config = configparser.ConfigParser()
                
                # 数据库配置
                config['DATABASE'] = {
                    'type': form.db_type.data
                }
                
                if form.db_type.data == 'sqlite':
                    config['SQLITE'] = {
                        'path': form.sqlite_path.data
                    }
                else:  # MySQL
                    config['MYSQL'] = {
                        'host': form.mysql_host.data,
                        'port': form.mysql_port.data,
                        'user': form.mysql_user.data,
                        'password': form.mysql_password.data,
                        'database': form.mysql_database.data
                    }
                
                # 写入配置文件
                with open(config_file, 'w') as configfile:
                    config.write(configfile)
                
                flash('系统配置已保存。重启应用后生效。', 'success')
                return redirect(url_for('system_config'))
            
            except Exception as e:
                flash(f'保存配置时出错：{str(e)}', 'danger')
        
        # 如果是GET请求，从配置文件加载当前配置
        elif request.method == 'GET':
            if os.path.exists(config_file):
                config = configparser.ConfigParser()
                config.read(config_file)
                
                if 'DATABASE' in config and 'type' in config['DATABASE']:
                    form.db_type.data = config['DATABASE']['type']
                    
                    if form.db_type.data == 'sqlite' and 'SQLITE' in config:
                        form.sqlite_path.data = config['SQLITE'].get('path', '')
                    
                    elif form.db_type.data == 'mysql' and 'MYSQL' in config:
                        form.mysql_host.data = config['MYSQL'].get('host', '')
                        form.mysql_port.data = config['MYSQL'].get('port', '')
                        form.mysql_user.data = config['MYSQL'].get('user', '')
                        form.mysql_password.data = config['MYSQL'].get('password', '')
                        form.mysql_database.data = config['MYSQL'].get('database', '')
        
        return render_template('system_config.html', form=form, title='系统管理')