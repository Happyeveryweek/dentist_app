#!/usr/bin/env python3
"""批量清理 UI 层中几个安全的模式。"""

import re
from pathlib import Path

ROOTS = [
    Path(r"D:\Data\android_project\dentist_app\android_app\lib\screens"),
    Path(r"D:\Data\android_project\dentist_app\android_app\lib\widgets"),
    Path(r"D:\Data\android_project\dentist_app\android_app\lib\features"),
]


def fix_form_key_validate(text: str) -> str:
    """将 if (!_formKey.currentState!.validate()) { return; } 改造为局部变量。"""
    pattern = re.compile(
        r"if\s*\(\s*!\s*_formKey\.currentState!\.validate\(\)\s*\)\s*\{\s*return;\s*\}"
    )
    return pattern.sub(
        "final formState = _formKey.currentState;\n    "
        "if (formState == null || !formState.validate()) {\n      "
        "return;\n    "
        "}",
        text,
    )


def fix_on_changed_value(text: str) -> str:
    """将 onChanged: (value) { setState(() { _x = value!; }); } 添加空值检查。"""
    pattern = re.compile(
        r"onChanged:\s*\(value\)\s*\{\s*"
        r"setState\(\(\)\s*\{\s*"
        r"(_[a-zA-Z_$][\w$]*)\s*=\s*value!;\s*"
        r"\}\);\s*"
        r"\},"
    )
    return pattern.sub(
        r"onChanged: (value) {\n"
        r"          if (value == null) return;\n"
        r"          setState(() {\n"
        r"            \1 = value;\n"
        r"          });\n"
        r"        },",
        text,
    )


def process_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    new_text = fix_form_key_validate(text)
    new_text = fix_on_changed_value(new_text)
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
