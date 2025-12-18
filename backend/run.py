#!/usr/bin/env python3
"""
Скрипт запуска сервера для системы управления ЛЭП
"""

import uvicorn
import socket
import sys
from app.main import app

def is_port_in_use(port: int, host: str = "0.0.0.0") -> bool:
    """Проверка, занят ли порт"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind((host, port))
            return False
        except OSError:
            return True

if __name__ == "__main__":
    import os
    
    port = 8000
    host = "0.0.0.0"
    
    # Проверяем, занят ли порт
    if is_port_in_use(port, host):
        print(f"ERROR: Порт {port} уже занят!")
        print(f"Остановите другой процесс, использующий этот порт, или измените порт в run.py")
        print(f"\nДля проверки процесса используйте:")
        print(f"  Windows: netstat -ano | findstr \":{port}\"")
        print(f"  Linux/Mac: lsof -i :{port}")
        sys.exit(1)
    
    # В Docker не используем reload (он не работает там)
    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        reload=os.getenv("RELOAD", "false").lower() == "true",
        log_level="info"
    )
