#!/usr/bin/env python3
"""
Расширение колонки acline_segment.code до VARCHAR(36) для единого UID (mrid).
Запуск: из backend с установленным psycopg2 или: py -3 scripts/run_extend_acline_segment_code.py
Читает DATABASE_URL из .env или переменных окружения.
"""
import os
import re
import sys

def load_env():
    backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    env_path = os.path.join(backend_dir, ".env")
    if not os.path.isfile(env_path):
        return os.environ.get("DATABASE_URL", "")
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            m = re.match(r"DATABASE_URL\s*=\s*(.+)", line)
            if m:
                return m.group(1).strip().strip("'\"").replace("postgresql+asyncpg://", "postgresql://").replace("postgresql+psycopg2://", "postgresql://")
    return os.environ.get("DATABASE_URL", "")

def main():
    url = load_env()
    if not url:
        url = "postgresql://postgres:dragon167@localhost:5433/lepm_db"
        print("DATABASE_URL не найден, используется значение по умолчанию.", file=sys.stderr)
    try:
        import psycopg2
    except ImportError:
        print("Установите psycopg2-binary: pip install psycopg2-binary", file=sys.stderr)
        sys.exit(1)
    conn = psycopg2.connect(url)
    conn.autocommit = True
    cur = conn.cursor()
    try:
        cur.execute("""
            ALTER TABLE acline_segment
            ALTER COLUMN code TYPE VARCHAR(36);
        """)
        print("OK: колонка acline_segment.code расширена до VARCHAR(36).")
        cur.execute("""
            COMMENT ON COLUMN acline_segment.code IS 'Единый UID (совпадает с mrid), без префиксов SEG- и т.п.';
        """)
        print("OK: комментарий на колонку установлен.")
    except Exception as e:
        print(f"Ошибка: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    main()
