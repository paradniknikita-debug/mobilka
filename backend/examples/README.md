# Примеры Excel файлов для импорта

Эта папка содержит шаблоны Excel файлов для массового импорта данных.

## Создание шаблонов

Запусти скрипт для создания шаблонов:

```bash
# В Docker контейнере
docker compose exec backend python create_excel_templates.py

# Или локально (если установлен Python)
cd backend
python create_excel_templates.py
```

## Доступные шаблоны

1. **template_power_lines.xlsx** - Шаблон для импорта ЛЭП
2. **template_poles.xlsx** - Шаблон для импорта опор
3. **template_substations.xlsx** - Шаблон для импорта подстанций
4. **template_equipment.xlsx** - Шаблон для импорта оборудования

## Использование

1. Открой шаблон в Excel
2. Заполни данными (можно удалить примеры)
3. Сохрани файл
4. Импортируй через API (Swagger UI) или скрипт

Подробные инструкции см. в `IMPORT_DATA.md`

