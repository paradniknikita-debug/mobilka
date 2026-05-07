"""
Фиксированные mRID и подписи для выгрузки CIM 552 diff под целевое дерево объектов.
UID совпадают с контуром импорта во внешней системе.
"""

# Корень дерева объектов (внешний) — только ссылка ParentObject, объект не создаём
CIM_OBJECT_TREE_ROOT_MRID = "00000001-0000-0000-c000-0000006d746c"

# Папка «всё импортированное»
CIM_IMPORT_FOLDER_MRID = "caab1a52-eab7-4440-aa1d-f511dbea5e2c"

# География
CIM_GEOGRAPHICAL_REGION_MRID = "c279a526-f085-4aa8-9575-85f50f70e3b0"
CIM_SUB_GEOGRAPHICAL_REGION_MRID = "0c18715a-461a-4b54-8273-00ea9e58a9d3"

# Папки ТП и ЛЭП
CIM_FOLDER_SUBSTATIONS_MRID = "f6d71e32-38e1-42f0-afd2-40ee7628c1a5"
CIM_FOLDER_POWER_LINES_MRID = "b09f1698-6244-4b1a-8eea-c9bf5f692e59"

# Имена по умолчанию (можно переопределить из settings позже)
DEFAULT_IMPORT_FOLDER_NAME = "LEPM импорт"
DEFAULT_GEO_REGION_NAME = "LEPM регион"
DEFAULT_SUB_REGION_NAME = "LEPM субрегион"
DEFAULT_FOLDER_SUBSTATIONS_NAME = "lepm Подстанции"
DEFAULT_FOLDER_LINES_NAME = "lepm ЛЭП"
