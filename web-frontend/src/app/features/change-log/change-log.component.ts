import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { ChangeLogEntry, ModelIssue } from '../../core/models/change-log.model';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ChangeLogDetailDialogComponent } from './change-log-detail-dialog/change-log-detail-dialog.component';

type SortCol = 'created_at' | 'source' | 'action' | 'entity_type' | 'name' | 'uid' | 'user_name' | '';

@Component({
  selector: 'app-change-log',
  templateUrl: './change-log.component.html',
  styleUrls: ['./change-log.component.scss']
})
export class ChangeLogComponent implements OnInit {
  entries: ChangeLogEntry[] = [];
  displayedColumns: string[] = ['created_at', 'source', 'action', 'entity_type', 'name', 'uid', 'user_name', 'detail'];
  loading = true;
  error: string | null = null;

  /** Клиентские фильтры по столбцам (подстрока, без учёта регистра). */
  colFilter: Record<string, string> = {};
  sortColumn: SortCol = 'created_at';
  sortDir: 'asc' | 'desc' = 'desc';

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
    this.apiService.getChangeLog({
      limit: 500,
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

  /** Отображаемые строки: фильтр по столбцам + сортировка. */
  get displayedEntries(): ChangeLogEntry[] {
    let rows = [...this.entries];
    const f = this.colFilter;
    const has = (key: string, val: string | undefined | null) => {
      const q = (f[key] || '').trim().toLowerCase();
      if (!q) return true;
      return String(val ?? '').toLowerCase().includes(q);
    };
    rows = rows.filter(e => {
      if (!has('created_at', this.formatDate(e.created_at))) return false;
      if (!has('source', this.sourceLabel(e.source))) return false;
      if (!has('action', this.actionLabel(e.action))) return false;
      if (!has('entity_type', this.entityTypeLabel(e.entity_type))) return false;
      if (!has('name', (e.entity_name || this.getName(e)))) return false;
      if (!has('uid', this.getUid(e))) return false;
      if (!has('user_name', e.user_name ?? '')) return false;
      return true;
    });
    const col = this.sortColumn;
    const dir = this.sortDir === 'asc' ? 1 : -1;
    if (col) {
      rows.sort((a, b) => {
        let va: string | number = '';
        let vb: string | number = '';
        switch (col) {
          case 'created_at':
            va = new Date(a.created_at).getTime();
            vb = new Date(b.created_at).getTime();
            break;
          case 'source':
            va = this.sourceLabel(a.source);
            vb = this.sourceLabel(b.source);
            break;
          case 'action':
            va = this.actionLabel(a.action);
            vb = this.actionLabel(b.action);
            break;
          case 'entity_type':
            va = this.entityTypeLabel(a.entity_type);
            vb = this.entityTypeLabel(b.entity_type);
            break;
          case 'name':
            va = a.entity_name || this.getName(a);
            vb = b.entity_name || this.getName(b);
            break;
          case 'uid':
            va = this.getUid(a);
            vb = this.getUid(b);
            break;
          case 'user_name':
            va = a.user_name ?? '';
            vb = b.user_name ?? '';
            break;
          default:
            return 0;
        }
        if (typeof va === 'number' && typeof vb === 'number') {
          return va < vb ? -dir : va > vb ? dir : 0;
        }
        return String(va).localeCompare(String(vb), 'ru') * dir;
      });
    }
    return rows;
  }

  setColFilter(key: string, value: string): void {
    const next = { ...this.colFilter, [key]: value };
    if (!String(value).trim()) {
      delete next[key];
    }
    this.colFilter = next;
  }

  clearColFilter(key: string): void {
    const next = { ...this.colFilter };
    delete next[key];
    this.colFilter = next;
  }

  toggleSort(column: SortCol): void {
    if (this.sortColumn === column) {
      this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      this.sortColumn = column;
      this.sortDir = column === 'created_at' ? 'desc' : 'asc';
    }
  }

  sortIcon(column: SortCol): string {
    if (this.sortColumn !== column) return 'unfold_more';
    return this.sortDir === 'asc' ? 'arrow_upward' : 'arrow_downward';
  }

  filterIconColor(key: string): string | undefined {
    return (this.colFilter[key] || '').trim() ? 'primary' : undefined;
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
    if (p['pole_card'] === true && typeof p['summary_ru'] === 'string') {
      return p['summary_ru'] as string;
    }
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
      width: 'min(96vw, 720px)',
      maxWidth: '96vw',
      maxHeight: '90vh',
      panelClass: 'change-log-detail-pane',
      autoFocus: false,
      data: { entry }
    });
  }

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
