import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';
import { PowerLine } from '../../core/models/power-line.model';

@Component({
  selector: 'app-reports',
  templateUrl: './reports.component.html',
  styleUrls: ['./reports.component.scss']
})
export class ReportsComponent implements OnInit {
  powerLines: PowerLine[] = [];
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
        this.powerLines = list || [];
        this.selectedLineId = this.selectedLineId ?? (this.powerLines.length ? this.powerLines[0].id : null);
      },
      error: () => {}
    });
  }

  onReportTabChange(i: number): void {
    this.reportTabIndex = i;
    this.reportsError = null;
    this.byLineReport = null;
    this.defectsReport = null;
    this.patrolReport = null;
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

