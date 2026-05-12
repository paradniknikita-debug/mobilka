import { Component, Input, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { PowerLine } from '../../core/models/power-line.model';

@Component({
  selector: 'app-reports',
  templateUrl: './reports.component.html',
  styleUrls: ['./reports.component.scss']
})
export class ReportsComponent implements OnInit {
  /** Внутри «Паспортизация» — без дублирующего заголовка страницы. */
  @Input() embedded = false;

  powerLines: PowerLine[] = [];
  /** Ошибка загрузки списка ЛЭП (отдельно от ошибок отчёта). */
  linesLoadError: string | null = null;
  reportsError: string | null = null;
  reportsLoading = false;
  reportTabIndex = 0; // 0=defects,1=byLine,2=patrol
  selectedLineId: number | null = null;

  defectsCriticality: string | null = null;
  defectsFromDt: string | null = null;
  defectsToDt: string | null = null;
  defectsSearch: string | null = null;
  defectsReport: any | null = null;

  byLineReport: any | null = null;

  patrolFromDt: string | null = null;
  patrolToDt: string | null = null;
  patrolReport: any | null = null;

  constructor(private apiService: ApiService) {}

  ngOnInit(): void {
    this.apiService.getPowerLines().subscribe({
      next: (list) => {
        this.linesLoadError = null;
        this.powerLines = (list || []).map((pl) => ({ ...pl, id: Number(pl.id) }));
        this.syncDefaultLineForTab();
      },
      error: (e) => {
        this.linesLoadError =
          e?.error?.detail || e?.message || 'Не удалось загрузить список ЛЭП';
        this.powerLines = [];
        this.selectedLineId = null;
      }
    });
  }

  /** Вкладка «По ЛЭП» требует конкретную линию; «Все» оставляем для дефектов/обходов. */
  private syncDefaultLineForTab(): void {
    if (!this.powerLines.length) {
      this.selectedLineId = null;
      return;
    }
    const valid =
      this.selectedLineId != null && this.powerLines.some((p) => p.id === this.selectedLineId);
    if (!valid) {
      this.selectedLineId = null;
    }
    if (this.reportTabIndex === 1 && this.selectedLineId == null) {
      this.selectedLineId = this.powerLines[0].id;
    }
  }

  onReportTabChange(i: number): void {
    this.reportTabIndex = i;
    this.reportsError = null;
    this.byLineReport = null;
    this.defectsReport = null;
    this.patrolReport = null;
    this.syncDefaultLineForTab();
  }

  loadDefectsReport(): void {
    this.reportsLoading = true;
    this.reportsError = null;
    this.defectsReport = null;
    this.apiService.getDefectsReport({
      line_id: this.selectedLineId,
      criticality: this.defectsCriticality,
      from_dt: this.defectsFromDt,
      to_dt: this.defectsToDt,
      defect_contains: this.defectsSearch,
      limit: 200,
      offset: 0,
      format: 'json'
    }).subscribe({
      next: (r) => {
        this.defectsReport = r;
        this.reportsLoading = false;
      },
      error: (e) => {
        this.reportsError = e?.error?.detail || e?.message || 'Ошибка отчета по дефектам';
        this.reportsLoading = false;
      }
    });
  }

  downloadDefectsCsv(): void {
    if (!this.selectedLineId) return;
    this.reportsLoading = true;
    this.reportsError = null;
    this.apiService.downloadDefectsReportCsv({
      line_id: this.selectedLineId,
      criticality: this.defectsCriticality,
      from_dt: this.defectsFromDt,
      to_dt: this.defectsToDt,
      defect_contains: this.defectsSearch,
      limit: 200,
      offset: 0
    }).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `defects_report_${new Date().toISOString().replace(/[:.]/g, '-')}.csv`;
        a.click();
        window.URL.revokeObjectURL(url);
        this.reportsLoading = false;
      },
      error: (e) => {
        this.reportsError = e?.error?.detail || e?.message || 'Ошибка скачивания CSV';
        this.reportsLoading = false;
      }
    });
  }

  onLineSelectionChange(): void {
    this.byLineReport = null;
  }

  loadByLineReport(): void {
    if (!this.selectedLineId) return;
    this.reportsLoading = true;
    this.reportsError = null;
    this.byLineReport = null;
    this.apiService.getByLineReport(this.selectedLineId).subscribe({
      next: (r) => {
        this.byLineReport = r;
        this.reportsLoading = false;
      },
      error: (e) => {
        this.reportsError = e?.error?.detail || e?.message || 'Ошибка отчета по ЛЭП';
        this.reportsLoading = false;
      }
    });
  }

  loadPatrolReport(): void {
    this.reportsLoading = true;
    this.reportsError = null;
    this.patrolReport = null;
    this.apiService.getPatrolReport({
      line_id: this.selectedLineId,
      from_dt: this.patrolFromDt,
      to_dt: this.patrolToDt,
      limit: 200,
      offset: 0
    }).subscribe({
      next: (r) => {
        this.patrolReport = r;
        this.reportsLoading = false;
      },
      error: (e) => {
        this.reportsError = e?.error?.detail || e?.message || 'Ошибка отчета по обходам';
        this.reportsLoading = false;
      }
    });
  }
}

