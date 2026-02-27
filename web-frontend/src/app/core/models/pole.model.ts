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
  /** 'main' — магистраль, 'tap' — отпайка */
  branch_type?: string | null;
  /** id отпаечной опоры, от которой идёт эта ветка (для отпайки) */
  tap_pole_id?: number | null;
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
  /** Порядок опоры в линии (1, 2, 3…). Если не задан — назначается автоматически. */
  sequence_number?: number;
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
  /** Направление после отпаечной опоры: 'main' — магистраль, 'tap' — отпайка */
  branch_type?: string | null;
  /** id отпаечной опоры (при выборе «По отпайке») */
  tap_pole_id?: number | null;
  /** Марка провода (AC-70 и т.д.) — для автосоздания пролёта */
  conductor_type?: string;
  /** Материал провода (алюминий, медь) */
  conductor_material?: string;
  /** Сечение провода, мм² */
  conductor_section?: string;
}

