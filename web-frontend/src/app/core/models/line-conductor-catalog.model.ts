export interface LineConductorCatalogItem {
  id: number;
  mark: string;
  voltage_kv: number;
  is_active: boolean;
  created_at: string;
  updated_at?: string | null;
}

export interface LineConductorCatalogCreate {
  mark: string;
  voltage_kv: number;
  is_active: boolean;
}
