import { EquipmentCreate } from '../models/equipment.model';
import { PoleEquipmentDraft } from '../models/pole-equipment-draft.model';
import { isElectricalEquipmentType } from '../data/pole-equipment.data';

export function buildEquipmentCreateBody(
  draft: PoleEquipmentDraft,
  poleId: number,
  lineVoltageKv?: number | null,
): EquipmentCreate {
  const isElectrical = isElectricalEquipmentType(draft.equipmentType);
  const notesParts: string[] = [];
  if (draft.quantity > 1) notesParts.push(`количество: ${draft.quantity}`);

  return {
    pole_id: poleId,
    name: draft.name.trim(),
    equipment_type: draft.equipmentType,
    condition: 'good',
    defect: draft.defect?.trim() || null,
    criticality: draft.criticality || null,
    nameplate: draft.nameplate?.trim() || null,
    rated_current: isElectrical && draft.ratedCurrent != null ? Number(draft.ratedCurrent) : undefined,
    i_th: isElectrical && draft.iTh != null ? Number(draft.iTh) : undefined,
    ip_max: isElectrical && draft.ipMax != null ? Number(draft.ipMax) : undefined,
    t_th: isElectrical && draft.tTh != null ? Number(draft.tTh) : undefined,
    normal_open: isElectrical ? true : undefined,
    retained: isElectrical ? true : undefined,
    installation_display_name: isElectrical ? 'ЛЭП' : undefined,
    nominal_voltage_kv:
      isElectrical && lineVoltageKv != null && Number.isFinite(lineVoltageKv) ? Number(lineVoltageKv) : undefined,
    notes: notesParts.length ? notesParts.join('; ') : undefined,
    psr_subtype:
      draft.equipmentType === 'disconnector' || draft.equipmentType === 'grounding_switch'
        ? 'retractable'
        : undefined,
    pole_count:
      draft.equipmentType === 'breaker' || draft.equipmentType === 'recloser' ? 2 : 1,
  };
}
