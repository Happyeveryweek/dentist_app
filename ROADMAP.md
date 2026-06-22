# ROADMAP

## 当前阶段
- 脚本维护

## 已完成
- `scripts/send_today_appointment_emails.py` 新增 `LOG_RETENTION_DAYS` 变量，并在脚本启动时自动删除超过保留天数的历史日志。

## 进行中
- 无

## 待办
- 待确认：日志保留天数默认值是否需要从 `30` 调整为其他业务周期。

## 阻塞
- 无

## 最近验证
- 2026-06-21：执行 `python3 -m py_compile scripts/send_today_appointment_emails.py`，语法通过。
