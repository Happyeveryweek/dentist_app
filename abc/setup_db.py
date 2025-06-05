from init import app, db
from models import User
# 不再需要密码加密

def setup_database():
    with app.app_context():
        # 创建所有数据库表
        # db.create_all()
        
        # 检查是否已存在admin用户
        admin = User.query.filter_by(username='admin').first()
        if not admin:
            # 创建默认管理员账号，直接使用明文密码
            admin = User(username='admin', 
                        email='admin@example.com', 
                        password='123456', 
                        role='admin')
            db.session.add(admin)
            db.session.commit()
            print('数据库初始化和管理员账号创建成功！')
        else:
            print('管理员账号已存在，无需创建')

if __name__ == '__main__':
    setup_database()