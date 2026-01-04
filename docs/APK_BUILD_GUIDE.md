# Руководство по сборке APK

## Быстрая сборка

### Windows
```bash
build-apk.bat
```

### Linux/macOS
```bash
chmod +x build-apk.sh
./build-apk.sh
```

## Ручная сборка

### 1. Подготовка

```bash
cd frontend

# Очистка предыдущих сборок
flutter clean

# Получение зависимостей
flutter pub get

# Генерация кода
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Сборка APK

```bash
# Release сборка (для установки)
flutter build apk --release

# Debug сборка (для тестирования)
flutter build apk --debug
```

### 3. Результат

APK файл будет находиться в:
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## Настройка IP сервера в приложении

После установки APK на устройство:

1. Откройте приложение
2. Войдите в систему
3. Перейдите в **Профиль** (иконка профиля)
4. Нажмите **"Настройки сервера"**
5. Введите:
   - **IP адрес** или доменное имя сервера (например: `192.168.1.100` или `lepm.local`)
   - **Порт** (по умолчанию: `8000`)
6. Нажмите **"Проверить подключение"** для теста
7. Нажмите **"Сохранить настройки"**

## Подпись APK (для публикации)

### Создание keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Настройка подписи

Создайте файл `frontend/android/key.properties`:

```properties
storePassword=<ваш пароль>
keyPassword=<ваш пароль>
keyAlias=upload
storeFile=<путь к keystore>
```

Обновите `frontend/android/app/build.gradle.kts`:

```kotlin
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### Сборка подписанного APK

```bash
flutter build apk --release
```

## Установка APK на устройство

### Через ADB

```bash
# Подключите устройство через USB
adb devices

# Установите APK
adb install frontend/build/app/outputs/flutter-apk/app-release.apk
```

### Через файловый менеджер

1. Скопируйте APK файл на устройство
2. Откройте файловый менеджер на устройстве
3. Найдите APK файл
4. Нажмите на него для установки
5. Разрешите установку из неизвестных источников (если требуется)

## Troubleshooting

### Ошибка: "Gradle build failed"

1. Проверьте версию Java:
   ```bash
   java -version
   ```
   Должна быть Java 11 или выше

2. Очистите кэш Gradle:
   ```bash
   cd frontend/android
   ./gradlew clean
   ```

### Ошибка: "SDK location not found"

Проверьте файл `frontend/android/local.properties`:
```properties
sdk.dir=C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
```

### Ошибка при генерации кода

```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### APK слишком большой

Используйте split APK:
```bash
flutter build apk --split-per-abi
```

Это создаст отдельные APK для разных архитектур (armeabi-v7a, arm64-v8a, x86_64).

## Размер APK

- **Release APK**: ~20-30 MB
- **Split APK (per ABI)**: ~8-12 MB каждый

## Версионирование

Версия приложения задается в `frontend/pubspec.yaml`:

```yaml
version: 1.0.0+1
```

Формат: `версия+build_number`
- `1.0.0` - версия приложения
- `1` - номер сборки (build number)

Для обновления версии измените эти значения.

