#!/bin/bash
# Генерация самоподписанного SSL сертификата для Nginx на Ubuntu
# Использование: ./generate-ssl-ubuntu.sh

set -e  # Остановка при ошибке

echo "========================================"
echo "Генерация SSL сертификатов для Nginx"
echo "========================================"
echo ""

# Проверка наличия openssl
if ! command -v openssl &> /dev/null; then
    echo "❌ OpenSSL не установлен!"
    echo "Установка OpenSSL..."
    apt update && apt install -y openssl
fi

# Определение директории для сертификатов
SSL_DIR="./nginx/ssl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_FULL_PATH="$PROJECT_ROOT/nginx/ssl"

# Создание директории
echo "[1/3] Создание директории для сертификатов..."
mkdir -p "$SSL_FULL_PATH"
echo "✅ Директория создана: $SSL_FULL_PATH"
echo ""

# Генерация приватного ключа
echo "[2/3] Генерация приватного ключа (2048 бит)..."
openssl genrsa -out "$SSL_FULL_PATH/key.pem" 2048
chmod 600 "$SSL_FULL_PATH/key.pem"  # Только для чтения владельцем
echo "✅ Приватный ключ создан: $SSL_FULL_PATH/key.pem"
echo ""

# Генерация самоподписанного сертификата
echo "[3/3] Генерация самоподписанного сертификата (действителен 365 дней)..."
openssl req -new -x509 \
    -key "$SSL_FULL_PATH/key.pem" \
    -out "$SSL_FULL_PATH/cert.pem" \
    -days 365 \
    -subj "/C=BY/ST=Minsk/L=Minsk/O=LEPM/CN=localhost" \
    -extensions v3_req \
    -config <(
        echo "[req]"
        echo "distinguished_name=req"
        echo "[v3_req]"
        echo "keyUsage=keyEncipherment,dataEncipherment"
        echo "extendedKeyUsage=serverAuth"
        echo "subjectAltName=@alt_names"
        echo "[alt_names]"
        echo "DNS.1=localhost"
        echo "DNS.2=*.localhost"
        echo "IP.1=127.0.0.1"
    )

chmod 644 "$SSL_FULL_PATH/cert.pem"
echo "✅ Сертификат создан: $SSL_FULL_PATH/cert.pem"
echo ""

# Проверка созданных файлов
echo "========================================"
echo "✅ SSL сертификаты успешно созданы!"
echo "========================================"
echo ""
echo "📁 Расположение:"
echo "   - $SSL_FULL_PATH/key.pem (приватный ключ)"
echo "   - $SSL_FULL_PATH/cert.pem (сертификат)"
echo ""
echo "📋 Информация о сертификате:"
openssl x509 -in "$SSL_FULL_PATH/cert.pem" -noout -subject -dates
echo ""
echo "⚠️  ВАЖНО:"
echo "   Это самоподписанный сертификат для разработки/тестирования!"
echo "   При первом подключении браузер покажет предупреждение безопасности."
echo "   Нужно принять сертификат:"
echo "   - Chrome/Edge: 'Продолжить на сайт' / 'Advanced' -> 'Proceed to localhost'"
echo "   - Firefox: 'Дополнительно' -> 'Принять риск и продолжить'"
echo ""
echo "💡 Для продакшена рекомендуется использовать Let's Encrypt:"
echo "   certbot certonly --standalone -d your-domain.com"
echo ""

