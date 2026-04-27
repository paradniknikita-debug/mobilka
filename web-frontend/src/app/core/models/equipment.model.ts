export interface Equipment {
  id: number;
  mrid: string;
  pole_id: number;
  /** Краткое имя/обозначение (например, «QF-1» или «Разъединитель 10 кВ») */
  name: string;
  /** Тип оборудования (выключатель, разъединитель, ЗН, разрядник и т.п.) */
  equipment_type: string;
  manufacturer?: string;
  model?: string;
  serial_number?: string;
  /** Год выпуска (опционально) */
  year_manufactured?: number;
  /** Дата установки (ISO-строка) */
  installation_date?: string;
  /** Текстовое состояние/примечание (good / poor и т.п.) */
  condition?: string;
  /** Доп. описание и характеристики (в т.ч. ном. ток/напряжение, марка) */
  notes?: string;
  /** Описание дефекта */
  defect?: string | null;
  /** Критичность: low | medium | high */
  criticality?: string | null;
  /** Координаты оборудования как отдельного объекта (CIM: x_position = longitude, y_position = latitude) */
  x_position?: number;
  y_position?: number;
  catalog_item_id?: number;
  rated_current?: number;
  i_th?: number;
  ip_max?: number;
  t_th?: number;
  normal_open?: boolean;
  retained?: boolean;
  created_at: string;
  updated_at?: string;
}

export interface EquipmentCreate {
  pole_id: number;
  name: string;
  equipment_type: string;
  manufacturer?: string;
  model?: string;
  serial_number?: string;
  year_manufactured?: number;
  installation_date?: string;
  condition?: string;
  notes?: string;
  defect?: string | null;
  criticality?: string | null;
  x_position?: number;
  y_position?: number;
  catalog_item_id?: number;
  rated_current?: number;
  i_th?: number;
  ip_max?: number;
  t_th?: number;
  normal_open?: boolean;
  retained?: boolean;
}

