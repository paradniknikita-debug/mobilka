"""
Скрипт для создания примеров Excel файлов для импорта данных
"""
import pandas as pd
from pathlib import Path

# Создаём папку для примеров
examples_dir = Path("examples")
examples_dir.mkdir(exist_ok=True)

# 1. Шаблон для импорта ЛЭП
power_lines_data = {
    "name": [
        "ЛЭП 110 кВ Минск-Западная",
        "ЛЭП 35 кВ Минск-Северная",
        "ЛЭП 220 кВ Минск-Восточная"
    ],
    "code": [
        "LINE_110_1",
        "LINE_35_1",
        "LINE_220_1"
    ],
    "voltage_level": [110, 35, 220],
    "length": [25.5, 15.2, 45.8],
    "region_code": ["REG_001", "REG_001", "REG_002"],
    "region_name": ["РЭС Минск-Запад", "РЭС Минск-Запад", "РЭС Минск-Восток"],
    "status": ["active", "active", "active"],
    "description": [
        "Основная линия",
        "Резервная линия",
        "Магистральная линия"
    ]
}
df_power_lines = pd.DataFrame(power_lines_data)
df_power_lines.to_excel(examples_dir / "template_power_lines.xlsx", index=False)
print("✓ Создан шаблон: template_power_lines.xlsx")

# 2. Шаблон для импорта опор
poles_data = {
    "power_line_code": [
        "LINE_110_1",
        "LINE_110_1",
        "LINE_110_1",
        "LINE_110_1"
    ],
    "pole_number": ["T001", "T002", "T003", "T004"],
    "latitude": [53.9045, 53.9050, 53.9055, 53.9060],
    "longitude": [27.5615, 27.5620, 27.5625, 27.5630],
    "pole_type": ["анкерная", "промежуточная", "промежуточная", "анкерная"],
    "height": [25.5, 22.0, 22.0, 25.5],
    "foundation_type": ["железобетонная", "железобетонная", "железобетонная", "железобетонная"],
    "material": ["металл", "железобетон", "железобетон", "металл"],
    "year_installed": [2020, 2020, 2020, 2020],
    "condition": ["good", "good", "good", "good"],
    "notes": ["", "", "", ""]
}
df_poles = pd.DataFrame(poles_data)
df_poles.to_excel(examples_dir / "template_poles.xlsx", index=False)
print("✓ Создан шаблон: template_poles.xlsx")

# 3. Шаблон для импорта подстанций
substations_data = {
    "name": [
        "Подстанция 110/10 кВ №1",
        "Подстанция 35/10 кВ №2",
        "Подстанция 220/110 кВ №3"
    ],
    "code": ["SUB_110_1", "SUB_35_1", "SUB_220_1"],
    "voltage_level": [110, 35, 220],
    "latitude": [53.9000, 53.9100, 53.9200],
    "longitude": [27.5500, 27.5600, 27.5700],
    "address": [
        "г. Минск, ул. Примерная, 1",
        "г. Минск, ул. Другая, 2",
        "г. Минск, ул. Третья, 3"
    ],
    "region_code": ["REG_001", "REG_001", "REG_002"],
    "region_name": ["РЭС Минск-Запад", "РЭС Минск-Запад", "РЭС Минск-Восток"],
    "description": [
        "Основная подстанция",
        "Резервная подстанция",
        "Магистральная подстанция"
    ]
}
df_substations = pd.DataFrame(substations_data)
df_substations.to_excel(examples_dir / "template_substations.xlsx", index=False)
print("✓ Создан шаблон: template_substations.xlsx")

# 4. Шаблон для импорта оборудования
equipment_data = {
    "power_line_code": [
        "LINE_110_1",
        "LINE_110_1",
        "LINE_110_1",
        "LINE_110_1"
    ],
    "pole_number": ["T001", "T001", "T002", "T002"],
    "equipment_type": ["изолятор", "разрядник", "изолятор", "грозозащитный трос"],
    "name": [
        "Изолятор ПС-70",
        "Разрядник РВО-10",
        "Изолятор ПС-70",
        "Грозозащитный трос С-50"
    ],
    "manufacturer": ["Завод №1", "Завод №2", "Завод №1", "Завод №3"],
    "model": ["ПС-70", "РВО-10", "ПС-70", "С-50"],
    "serial_number": ["SN001", "SN002", "SN003", "SN004"],
    "year_manufactured": [2020, 2020, 2020, 2020],
    "condition": ["good", "good", "good", "good"],
    "notes": ["", "", "", ""]
}
df_equipment = pd.DataFrame(equipment_data)
df_equipment.to_excel(examples_dir / "template_equipment.xlsx", index=False)
print("✓ Создан шаблон: template_equipment.xlsx")

print("\n✅ Все шаблоны созданы в папке 'examples/'")
print("\nИспользование:")
print("1. Открой шаблон в Excel")
print("2. Заполни данными (можно удалить примеры)")
print("3. Сохрани файл")
print("4. Импортируй через API или скрипт (см. IMPORT_DATA.md)")

