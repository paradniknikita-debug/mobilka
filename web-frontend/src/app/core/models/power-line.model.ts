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
}

