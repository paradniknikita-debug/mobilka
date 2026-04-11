/** Координаты по CIM: x_position = долгота (longitude), y_position = широта (latitude). */
export interface Pole {
  id: number;
  mrid: string;
  /** Единое поле line_id (без приставки power). */
  line_id: number;
  segment_id?: number;
  connectivity_node_id?: number;
  pole_number: string;
  sequence_number?: number;
  is_tap_pole?: boolean;
  /** 'main' — магистраль, 'tap' — отпайка */
  branch_type?: string | null;
  /** id отпаечной опоры, от которой идёт эта ветка (для отпайки) */
  tap_pole_id?: number | null;
  /** Номер ветки от одной отпаечной опоры (1, 2, …) */
  tap_branch_index?: number | null;
  /** Долгота (longitude) */
  x_position: number;
  /** Широта (latitude) */
  y_position: number;
  pole_type: string;
  height?: number;
  /** Тип фундамента (не отображать как оборудование в дереве) */
  foundation_type?: string | null;
  material?: string;
  condition?: string;
  /** Дефект конструкции опоры */
  structural_defect?: string | null;
  structural_defect_criticality?: string | null;
  installation_date?: string;
  created_at: string;
  updated_at?: string;
  connectivity_node?: any;
  /** Комментарий карточки опоры */
  card_comment?: string | null;
  /** Вложения карточки: JSON-массив [{t: 'photo'|'voice'|'schema', url: string}] */
  card_comment_attachment?: string | null;
  segment_name?: string;
  power_line_name?: string;
  equipment?: any[];
  terminals?: any[];
}

export interface PoleCreate {
  line_id: number;
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
  structural_defect?: string;
  structural_defect_criticality?: string | null;
  is_tap?: boolean;
  /** Направление после отпаечной опоры: 'main' — магистраль, 'tap' — отпайка */
  branch_type?: string | null;
  /** id отпаечной опоры (при выборе «По отпайке») */
  tap_pole_id?: number | null;
  /** Номер ветки от одной отпаечной (1, 2, …); при продолжении существующей отпайки */
  tap_branch_index?: number | null;
  /** Начать новую отпайку от tap_pole_id (вторая/третья ветка от одной опоры) */
  start_new_tap?: boolean;
  /** Марка провода (AC-70 и т.д.) — для автосоздания пролёта */
  conductor_type?: string;
  /** Материал провода (алюминий, медь) */
  conductor_material?: string;
  /** Сечение провода, мм² */
  conductor_section?: string;
  /** Комментарий карточки опоры (для обновления) */
  card_comment?: string | null;
  /** Вложения карточки: JSON [{t, url}] (для обновления) */
  card_comment_attachment?: string | null;
}

