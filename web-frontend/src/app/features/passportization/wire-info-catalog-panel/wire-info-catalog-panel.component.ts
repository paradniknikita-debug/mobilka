import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';

import { WireInfoCreate, WireInfoItem } from '../../../core/models/wire-info.model';
import { ApiService } from '../../../core/services/api.service';
import { AuthService } from '../../../core/services/auth.service';
import { canManageCatalog, isAdminUser } from '../../../core/utils/role-utils';

@Component({
  selector: 'app-wire-info-catalog-panel',
  templateUrl: './wire-info-catalog-panel.component.html',
  styleUrls: ['./wire-info-catalog-panel.component.scss'],
})
export class WireInfoCatalogPanelComponent implements OnInit {
  items: WireInfoItem[] = [];
  loading = false;
  search = '';
  showWithdrawn = false;

  form: WireInfoCreate = this.emptyForm();

  constructor(
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
    private readonly auth: AuthService,
  ) {}

  ngOnInit(): void {
    this.load();
  }

  canEdit(): boolean {
    return canManageCatalog(this.auth.getCurrentUser());
  }

  isAdmin(): boolean {
    return isAdminUser(this.auth.getCurrentUser());
  }

  emptyForm(): WireInfoCreate {
    return {
      name: '',
      code: '',
      material: 'алюминий',
      section: 70,
      voltage_kv: 10,
      nominal_current: null,
      i_th: null,
      ip_max: null,
      t_th: null,
      r: null,
      x: null,
      b: null,
      g: null,
      max_operating_temperature: 90,
      in_service: true,
    };
  }

  load(): void {
    this.loading = true;
    this.api
      .getWireInfoCatalog({
        q: this.search || undefined,
        in_service: this.showWithdrawn ? undefined : true,
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

  save(): void {
    if (!this.form.name?.trim()) {
      this.snackBar.open('Укажите марку провода', 'Закрыть', { duration: 2500 });
      return;
    }
    if (!this.form.section || this.form.section <= 0) {
      this.snackBar.open('Укажите сечение, мм²', 'Закрыть', { duration: 2500 });
      return;
    }
    this.api.createWireInfo({ ...this.form, name: this.form.name.trim() }).subscribe({
      next: () => {
        this.snackBar.open('Марка сохранена', 'Закрыть', { duration: 2000 });
        this.form = this.emptyForm();
        this.load();
      },
      error: (err) => {
        this.snackBar.open(err?.error?.detail || 'Ошибка сохранения', 'Закрыть', { duration: 4000 });
      },
    });
  }

  withdraw(item: WireInfoItem): void {
    this.api.withdrawWireInfo(item.id).subscribe({
      next: () => {
        this.snackBar.open('Марка выведена из эксплуатации', 'Закрыть', { duration: 2500 });
        this.load();
      },
      error: () => this.snackBar.open('Ошибка', 'Закрыть', { duration: 3000 }),
    });
  }

  deleteItem(item: WireInfoItem): void {
    if (!confirm(`Удалить марку «${item.name}» безвозвратно?`)) {
      return;
    }
    this.api.deleteWireInfo(item.id).subscribe({
      next: () => {
        this.snackBar.open('Марка удалена', 'Закрыть', { duration: 2000 });
        this.load();
      },
      error: (err) => {
        this.snackBar.open(err?.error?.detail || 'Ошибка удаления', 'Закрыть', { duration: 4000 });
      },
    });
  }

  downloadTemplate(): void {
    this.api.downloadWireInfoTemplate().subscribe({
      next: (blob) => this.saveBlob(blob, 'wire_catalog_template.xlsx'),
      error: () => this.snackBar.open('Ошибка шаблона', 'Закрыть', { duration: 3000 }),
    });
  }

  exportFmt(fmt: 'xlsx' | 'csv'): void {
    this.api.exportWireInfoCatalog(fmt).subscribe({
      next: (blob) => this.saveBlob(blob, `wire_catalog.${fmt}`),
      error: () => this.snackBar.open('Ошибка экспорта', 'Закрыть', { duration: 3000 }),
    });
  }

  onImport(ev: Event): void {
    const file = (ev.target as HTMLInputElement).files?.[0];
    if (!file) return;
    this.api.importWireInfoCatalog(file).subscribe({
      next: (res) => {
        this.snackBar.open(
          `Импорт: добавлено ${res.inserted}, обновлено ${res.updated}, пропущено ${res.skipped}`,
          'Закрыть',
          { duration: 4500 },
        );
        this.load();
      },
      error: (err) => {
        this.snackBar.open(err?.error?.detail || 'Ошибка импорта', 'Закрыть', { duration: 4000 });
      },
    });
    (ev.target as HTMLInputElement).value = '';
  }

  private saveBlob(blob: Blob, name: string): void {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.click();
    URL.revokeObjectURL(url);
  }
}
