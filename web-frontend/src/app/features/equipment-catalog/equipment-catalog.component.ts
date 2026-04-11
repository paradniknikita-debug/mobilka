import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';

import { EquipmentCatalogCreate, EquipmentCatalogItem } from '../../core/models/equipment-catalog.model';
import { ApiService } from '../../core/services/api.service';

/** Код типа (латиница) → подпись для пользователя */
const EQUIPMENT_TYPE_LABELS: Record<string, string> = {
  disconnector: 'Разъединитель',
  breaker: 'Выключатель',
  zn: 'Заземляющий нож (ЗН)',
  arrester: 'ОПН (ограничитель перенапряжения)',
  recloser: 'Реклоузер',
  transformer: 'Трансформатор',
  ct: 'Трансформатор тока',
  vt: 'Трансформатор напряжения',
  fuse: 'Предохранитель',
  insulator: 'Изолятор',
};

@Component({
  selector: 'app-equipment-catalog',
  templateUrl: './equipment-catalog.component.html',
  styleUrls: ['./equipment-catalog.component.scss']
})
export class EquipmentCatalogComponent implements OnInit {
  items: EquipmentCatalogItem[] = [];
  isLoading = false;
  query = '';
  typeCodeFilter = '';

  /** Фильтр по типу: значение — код для API, подпись — на русском */
  readonly typeFilterOptions: { value: string; label: string }[] = [
    { value: '', label: 'Все типы' },
    { value: 'disconnector', label: 'Разъединитель' },
    { value: 'breaker', label: 'Выключатель' },
    { value: 'zn', label: 'Заземляющий нож (ЗН)' },
    { value: 'arrester', label: 'ОПН (ограничитель перенапряжения)' },
    { value: 'recloser', label: 'Реклоузер' },
  ];

  form: EquipmentCatalogCreate = {
    type_code: '',
    brand: '',
    model: '',
    full_name: '',
    voltage_kv: null,
    current_a: null,
    manufacturer: '',
    country: '',
    description: '',
    attrs_json: '',
    is_active: true,
  };

  constructor(
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
  ) {}

  ngOnInit(): void {
    this.loadItems();
  }

  loadItems(): void {
    this.isLoading = true;
    this.api.getEquipmentCatalog({
      q: this.query || undefined,
      type_code: this.typeCodeFilter || undefined,
      is_active: true,
      limit: 1000,
    }).subscribe({
      next: (rows) => {
        this.items = rows ?? [];
        this.isLoading = false;
      },
      error: () => {
        this.isLoading = false;
        this.snackBar.open('Ошибка загрузки справочника', 'Закрыть', { duration: 3000 });
      }
    });
  }

  addItem(): void {
    if (!this.form.type_code?.trim() || !this.form.brand?.trim() || !this.form.model?.trim()) {
      this.snackBar.open('Укажите тип (код), марку и модель', 'Закрыть', { duration: 2500 });
      return;
    }
    this.api.createEquipmentCatalogItem(this.form).subscribe({
      next: () => {
        this.snackBar.open('Позиция добавлена', 'Закрыть', { duration: 2000 });
        this.form = { ...this.form, brand: '', model: '', full_name: '' };
        this.loadItems();
      },
      error: (err) => {
        this.snackBar.open(err?.error?.detail || 'Ошибка добавления', 'Закрыть', { duration: 3500 });
      }
    });
  }

  seedDefaults(): void {
    this.api.seedEquipmentCatalogDefaults().subscribe({
      next: (res) => {
        this.snackBar.open(`Добавлено по умолчанию: ${res?.inserted ?? 0}`, 'Закрыть', { duration: 2500 });
        this.loadItems();
      },
      error: () => this.snackBar.open('Ошибка инициализации справочника', 'Закрыть', { duration: 3000 }),
    });
  }

  onImportFileSelected(ev: Event): void {
    const input = ev.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.api.importEquipmentCatalog(file, 'upsert').subscribe({
      next: (res) => {
        this.snackBar.open(
          `Импорт: inserted=${res.inserted}, updated=${res.updated}, skipped=${res.skipped}`,
          'Закрыть',
          { duration: 3500 },
        );
        this.loadItems();
      },
      error: (err) => {
        this.snackBar.open(err?.error?.detail || 'Ошибка импорта', 'Закрыть', { duration: 4000 });
      }
    });
    input.value = '';
  }

  downloadTemplate(): void {
    this.api.downloadEquipmentCatalogTemplate().subscribe({
      next: (blob) => this.downloadBlob(blob, 'equipment_catalog_template.xlsx'),
      error: () => this.snackBar.open('Ошибка скачивания шаблона', 'Закрыть', { duration: 3000 }),
    });
  }

  exportCatalog(format: 'xlsx' | 'csv'): void {
    this.api.exportEquipmentCatalog(format).subscribe({
      next: (blob) => this.downloadBlob(blob, `equipment_catalog.${format}`),
      error: () => this.snackBar.open('Ошибка экспорта', 'Закрыть', { duration: 3000 }),
    });
  }

  deactivate(item: EquipmentCatalogItem): void {
    this.api.deleteEquipmentCatalogItem(item.id, false).subscribe({
      next: () => {
        this.snackBar.open('Позиция деактивирована', 'Закрыть', { duration: 2000 });
        this.loadItems();
      },
      error: () => this.snackBar.open('Ошибка деактивации', 'Закрыть', { duration: 3000 }),
    });
  }

  private downloadBlob(blob: Blob, filename: string): void {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  /** Русская подпись типа для таблицы; внутренний код не меняется */
  displayTypeLabel(code: string | null | undefined): string {
    if (code == null || String(code).trim() === '') {
      return '—';
    }
    const key = String(code).trim().toLowerCase();
    return EQUIPMENT_TYPE_LABELS[key] ?? code;
  }

  /** Подсказка с системным кодом, если показали русское название */
  typeCodeTooltip(code: string | null | undefined): string {
    if (code == null || String(code).trim() === '') {
      return '';
    }
    const key = String(code).trim().toLowerCase();
    const ru = EQUIPMENT_TYPE_LABELS[key];
    if (ru && ru !== code) {
      return `Код в системе: ${code}`;
    }
    return `Тип оборудования (код): ${code}`;
  }
}

