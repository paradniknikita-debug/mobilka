export interface Equipment {
  id: number;
  mrid: string;
  pole_id: number;
  equipment_type: string;
  manufacturer?: string;
  model?: string;
  serial_number?: string;
  installation_date?: string;
  condition?: string;
  created_at: string;
  updated_at?: string;
}

export interface EquipmentCreate {
  pole_id: number;
  equipment_type: string;
  manufacturer?: string;
  model?: string;
  serial_number?: string;
  installation_date?: string;
  condition?: string;
}

