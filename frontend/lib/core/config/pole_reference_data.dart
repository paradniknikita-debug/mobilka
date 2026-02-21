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
}

/// Справочник типов оборудования на опорах (офлайн).
/// Используется в формах создания/редактирования оборудования без обращения к серверу.
class EquipmentReferenceData {
  EquipmentReferenceData._();

  /// Типы оборудования
  static const List<String> equipmentTypes = [
    'изолятор',
    'разрядник',
    'грозозащитный трос',
    'линейный разъединитель',
    'конденсатор',
    'трансформатор',
    'ограждение',
    'маркировка',
    'другое',
  ];

  static const String defaultEquipmentType = 'изолятор';
}

/// Справочник типов дефектов (офлайн). Можно использовать в заметках или будущих полях.
class DefectReferenceData {
  DefectReferenceData._();

  static const List<String> defectTypes = [
    'трещина',
    'коррозия',
    'повреждение изолятора',
    'отклонение от вертикали',
    'повреждение фундамента',
    'отсутствует маркировка',
    'другое',
  ];
}
