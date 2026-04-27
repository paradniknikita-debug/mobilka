import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { CimPreviewMapDialogComponent, CimPreviewMapDialogData } from './cim-preview-map-dialog/cim-preview-map-dialog.component';
import {
  CimExportSettingsDialogComponent,
  CimExportSettingsDialogData,
} from './cim-export-settings-dialog/cim-export-settings-dialog.component';
import { PowerLine } from '../../core/models/power-line.model';
import { CimExportOptions, defaultCimExportOptions } from './cim-export-options.model';

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
  lastImportedFile: File | null = null;

  // Параметры экспорта CIM XML (чекбоксы → query API)
  exportScope: 'full' | 'partial' = 'full';
  xmlExportOpts: CimExportOptions = defaultCimExportOptions();
  powerLines: PowerLine[] = [];
  selectedLineId: number | null = null;

  // Параметры экспорта 552-diff (те же атрибуты, без useCimpy в запросе)
  diffExportScope: 'full' | 'partial' = 'full';
  diffExportOpts: CimExportOptions = defaultCimExportOptions();
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
        this.lastImportedFile = this.selectedFile;
        this.isUploading = false;
      },
      error: (err) => {
        this.error = err?.error?.detail || err?.message || 'Ошибка импорта CIM XML';
        this.isUploading = false;
      }
    });
  }

  /** Краткая подсказка под кнопкой «Настройки экспорта» */
  formatExportSummary(o: CimExportOptions): string {
    const parts: string[] = [];
    if (o.includeSubstations) {
      parts.push('подстанции');
    }
    if (o.includePowerLines) {
      parts.push('ЛЭП');
    }
    if (o.includeGps) {
      parts.push('GPS');
    }
    if (o.includeSubstationVoltageLevels) {
      parts.push('уровни напряжения');
    }
    if (o.includeElectricalModel) {
      parts.push('электромодель');
    }
    if (o.includeEquipment) {
      parts.push('оборудование');
    }
    if (o.includeDefects) {
      parts.push('дефекты');
    }
    return parts.length ? parts.join(', ') : 'ничего не выбрано';
  }

  openXmlExportSettings(): void {
    this.dialog
      .open<CimExportSettingsDialogComponent, CimExportSettingsDialogData, CimExportOptions | undefined>(
        CimExportSettingsDialogComponent,
        {
          width: '520px',
          maxWidth: '95vw',
          data: { mode: 'xml', options: this.xmlExportOpts },
        }
      )
      .afterClosed()
      .subscribe((result) => {
        if (result) {
          this.xmlExportOpts = result;
        }
      });
  }

  openDiffExportSettings(): void {
    this.dialog
      .open<CimExportSettingsDialogComponent, CimExportSettingsDialogData, CimExportOptions | undefined>(
        CimExportSettingsDialogComponent,
        {
          width: '520px',
          maxWidth: '95vw',
          data: { mode: '552', options: this.diffExportOpts },
        }
      )
      .afterClosed()
      .subscribe((result) => {
        if (result) {
          this.diffExportOpts = result;
        }
      });
  }

  exportXml(): void {
    const lineId = this.exportScope === 'partial' ? this.selectedLineId : null;
    if (this.exportScope === 'partial' && lineId == null) {
      this.error = 'Выберите ЛЭП для частичного экспорта';
      return;
    }
    if (!this.xmlExportOpts.includeSubstations && !this.xmlExportOpts.includePowerLines) {
      this.error = 'Включите хотя бы один объём: подстанции или ЛЭП';
      return;
    }

    const o = this.xmlExportOpts;
    this.apiService.exportCIMXml(
      o.includeSubstations,
      o.includePowerLines,
      o.useCimpy,
      o.includeGps,
      lineId,
      o.includeEquipment,
      o.includeElectricalModel,
      o.includeDefects,
      o.includeSubstationVoltageLevels
    ).subscribe({
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
        this.lastImportedFile = this.selectedDiffFile;
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
    if (!this.diffExportOpts.includeSubstations && !this.diffExportOpts.includePowerLines) {
      this.error = 'Включите хотя бы один объём: подстанции или ЛЭП';
      return;
    }

    const o = this.diffExportOpts;
    this.apiService.exportCIM552Diff(
      o.includeSubstations,
      o.includePowerLines,
      o.includeGps,
      lineId,
      o.includeEquipment,
      o.includeElectricalModel,
      o.includeDefects,
      o.includeSubstationVoltageLevels
    ).subscribe({
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

  private toMrid(ref: any): string | null {
    if (!ref) return null;
    if (typeof ref === 'string') return ref;
    if (typeof ref === 'object') return (ref.mRID || ref.mrid || null) as string | null;
    return null;
  }

  /** Извлечь геометрию (точки и линии) из разобранных CIM-объектов для предпросмотра. */
  private extractPreviewGeometryFromObjects(objects: any[]): {
    points: { lat: number; lng: number; label?: string }[];
    polylines: { from: [number, number]; to: [number, number]; label?: string }[];
  } {
    const byMrid: Record<string, any> = {};
    objects.forEach(o => { if (o?.mRID) byMrid[o.mRID] = o; });
    const points: { lat: number; lng: number; label?: string }[] = [];
    const polylines: { from: [number, number]; to: [number, number]; label?: string }[] = [];
    const locationCoords: Record<string, [number, number]> = {};
    const poleCoords: Record<string, [number, number]> = {};

    const addPoint = (latRaw: any, lngRaw: any, label?: string) => {
      const lat = Number(latRaw);
      const lng = Number(lngRaw);
      if (Number.isNaN(lat) || Number.isNaN(lng)) return;
      points.push({ lat, lng, label });
    };

    // 1) Собираем PositionPoint и индексируем в Location.
    objects.forEach(obj => {
      const cls = obj?._class || obj?.type;
      if (cls === 'PositionPoint') {
        const x = obj.xPosition ?? obj.XPosition;
        const y = obj.yPosition ?? obj.YPosition;
        addPoint(y, x, (obj.name || obj.mRID || '') as string);
      }
    });

    objects.forEach(obj => {
      const cls = obj?._class || obj?.type;
      if (cls !== 'Location') return;
      const refsRaw =
        obj.PositionPoints ??
        obj['Location.PositionPoints'] ??
        obj.PositionPoint ??
        obj['me:IdentifiedObject.ChildObjects'];
      const refs = Array.isArray(refsRaw) ? refsRaw : (refsRaw ? [refsRaw] : []);
      for (const ref of refs) {
        const mrid = this.toMrid(ref);
        const pp = mrid ? byMrid[mrid] : null;
        if (!pp || ((pp._class !== 'PositionPoint') && (pp.type !== 'PositionPoint'))) continue;
        const x = pp.xPosition ?? pp.XPosition;
        const y = pp.yPosition ?? pp.YPosition;
        const lat = Number(y);
        const lng = Number(x);
        if (Number.isNaN(lat) || Number.isNaN(lng)) continue;
        const locMrid = obj.mRID || obj.mrid;
        if (locMrid) locationCoords[locMrid] = [lat, lng];
        addPoint(lat, lng, (obj.name || pp.name || obj.mRID || '') as string);
        break;
      }
    });

    // 2) Опоры и подстанции по Location.
    objects.forEach(obj => {
      const cls = obj?._class || obj?.type;
      if (cls !== 'Pole' && cls !== 'Substation') return;
      const locMrid = this.toMrid(obj.Location ?? obj.location ?? obj['PowerSystemResource.Location']);
      if (!locMrid) return;
      const coord = locationCoords[locMrid];
      if (!coord) return;
      const [lat, lng] = coord;
      const label = (obj.name || obj.poleNumber || obj.pole_number || obj.mRID || '') as string;
      addPoint(lat, lng, label);
      if (cls === 'Pole' && obj.mRID) {
        poleCoords[obj.mRID] = [lat, lng];
      }
    });

    // 3) Связи LineSpan по опорам.
    objects.forEach(obj => {
      const cls = obj?._class || obj?.type;
      if (cls !== 'LineSpan') return;
      const fromPoleMrid = this.toMrid(obj.StartTower ?? obj['LineSpan.StartTower']);
      const toPoleMrid = this.toMrid(obj.EndTower ?? obj['LineSpan.EndTower']);
      if (!fromPoleMrid || !toPoleMrid) return;
      const from = poleCoords[fromPoleMrid];
      const to = poleCoords[toPoleMrid];
      if (!from || !to) return;
      polylines.push({
        from,
        to,
        label: (obj.name || obj.mRID || '') as string,
      });
    });

    return { points, polylines };
  }

  openPreviewMapDialog(): void {
    const preview = this.extractPreviewGeometryFromObjects(this.lastImportObjects);
    this.dialog.open(CimPreviewMapDialogComponent, {
      width: '560px',
      data: { points: preview.points, polylines: preview.polylines } as CimPreviewMapDialogData,
    });
  }

  apply552ToDb(): void {
    if (!this.lastImportedFile || this.isApplying) return;
    this.isApplying = true;
    this.error = null;
    this.apiService.applyCIM552Diff(this.lastImportedFile).subscribe({
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

