import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { ChangeLogEntry } from '../../core/models/change-log.model';
import { MatDialog } from '@angular/material/dialog';
import { ChangeLogDetailDialogComponent } from './change-log-detail-dialog/change-log-detail-dialog.component';

@Component({
  selector: 'app-change-log',
  templateUrl: './change-log.component.html',
  styleUrls: ['./change-log.component.scss']
})
export class ChangeLogComponent implements OnInit {
  entries: ChangeLogEntry[] = [];
  displayedColumns: string[] = ['created_at', 'source', 'action', 'entity_type', 'name', 'uid', 'entity_id', 'user_id', 'detail'];
  loading = true;
  error: string | null = null;

  constructor(
    private apiService: ApiService,
    private dialog: MatDialog
  ) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.error = null;
    this.apiService.getChangeLog({ limit: 200 }).subscribe({
      next: (list) => {
        this.entries = list || [];
        this.loading = false;
      },
      error: (err) => {
        this.error = err.error?.detail || err.message || 'Ошибка загрузки журнала';
        this.loading = false;
      }
    });
  }

  getName(entry: ChangeLogEntry): string {
    const p = entry.payload;
    const v = p?.name ?? p?.['title'];
    return typeof v === 'string' ? v : '—';
  }

  getUid(entry: ChangeLogEntry): string {
    const p = entry.payload;
    const v = p?.mrid ?? p?.['uid'];
    return typeof v === 'string' ? v : '—';
  }

  formatDate(s: string): string {
    if (!s) return '—';
    const d = new Date(s);
    return d.toLocaleString('ru-RU');
  }

  actionLabel(action: string): string {
    const labels: Record<string, string> = {
      create: 'Создание',
      update: 'Изменение',
      delete: 'Удаление',
      session_start: 'Начало сессии',
      session_end: 'Завершение сессии'
    };
    return labels[action] ?? action;
  }

  entityTypeLabel(type: string): string {
    const labels: Record<string, string> = {
      pole: 'Опора',
      power_line: 'Линия',
      span: 'Пролёт',
      substation: 'Подстанция',
      equipment: 'Оборудование',
      acline_segment: 'Участок линии',
      line_section: 'Секция линии',
      session: 'Сессия'
    };
    return labels[type] ?? type;
  }

  sourceLabel(source: string): string {
    return source === 'web' ? 'Веб' : source === 'flutter' ? 'Flutter' : source;
  }

  openDetail(entry: ChangeLogEntry): void {
    this.dialog.open(ChangeLogDetailDialogComponent, {
      width: '700px',
      maxHeight: '90vh',
      data: { entry }
    });
  }
}
