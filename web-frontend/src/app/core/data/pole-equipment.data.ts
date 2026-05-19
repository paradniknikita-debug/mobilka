export interface PoleEquipmentCategory {
  title: string;
  equipmentType: string;
  singleInstance?: boolean;
}

/** Категории оборудования на опоре (как во Flutter create_pole_dialog). */
export const POLE_EQUIPMENT_CATEGORIES: PoleEquipmentCategory[] = [
  { title: 'Фундамент', equipmentType: 'фундамент', singleInstance: true },
  { title: 'Изоляторы', equipmentType: 'изолятор' },
  { title: 'Траверсы', equipmentType: 'траверса' },
  { title: 'Грозоотвод', equipmentType: 'грозоотвод', singleInstance: true },
  { title: 'Разрядники', equipmentType: 'разрядник' },
  { title: 'Разъединители', equipmentType: 'disconnector' },
  { title: 'Реклоузеры', equipmentType: 'recloser' },
  { title: 'ЗН', equipmentType: 'grounding_switch', singleInstance: true },
];

export function isElectricalEquipmentType(type: string): boolean {
  const t = (type || '').toLowerCase();
  return ['disconnector', 'breaker', 'recloser', 'grounding_switch', 'surge_arrester', 'разрядник', 'выключатель', 'реклоузер'].some(
    (x) => t.includes(x),
  );
}
