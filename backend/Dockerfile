# syntax=docker/dockerfile:1
# BuildKit: кэш pip между сборками (DOCKER_BUILDKIT=1 или docker compose build)
FROM python:3.9-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Установка часового пояса (Минск)
ENV TZ=Europe/Minsk
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

# 1) Только requirements — этот слой пересобирается только при изменении зависимостей
COPY requirements.txt .

# 2) Кэш pip: повторные сборки не качают пакеты заново (пока версии те же)
# Проверка boto3 — в requirements.txt уже есть; падаем при сборке, если S3-клиент не ставится
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt \
    && python -c "import boto3; print('boto3 OK', boto3.__version__)"

# 3) Код приложения — меняется чаще всего; слой с pip не трогаем
COPY . .

RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

EXPOSE 8000

CMD ["python", "run.py"]
