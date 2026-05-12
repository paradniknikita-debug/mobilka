import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ApiService } from '../../../core/services/api.service';
import { AuthService } from '../../../core/services/auth.service';
import { LineConductorCatalogItem } from '../../../core/models/line-conductor-catalog.model';
import { canManageCatalog } from '../../../core/utils/role-utils';

@Component({
  selector: 'app-line-conductor-catalog-panel',
  templateUrl: './line-conductor-catalog-panel.component.html',
  styleUrls: ['./line-conductor-catalog-panel.component.scss'],
})
export class LineConductorCatalogPanelComponent implements OnInit {
  items: LineConductorCatalogItem[] = [];
  loading = false;
  search = '';
  mark = '';
  voltageKv: number | null = null;

  constructor(
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
    private readonly auth: AuthService,
  ) {}

  canEditCatalog(): boolean {
    return canManageCatalog(this.auth.getCurrentUser());
  }

  get displayedColumns(): string[] {
    return this.canEditCatalog() ? ['mark', 'voltage_kv', 'is_active', 'actions'] : ['mark', 'voltage_kv', 'is_active'];
  }

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.api
      .getLineConductorCatalog({
        q: this.search.trim() || undefined,
        is_active: true,
        limit: 2000,
      })
      .subscribe({
        next: (rows) => {
          this.items = rows ?? [];
          this.loading = false;
        },
        error: () => {
          this.loading = false;
          this.snackBar.open('Не удалось загрузить марки проводов', 'Закрыть', { duration: 4000 });
        },
      });
  }

  add(): void {
    const m = this.mark.trim();
    const kv = this.voltageKv;
    if (!m || kv == null) {
      this.snackBar.open('Укажите марку и напряжение, кВ', 'Закрыть', { duration: 3000 });
      return;
    }
    this.api
      .createLineConductorCatalogItem({
        mark: m,
        voltage_kv: kv,
        is_active: true,
      })
      .subscribe({
        next: () => {
          this.snackBar.open('Позиция добавлена или обновлена', 'Закрыть', { duration: 2500 });
          this.mark = '';
          this.load();
        },
        error: (e) => {
          const msg = e?.error?.detail || 'Ошибка сохранения';
          this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка', 'Закрыть', { duration: 4000 });
        },
      });
  }

  deactivate(row: LineConductorCatalogItem): void {
    this.api
      .createLineConductorCatalogItem({
        mark: row.mark,
        voltage_kv: row.voltage_kv,
        is_active: false,
      })
      .subscribe({
        next: () => {
          this.snackBar.open('Позиция деактивирована', 'Закрыть', { duration: 2500 });
          this.load();
        },
        error: () => this.snackBar.open('Ошибка', 'Закрыть', { duration: 3000 }),
      });
  }
}
