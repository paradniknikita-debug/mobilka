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
  /** CIM IdentifiedObject.description — номер единицы оборудования */
  identified_object_description?: string | null;
  /** CIM me:Equipment.nameplate */
  nameplate?: string | null;
  /** Подтип ПСР: retractable | sectionalizer */
  psr_subtype?: string | null;
  /** Название электроустановки (для отображения; в CIM контейнер — ЛЭП) */
  installation_display_name?: string | null;
  tm_code?: string | null;
  object_subtype?: string | null;
  pole_count?: number | null;
  parent_object_ref?: string | null;
  parent_main_equipment_pole_ref?: string | null;
  nominal_voltage_kv?: number | null;
  nominal_breaking_current_ka?: number | null;
  own_trip_time_sec?: number | null;
  emergency_current_a?: number | null;
  continuous_current_a?: number | null;
  arrester_type?: string | null;
  /** Комментарий карточки (JSON-история, как у опоры) */
  card_comment?: string | null;
  /** Вложения карточки (JSON массив с url) */
  card_comment_attachment?: string | null;
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
  identified_object_description?: string | null;
  nameplate?: string | null;
  psr_subtype?: string | null;
  installation_display_name?: string | null;
  tm_code?: string | null;
  object_subtype?: string | null;
  pole_count?: number | null;
  parent_object_ref?: string | null;
  parent_main_equipment_pole_ref?: string | null;
  nominal_voltage_kv?: number | null;
  nominal_breaking_current_ka?: number | null;
  own_trip_time_sec?: number | null;
  emergency_current_a?: number | null;
  continuous_current_a?: number | null;
  arrester_type?: string | null;
  card_comment?: string | null;
  card_comment_attachment?: string | null;
}

