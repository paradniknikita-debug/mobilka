/**
 * Параметры экспорта CIM, соответствующие query API /cim/export/xml и /cim/export/552-diff
 */
export interface CimExportOptions {
  includeSubstations: boolean;
  includePowerLines: boolean;
  /** Только FullModel XML; для 552 не используется */
  useCimpy: boolean;
  includeGps: boolean;
  includeSubstationVoltageLevels: boolean;
  includeElectricalModel: boolean;
  includeEquipment: boolean;
  includeDefects: boolean;
}

export function defaultCimExportOptions(): CimExportOptions {
  return {
    includeSubstations: true,
    includePowerLines: true,
    useCimpy: true,
    includeGps: true,
    includeSubstationVoltageLevels: true,
    includeElectricalModel: true,
    includeEquipment: true,
    includeDefects: true,
  };
}

export function cloneCimExportOptions(o: CimExportOptions): CimExportOptions {
  return { ...o };
}
