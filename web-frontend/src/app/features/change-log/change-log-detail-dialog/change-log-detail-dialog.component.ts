import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ChangeLogEntry, ChangeLogPayload } from '../../../core/models/change-log.model';

export interface ChangeLogDetailDialogData {
  entry: ChangeLogEntry;
}

interface KeyValueRow {
  key: string;
  before: string;
  after: string;
  changed: boolean;
  added?: boolean;
  removed?: boolean;
}

interface JsonDiffLine {
  tag: ' ' | '-' | '+';
  text: string;
}

interface SessionItemPreview {
  created_at?: string | null;
  action?: string;
  entity_type?: string;
  entity_id?: number | null;
  payload?: unknown;
}

interface SessionSummary {
  by_action?: Record<string, number>;
  by_entity?: Record<string, number>;
  items_preview?: SessionItemPreview[];
}

@Component({
  selector: 'app-change-log-detail-dialog',
  templateUrl: './change-log-detail-dialog.component.html',
  styleUrls: ['./change-log-detail-dialog.component.scss']
})
export class ChangeLogDetailDialogComponent {
  entry: ChangeLogEntry;
  onlyChanges = false;
  rows: KeyValueRow[] = [];
  isMaximized = false;

  /** Payload как словарь для шаблона (строгий strictTemplates). */
  get pl(): Record<string, unknown> | null {
    const p = this.entry.payload;
    return p && typeof p === 'object' ? (p as Record<string, unknown>) : null;
  }

  get sessionSummary(): SessionSummary | null {
    const p = this.pl;
    const ss = p?.['session_summary'];
    if (!ss || typeof ss !== 'object') return null;
    return ss as SessionSummary;
  }

  /** События вложений карточки опоры для *ngFor. */
  get attachmentEventsList(): { label_ru?: string; kind?: string }[] {
    const raw = this.pl?.['attachment_events'];
    if (!Array.isArray(raw)) return [];
    return raw as { label_ru?: string; kind?: string }[];
  }

  /** Полная запись журнала (JSON). */
  get fullEntryJson(): string {
    return JSON.stringify(this.entry, null, 2);
  }

  /** Пересборка топологии: объединённый отчёт (payload целиком + служебные поля). */
  get topologyMergedJson(): string | null {
    const p = this.pl;
    if (!p || p['topology_rebuild'] !== true) return null;
    const merged = {
      ...p,
      entity_type: this.entry.entity_type,
      entity_id: this.entry.entity_id,
      entity_name: this.entry.entity_name,
      action: this.entry.action,
      created_at: this.entry.created_at,
      user_name: this.entry.user_name,
      source: this.entry.source,
    };
    return JSON.stringify(merged, null, 2);
  }

  /** Создание / удаление: один объект в JSON. */
  get singleObjectJson(): string | null {
    if (this.pl?.['topology_rebuild'] === true) return null;
    if (this.hasPayload || this.pl?.['pole_card'] === true || this.pl?.['data_quality_warning'] === true) {
      return null;
    }
    if (!this.entry.payload) return null;
    return JSON.stringify(this.entry.payload, null, 2);
  }

  get jsonDiffLines(): JsonDiffLine[] {
    const p = this.entry.payload as ChangeLogPayload | Record<string, unknown> | null;
    if (!p || typeof p !== 'object') return [];
    const oldVal = (p as any).old_value ?? (p as any).before;
    const newVal = (p as any).new_value ?? (p as any).after;
    if (oldVal === undefined && newVal === undefined) return [];
    return this.buildUnifiedJsonDiff(oldVal, newVal);
  }

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: ChangeLogDetailDialogData,
    private dialogRef: MatDialogRef<ChangeLogDetailDialogComponent>
  ) {
    this.entry = data.entry;
    this.buildRows();
  }

  private buildUnifiedJsonDiff(oldVal: unknown, newVal: unknown): JsonDiffLine[] {
    const a = oldVal !== undefined && oldVal !== null ? JSON.stringify(oldVal, null, 2) : '';
    const b = newVal !== undefined && newVal !== null ? JSON.stringify(newVal, null, 2) : '';
    const la = a ? a.split('\n') : [];
    const lb = b ? b.split('\n') : [];
    const n = Math.max(la.length, lb.length);
    const out: JsonDiffLine[] = [];
    for (let i = 0; i < n; i++) {
      const ka = la[i];
      const kb = lb[i];
      if (ka === kb) {
        out.push({ tag: ' ', text: ka ?? '' });
      } else {
        if (ka !== undefined) out.push({ tag: '-', text: ka });
        if (kb !== undefined) out.push({ tag: '+', text: kb });
      }
    }
    return out;
  }

  private buildRows(): void {
    const p = this.entry.payload as ChangeLogPayload | null;
    const oldVal = (p?.old_value ?? p?.['before']) as Record<string, unknown> | undefined;
    const newVal = (p?.new_value ?? p?.['after']) as Record<string, unknown> | undefined;
    const allKeys = new Set<string>();
    if (oldVal && typeof oldVal === 'object') Object.keys(oldVal).forEach(k => allKeys.add(k));
    if (newVal && typeof newVal === 'object') Object.keys(newVal).forEach(k => allKeys.add(k));
    this.rows = Array.from(allKeys).map(key => {
      const b = oldVal?.[key];
      const a = newVal?.[key];
      const beforeStr = b === undefined || b === null ? '—' : JSON.stringify(b);
      const afterStr = a === undefined || a === null ? '—' : JSON.stringify(a);
      const added = beforeStr === '—' && afterStr !== '—';
      const removed = beforeStr !== '—' && afterStr === '—';
      const changed = !added && !removed && beforeStr !== afterStr;
      return { key, before: beforeStr, after: afterStr, changed, added, removed };
    }).sort((a, b) => a.key.localeCompare(b.key));
  }

  get displayedRows(): KeyValueRow[] {
    if (this.onlyChanges) return this.rows.filter(r => r.changed || r.added || r.removed);
    return this.rows;
  }

  get hasPayload(): boolean {
    const p = this.entry.payload;
    if (!p) return false;
    if ((p as any).pole_card === true) return false;
    if ((p as any).data_quality_warning === true) return false;
    const oldVal = (p as any).old_value ?? (p as any).before;
    const newVal = (p as any).new_value ?? (p as any).after;
    return (oldVal && typeof oldVal === 'object' && Object.keys(oldVal).length > 0) ||
           (newVal && typeof newVal === 'object' && Object.keys(newVal).length > 0);
  }

  get payloadRest(): Record<string, unknown> {
    const p = this.entry.payload as Record<string, unknown> | null;
    if (!p) return {};
    const omit = new Set(['old_value', 'new_value', 'before', 'after', 'name', 'mrid', 'uid']);
    return Object.fromEntries(Object.entries(p).filter(([k]) => !omit.has(k)));
  }

  formatDate(s: string): string {
    return s ? new Date(s).toLocaleString('ru-RU') : '—';
  }

  actionLabel(action: string | undefined | null): string {
    if (!action) return '—';
    const labels: Record<string, string> = {
      create: 'Создание',
      update: 'Изменение',
      delete: 'Удаление',
      session_start: 'Начало сессии',
      session_end: 'Завершение сессии',
      topology_rebuild: 'Пересборка топологии',
      pole_card_update: 'Обновление карточки опоры',
      defect_add: 'Добавление дефекта',
      defect_update: 'Изменение дефекта',
      defect_media_add: 'Добавление медиа дефекта',
    };
    return labels[action] ?? action;
  }

  entityTypeLabel(type: string | undefined | null): string {
    if (!type) return '—';
    const labels: Record<string, string> = {
      pole: 'Опора', power_line: 'Линия', span: 'Пролёт', substation: 'Подстанция',
      equipment: 'Оборудование', acline_segment: 'Участок линии', line_section: 'Секция линии', session: 'Сессия'
    };
    return labels[type] ?? type;
  }

  toggleMaximize(): void {
    this.isMaximized = !this.isMaximized;
    if (this.isMaximized) {
      this.dialogRef.updateSize('min(96vw, 1200px)', '90vh');
      this.dialogRef.addPanelClass('change-log-detail--maximized');
    } else {
      this.dialogRef.updateSize('min(96vw, 720px)', undefined);
      this.dialogRef.removePanelClass('change-log-detail--maximized');
    }
  }

  close(): void {
    this.dialogRef.close();
  }
}
