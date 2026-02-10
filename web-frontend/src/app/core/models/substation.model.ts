export interface Substation {
  id: number;
  mrid: string;
  name: string;
  code: string;
  voltage_level: number;
  latitude: number;
  longitude: number;
  address?: string;
  region_id?: number;
  branch_id?: number;
  is_active: boolean;
  created_at: string;
  updated_at?: string;
}

export interface SubstationCreate {
  name: string;
  code: string;
  voltage_level: number;
  latitude: number;
  longitude: number;
  address?: string;
  region_id?: number;
  branch_id?: number;
  description?: string;
  is_active?: boolean;
}

