/** Справочник дефектов (синхронизирован с Flutter DefectReferenceData). */
export interface DefectItem {
  name: string;
  criticality: 'low' | 'medium' | 'high';
  allowedCategoryTitles?: string[];
}

export const OTHER_DEFECT_KEY = 'Иной дефект';

export const CRITICALITY_LABELS: Record<string, string> = {
  low: 'Низкая',
  medium: 'Средняя',
  high: 'Высокая',
};

export const DEFECT_ITEMS: DefectItem[] = [
  { name: 'Трещины бетона', criticality: 'high', allowedCategoryTitles: ['Фундамент'] },
  { name: 'Разрушение бетона', criticality: 'high', allowedCategoryTitles: ['Фундамент'] },
  { name: 'Просадка фундамента', criticality: 'medium', allowedCategoryTitles: ['Фундамент'] },
  { name: 'Оголение арматуры', criticality: 'medium', allowedCategoryTitles: ['Фундамент'] },
  { name: 'Трещина изолятора', criticality: 'high', allowedCategoryTitles: ['Изоляторы'] },
  { name: 'Сколы изолятора', criticality: 'medium', allowedCategoryTitles: ['Изоляторы'] },
  { name: 'Загрязнение изолятора', criticality: 'medium', allowedCategoryTitles: ['Изоляторы'] },
  { name: 'Пробой изолятора', criticality: 'high', allowedCategoryTitles: ['Изоляторы'] },
  { name: 'Коррозия траверсы', criticality: 'medium', allowedCategoryTitles: ['Траверсы'] },
  { name: 'Деформация траверсы', criticality: 'medium', allowedCategoryTitles: ['Траверсы'] },
  { name: 'Ослабление креплений траверсы', criticality: 'medium', allowedCategoryTitles: ['Траверсы'] },
  { name: 'Коррозия заземляющего проводника', criticality: 'medium', allowedCategoryTitles: ['ЗН'] },
  { name: 'Обрыв заземляющего проводника', criticality: 'high', allowedCategoryTitles: ['ЗН'] },
  { name: 'Нет соединения с контуром', criticality: 'high', allowedCategoryTitles: ['ЗН'] },
  { name: 'Обрыв грозотроса', criticality: 'high', allowedCategoryTitles: ['Грозоотвод'] },
  { name: 'Коррозия грозотроса', criticality: 'medium', allowedCategoryTitles: ['Грозоотвод'] },
  { name: 'Следы срабатывания разрядника', criticality: 'medium', allowedCategoryTitles: ['Разрядники'] },
  { name: 'Трещины фарфора разрядника', criticality: 'high', allowedCategoryTitles: ['Разрядники'] },
  { name: 'Разрушение корпуса разрядника', criticality: 'high', allowedCategoryTitles: ['Разрядники'] },
  { name: 'Подгорание контактов', criticality: 'medium', allowedCategoryTitles: ['Разъединители', 'ЗН'] },
  { name: 'Неполное размыкание контактов', criticality: 'high', allowedCategoryTitles: ['Разъединители', 'ЗН'] },
  { name: 'Заедание привода', criticality: 'medium', allowedCategoryTitles: ['Разъединители', 'ЗН'] },
  { name: 'Некорректная работа автоматики реклоузера', criticality: 'high', allowedCategoryTitles: ['Реклоузеры'] },
  { name: 'Подгорание контактов реклоузера', criticality: 'medium', allowedCategoryTitles: ['Реклоузеры'] },
  { name: 'Повреждение корпуса реклоузера', criticality: 'medium', allowedCategoryTitles: ['Реклоузеры'] },
  { name: 'Коррозия металлических элементов', criticality: 'medium' },
  { name: 'Отклонение опоры от вертикали', criticality: 'medium' },
  { name: 'Отсутствует маркировка', criticality: 'low' },
];

export function defectsForCategory(categoryTitle: string | null | undefined): DefectItem[] {
  if (!categoryTitle) return DEFECT_ITEMS;
  return DEFECT_ITEMS.filter(
    (d) => !d.allowedCategoryTitles || d.allowedCategoryTitles.includes(categoryTitle),
  );
}

export function defaultCriticalityForDefect(defectName: string, categoryTitle?: string): string | null {
  const list = defectsForCategory(categoryTitle);
  const hit = list.find((d) => d.name === defectName);
  return hit?.criticality ?? null;
}
