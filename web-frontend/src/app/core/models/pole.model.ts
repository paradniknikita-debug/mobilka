export interface Pole {
  id: number;
  mrid: string;
  power_line_id: number;
  segment_id?: number;
  connectivity_node_id?: number;
  pole_number: string;
  sequence_number?: number;  // Порядковый номер опоры в линии
  is_tap_pole?: boolean;     // Отпаечная опора (конец участка ACLineSegment)
  latitude: number;
  longitude: number;
  pole_type: string;
  height?: number;
  material?: string;
  condition?: string;
  installation_date?: string;
  created_at: string;
  updated_at?: string;
  connectivity_node?: any;  // ConnectivityNode если есть
}

export interface PoleCreate {
  power_line_id: number;
  segment_id?: number;
  pole_number: string;
  latitude: number;
  longitude: number;
  pole_type: string;
  mrid?: string;  // Опциональный UID, если не указан - генерируется автоматически
  height?: number;
  foundation_type?: string;
  material?: string;
  year_installed?: number;
  condition?: string;
  notes?: string;
  is_tap?: boolean;  // Отпаечная опора при создании/обновлении
}

