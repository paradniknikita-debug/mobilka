# Настройка Drift (локальная БД) для веб-сборки

Приложение открывает БД в **главном потоке** (без воркера), поэтому нужен только один файл:

1. **sqlite3.wasm** — WebAssembly-модуль SQLite.  
   **Важно:** версия должна совпадать с пакетом `sqlite3` в проекте (в `pubspec.lock` — например 2.9.3).  
   Скачать: https://github.com/simolus3/sqlite3.dart/releases (релиз **sqlite3-2.9.3** или ваша версия 2.x, в Assets — `sqlite3.wasm`).

Положите файл в папку `web/` (рядом с `index.html`). Файл `drift_worker.js` не используется.

После добавления пересоберите: `flutter build web` или `flutter run -d chrome`.

Подробнее: https://drift.simonbinder.eu/platforms/web/
