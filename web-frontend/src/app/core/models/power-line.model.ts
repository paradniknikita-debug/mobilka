export interface PowerLine {
  id: number;
  mrid: string;
  name: string;
  code: string;
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
  code: string;
  voltage_level: number;
  length?: number;
  region_id?: number;
  branch_id?: number;
  status?: string;
  description?: string;
}

