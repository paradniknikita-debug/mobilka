import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  ApiService,
  PassportSection,
  PassportSectionTable,
  TechPassportDetail,
  TechPassportListItem,
} from '../../../core/services/api.service';
import { AuthService } from '../../../core/services/auth.service';
import { canUseExports } from '../../../core/utils/role-utils';

type ObjectType = 'power_line' | 'pole' | 'substation';

@Component({
  selector: 'app-tech-passports-panel',
  templateUrl: './tech-passports-panel.component.html',
  styleUrls: ['./tech-passports-panel.component.scss'],
})
export class TechPassportsPanelComponent implements OnInit {
  loading = false;
  saving = false;
  exportInProgress: { id: number; format: string } | null = null;
  items: TechPassportListItem[] = [];
  total = 0;

  objectType: ObjectType = 'power_line';
  title = '';
  stpReference = '';
  manualNotes = '';

  lines: { id: number; name: string }[] = [];
  poles: { id: number; pole_number: string }[] = [];
  substations: { id: number; name: string }[] = [];

  selectedLineId: number | null = null;
  selectedPoleId: number | null = null;
  selectedSubstationId: number | null = null;

  detail: TechPassportDetail | null = null;

  displayedColumns = ['title', 'object_type', 'object_mrid', 'stp_reference', 'created_at', 'actions'];

  filterObjectType = '';

  showRawJson = false;

  constructor(
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
    private readonly auth: AuthService,
  ) {}

  /** Создание и удаление паспортов — только паспортист и администратор. */
  canEditPassports(): boolean {
    return canUseExports(this.auth.getCurrentUser());
  }

  ngOnInit(): void {
    this.loadList();
    this.api.getPowerLines().subscribe({
      next: (rows) => {
        this.lines = (rows ?? []).map((l) => ({ id: l.id, name: l.name }));
      },
      error: () => {
        this.snackBar.open('Не удалось загрузить список ЛЭП', 'Закрыть', { duration: 4000 });
      },
    });
    this.api.getSubstations().subscribe({
      next: (rows) => {
        this.substations = (rows ?? []).map((s) => ({ id: s.id, name: s.name }));
      },
      error: () => {
        this.snackBar.open('Не удалось загрузить подстанции', 'Закрыть', { duration: 4000 });
      },
    });
  }

  loadList(): void {
    this.loading = true;
    this.api.listTechPassports(0, 100).subscribe({
      next: (res) => {
        this.items = res.items ?? [];
        this.total = res.total ?? 0;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.snackBar.open('Не удалось загрузить паспорта', 'Закрыть', { duration: 4000 });
      },
    });
  }

  onObjectTypeChange(): void {
    this.selectedPoleId = null;
    this.selectedSubstationId = null;
    if (this.objectType !== 'pole') {
      this.selectedLineId = null;
    }
    if (this.objectType === 'pole' && this.selectedLineId != null) {
      this.loadPolesForLine(this.selectedLineId);
    }
  }

  onLineSelectedForPole(): void {
    this.selectedPoleId = null;
    if (this.selectedLineId != null) {
      this.loadPolesForLine(this.selectedLineId);
    } else {
      this.poles = [];
    }
  }

  private loadPolesForLine(lineId: number): void {
    this.api.getPolesByPowerLine(lineId).subscribe({
      next: (rows) => {
        this.poles = (rows ?? []).map((p) => ({ id: p.id, pole_number: p.pole_number }));
      },
      error: () => {
        this.poles = [];
        this.snackBar.open('Не удалось загрузить опоры линии', 'Закрыть', { duration: 4000 });
      },
    });
  }

  objectTypeLabel(t: string): string {
    switch (t) {
      case 'power_line':
        return 'ЛЭП';
      case 'pole':
        return 'Опора';
      case 'substation':
        return 'Подстанция';
      default:
        return t;
    }
  }

  createPassport(): void {
    const manual = this.manualNotes.trim()
      ? { notes: this.manualNotes.trim() }
      : undefined;

    let object_id: number | null = null;
    if (this.objectType === 'power_line') {
      object_id = this.selectedLineId;
    } else if (this.objectType === 'pole') {
      object_id = this.selectedPoleId;
    } else {
      object_id = this.selectedSubstationId;
    }

    if (object_id == null) {
      this.snackBar.open('Выберите объект для паспорта', 'Закрыть', { duration: 3500 });
      return;
    }

    this.saving = true;
    this.api
      .createTechPassport({
        object_type: this.objectType,
        object_id,
        title: this.title.trim() || undefined,
        stp_reference: this.stpReference.trim() || undefined,
        manual_sections: manual,
      })
      .subscribe({
        next: () => {
          this.saving = false;
          this.snackBar.open('Паспорт сформирован и сохранён', 'Закрыть', { duration: 3000 });
          this.title = '';
          this.manualNotes = '';
          this.loadList();
        },
        error: (e) => {
          this.saving = false;
          const d = e?.error?.detail;
          const msg = typeof d === 'string' ? d : 'Ошибка сохранения';
          this.snackBar.open(msg, 'Закрыть', { duration: 5000 });
        },
      });
  }

  showDetail(row: TechPassportListItem): void {
    this.api.getTechPassport(row.id).subscribe({
      next: (d) => {
        this.detail = d;
      },
      error: () => {
        this.snackBar.open('Не удалось загрузить паспорт', 'Закрыть', { duration: 4000 });
      },
    });
  }

  closeDetail(): void {
    this.detail = null;
    this.showRawJson = false;
  }

  get filteredItems(): TechPassportListItem[] {
    if (!this.filterObjectType) {
      return this.items;
    }
    return this.items.filter((i) => i.object_type === this.filterObjectType);
  }

  tableCellAt(row: Record<string, unknown>, index: number): string {
    const vals = Object.values(row);
    const v = vals[index];
    if (v == null || v === '') {
      return '—';
    }
    return String(v);
  }

  sectionTables(section: PassportSection): PassportSectionTable[] {
    return section.tables ?? [];
  }

  deletePassport(row: TechPassportListItem): void {
    if (!confirm(`Удалить паспорт «${row.title}»?`)) {
      return;
    }
    this.api.deleteTechPassport(row.id).subscribe({
      next: () => {
        if (this.detail?.id === row.id) {
          this.detail = null;
        }
        this.snackBar.open('Удалено', 'Закрыть', { duration: 2500 });
        this.loadList();
      },
      error: () => {
        this.snackBar.open('Не удалось удалить', 'Закрыть', { duration: 4000 });
      },
    });
  }

  download(row: TechPassportListItem, format: 'pdf' | 'docx' | 'xlsx'): void {
    if (this.exportInProgress) {
      return;
    }
    this.exportInProgress = { id: row.id, format };
    this.api.downloadTechPassportExport(row.id, format).subscribe({
      next: (blob) => {
        const ext = format === 'docx' ? 'docx' : format;
        const mime =
          format === 'pdf'
            ? 'application/pdf'
            : format === 'docx'
              ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        const name = `passport_${row.id}.${ext}`;
        this.saveBlob(blob, name, mime);
        this.snackBar.open(`Файл ${name} загружен`, 'Закрыть', { duration: 3000 });
      },
      error: (e: unknown) => {
        const err = e as Error;
        const msg = err?.message?.trim() || 'Ошибка выгрузки';
        this.snackBar.open(msg, 'Закрыть', { duration: 9000 });
      },
      complete: () => {
        this.exportInProgress = null;
      },
    });
  }

  isExporting(row: TechPassportListItem, format: string): boolean {
    return (
      this.exportInProgress?.id === row.id && this.exportInProgress?.format === format
    );
  }

  private saveBlob(blob: Blob, filename: string, mime: string): void {
    const file =
      blob.type && blob.type !== 'application/octet-stream'
        ? blob
        : new Blob([blob], { type: mime });
    const url = URL.createObjectURL(file);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.setTimeout(() => URL.revokeObjectURL(url), 200);
  }
}
