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
  added?: boolean;   // только после (новое значение)
  removed?: boolean; // только до (удалённое значение)
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

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: ChangeLogDetailDialogData,
    private dialogRef: MatDialogRef<ChangeLogDetailDialogComponent>
  ) {
    this.entry = data.entry;
    this.buildRows();
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

  actionLabel(action: string): string {
    const labels: Record<string, string> = {
      create: 'Создание', update: 'Изменение', delete: 'Удаление',
      session_start: 'Начало сессии', session_end: 'Завершение сессии'
    };
    return labels[action] ?? action;
  }

  entityTypeLabel(type: string): string {
    const labels: Record<string, string> = {
      pole: 'Опора', power_line: 'Линия', span: 'Пролёт', substation: 'Подстанция',
      equipment: 'Оборудование', acline_segment: 'Участок линии', line_section: 'Секция линии', session: 'Сессия'
    };
    return labels[type] ?? type;
  }

  close(): void {
    this.dialogRef.close();
  }
}
