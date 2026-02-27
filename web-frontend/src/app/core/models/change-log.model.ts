export interface ChangeLogEntry {
  id: number;
  created_at: string;
  user_id: number | null;
  source: string;
  action: string;
  entity_type: string;
  entity_id: number | null;
  payload: ChangeLogPayload | null;
  session_id: string | null;
}

export interface ChangeLogPayload {
  name?: string;
  mrid?: string;
  old_value?: Record<string, unknown>;
  new_value?: Record<string, unknown>;
  [key: string]: unknown;
}

export interface ChangeLogFilters {
  source?: string;
  action?: string;
  entity_type?: string;
  limit?: number;
  offset?: number;
}

export interface ModelIssue {
  issue_type: string;
  entity_type: string;
  entity_id: number | null;
  line_id: number | null;
  message: string;
  details: Record<string, unknown> | null;
  entity_uid?: string | null;
  line_uid?: string | null;
}
