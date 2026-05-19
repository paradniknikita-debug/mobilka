import {
  AfterViewInit,
  Component,
  OnDestroy,
  OnInit,
  ViewChild,
} from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatSort } from '@angular/material/sort';
import { MatTableDataSource } from '@angular/material/table';
import { AdminLoadMetrics, ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { User, UserCreate } from '../../core/models/user.model';
import { DockerLogsDialogComponent } from './docker-logs-dialog/docker-logs-dialog.component';
import { DevelopmentGuideDialogComponent } from './development-guide-dialog/development-guide-dialog.component';
import {
  ROLE_ADMIN,
  ROLE_FIELD_ENGINEER,
  ROLE_LABELS,
  ROLE_PASSPORT_CLERK,
  normalizeRole,
} from '../../core/utils/role-utils';

export interface LoadChartBar {
  title: string;
  shortLabel: string;
  http: number;
  db: number;
  httpHeight: number;
  dbHeight: number;
}

export interface LoadPeriodPreset {
  label: string;
  minutes: number;
}

@Component({
  selector: 'app-admin',
  templateUrl: './admin.component.html',
  styleUrls: ['./admin.component.scss'],
})
export class AdminComponent implements OnInit, AfterViewInit, OnDestroy {
  readonly normalizeRole = normalizeRole;

  readonly displayedColumns = [
    'id',
    'username',
    'full_name',
    'email',
    'online',
    'role',
    'active',
    'password_plain',
    'actions',
  ];

  readonly usersDataSource = new MatTableDataSource<User>([]);

  @ViewChild(MatSort) sort!: MatSort;

  stats: Record<string, unknown> | null = null;
  loading = false;

  readonly loadPeriodPresets: LoadPeriodPreset[] = [
    { label: '30 мин', minutes: 30 },
    { label: '1 ч', minutes: 60 },
    { label: '3 ч', minutes: 180 },
    { label: '6 ч', minutes: 360 },
    { label: '12 ч', minutes: 720 },
    { label: '24 ч', minutes: 1440 },
    { label: '3 дня', minutes: 4320 },
    { label: '7 дней', minutes: 10080 },
  ];

  readonly loadBucketOptions = [
    { value: null as number | null, label: 'Авто' },
    { value: 1, label: '1 мин' },
    { value: 5, label: '5 мин' },
    { value: 15, label: '15 мин' },
    { value: 30, label: '30 мин' },
    { value: 60, label: '1 ч' },
  ];

  loadMinutes = 60;
  loadBucketMinutes: number | null = null;
  loadMetrics: AdminLoadMetrics | null = null;
  loadChartBars: LoadChartBar[] = [];
  loadChartScaleMax = 1;
  loadYTicks: number[] = [0, 1];
  loadXLabels: { label: string; index: number }[] = [];
  readonly loadChartPlotHeight = 200;

  currentUserId: number | null = null;

  filterId = '';
  filterUsername = '';
  filterFullName = '';
  filterEmail = '';
  filterPassword = '';
  filterOnline: '' | 'online' | 'offline' = '';
  filterRole = '';
  filterActive: '' | 'active' | 'inactive' = '';

  infrastructure: {
    minio_console_url: string;
    swagger_url: string;
    redoc_url: string;
    api_home_url: string;
    openapi_url: string;
    development_guide_available: boolean;
    docker_logs_available: boolean;
  } | null = null;

  readonly dockerServices = [
    { id: 'backend', label: 'Backend API' },
    { id: 'postgres', label: 'PostgreSQL' },
    { id: 'redis', label: 'Redis' },
    { id: 'minio', label: 'MinIO' },
    { id: 'nginx', label: 'Nginx' },
  ];

  readonly roleOptions = [
    { value: ROLE_ADMIN, label: ROLE_LABELS[ROLE_ADMIN] },
    { value: ROLE_PASSPORT_CLERK, label: ROLE_LABELS[ROLE_PASSPORT_CLERK] },
    { value: ROLE_FIELD_ENGINEER, label: ROLE_LABELS[ROLE_FIELD_ENGINEER] },
  ];

  readonly onlineFilterOptions = [
    { value: '', label: 'Все' },
    { value: 'online', label: 'Онлайн' },
    { value: 'offline', label: 'Офлайн' },
  ];

  readonly activeFilterOptions = [
    { value: '', label: 'Все' },
    { value: 'active', label: 'Активные' },
    { value: 'inactive', label: 'Неактивные' },
  ];

  createForm: UserCreate = {
    username: '',
    email: '',
    full_name: '',
    password: '',
    role: ROLE_FIELD_ENGINEER,
  };

  private usersRefreshTimer?: ReturnType<typeof setInterval>;
  private loadMetricsTimer?: ReturnType<typeof setInterval>;

  constructor(
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
    private readonly auth: AuthService,
    private readonly dialog: MatDialog,
  ) {
    this.usersDataSource.filterPredicate = (user, filter) => {
      const parts = filter.split('\u0001');
      const [
        idQ,
        usernameQ,
        fullNameQ,
        emailQ,
        online,
        role,
        active,
        passwordQ,
      ] = parts;

      if (idQ && !String(user.id).includes(idQ)) {
        return false;
      }
      if (usernameQ && !user.username.toLowerCase().includes(usernameQ)) {
        return false;
      }
      if (fullNameQ && !user.full_name.toLowerCase().includes(fullNameQ)) {
        return false;
      }
      if (emailQ && !user.email.toLowerCase().includes(emailQ)) {
        return false;
      }
      if (passwordQ) {
        const pwd = (user.password_plain || '').toLowerCase();
        if (!pwd.includes(passwordQ)) {
          return false;
        }
      }
      if (online === 'online' && !user.is_online) {
        return false;
      }
      if (online === 'offline' && user.is_online) {
        return false;
      }
      if (role && normalizeRole(user.role) !== role) {
        return false;
      }
      if (active === 'active' && !user.is_active) {
        return false;
      }
      if (active === 'inactive' && user.is_active) {
        return false;
      }
      return true;
    };

    this.usersDataSource.sortingDataAccessor = (user, property) => {
      switch (property) {
        case 'online':
          return user.is_online ? 1 : 0;
        case 'role':
          return this.displayRole(user.role);
        case 'active':
          return user.is_active ? 1 : 0;
        case 'last_seen_at':
          return user.last_seen_at ? new Date(user.last_seen_at).getTime() : 0;
        default: {
          const v = (user as unknown as Record<string, unknown>)[property];
          if (typeof v === 'string') {
            return v.toLowerCase();
          }
          if (typeof v === 'number') {
            return v;
          }
          if (typeof v === 'boolean') {
            return v ? 1 : 0;
          }
          return '';
        }
      }
    };
  }

  ngOnInit(): void {
    this.currentUserId = this.auth.getCurrentUser()?.id ?? null;
    this.reload();
    this.usersRefreshTimer = setInterval(() => this.loadUsers(false), 45_000);
    this.loadLoadMetrics();
    this.loadMetricsTimer = setInterval(() => this.loadLoadMetrics(), 60_000);
  }

  ngAfterViewInit(): void {
    this.usersDataSource.sort = this.sort;
  }

  ngOnDestroy(): void {
    if (this.usersRefreshTimer) {
      clearInterval(this.usersRefreshTimer);
    }
    if (this.loadMetricsTimer) {
      clearInterval(this.loadMetricsTimer);
    }
  }

  reload(): void {
    this.loading = true;
    this.api.getAdminStats().subscribe({
      next: (s) => {
        this.stats = s;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.snackBar.open('Не удалось загрузить метрики', 'Закрыть', { duration: 4000 });
      },
    });
    this.loadUsers(true);
    this.api.getAdminInfrastructure().subscribe({
      next: (infra) => {
        this.infrastructure = infra;
      },
      error: () => {
        this.infrastructure = null;
      },
    });
    this.loadLoadMetrics();
  }

  loadPeriodCaption(): string {
    const m = this.loadMetrics;
    if (!m) {
      return '';
    }
    const bucket = m.bucket_minutes ?? 1;
    const bucketLabel =
      bucket >= 60 ? `${bucket / 60} ч` : bucket === 1 ? '1 мин' : `${bucket} мин`;
    return `Интервал агрегации: ${bucketLabel} · точек: ${m.points?.length ?? 0}`;
  }

  onLoadPeriodChange(minutes: number): void {
    this.loadMinutes = minutes;
    this.loadLoadMetrics();
  }

  loadLoadMetrics(): void {
    const bucket =
      this.loadBucketMinutes != null && this.loadBucketMinutes > 0
        ? this.loadBucketMinutes
        : undefined;
    this.api.getAdminLoadMetrics(this.loadMinutes, bucket, 120).subscribe({
      next: (m) => {
        this.loadMetrics = m;
        this.buildLoadChart(m);
      },
      error: () => {
        this.loadMetrics = null;
        this.loadChartBars = [];
        this.loadYTicks = [0];
        this.loadXLabels = [];
      },
    });
  }

  private buildLoadChart(m: AdminLoadMetrics): void {
    const points = m.points ?? [];
    if (!points.length) {
      this.loadChartBars = [];
      this.loadChartScaleMax = 1;
      this.loadYTicks = [0];
      this.loadXLabels = [];
      return;
    }

    const dataMax = Math.max(
      1,
      ...points.map((p) => Math.max(p.http_requests, p.db_writes)),
    );
    const { scaleMax, ticks } = this.computeChartScale(dataMax);
    this.loadChartScaleMax = scaleMax;
    this.loadYTicks = ticks;

    const bucketMin = m.bucket_minutes ?? 1;
    this.loadChartBars = points.map((p) => {
      const d = new Date(p.ts);
      const shortLabel =
        bucketMin >= 60
          ? d.toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', hour: '2-digit' })
          : d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
      const httpH = this.barHeightPx(p.http_requests, scaleMax);
      const dbH = this.barHeightPx(p.db_writes, scaleMax);
      return {
        title: `${shortLabel} — API: ${p.http_requests}, БД: ${p.db_writes}`,
        shortLabel,
        http: p.http_requests,
        db: p.db_writes,
        httpHeight: httpH,
        dbHeight: dbH,
      };
    });

    this.loadXLabels = this.buildXLabelIndices(points.length).map((index) => ({
      index,
      label: this.loadChartBars[index]?.shortLabel ?? '',
    }));
  }

  /** Подписи Y без нуля — ноль совпадает с осью времени и накладывается на неё. */
  displayYTicks(): number[] {
    return this.loadYTicks.filter((t) => t > 0).slice().reverse();
  }

  xLabelLeftPct(index: number, total: number): number {
    if (total <= 1) {
      return 0;
    }
    const inset = 3;
    const t = index / (total - 1);
    return inset + t * (100 - 2 * inset);
  }

  isFirstXLabel(index: number): boolean {
    return this.loadXLabels.length > 0 && this.loadXLabels[0].index === index;
  }

  isLastXLabel(index: number): boolean {
    const labels = this.loadXLabels;
    return labels.length > 0 && labels[labels.length - 1].index === index;
  }

  private buildXLabelIndices(pointCount: number): number[] {
    if (pointCount <= 1) {
      return [0];
    }
    const maxLabels = pointCount <= 12 ? pointCount : pointCount <= 24 ? 6 : pointCount <= 48 ? 7 : 8;
    const labelCount = Math.min(maxLabels, pointCount);
    if (labelCount >= pointCount) {
      return Array.from({ length: pointCount }, (_, i) => i);
    }
    const step = Math.max(1, Math.round((pointCount - 1) / (labelCount - 1)));
    const idxs: number[] = [];
    for (let i = 0; i < pointCount; i += step) {
      idxs.push(i);
    }
    if (idxs[idxs.length - 1] !== pointCount - 1) {
      idxs.push(pointCount - 1);
    }
    return idxs;
  }

  formatYTick(value: number): string {
    if (value >= 1_000_000) {
      return `${(value / 1_000_000).toLocaleString('ru-RU', { maximumFractionDigits: 1 })}M`;
    }
    if (value >= 10_000) {
      return `${Math.round(value / 1000)}k`;
    }
    if (value >= 1000) {
      return `${(value / 1000).toLocaleString('ru-RU', { maximumFractionDigits: 1 })}k`;
    }
    return String(Math.round(value));
  }

  gridLineBottomPct(tick: number): number {
    if (this.loadChartScaleMax <= 0) {
      return 0;
    }
    return (tick / this.loadChartScaleMax) * 100;
  }

  private barHeightPx(value: number, scaleMax: number): number {
    if (value <= 0 || scaleMax <= 0) {
      return 0;
    }
    const h = Math.round((value / scaleMax) * this.loadChartPlotHeight);
    return Math.max(value > 0 ? 4 : 0, h);
  }

  private computeChartScale(dataMax: number): { scaleMax: number; ticks: number[] } {
    const scaleMax = this.niceCeil(dataMax);
    const divisions = 4;
    let step = scaleMax / divisions;
    step = this.niceStep(step) || 1;
    const ticks: number[] = [0];
    for (let v = step; v < scaleMax; v += step) {
      ticks.push(Math.round(v));
    }
    if (ticks[ticks.length - 1] !== scaleMax) {
      ticks.push(scaleMax);
    }
    return { scaleMax, ticks };
  }

  private niceCeil(value: number): number {
    if (value <= 0) {
      return 1;
    }
    if (value <= 5) {
      return Math.max(1, Math.ceil(value));
    }
    const exp = Math.floor(Math.log10(value));
    const magnitude = Math.pow(10, exp);
    const fraction = value / magnitude;
    let niceFraction: number;
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
    let nice = niceFraction * magnitude;
    if (nice < value) {
      if (niceFraction === 1) {
        niceFraction = 2;
      } else if (niceFraction === 2) {
        niceFraction = 5;
      } else if (niceFraction === 5) {
        niceFraction = 10;
      } else {
        niceFraction = 1;
        nice = 10 * magnitude;
      }
      nice = niceFraction * magnitude;
    }
    return nice;
  }

  private niceStep(step: number): number {
    if (step <= 0) {
      return 1;
    }
    const magnitude = Math.pow(10, Math.floor(Math.log10(step)));
    const normalized = step / magnitude;
    let niceUnit: number;
    if (normalized <= 1) {
      niceUnit = 1;
    } else if (normalized <= 2) {
      niceUnit = 2;
    } else if (normalized <= 5) {
      niceUnit = 5;
    } else {
      niceUnit = 10;
    }
    return niceUnit * magnitude;
  }

  loadUsers(showError = true): void {
    this.api.getAdminUsers().subscribe({
      next: (rows) => {
        this.usersDataSource.data = rows ?? [];
        this.applyUsersFilter();
      },
      error: () => {
        if (showError) {
          this.snackBar.open('Не удалось загрузить пользователей', 'Закрыть', { duration: 4000 });
        }
      },
    });
  }

  applyUsersFilter(): void {
    this.usersDataSource.filter = [
      this.filterId.trim(),
      this.filterUsername.trim().toLowerCase(),
      this.filterFullName.trim().toLowerCase(),
      this.filterEmail.trim().toLowerCase(),
      this.filterOnline,
      this.filterRole,
      this.filterActive,
      this.filterPassword.trim().toLowerCase(),
    ].join('\u0001');
  }

  clearUsersFilter(): void {
    this.filterId = '';
    this.filterUsername = '';
    this.filterFullName = '';
    this.filterEmail = '';
    this.filterPassword = '';
    this.filterOnline = '';
    this.filterRole = '';
    this.filterActive = '';
    this.applyUsersFilter();
  }

  hasUsersFilters(): boolean {
    return !!(
      this.filterId.trim() ||
      this.filterUsername.trim() ||
      this.filterFullName.trim() ||
      this.filterEmail.trim() ||
      this.filterPassword.trim() ||
      this.filterOnline ||
      this.filterRole ||
      this.filterActive
    );
  }

  isColumnFilterActive(column: string): boolean {
    switch (column) {
      case 'id':
        return !!this.filterId.trim();
      case 'username':
        return !!this.filterUsername.trim();
      case 'full_name':
        return !!this.filterFullName.trim();
      case 'email':
        return !!this.filterEmail.trim();
      case 'password_plain':
        return !!this.filterPassword.trim();
      case 'online':
        return !!this.filterOnline;
      case 'role':
        return !!this.filterRole;
      case 'active':
        return !!this.filterActive;
      default:
        return false;
    }
  }

  clearColumnFilter(column: string): void {
    switch (column) {
      case 'id':
        this.filterId = '';
        break;
      case 'username':
        this.filterUsername = '';
        break;
      case 'full_name':
        this.filterFullName = '';
        break;
      case 'email':
        this.filterEmail = '';
        break;
      case 'password_plain':
        this.filterPassword = '';
        break;
      case 'online':
        this.filterOnline = '';
        break;
      case 'role':
        this.filterRole = '';
        break;
      case 'active':
        this.filterActive = '';
        break;
      default:
        break;
    }
    this.applyUsersFilter();
  }

  displayRole(role: string): string {
    const n = normalizeRole(role);
    return ROLE_LABELS[n] || n;
  }

  formatLastSeen(user: User): string {
    if (!user.last_seen_at) {
      return '—';
    }
    try {
      return new Date(user.last_seen_at).toLocaleString('ru-RU', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return '—';
    }
  }

  createUser(): void {
    const c = this.createForm;
    if (!c.username?.trim() || !c.email?.trim() || !c.full_name?.trim() || !c.password?.trim()) {
      this.snackBar.open('Заполните логин, email, ФИО и пароль', 'Закрыть', { duration: 4000 });
      return;
    }
    this.api.createAdminUser(c).subscribe({
      next: () => {
        this.snackBar.open('Пользователь создан', 'Закрыть', { duration: 3000 });
        this.createForm = {
          username: '',
          email: '',
          full_name: '',
          password: '',
          role: ROLE_FIELD_ENGINEER,
        };
        this.reload();
      },
      error: (e) => {
        const msg = e?.error?.detail || 'Ошибка создания пользователя';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка создания', 'Закрыть', { duration: 5000 });
      },
    });
  }

  updateUser(u: User, patch: { role?: string; is_active?: boolean }): void {
    this.api.patchAdminUser(u.id, patch).subscribe({
      next: () => {
        this.snackBar.open('Сохранено', 'Закрыть', { duration: 2000 });
        this.loadUsers(false);
      },
      error: (e) => {
        const msg = e?.error?.detail || 'Ошибка сохранения';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка', 'Закрыть', { duration: 5000 });
      },
    });
  }

  onRoleChange(u: User, value: string): void {
    this.updateUser(u, { role: value });
  }

  onActiveChange(u: User, checked: boolean): void {
    this.updateUser(u, { is_active: checked });
  }

  changePassword(u: User): void {
    const v = window.prompt(
      `Новый пароль для «${u.username}» (не короче 6 символов). Отмена — без изменений.`,
      '',
    );
    if (v === null) {
      return;
    }
    const pwd = (v || '').trim();
    if (pwd.length < 6) {
      this.snackBar.open('Пароль должен быть не короче 6 символов', 'Закрыть', { duration: 4000 });
      return;
    }
    this.api.patchAdminUser(u.id, { password: pwd }).subscribe({
      next: () => {
        this.snackBar.open('Пароль обновлён', 'Закрыть', { duration: 3000 });
        this.loadUsers(false);
      },
      error: (e) => {
        const msg = e?.error?.detail || 'Ошибка смены пароля';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка', 'Закрыть', { duration: 5000 });
      },
    });
  }

  openExternal(url: string | undefined | null): void {
    const u = (url || '').trim();
    if (!u) {
      this.snackBar.open('Ссылка недоступна', 'Закрыть', { duration: 3000 });
      return;
    }
    window.open(u, '_blank', 'noopener,noreferrer');
  }

  openDockerLogs(): void {
    this.dialog.open(DockerLogsDialogComponent, {
      width: 'min(96vw, 760px)',
      maxWidth: '96vw',
      maxHeight: '90vh',
      data: { services: this.dockerServices },
    });
  }

  openDevelopmentGuide(): void {
    this.dialog.open(DevelopmentGuideDialogComponent, {
      width: 'min(96vw, 900px)',
      maxWidth: '96vw',
      maxHeight: '90vh',
    });
  }

  deleteUser(u: User): void {
    if (
      !confirm(
        `Удалить пользователя «${u.username}» безвозвратно?\n` +
          'Все ссылки «создал» на объектах будут переназначены на вашу учётную запись.',
      )
    ) {
      return;
    }
    this.api.deleteAdminUser(u.id).subscribe({
      next: () => {
        this.snackBar.open('Пользователь удалён', 'Закрыть', { duration: 3000 });
        this.reload();
      },
      error: (e) => {
        const msg = e?.error?.detail || e?.message || 'Не удалось удалить';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка удаления', 'Закрыть', { duration: 6000 });
      },
    });
  }
}
