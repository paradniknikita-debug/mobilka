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

function parseLegacyFromNotes(notes?: string | null): { defect: string | null; nameplate: string | null } {
  const text = (notes || '').trim();
  if (!text) return { defect: null, nameplate: null };
  let defect: string | null = null;
  const defectMatch = text.match(/дефект:\s*([^;]+)/i);
  if (defectMatch) defect = defectMatch[1].trim();
  let nameplate: string | null = null;
  const nameplateMatch = text.match(/марка\s*\(nameplate\):\s*([^;]+)/i);
  if (nameplateMatch) nameplate = nameplateMatch[1].trim();
  return { defect, nameplate };
}

export function equipmentToDraft(eq: Equipment, categoryTitle?: string): PoleEquipmentDraft {
  const legacy = parseLegacyFromNotes(eq.notes);
  const displayName =
    (eq.nameplate || legacy.nameplate || eq.name || '').trim() ||
    (eq.name || '').trim();
  return {
    localKey: `srv-${eq.id}`,
    serverId: eq.id,
    categoryTitle: categoryTitle || guessCategoryFromType(eq.equipment_type),
    equipmentType: eq.equipment_type,
    name: displayName,
    quantity: 1,
    defect: eq.defect?.trim() || legacy.defect,
    criticality: eq.criticality ?? null,
    nameplate: eq.nameplate?.trim() || legacy.nameplate,
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
