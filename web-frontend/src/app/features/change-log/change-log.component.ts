import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { ChangeLogEntry, ModelIssue } from '../../core/models/change-log.model';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
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

  issues: ModelIssue[] = [];
  issuesColumns: string[] = ['issue_type', 'entity_type', 'entity_uid', 'line_uid', 'message'];
  issuesLoading = false;
  issuesError: string | null = null;
  selectedTabIndex = 0;

  constructor(
    private apiService: ApiService,
    private dialog: MatDialog,
    private snackBar: MatSnackBar
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

  loadIssues(): void {
    this.issuesLoading = true;
    this.issuesError = null;
    this.apiService.getChangeLogErrors().subscribe({
      next: (list) => {
        this.issues = list || [];
        this.issuesLoading = false;
      },
      error: (err) => {
        this.issuesError = err.error?.detail || err.message || 'Ошибка загрузки несоответствий';
        this.issuesLoading = false;
      }
    });
  }

  onTabChange(index: number): void {
    if (index === 1 && this.issues.length === 0 && !this.issuesLoading) {
      this.loadIssues();
    }
  }

  getName(entry: ChangeLogEntry): string {
    const p = entry.payload;
    if (!p) return entry.entity_name ?? '—';
    if (p['cascade'] === true && p['name']) {
      const parts = [`Линия «${p['name']}»`];
      if (p['deleted_poles']) parts.push(`${p['deleted_poles']} опор`);
      if (p['deleted_spans']) parts.push(`${p['deleted_spans']} пролётов`);
      if (p['deleted_segments']) parts.push(`${p['deleted_segments']} участков`);
      return parts.join(', ');
    }
    if (p['topology_rebuild'] === true) {
      const n = p['created_spans'];
      const msg = typeof p['message'] === 'string' ? p['message'] : 'Автосборка топологии';
      return n != null ? `${msg}: ${n} пролётов` : msg;
    }
    const v = p?.name ?? p?.['title'];
    return typeof v === 'string' ? v : (entry.entity_name ?? '—');
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
    return source === 'web' ? 'Веб' : source === 'flutter' ? 'Мобильное' : source;
  }

  issueTypeLabel(type: string): string {
    const labels: Record<string, string> = {
      orphan_pole: 'Опора без ЛЭП',
      orphan_span: 'Пролёт без секции',
      tap_pole_without_tap: 'Отпаечная опора без отпайки',
      line_break: 'Обрыв линии',
      orphan_connectivity_node: 'Узел без ЛЭП',
      orphan_line_section: 'Секция без участка'
    };
    return labels[type] ?? type;
  }

  entityTypeLabelForIssue(type: string): string {
    const labels: Record<string, string> = {
      pole: 'Опора',
      span: 'Пролёт',
      acline_segment: 'Участок',
      connectivity_node: 'Узел соединения',
      line_section: 'Секция линии'
    };
    return labels[type] ?? type;
  }

  openDetail(entry: ChangeLogEntry): void {
    this.dialog.open(ChangeLogDetailDialogComponent, {
      width: '700px',
      maxHeight: '90vh',
      data: { entry }
    });
  }

  /** Показать UID сокращённо (начало + «...») для копирования по клику */
  formatUidForDisplay(uid: string | null | undefined): string {
    if (!uid) return '—';
    return uid.length <= 12 ? uid : uid.slice(0, 8) + '…';
  }

  copyUidToClipboard(uid: string | null | undefined, event?: Event): void {
    if (!uid) return;
    event?.preventDefault();
    event?.stopPropagation();
    navigator.clipboard.writeText(uid).then(
      () => this.snackBar.open('UID скопирован', 'Закрыть', { duration: 2000 }),
      () => this.snackBar.open('Не удалось скопировать', 'Закрыть', { duration: 2000 })
    );
  }
}
