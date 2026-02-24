export interface Substation {
  id: number;
  mrid: string;
  name: string;
  /** Диспетчерское наименование (в UI показываем как UID) */
  dispatcher_name?: string;
  code?: string; // устаревшее, для обратной совместимости
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
  /** UID в формате системы (как у остальных сущностей); если не передан — генерируется на бэкенде */
  mrid?: string;
  /** Диспетчерское наименование (по желанию пользователя) */
  dispatcher_name?: string;
  voltage_level: number;
  latitude: number;
  longitude: number;
  address?: string;
  region_id?: number;
  branch_id?: number;
  description?: string;
  is_active?: boolean;
}

