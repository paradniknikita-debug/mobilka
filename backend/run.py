#!/usr/bin/env python3
"""
Скрипт запуска сервера для системы управления ЛЭП
"""

import uvicorn
from app.main import app

if __name__ == "__main__":
    import os
    # В Docker не используем reload (он не работает там)
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=os.getenv("RELOAD", "false").lower() == "true",
        log_level="info"
    )
