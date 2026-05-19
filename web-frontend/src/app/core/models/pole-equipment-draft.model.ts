import { Equipment } from './equipment.model';

/** Черновик / позиция оборудования в карточке опоры. */
export interface PoleEquipmentDraft {
  localKey: string;
  serverId?: number;
  categoryTitle: string;
  equipmentType: string;
  name: string;
  quantity: number;
  defect?: string | null;
  criticality?: string | null;
  nameplate?: string | null;
  ratedCurrent?: number | null;
  iTh?: number | null;
  ipMax?: number | null;
  tTh?: number | null;
  /** Помечено на удаление (при сохранении опоры). */
  markedDelete?: boolean;
}

export function equipmentToDraft(eq: Equipment, categoryTitle?: string): PoleEquipmentDraft {
  return {
    localKey: `srv-${eq.id}`,
    serverId: eq.id,
    categoryTitle: categoryTitle || guessCategoryFromType(eq.equipment_type),
    equipmentType: eq.equipment_type,
    name: eq.name,
    quantity: 1,
    defect: eq.defect ?? null,
    criticality: eq.criticality ?? null,
    nameplate: eq.nameplate ?? null,
    ratedCurrent: eq.rated_current ?? null,
    iTh: eq.i_th ?? null,
    ipMax: eq.ip_max ?? null,
    tTh: eq.t_th ?? null,
  };
}

function guessCategoryFromType(equipmentType: string): string {
  const t = (equipmentType || '').toLowerCase();
  if (t.includes('фундамент') || t === 'foundation') return 'Фундамент';
  if (t.includes('изолятор')) return 'Изоляторы';
  if (t.includes('траверс')) return 'Траверсы';
  if (t.includes('гроз')) return 'Грозоотвод';
  if (t.includes('разряд') || t.includes('arrester') || t.includes('opn')) return 'Разрядники';
  if (t.includes('разъедин') || t === 'disconnector') return 'Разъединители';
  if (t.includes('реклоуз') || t === 'recloser') return 'Реклоузеры';
  if (t.includes('grounding') || t === 'zn' || t.includes('зн')) return 'ЗН';
  return 'Прочее';
}
