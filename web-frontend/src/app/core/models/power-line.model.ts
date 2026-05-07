export interface PowerLine {
  id: number;
  mrid: string;
  name: string;
  voltage_level: number;
  length?: number;
  dispatcher_name?: string;
  branch_name?: string;
  region_name?: string;
  region_uid?: string;
  balance_ownership?: string;
  parent_object_ref?: string;
  alcs_ref?: string;
  region_id?: number;
  branch_id?: number;
  status: string;
  description?: string;
  created_at: string;
  updated_at?: string;
  substation_start_id?: number | null;
  substation_end_id?: number | null;
  poles?: Array<{
    id: number;
    mrid?: string;
    pole_number?: string;
    sequence_number?: number | null;
    line_id?: number;
    x_position?: number | null;
    y_position?: number | null;
    pole_type?: string;
  }>;
  /** Сегменты линии (участки), в т.ч. отпайки — для привязки ТП в конце отпайки */
  acline_segments?: Array<{
    id: number;
    mrid?: string;
    name?: string;
    is_tap?: boolean;
    line_sections?: Array<{
      id: number;
      mrid?: string;
      spans?: Array<{
        id: number;
        mrid?: string;
        span_number?: string;
      }>;
    }>;
    to_substation_id?: number | null;
    to_pole_id?: number | null;
    to_pole_display_name?: string | null;
  }>;
}

export interface PowerLineCreate {
  name: string;
  voltage_level?: number;
  length?: number;
  dispatcher_name?: string;
  branch_name?: string; // Административная принадлежность (текстовое поле)
  region_name?: string; // Географический регион (текстовое поле)
  region_uid?: string;
  balance_ownership?: string;
  parent_object_ref?: string;
  alcs_ref?: string;
  status?: string;
  description?: string;
  mrid?: string; // Опциональный UID, если не указан - генерируется автоматически
  substation_start_id?: number | null;
  substation_end_id?: number | null;
}

