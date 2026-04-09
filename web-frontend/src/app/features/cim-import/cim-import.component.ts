import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { CimPreviewMapDialogComponent, CimPreviewMapDialogData } from './cim-preview-map-dialog/cim-preview-map-dialog.component';
import { PowerLine } from '../../core/models/power-line.model';

@Component({
  selector: 'app-cim-import',
  templateUrl: './cim-import.component.html',
  styleUrls: ['./cim-import.component.scss']
})
export class CimImportComponent implements OnInit {
  selectedFile: File | null = null;
  selectedDiffFile: File | null = null;
  isUploading = false;
  isApplying = false;
  error: string | null = null;
  summary: { [key: string]: number } | null = null;
  totalCount = 0;
  /** Объекты последнего импорта для предпросмотра на карте и записи в БД */
  lastImportObjects: any[] = [];
  lastImportSource: 'xml' | '552' | null = null;

  // Параметры экспорта CIM XML
  exportScope: 'full' | 'partial' = 'full';
  includeGps: boolean = true;
  powerLines: PowerLine[] = [];
  selectedLineId: number | null = null;

  // Отдельные параметры для экспорта 552-diff
  diffExportScope: 'full' | 'partial' = 'full';
  diffSelectedLineId: number | null = null;

  constructor(
    private apiService: ApiService,
    private dialog: MatDialog,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    // Загружаем ЛЭП только для UI выбора “частично по ЛЭП”.
    this.apiService.getPowerLines().subscribe({
      next: (lines) => {
        this.powerLines = lines ?? [];
        if (this.powerLines.length > 0 && this.selectedLineId == null) {
          this.selectedLineId = this.powerLines[0].id;
        }
        if (this.powerLines.length > 0 && this.diffSelectedLineId == null) {
          this.diffSelectedLineId = this.powerLines[0].id;
        }
      },
      error: () => {
        // UI всё равно работает для полного экспорта.
      }
    });
  }

  onFileChange(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length ? input.files[0] : null;
    this.selectedFile = file;
    this.summary = null;
    this.totalCount = 0;
    this.error = null;
  }

  onDiffFileChange(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length ? input.files[0] : null;
    this.selectedDiffFile = file;
    this.summary = null;
    this.totalCount = 0;
    this.error = null;
  }

  import(): void {
    if (!this.selectedFile || this.isUploading) {
      return;
    }
    this.isUploading = true;
    this.error = null;
    this.summary = null;

    this.apiService.importCIMXml(this.selectedFile).subscribe({
      next: (res) => {
        this.summary = res?.summary || {};
        this.totalCount = res?.count ?? 0;
        this.lastImportObjects = res?.objects ?? [];
        this.lastImportSource = 'xml';
        this.isUploading = false;
      },
      error: (err) => {
        this.error = err?.error?.detail || err?.message || 'Ошибка импорта CIM XML';
        this.isUploading = false;
      }
    });
  }

  exportXml(): void {
    const lineId = this.exportScope === 'partial' ? this.selectedLineId : null;
    if (this.exportScope === 'partial' && lineId == null) {
      this.error = 'Выберите ЛЭП для частичного экспорта';
      return;
    }

    this.apiService.exportCIMXml(true, true, true, this.includeGps, lineId, true).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `cim_export_${new Date().toISOString().replace(/[:.]/g, '-')}.xml`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
      },
      error: (err) => {
        this.error = err?.error?.detail || err?.message || 'Ошибка экспорта CIM XML';
      }
    });
  }

  import552(): void {
    if (!this.selectedDiffFile || this.isUploading) {
      return;
    }
    this.isUploading = true;
    this.error = null;
    this.summary = null;

    this.apiService.importCIM552Diff(this.selectedDiffFile).subscribe({
      next: (res) => {
        this.summary = res?.summary || {};
        this.totalCount = res?.count ?? 0;
        this.lastImportObjects = res?.objects ?? [];
        this.lastImportSource = '552';
        this.isUploading = false;
      },
      error: (err) => {
        this.error = err?.error?.detail || err?.message || 'Ошибка импорта 552 diff';
        this.isUploading = false;
      }
    });
  }

  export552(): void {
    const lineId = this.diffExportScope === 'partial' ? this.diffSelectedLineId : null;
    if (this.diffExportScope === 'partial' && lineId == null) {
      this.error = 'Выберите ЛЭП для частичного экспорта 552 diff';
      return;
    }

    this.apiService.exportCIM552Diff(true, true, this.includeGps, lineId, true).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `cim_552_diff_${new Date().toISOString().replace(/[:.]/g, '-')}.xml`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
      },
      error: (err) => {
        this.error = err?.error?.detail || err?.message || 'Ошибка экспорта 552 diff';
      }
    });
  }

  /** Извлечь точки с координатами из разобранных CIM-объектов для отображения на карте */
  private extractPointsFromObjects(objects: any[]): { lat: number; lng: number; label?: string }[] {
    const byMrid: Record<string, any> = {};
    objects.forEach(o => { if (o?.mRID) byMrid[o.mRID] = o; });
    const points: { lat: number; lng: number; label?: string }[] = [];
    objects.forEach(obj => {
      const cls = obj?._class || obj?.type;
      if (cls === 'PositionPoint') {
        const x = obj.xPosition ?? obj.XPosition;
        const y = obj.yPosition ?? obj.YPosition;
        if (x != null && y != null) {
          const lat = Number(y);
          const lng = Number(x);
          if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
            points.push({ lat, lng, label: (obj.name || obj.mRID || '') as string });
          }
        }
        return;
      }
      if (cls === 'Location') {
        const ppRef = obj.PositionPoints ?? obj.PositionPoint;
        const refs = Array.isArray(ppRef) ? ppRef : (ppRef ? [ppRef] : []);
        refs.forEach((ref: any) => {
          const mrid = ref?.mRID;
          const pp = mrid ? byMrid[mrid] : null;
          if (pp && (pp._class === 'PositionPoint' || pp.type === 'PositionPoint')) {
            const x = pp.xPosition ?? pp.XPosition;
            const y = pp.yPosition ?? pp.YPosition;
            if (x != null && y != null) {
              const lat = Number(y);
              const lng = Number(x);
              if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
                points.push({ lat, lng, label: (pp.name || pp.mRID || obj.name || '') as string });
              }
            }
          }
        });
      }
    });
    return points;
  }

  openPreviewMapDialog(): void {
    const points = this.extractPointsFromObjects(this.lastImportObjects);
    this.dialog.open(CimPreviewMapDialogComponent, {
      width: '560px',
      data: { points } as CimPreviewMapDialogData,
    });
  }

  apply552ToDb(): void {
    if (!this.selectedDiffFile || this.isApplying) return;
    this.isApplying = true;
    this.error = null;
    this.apiService.applyCIM552Diff(this.selectedDiffFile).subscribe({
      next: (res) => {
        this.isApplying = false;
        const created = res?.created_substations ?? 0;
        this.snackBar.open(
          `Записано в БД: подстанций ${created}, локаций ${res?.created_locations ?? 0}, точек ${res?.created_position_points ?? 0}.`,
          'Закрыть',
          { duration: 5000 }
        );
      },
      error: (err) => {
        this.isApplying = false;
        this.error = err?.error?.detail?.message || err?.error?.detail || err?.message || 'Ошибка записи в БД';
      }
    });
  }
}

