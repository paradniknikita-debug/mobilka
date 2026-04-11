export interface EquipmentCatalogItem {
  id: number;
  type_code: string;
  brand: string;
  model: string;
  full_name?: string | null;
  voltage_kv?: number | null;
  current_a?: number | null;
  manufacturer?: string | null;
  country?: string | null;
  description?: string | null;
  attrs_json?: string | null;
  is_active: boolean;
  created_by?: number | null;
  created_at: string;
  updated_at?: string | null;
}

export interface EquipmentCatalogCreate {
  type_code: string;
  brand: string;
  model: string;
  full_name?: string | null;
  voltage_kv?: number | null;
  current_a?: number | null;
  manufacturer?: string | null;
  country?: string | null;
  description?: string | null;
  attrs_json?: string | null;
  is_active?: boolean;
}

