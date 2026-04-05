export interface PowerLine {
  id: number;
  mrid: string;
  name: string;
  voltage_level: number;
  length?: number;
  region_id?: number;
  branch_id?: number;
  status: string;
  description?: string;
  created_at: string;
  updated_at?: string;
  substation_start_id?: number | null;
  substation_end_id?: number | null;
  /** Сегменты линии (участки), в т.ч. отпайки — для привязки ТП в конце отпайки */
  acline_segments?: Array<{
    id: number;
    name?: string;
    is_tap?: boolean;
    to_substation_id?: number | null;
    to_pole_id?: number | null;
    to_pole_display_name?: string | null;
  }>;
}

export interface PowerLineCreate {
  name: string;
  voltage_level?: number;
  length?: number;
  branch_name?: string; // Административная принадлежность (текстовое поле)
  region_name?: string; // Географический регион (текстовое поле)
  status?: string;
  description?: string;
  mrid?: string; // Опциональный UID, если не указан - генерируется автоматически
  substation_start_id?: number | null;
  substation_end_id?: number | null;
}

