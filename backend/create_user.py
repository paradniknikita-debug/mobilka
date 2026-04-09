#!/usr/bin/env python3
"""
Совместимость со старой командой:
  python create_user.py ...

Теперь скрипт создаёт пользователя напрямую в БД (без SQL).
Основная реализация находится в scripts/create_user.py.
"""

import subprocess
import sys
import runpy
from pathlib import Path


if __name__ == "__main__":
    backend_dir = Path(__file__).parent
    script_path = backend_dir / "scripts" / "create_user.py"

    try:
        runpy.run_path(str(script_path), run_name="__main__")
    except ModuleNotFoundError as exc:
        # Частый случай: запустили через корневой .venv, где нет backend-зависимостей.
        if exc.name != "sqlalchemy":
            raise

        backend_python = backend_dir / ".venv" / "Scripts" / "python.exe"
        if backend_python.exists():
            cmd = [str(backend_python), str(script_path), *sys.argv[1:]]
            raise SystemExit(subprocess.call(cmd))

        print(
            "Не найден модуль 'sqlalchemy'.\n"
            "Установите зависимости backend или запускайте через backend/.venv:\n"
            "  backend\\.venv\\Scripts\\python.exe backend\\create_user.py",
            file=sys.stderr,
        )
        raise SystemExit(1)
