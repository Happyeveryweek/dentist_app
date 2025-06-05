-- 首先删除错误的外键约束
ALTER TABLE appointments DROP FOREIGN KEY appointments_ibfk_1;

-- 创建新的外键约束，正确引用patients表
ALTER TABLE appointments ADD CONSTRAINT appointments_ibfk_1 FOREIGN KEY (patient_id) REFERENCES patients (id);

-- 检查表结构和约束
SHOW CREATE TABLE appointments; 