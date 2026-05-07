#!/bin/bash
# Генерация self-signed SSL сертификата для разработки

SSL_DIR="./nginx/ssl"
mkdir -p "$SSL_DIR"

# Генерируем приватный ключ
openssl genrsa -out "$SSL_DIR/key.pem" 2048

# Генерируем сертификат
openssl req -new -x509 -key "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.pem" -days 365 -subj "/CN=localhost"

echo "SSL сертификаты созданы в $SSL_DIR"
echo "cert.pem и key.pem готовы для использования в nginx"

