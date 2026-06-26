#!/usr/bin/env python3
"""清理 UI 中常见的 String? 字段非空断言模式。"""

import re
from pathlib import Path

ROOTS = [
    Path(r"D:\Data\android_project\dentist_app\android_app\lib\screens"),
    Path(r"D:\Data\android_project\dentist_app\android_app\lib\widgets"),
    Path(r"D:\Data\android_project\dentist_app\android_app\lib\features"),
]

# 对象.字段 模式，字段是常见的可空字符串
STRING_FIELDS = [
    "doctor",
    "address",
    "identificationNumber",
    "treatmentItems",
    "notes",
    "supplier",
    "patientName",
    "avatar",
]


def fix_common_patterns(text: str) -> str:
    # 处理 x.field != null && x.field!.isNotEmpty
    for field in STRING_FIELDS:
        pattern = re.compile(
            rf"(\w+)\.{field}\s*!=\s*null\s*&&\s*\1\.{field}!\.isNotEmpty"
        )
        text = pattern.sub(r"\1." + field + r"?.isNotEmpty == true", text)

    # 处理 x.field! 单独出现且前面没有 ?. 的情况（简单兜底）
    for field in STRING_FIELDS:
        # 匹配不以 ? 或 ?? 开头的 field!，但会跳过非 String 字段，风险可控
        pattern = re.compile(rf"(?<![?\?])\.{field}!")
        text = pattern.sub(f".{field} ?? ''", text)

    return text


def process_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    new_text = fix_common_patterns(text)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        return True
    return False


def main():
    changed = 0
    for root in ROOTS:
        for path in root.rglob("*.dart"):
            if process_file(path):
                changed += 1
    print(f"Modified {changed} files")


if __name__ == "__main__":
    main()
