# Согласованность полей БД, схем и API

## Исправления (выполнены)

### 1. **User** (auth)
- **Было:** в `auth.py` при создании пользователя передавалось `last_name=user_data.full_name`.
- **Модель:** поле называется `full_name`.
- **Исправлено:** `full_name=user_data.full_name`.

### 2. **Substation** (excel_import)
- **Было:** при импорте из Excel подстанция создавалась с `code=str(row['code'])`.
- **Модель:** поле называется `dispatcher_name` (поле `code` отсутствует).
- **Исправлено:** `dispatcher_name=str(row.get('dispatcher_name') or row.get('code', ''))`. В Excel может быть колонка `code` или `dispatcher_name`.

### 3. **PowerLine** (power_lines API)
- **Схема PowerLineCreate:** содержит `base_voltage_id` (для будущего CIM).
- **Модель PowerLine:** поля `base_voltage_id` нет (закомментировано).
- **Исправлено:** при создании ЛЭП из словаря удаляется `base_voltage_id`, чтобы не передавать его в конструктор модели.

---

## Соответствие моделей и схем

### User
| Модель (users)     | Схема UserCreate / UserResponse | Примечание |
|--------------------|----------------------------------|------------|
| username           | username                         | OK         |
| email              | email                            | OK         |
| full_name          | full_name                        | OK         |
| hashed_password    | password (только Create)         | OK         |
| role               | role                             | OK         |
| branch_id          | branch_id                        | OK         |
| is_active, is_superuser, created_at, updated_at | UserResponse | OK |

### Substation
| Модель (substations) | Схема SubstationCreate/Response | Примечание |
|----------------------|----------------------------------|------------|
| name                 | name                             | OK         |
| dispatcher_name      | dispatcher_name                  | OK (в Excel — колонка code маппится на dispatcher_name) |
| voltage_level        | voltage_level                    | OK         |
| latitude, longitude  | latitude, longitude              | OK         |
| address              | address                          | OK         |
| region_id            | —                                | Только в модели (в схеме нет, задаётся при импорте) |
| branch_id            | branch_id                        | OK         |
| description          | description                      | OK         |
| is_active            | —                                | В Response через from_attributes |

### PowerLine
| Модель (power_lines) | Схема PowerLineCreate | Примечание |
|----------------------|------------------------|------------|
| name                 | name                   | OK         |
| code                 | генерируется в API     | OK         |
| voltage_level        | voltage_level          | OK         |
| length               | length                 | OK         |
| region_id            | —                      | Удаляется из ввода, задаётся отдельно при необходимости |
| branch_id            | —                      | Аналогично |
| status                | status                 | OK         |
| description          | description + branch_name, region_name | OK         |
| base_voltage_id      | в схеме есть           | В модели нет; в API удаляется перед созданием |

### Pole
| Модель (poles)       | Схема PoleCreate/PoleResponse | Примечание |
|----------------------|--------------------------------|------------|
| pole_number          | pole_number                    | OK         |
| latitude, longitude  | latitude, longitude           | OK         |
| pole_type            | pole_type                      | OK         |
| height, foundation_type, material, year_installed | Аналогично | OK |
| condition            | condition                      | OK         |
| notes                | notes                          | OK         |
| sequence_number      | sequence_number                | OK         |
| conductor_type, conductor_material, conductor_section | Аналогично | OK |

### Branch
| Модель (branches) | Схема BranchCreate/Response | OK |
|-------------------|-----------------------------|----|
| name, code, address, phone, email, manager_name, description | Совпадают | ✓ |

---

## Рекомендации

1. **Создание сущностей через API:** везде использовать только поля, существующие в модели; лишние поля из схем (например, `base_voltage_id`, `branch_name`, `region_name`) удалять или маппить перед передачей в модель.
2. **Импорт из Excel:** для подстанций использовать колонку `dispatcher_name` или `code` (маппинг на `dispatcher_name` уже реализован).
3. **Sync API:** при создании Pole в sync передаются основные поля; при необходимости расширить синхронизацию — добавить `sequence_number`, `conductor_type`, `conductor_material`, `conductor_section` в payload и в создание Pole в sync.
