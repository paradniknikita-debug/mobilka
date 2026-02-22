/** Координаты по CIM: x_position = долгота (longitude), y_position = широта (latitude). */
export interface Pole {
  id: number;
  mrid: string;
  power_line_id: number;
  segment_id?: number;
  connectivity_node_id?: number;
  pole_number: string;
  sequence_number?: number;
  is_tap_pole?: boolean;
  /** Долгота (longitude) */
  x_position: number;
  /** Широта (latitude) */
  y_position: number;
  pole_type: string;
  height?: number;
  material?: string;
  condition?: string;
  installation_date?: string;
  created_at: string;
  updated_at?: string;
  connectivity_node?: any;
}

export interface PoleCreate {
  power_line_id: number;
  segment_id?: number;
  pole_number: string;
  /** Долгота (longitude) */
  x_position: number;
  /** Широта (latitude) */
  y_position: number;
  pole_type: string;
  mrid?: string;
  height?: number;
  foundation_type?: string;
  material?: string;
  year_installed?: number;
  condition?: string;
  notes?: string;
  is_tap?: boolean;
}

