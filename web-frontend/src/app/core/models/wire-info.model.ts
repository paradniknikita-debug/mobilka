export interface WireInfoItem {
  id: number;
  mrid: string;
  name: string;
  code?: string | null;
  material: string;
  section: number;
  voltage_kv?: number | null;
  nominal_current?: number | null;
  i_th?: number | null;
  ip_max?: number | null;
  t_th?: number | null;
  r?: number | null;
  x?: number | null;
  b?: number | null;
  g?: number | null;
  max_operating_temperature?: number | null;
  breaking_load?: number | null;
  weight_per_length?: number | null;
  description?: string | null;
  in_service: boolean;
  is_active?: boolean;
  created_at: string;
  updated_at?: string | null;
}

export interface WireInfoCreate {
  name: string;
  code?: string | null;
  material?: string;
  section: number;
  voltage_kv?: number | null;
  nominal_current?: number | null;
  i_th?: number | null;
  ip_max?: number | null;
  t_th?: number | null;
  r?: number | null;
  x?: number | null;
  b?: number | null;
  g?: number | null;
  max_operating_temperature?: number | null;
  breaking_load?: number | null;
  weight_per_length?: number | null;
  description?: string | null;
  in_service?: boolean;
}
