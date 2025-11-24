# 🚀 Быстрый гайд по импорту данных

## 📊 Импорт через Swagger UI (самый простой способ)

1. **Открой Swagger UI:**
   - `https://localhost/api/docs` (или `http://localhost/api/docs`)

2. **Авторизуйся:**
   - Нажми кнопку **"Authorize"** (🔒)
   - Введи токен: `Bearer <твой_токен>`
   - Получить токен: `POST /api/v1/auth/login`

3. **Импортируй данные:**
   - Найди раздел **"import"**
   - Выбери нужный endpoint (power-lines, poles, substations, equipment)
   - Нажми **"Try it out"**
   - Выбери Excel файл
   - Нажми **"Execute"**

## 📝 Создание Excel файлов

### Шаблоны Excel

Создай шаблоны командой:
```bash
docker compose exec backend python create_excel_templates.py
```

Шаблоны появятся в `backend/examples/`:
- `template_power_lines.xlsx` - для ЛЭП
- `template_poles.xlsx` - для опор
- `template_substations.xlsx` - для подстанций
- `template_equipment.xlsx` - для оборудования

### Формат данных

**ЛЭП (power-lines):**
- Обязательно: `name`, `code`, `voltage_level`
- Опционально: `length`, `region_code`, `status`, `description`

**Опоры (poles):**
- Обязательно: `power_line_code`, `pole_number`, `latitude`, `longitude`, `pole_type`
- Опционально: `height`, `material`, `condition`, `notes`

**Подстанции (substations):**
- Обязательно: `name`, `code`, `voltage_level`, `latitude`, `longitude`
- Опционально: `address`, `region_code`, `description`

**Оборудование (equipment):**
- Обязательно: `power_line_code`, `pole_number`, `equipment_type`, `name`
- Опционально: `manufacturer`, `model`, `condition`, `notes`

## ✋ Ручное добавление через API

### Примеры запросов

**Создать ЛЭП:**
```bash
POST /api/v1/power-lines
{
  "name": "ЛЭП 110 кВ",
  "code": "LINE_110_1",
  "voltage_level": 110,
  "branch_id": 1
}
```

**Создать опору:**
```bash
POST /api/v1/power-lines/{power_line_id}/poles
{
  "pole_number": "T001",
  "latitude": 53.9045,
  "longitude": 27.5615,
  "pole_type": "анкерная"
}
```

**Создать подстанцию:**
```bash
POST /api/v1/substations
{
  "name": "Подстанция №1",
  "code": "SUB_110_1",
  "voltage_level": 110,
  "latitude": 53.9000,
  "longitude": 27.5500,
  "branch_id": 1
}
```

## 📚 Подробная документация

См. `backend/IMPORT_DATA.md` для полной документации.

