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
    final raw = equipmentBrandsByCategory[category] ?? ['другое'];
    final specs = raw.map((b) => EquipmentBrandSpec(b)).toList();
    _sortBrandSpecsInPlace(specs);
    return specs.map((s) => s.brand).toList();
  }

  /// Марка оборудования + ключевой параметр (номинальный ток, А).
  /// Для ОПН/изоляторов и т.п. ток может быть не определён в этой модели.
  static final Map<String, Map<double, List<EquipmentBrandSpec>>> equipmentBrandSpecsByCategoryAndKv = {
    'Изоляторы': {
      0.4: [EquipmentBrandSpec('ИО-0.4'), EquipmentBrandSpec('штыревый 0.4 кВ'), EquipmentBrandSpec('другое')],
      6: [EquipmentBrandSpec('ИО-6'), EquipmentBrandSpec('ПС-6'), EquipmentBrandSpec('другое')],
      10: [EquipmentBrandSpec('ИО-10'), EquipmentBrandSpec('ПС-10'), EquipmentBrandSpec('ПФ-10'), EquipmentBrandSpec('другое')],
      35: [EquipmentBrandSpec('ПС-35'), EquipmentBrandSpec('ПСД-35'), EquipmentBrandSpec('ПФ-35'), EquipmentBrandSpec('другое')],
      110: [EquipmentBrandSpec('ПС-70Е'), EquipmentBrandSpec('ПС-120Б'), EquipmentBrandSpec('ПСД-110'), EquipmentBrandSpec('другое')],
      220: [EquipmentBrandSpec('ПС-120Б'), EquipmentBrandSpec('ПС-160Е'), EquipmentBrandSpec('ПСД-220'), EquipmentBrandSpec('другое')],
      330: [EquipmentBrandSpec('ПС-160Е'), EquipmentBrandSpec('ПС-210Д'), EquipmentBrandSpec('ПСД-330'), EquipmentBrandSpec('другое')],
      500: [EquipmentBrandSpec('ПС-210Д'), EquipmentBrandSpec('ПС-300'), EquipmentBrandSpec('ПСД-500'), EquipmentBrandSpec('другое')],
      750: [EquipmentBrandSpec('ПС-300'), EquipmentBrandSpec('ПС-400'), EquipmentBrandSpec('ПСД-750'), EquipmentBrandSpec('другое')],
    },
    'Разрядники': {
      0.4: [EquipmentBrandSpec('ОПН-0.4'), EquipmentBrandSpec('другое')],
      6: [EquipmentBrandSpec('ОПН-6'), EquipmentBrandSpec('РВО-6'), EquipmentBrandSpec('другое')],
      10: [EquipmentBrandSpec('ОПН-10'), EquipmentBrandSpec('РВО-10'), EquipmentBrandSpec('другое')],
      35: [EquipmentBrandSpec('ОПН-35'), EquipmentBrandSpec('РВМ-35'), EquipmentBrandSpec('другое')],
      110: [EquipmentBrandSpec('ОПН-110'), EquipmentBrandSpec('РВМ-110'), EquipmentBrandSpec('другое')],
      220: [EquipmentBrandSpec('ОПН-220'), EquipmentBrandSpec('другое')],
      330: [EquipmentBrandSpec('ОПН-330'), EquipmentBrandSpec('другое')],
      500: [EquipmentBrandSpec('ОПН-500'), EquipmentBrandSpec('другое')],
      750: [EquipmentBrandSpec('ОПН-750'), EquipmentBrandSpec('другое')],
    },
    'Разъединители': {
      0.4: [EquipmentBrandSpec('РБ-0.4', nominalCurrentA: 400), EquipmentBrandSpec('другое')],
      6: [EquipmentBrandSpec('РВФЗ-6', nominalCurrentA: 630), EquipmentBrandSpec('РЛНД-6', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      10: [EquipmentBrandSpec('РЛНД-10', nominalCurrentA: 630), EquipmentBrandSpec('РВФЗ-10', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      35: [EquipmentBrandSpec('РЛНД-35', nominalCurrentA: 1000), EquipmentBrandSpec('РВЗ-35', nominalCurrentA: 1000), EquipmentBrandSpec('другое')],
      110: [EquipmentBrandSpec('РГ-110', nominalCurrentA: 2000), EquipmentBrandSpec('РНДЗ-110', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      220: [EquipmentBrandSpec('РГ-220', nominalCurrentA: 2000), EquipmentBrandSpec('РНДЗ-220', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      330: [EquipmentBrandSpec('РГ-330', nominalCurrentA: 2000), EquipmentBrandSpec('РНДЗ-330', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      500: [EquipmentBrandSpec('РГ-500', nominalCurrentA: 2500), EquipmentBrandSpec('другое')],
      750: [EquipmentBrandSpec('РГ-750', nominalCurrentA: 3150), EquipmentBrandSpec('другое')],
    },
    'Выключатели': {
      0.4: [EquipmentBrandSpec('автомат 0.4 кВ', nominalCurrentA: 250), EquipmentBrandSpec('другое')],
      6: [EquipmentBrandSpec('ВВ/TEL-6', nominalCurrentA: 1000), EquipmentBrandSpec('ВМП-6', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      10: [EquipmentBrandSpec('ВВ/TEL-10', nominalCurrentA: 1000), EquipmentBrandSpec('ВМП-10', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      35: [EquipmentBrandSpec('ВГТ-35', nominalCurrentA: 1250), EquipmentBrandSpec('другое')],
      110: [EquipmentBrandSpec('Элегазовый 110 кВ', nominalCurrentA: 2000), EquipmentBrandSpec('ВГТ-110', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      220: [EquipmentBrandSpec('Элегазовый 220 кВ', nominalCurrentA: 2500), EquipmentBrandSpec('ВГТ-220', nominalCurrentA: 2500), EquipmentBrandSpec('другое')],
      330: [EquipmentBrandSpec('Элегазовый 330 кВ', nominalCurrentA: 3150), EquipmentBrandSpec('другое')],
      500: [EquipmentBrandSpec('Элегазовый 500 кВ', nominalCurrentA: 3150), EquipmentBrandSpec('другое')],
      750: [EquipmentBrandSpec('Элегазовый 750 кВ', nominalCurrentA: 4000), EquipmentBrandSpec('другое')],
    },
    'Реклоузеры': {
      6: [EquipmentBrandSpec('RECLOSER-6', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      10: [EquipmentBrandSpec('RECLOSER-10', nominalCurrentA: 630), EquipmentBrandSpec('RCB-10', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      35: [EquipmentBrandSpec('RECLOSER-35', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
    },
    'ЗН': {
      6: [EquipmentBrandSpec('ЗН-6', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      10: [EquipmentBrandSpec('ЗН-10', nominalCurrentA: 630), EquipmentBrandSpec('другое')],
      35: [EquipmentBrandSpec('ЗН-35', nominalCurrentA: 1000), EquipmentBrandSpec('другое')],
      110: [EquipmentBrandSpec('ЗН-110', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      220: [EquipmentBrandSpec('ЗН-220', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      330: [EquipmentBrandSpec('ЗН-330', nominalCurrentA: 2000), EquipmentBrandSpec('другое')],
      500: [EquipmentBrandSpec('ЗН-500', nominalCurrentA: 2500), EquipmentBrandSpec('другое')],
      750: [EquipmentBrandSpec('ЗН-750', nominalCurrentA: 3150), EquipmentBrandSpec('другое')],
    },
  };

  static const List<double> _nominalsKv = [0.4, 6, 10, 35, 110, 220, 330, 500, 750];

  /// Ближайший стандартный номинал кВ к напряжению линии (для подбора марок оборудования).
  static double nearestNominalKv(double voltageKv) {
    var nearest = _nominalsKv.first;
    var bestDiff = double.infinity;
    for (final n in _nominalsKv) {
      final d = (voltageKv - n).abs();
      if (d < bestDiff) {
        bestDiff = d;
        nearest = n;
      }
    }
    return nearest;
  }

  /// Ключ кВ в таблице категории, ближайший к напряжению линии (таблицы могут быть неполными).
  static double nearestKeyInCategoryTable(
    Map<double, List<EquipmentBrandSpec>> byKv,
    double voltageKv,
  ) {
    if (byKv.isEmpty) return nearestNominalKv(voltageKv);
    double best = byKv.keys.first;
    var bestDiff = double.infinity;
    for (final k in byKv.keys) {
      final d = (voltageKv - k).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = k;
      }
    }
    return best;
  }

  /// Категории, у которых марки завязаны на номинал линии (не показываем чужие кВ).
  static bool categoryUsesLineVoltage(String category) =>
      equipmentBrandSpecsByCategoryAndKv.containsKey(category) || category == 'Грозоотвод';

  static bool _isOtherBrandLabel(String brand) => brand.trim().toLowerCase() == 'другое';

  /// Напряжение для упорядочивания чипов: из модели или суффикса «-10», «… 35 кВ».
  static double? _kvForSort(EquipmentBrandSpec s) {
    if (s.nominalVoltageKv != null) return s.nominalVoltageKv;
    final b = s.brand.trim();
    var m = RegExp(r'-(\d+(?:\.\d+)?)\s*$').firstMatch(b);
    if (m != null) return double.tryParse(m.group(1)!);
    m = RegExp(r'(\d+(?:\.\d+)?)\s*кВ').firstMatch(b);
    if (m != null) return double.tryParse(m.group(1)!);
    return null;
  }

  static int _compareBrandSpecs(EquipmentBrandSpec a, EquipmentBrandSpec b) {
    final oa = _isOtherBrandLabel(a.brand);
    final ob = _isOtherBrandLabel(b.brand);
    if (oa != ob) return oa ? 1 : -1;
    final ka = _kvForSort(a);
    final kb = _kvForSort(b);
    if (ka != null || kb != null) {
      if (ka == null && kb != null) return 1;
      if (ka != null && kb == null) return -1;
      if (ka != null && kb != null && ka != kb) return ka.compareTo(kb);
    }
    final ia = a.nominalCurrentA ?? 0;
    final ib = b.nominalCurrentA ?? 0;
    if (ia != ib) return ia.compareTo(ib);
    return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
  }

  static void _sortBrandSpecsInPlace(List<EquipmentBrandSpec> list) {
    list.sort(_compareBrandSpecs);
  }

  static List<EquipmentBrandSpec> _brandSpecsGrozootvod(double voltageKv) {
    const raw = ['грозотрос', 'ГФ-10', 'ГФ-35', 'другое'];
    final nearest = nearestNominalKv(voltageKv);
    final out = <EquipmentBrandSpec>[];
    for (final b in raw) {
      final s = EquipmentBrandSpec(b);
      if (_isOtherBrandLabel(b)) {
        out.add(s);
        continue;
      }
      if (b == 'грозотрос') {
        out.add(s);
        continue;
      }
      final kv = _kvForSort(s);
      if (kv != null && (kv - nearest).abs() < 0.01) out.add(s);
    }
    _sortBrandSpecsInPlace(out);
    return out.isEmpty ? [const EquipmentBrandSpec('другое')] : out;
  }

  static List<EquipmentBrandSpec> getBrandSpecsForCategoryAndVoltage(String category, double? voltageKv) {
    final byKv = equipmentBrandSpecsByCategoryAndKv[category];
    final hasVoltage = voltageKv != null && voltageKv > 0;

    if (category == 'Грозоотвод') {
      if (!hasVoltage) {
        return [const EquipmentBrandSpec('другое')];
      }
      return _brandSpecsGrozootvod(voltageKv);
    }

    if (byKv != null && byKv.isNotEmpty) {
      if (!hasVoltage) {
        return [const EquipmentBrandSpec('другое')];
      }
      final rowKey = nearestKeyInCategoryTable(byKv, voltageKv);
      final baseSpecs = byKv[rowKey]!;
      final mapped = baseSpecs
          .map((s) => s.nominalVoltageKv == null
              ? s.copyWith(nominalVoltageKv: rowKey)
              : s)
          .toList();
      _sortBrandSpecsInPlace(mapped);
      return mapped;
    }

    return getBrandsForCategory(category)
        .map((b) => EquipmentBrandSpec(b))
        .toList();
  }

  static List<String> getBrandsForCategoryAndVoltage(String category, double? voltageKv) {
    return getBrandSpecsForCategoryAndVoltage(category, voltageKv)
        .map((e) => e.brand)
        .toList();
  }

  static bool hasVoltageSpecificBrands(String category) => categoryUsesLineVoltage(category);

  static bool isBrandAllowedForCategoryAndVoltage(
    String category,
    double? voltageKv,
    String brand,
  ) {
    final normalized = brand.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (voltageKv == null || voltageKv <= 0) {
      return true;
    }
    final allowed = getBrandsForCategoryAndVoltage(category, voltageKv)
        .map((e) => e.trim().toLowerCase())
        .toSet();
    return allowed.contains(normalized);
  }

  static bool isSingleInstance(String category) =>
      singleInstanceCategories.contains(category);
}

class EquipmentBrandSpec {
  const EquipmentBrandSpec(
    this.brand, {
    this.nominalCurrentA,
    this.nominalVoltageKv,
  });

  final String brand;
  final int? nominalCurrentA;
  final double? nominalVoltageKv;

  EquipmentBrandSpec copyWith({
    String? brand,
    int? nominalCurrentA,
    double? nominalVoltageKv,
  }) {
    return EquipmentBrandSpec(
      brand ?? this.brand,
      nominalCurrentA: nominalCurrentA ?? this.nominalCurrentA,
      nominalVoltageKv: nominalVoltageKv ?? this.nominalVoltageKv,
    );
  }
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
