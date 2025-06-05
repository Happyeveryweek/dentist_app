from flask_login import UserMixin
from datetime import datetime
from init import db

class User(db.Model, UserMixin):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.Text, nullable=False)
    role = db.Column(db.String(20), nullable=False, default='staff')  # admin, staff
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def __repr__(self):
        return f"User('{self.username}', '{self.email}', '{self.role}')"

class Patient(db.Model):
    __tablename__ = 'patients'
    id = db.Column(db.Integer, primary_key=True)
    medical_record_number = db.Column(db.Integer, nullable=True)  # 病历号
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    gender = db.Column(db.String(10), nullable=False)  # 男, 女
    phone = db.Column(db.String(100), nullable=False)
    address = db.Column(db.String(200), nullable=True)
    identification_number = db.Column(db.String(50), nullable=True)  # 身份证号
    doctor = db.Column(db.String(100), nullable=True)  # 主治医生
    first_visit_date = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    dental_condition = db.Column(db.Text, nullable=True)  # 牙齿治疗情况
    treatment_items = db.Column(db.Text, nullable=True)  # 诊疗费用项目
    total_cost = db.Column(db.Float, default=0.0)  # 总费用
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关联预约
    appointments = db.relationship('Appointment', backref='patient', lazy=True, cascade='all, delete-orphan')
    # 关联复诊时间
    follow_up_visits = db.relationship('FollowUpVisit', backref='patient', lazy=True, cascade='all, delete-orphan')

    def __repr__(self):
        return f"Patient('{self.name}', '{self.phone}')"

class Appointment(db.Model):
    __tablename__ = 'appointments'
    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'), nullable=False)
    appointment_date = db.Column(db.DateTime, nullable=False)
    status = db.Column(db.String(20), nullable=False, default='scheduled')  # scheduled, completed, cancelled
    treatment_type = db.Column(db.String(100), nullable=True)  # 治疗类型
    notes = db.Column(db.Text, nullable=True)  # 备注
    cost = db.Column(db.Float, default=0.0)  # 本次预约费用
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"Appointment(Patient ID: {self.patient_id}, Date: {self.appointment_date})"

class FollowUpVisit(db.Model):
    __tablename__ = 'follow_up_visits'
    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'), nullable=False)
    follow_up_date = db.Column(db.DateTime, nullable=False)
    notes = db.Column(db.Text, nullable=True)  # 备注
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"FollowUpVisit(Patient ID: {self.patient_id}, Date: {self.follow_up_date})"