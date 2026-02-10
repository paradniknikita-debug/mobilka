/**
 * CIM-совместимые модели для структуры линий электропередачи
 */

export interface ConnectivityNode {
  id: number;
  mrid: string;
  name: string;
  pole_id: number;
  latitude: number;
  longitude: number;
  description?: string;
  created_at: string;
  updated_at?: string;
}

export interface ConnectivityNodeCreate {
  name: string;
  pole_id: number;
  latitude: number;
  longitude: number;
  description?: string;
  mrid?: string;
}

export interface Terminal {
  id: number;
  mrid: string;
  name?: string;
  connectivity_node_id?: number;
  acline_segment_id?: number;
  conducting_equipment_id?: number;
  bay_id?: number;
  sequence_number: number;
  connection_direction: 'from' | 'to' | 'both';
  description?: string;
  created_at: string;
}

export interface TerminalCreate {
  name?: string;
  connectivity_node_id?: number;
  acline_segment_id?: number;
  conducting_equipment_id?: number;
  bay_id?: number;
  sequence_number?: number;
  connection_direction: 'from' | 'to' | 'both';
  description?: string;
  mrid?: string;
}

export interface LineSection {
  id: number;
  mrid: string;
  name: string;
  acline_segment_id: number;
  conductor_type: string;
  conductor_material?: string;
  conductor_section: string;
  r?: number;
  x?: number;
  b?: number;
  g?: number;
  sequence_number: number;
  total_length?: number;
  description?: string;
  created_by: number;
  created_at: string;
  updated_at?: string;
  spans?: Span[];
}

export interface LineSectionCreate {
  name: string;
  acline_segment_id: number;
  conductor_type: string;
  conductor_material?: string;
  conductor_section: string;
  r?: number;
  x?: number;
  b?: number;
  g?: number;
  sequence_number?: number;
  total_length?: number;
  description?: string;
  mrid?: string;
}

export interface AClineSegment {
  id: number;
  mrid: string;
  name: string;
  code: string;
  power_line_id: number;
  voltage_level: number;
  length: number;
  is_tap: boolean;
  tap_number?: string;
  from_connectivity_node_id: number;
  to_connectivity_node_id?: number;
  to_terminal_id?: number;
  sequence_number: number;
  conductor_type?: string;
  conductor_material?: string;
  conductor_section?: string;
  r?: number;
  x?: number;
  b?: number;
  g?: number;
  description?: string;
  created_by: number;
  created_at: string;
  updated_at?: string;
  line_sections?: LineSection[];
  terminals?: Terminal[];
}

export interface AClineSegmentCreate {
  name: string;
  code?: string; // Опциональный, генерируется на бэкенде
  power_line_id: number;
  voltage_level: number;
  length: number;
  is_tap?: boolean;
  tap_number?: string;
  from_connectivity_node_id: number;
  to_connectivity_node_id?: number;
  to_terminal_id?: number;
  sequence_number?: number;
  conductor_type?: string;
  conductor_material?: string;
  conductor_section?: string;
  r?: number;
  x?: number;
  b?: number;
  g?: number;
  description?: string;
  mrid?: string;
}

export interface Span {
  // Для обратной совместимости
  power_line_id?: number;
  from_pole_id?: number;
  to_pole_id?: number;
  id: number;
  mrid: string;
  line_section_id: number;
  from_connectivity_node_id: number;
  to_connectivity_node_id: number;
  span_number: string;
  length: number;
  sequence_number: number;
  conductor_type?: string;
  conductor_material?: string;
  conductor_section?: string;
  tension?: number;
  sag?: number;
  notes?: string;
  created_by: number;
  created_at: string;
  // Связанные объекты
  from_connectivity_node?: ConnectivityNode;
  to_connectivity_node?: ConnectivityNode;
}

export interface SpanCreate {
  line_section_id: number;
  from_connectivity_node_id: number;
  to_connectivity_node_id: number;
  span_number: string;
  length: number;
  sequence_number?: number;
  conductor_type?: string;
  conductor_material?: string;
  conductor_section?: string;
  tension?: number;
  sag?: number;
  notes?: string;
  mrid?: string;
  // Для обратной совместимости
  power_line_id?: number;
  from_pole_id?: number;
  to_pole_id?: number;
}

export interface PoleSequenceResponse {
  message: string;
  sequence: Array<{
    id: number;
    pole_number: string;
    sequence: number;
  }>;
}

