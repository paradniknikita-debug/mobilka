# Файлы для каталога деплоя на сервере (DEPLOY_PATH)

Содержимое этой папки нужно один раз разложить на сервере в каталог деплоя, например **/root/mobilka**.

---

## Структура на сервере (после настройки)

```
/root/mobilka/   (или ваш DEPLOY_PATH)
├── .env                    ← создать из env.example, заполнить секреты
├── docker-compose.prod.yml ← обновляется CI при деплое (можно скопировать из корня репо)
├── nginx/                  ← обновляется CI (можно скопировать из корня репо)
│   ├── nginx.conf
│   └── ssl/                ← создать пустую папку или сертификаты
├── frontend/build/web/     ← создаётся CI (статика Flutter)
└── web-frontend/dist/lepm-web-frontend/  ← создаётся CI (статика Angular)
```

---

## Шаг 1: Создать каталог и скопировать файлы

На сервере:

```bash
sudo mkdir -p /root/mobilka
sudo chown $USER:$USER /root/mobilka
cd /root/mobilka
```

Скопируйте с вашего компьютера (или клонируйте репозиторий и возьмите оттуда):

- `docker-compose.prod.yml` из корня репозитория
- папку `nginx/` из корня репозитория
- файл `server-deploy-files/env.example` → сохраните на сервере как основу для `.env`

```bash
# Пример: с вашей машины (из корня репо mobilka)
scp docker-compose.prod.yml user@SERVER:/root/mobilka/
scp -r nginx user@SERVER:/root/mobilka/
scp server-deploy-files/env.example user@SERVER:/root/mobilka/.env
```

---

## Шаг 2: Настроить .env

На сервере отредактируйте `/root/mobilka/.env`:

```bash
nano /root/mobilka/.env
```

Обязательно задайте:

- **BACKEND_IMAGE** — образ backend из GitHub Container Registry, например:  
  `ghcr.io/VASH_GITHUB_USERNAME/mobilka-backend:latest`
- **POSTGRES_DB**, **POSTGRES_USER**, **POSTGRES_PASSWORD** — для БД
- **DATABASE_URL** — строка подключения к PostgreSQL (хост `postgres`, порт 5432)
- **SECRET_KEY** — длинная случайная строка для JWT (сгенерируйте: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`)
- **REDIS_URL** — обычно `redis://redis:6379`
- **CORS_ORIGINS** — разрешённые origins для API (например `https://ваш-домен.ru` или `*` для теста)

Пример см. в `server-deploy-files/env.example`.

---

## Шаг 3: Nginx SSL (при необходимости)

Если используете HTTPS:

- Либо создайте пустую папку: `mkdir -p /root/mobilka/nginx/ssl`
- Либо сгенерируйте самоподписанный сертификат (см. `nginx/generate-ssl-ubuntu.sh` в репозитории)
- Либо настройте Let's Encrypt и укажите путь к сертификатам в `nginx.conf`

---

## Шаг 4: GitHub Actions и первый деплой

1. В настройках репозитория задайте **Variables** и **Secrets** (см. `docs/CI_CD.md`).
2. Укажите **DEPLOY_PATH** = `/root/mobilka`.
3. Для входа по паролю: **Variables** → `DEPLOY_AUTH` = `password`; **Secrets** → `DEPLOY_SSH_PASSWORD` = пароль от сервера (нигде в репо не указывайте).
4. После пуша в `master` workflow скопирует на сервер:
   - статику Flutter и Angular,
   - актуальные `docker-compose.prod.yml` и `nginx/`,
   - затем выполнит `docker compose pull backend` и `docker compose up -d`.

Файл `.env` на сервере CI не перезаписывает — он остаётся только вашим.
