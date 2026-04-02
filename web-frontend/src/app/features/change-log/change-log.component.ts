import { Component, OnInit, ViewChild } from '@angular/core';
import { MatMenuTrigger } from '@angular/material/menu';
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
  @ViewChild('filterTrigger') filterMenuTrigger?: MatMenuTrigger;

  entries: ChangeLogEntry[] = [];
  displayedColumns: string[] = ['created_at', 'source', 'action', 'entity_type', 'name', 'uid', 'user_name', 'detail'];
  loading = true;
  error: string | null = null;

  // ========== Change log filters ==========
  logSource: string | null = null; // web | flutter
  logAction: string | null = null; // create | update | delete | session_start | session_end
  logEntityType: string | null = null; // pole, power_line, ...
  logEntityId: number | null = null;
  logFromDt: string | null = null;
  logToDt: string | null = null;

  /** Панель с кнопками «Фильтры» / «Применить» (стрелка сворачивает её) */
  filterToolbarExpanded = true;

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

  get activeFilterCount(): number {
    let n = 0;
    if (this.logSource != null) n++;
    if (this.logAction != null) n++;
    if (this.logEntityType != null) n++;
    if (this.logEntityId != null) n++;
    if (this.logFromDt != null && String(this.logFromDt).trim() !== '') n++;
    if (this.logToDt != null && String(this.logToDt).trim() !== '') n++;
    return n;
  }

  resetFilters(): void {
    this.logSource = null;
    this.logAction = null;
    this.logEntityType = null;
    this.logEntityId = null;
    this.logFromDt = null;
    this.logToDt = null;
  }

  applyFiltersFromMenu(): void {
    this.load();
    this.filterMenuTrigger?.closeMenu();
  }

  load(): void {
    this.loading = true;
    this.error = null;
    this.apiService.getChangeLog({
      limit: 200,
      source: this.logSource ?? undefined,
      action: this.logAction ?? undefined,
      entity_type: this.logEntityType ?? undefined,
      entity_id: this.logEntityId ?? undefined,
      from_dt: this.logFromDt ?? undefined,
      to_dt: this.logToDt ?? undefined,
    }).subscribe({
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
    // Обходы (сессии): из payload показываем линию и время
    if (entry.entity_type === 'patrol_session') {
      const lineName = (p['line_name'] as string) || 'ЛЭП';
      if (entry.action === 'session_start') {
        return `Обход: «${lineName}» (начало)`;
      }
      if (entry.action === 'session_end') {
        const started = p['started_at'] as string | undefined;
        const ended = p['ended_at'] as string | undefined;
        const note = p['note'] as string | undefined;
        let s = `Обход: «${lineName}» (завершён)`;
        if (started && ended) {
          try {
            const startDate = new Date(started).toLocaleString('ru-RU', { dateStyle: 'short', timeStyle: 'short' });
            const endDate = new Date(ended).toLocaleString('ru-RU', { dateStyle: 'short', timeStyle: 'short' });
            s += ` ${startDate} — ${endDate}`;
          } catch (_) {}
        }
        if (note && String(note).trim()) s += ` • ${String(note).trim()}`;
        return s;
      }
      return lineName;
    }
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
    /** Карточка опоры: вложения и комментарий (сервер формирует summary_ru) */
    if (p['pole_card'] === true && typeof p['summary_ru'] === 'string') {
      return p['summary_ru'] as string;
    }
    /** Предупреждение по качеству данных (например длина пролёта vs GPS) */
    if (p['data_quality_warning'] === true && typeof p['message_ru'] === 'string') {
      return p['message_ru'] as string;
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
      session_end: 'Завершение сессии',
      topology_rebuild: 'Пересборка топологии',
      pole_card_update: 'Обновление карточки опоры',
      defect_add: 'Добавление дефекта',
      defect_update: 'Изменение дефекта',
      defect_media_add: 'Добавление медиа дефекта',
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
      session: 'Сессия',
      patrol_session: 'Обход ЛЭП'
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
