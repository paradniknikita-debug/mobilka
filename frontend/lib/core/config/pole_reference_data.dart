/// Справочные данные по характеристикам опор.
/// Используются в формах создания/редактирования опор без обращения к серверу.
class PoleReferenceData {
  PoleReferenceData._();

  /// Типы опор (все варианты для выбора в приложении)
  static const List<String> poleTypes = [
    'промежуточная',
    'анкерная',
    'угловая',
    'концевая',
    'переходная',
    'транспозиционная',
    'отпаечная',
  ];

  /// Материалы опор
  static const List<String> materials = [
    'металл',
    'железобетон',
    'дерево',
    'композит',
  ];

  /// Типы фундамента
  static const List<String> foundationTypes = [
    'стоечный',
    'анкерный',
    'свайный',
    'плитный',
    'комбинированный',
  ];

  /// Состояние опоры
  static const List<String> conditions = [
    'good',      // хорошее
    'satisfactory', // удовлетворительное
    'poor',      // неудовлетворительное
  ];

  /// Подписи для состояния (для UI)
  static const Map<String, String> conditionLabels = {
    'good': 'Хорошее',
    'satisfactory': 'Удовлетворительное',
    'poor': 'Неудовлетворительное',
  };

  /// Марки проводов (типы проводников)
  static const List<String> conductorTypes = [
    'AC-70',
    'AC-95',
    'AC-120',
    'AC-150',
    'AC-185',
    'AC-240',
    'AC-300',
  ];

  /// Материалы проводника
  static const List<String> conductorMaterials = [
    'алюминий',
    'медь',
    'сталь-алюминий',
  ];

  /// Типовые сечения провода, мм²
  static const List<String> conductorSections = [
    '35',
    '50',
    '70',
    '95',
    '120',
    '150',
    '185',
    '240',
    '300',
  ];

  /// Значение по умолчанию для типа опоры
  static const String defaultPoleType = 'промежуточная';

  /// Значение по умолчанию для состояния
  static const String defaultCondition = 'good';

  /// Значение по умолчанию для марки провода
  static const String defaultConductorType = 'AC-70';

  /// Значение по умолчанию для материала провода
  static const String defaultConductorMaterial = 'алюминий';

  /// Значение по умолчанию для сечения
  static const String defaultConductorSection = '70';

  /// Номинальное напряжение ЛЭП (кВ) — выпадающий список при создании линии (как на веб-клиенте).
  static const List<double> voltageLevelsKv = [
    0.4, 6, 10, 35, 110, 220, 330, 500, 750,
  ];
  static const double defaultVoltageKv = 110.0;
}

/// Справочник типов оборудования на опорах (офлайн).
class EquipmentReferenceData {
  EquipmentReferenceData._();

  /// Типы оборудования (ключи для equipment_type)
  static const List<String> equipmentTypes = [
    'фундамент',
    'изолятор',
    'траверса',
    'грозоотвод',
    'разрядник',
    'разъединитель',
    'выключатель',
    'реклоузер',
    'зн',
    'другое',
  ];

  static const String defaultEquipmentType = 'изолятор';

  /// Категории оборудования в карточке опоры → ключ для equipment_type
  static const Map<String, String> categoryToEquipmentType = {
    'Фундамент': 'фундамент',
    'Изоляторы': 'изолятор',
    'Траверсы': 'траверса',
    'Грозоотвод': 'грозоотвод',
    'Разрядники': 'разрядник',
    'Разъединители': 'разъединитель',
    'Выключатели': 'выключатель',
    'Реклоузеры': 'реклоузер',
    'ЗН': 'зн',
  };

  /// Оборудование только в 1 экземпляре на опоре (количество фиксировано = 1)
  static const Set<String> singleInstanceCategories = {
    'Фундамент',
    'Грозоотвод',
    'Выключатели',
    'Реклоузеры',
    'ЗН',
  };

  /// Марки оборудования по категориям (для быстрого выбора из справочника)
  static const Map<String, List<String>> equipmentBrandsByCategory = {
    'Фундамент': ['стоечный', 'анкерный', 'свайный', 'плитный', 'комбинированный', 'СЦ-2.0', 'СЦ-2.5', 'другое'],
    'Изоляторы': ['ПС-70', 'ПС-120', 'ПФ70-В', 'ИО-10', 'ИО-20', 'подвесной стеклянный', 'другое'],
    'Траверсы': ['ТМ-95', 'ТМ-120', 'ТМ-150', 'Т-образная', 'другое'],
    'Грозоотвод': ['грозотрос', 'ГФ-10', 'ГФ-35', 'другое'],
    'Разрядники': ['ОПН-10', 'ОПН-35', 'РВО-10', 'РВМ-10', 'другое'],
    'Разъединители': ['РЛНД-10', 'РВ-10', 'РЛК-10', 'другое'],
    'Выключатели': ['ВВЭ-10', 'ВВ/TEL-10', 'LFВ-110', 'другое'],
    'Реклоузеры': ['RECLOSER-10', 'RCB-10', 'другое'],
    'ЗН': ['ЗН-10', 'ЗН-35', 'другое'],
  };

  static List<String> getBrandsForCategory(String category) {
    return equipmentBrandsByCategory[category] ?? ['другое'];
  }

  static bool isSingleInstance(String category) =>
      singleInstanceCategories.contains(category);
}

/// Элемент справочника дефектов с критичностью.
class DefectItem {
  const DefectItem(this.name, this.criticality, {this.allowedCategoryTitles});
  final String name;
  /// low | medium | high
  final String criticality;
  /// Категории оборудования, для которых допустим этот дефект (null = все).
  final List<String>? allowedCategoryTitles;
}

/// Справочник дефектов с встроенной критичностью (для окрашивания опоры).
class DefectReferenceData {
  DefectReferenceData._();

  static const String otherDefectKey = 'Иной дефект';

  /// Дефекты с критичностью и привязкой к категориям оборудования.
  /// Например, «повреждение фундамента» только у Фундамента, «повреждение изолятора» только у Изоляторов.
  static const List<DefectItem> defectItems = [
    // Фундамент
    DefectItem('трещины бетона', 'high', allowedCategoryTitles: ['Фундамент']),
    DefectItem('разрушение бетона', 'high', allowedCategoryTitles: ['Фундамент']),
    DefectItem('просадка фундамента', 'medium', allowedCategoryTitles: ['Фундамент']),
    DefectItem('оголение арматуры', 'medium', allowedCategoryTitles: ['Фундамент']),

    // Изоляторы
    DefectItem('трещина изолятора', 'high', allowedCategoryTitles: ['Изоляторы']),
    DefectItem('сколы изолятора', 'medium', allowedCategoryTitles: ['Изоляторы']),
    DefectItem('загрязнение изолятора', 'medium', allowedCategoryTitles: ['Изоляторы']),

    // Траверсы
    DefectItem('коррозия траверсы', 'medium', allowedCategoryTitles: ['Траверсы']),
    DefectItem('деформация траверсы', 'medium', allowedCategoryTitles: ['Траверсы']),
    DefectItem('ослабление креплений траверсы', 'medium', allowedCategoryTitles: ['Траверсы']),

    // Заземление / грозоотвод
    DefectItem('коррозия заземляющего проводника', 'medium', allowedCategoryTitles: ['Заземление']),
    DefectItem('обрыв заземляющего проводника', 'high', allowedCategoryTitles: ['Заземление']),
    DefectItem('нет соединения с контуром', 'high', allowedCategoryTitles: ['Заземление']),
    DefectItem('обрыв грозотроса', 'high', allowedCategoryTitles: ['Грозоотвод']),
    DefectItem('коррозия грозотроса', 'medium', allowedCategoryTitles: ['Грозоотвод']),

    // Разрядники
    DefectItem('следы срабатывания разрядника', 'medium', allowedCategoryTitles: ['Разрядники']),
    DefectItem('трещины фарфора разрядника', 'high', allowedCategoryTitles: ['Разрядники']),
    DefectItem('разрушение корпуса разрядника', 'high', allowedCategoryTitles: ['Разрядники']),

    // Разъединители / ЗН
    DefectItem('подгорание контактов', 'medium', allowedCategoryTitles: ['Разъединители', 'ЗН']),
    DefectItem('неполное размыкание контактов', 'high', allowedCategoryTitles: ['Разъединители', 'ЗН']),
    DefectItem('заедание привода', 'medium', allowedCategoryTitles: ['Разъединители', 'ЗН']),

    // Выключатели
    DefectItem('повышенное сопротивление контактов', 'medium', allowedCategoryTitles: ['Выключатели']),
    DefectItem('течь масла/изоляционной жидкости', 'high', allowedCategoryTitles: ['Выключатели']),
    DefectItem('отказ включения/отключения', 'high', allowedCategoryTitles: ['Выключатели']),

    // Реклоузеры
    DefectItem('некорректная работа автоматики реклоузера', 'high', allowedCategoryTitles: ['Реклоузеры']),
    DefectItem('подгорание контактов реклоузера', 'medium', allowedCategoryTitles: ['Реклоузеры']),
    DefectItem('повреждение корпуса реклоузера', 'medium', allowedCategoryTitles: ['Реклоузеры']),

    // Общие дефекты / прочее
    DefectItem('коррозия металлических элементов', 'medium'),
    DefectItem('отклонение опоры от вертикали', 'medium'),
    DefectItem('отсутствует маркировка', 'low'),
    DefectItem('другое', 'low'),
  ];

  /// Список дефектов для данной категории оборудования (фильтр по allowedCategoryTitles).
  static List<DefectItem> defectItemsForCategory(String? categoryTitle) {
    if (categoryTitle == null || categoryTitle.isEmpty) return defectItems;
    return defectItems.where((e) {
      if (e.allowedCategoryTitles == null) return true;
      return e.allowedCategoryTitles!.contains(categoryTitle);
    }).toList();
  }

  static const List<String> criticalityLevels = ['low', 'medium', 'high'];

  static const Map<String, String> criticalityLabels = {
    'low': 'Низкая',
    'medium': 'Средняя',
    'high': 'Высокая',
  };
}
