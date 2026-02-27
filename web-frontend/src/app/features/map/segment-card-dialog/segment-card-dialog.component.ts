import { Component, Inject, HostListener, ElementRef } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { AClineSegment, LineSection } from '../../../core/models/cim.model';

export interface SegmentCardDialogData {
  segmentId: number;
  powerLineId?: number;
  segmentName?: string;
}

@Component({
  selector: 'app-segment-card-dialog',
  templateUrl: './segment-card-dialog.component.html',
  styleUrls: ['./segment-card-dialog.component.scss']
})
export class SegmentCardDialogComponent {
  segment: AClineSegment | null = null;
  loading = true;
  error: string | null = null;
  private resizing = false;
  private startX = 0;
  private startY = 0;
  private startW = 0;
  private startH = 0;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: SegmentCardDialogData,
    private dialogRef: MatDialogRef<SegmentCardDialogComponent>,
    private apiService: ApiService,
    private el: ElementRef<HTMLElement>
  ) {
    this.loadSegment();
  }

  private boundDoResize = (e: MouseEvent) => this.doResize(e);
  private boundStopResize = () => this.stopResize();

  startResize(e: MouseEvent): void {
    e.preventDefault();
    const container = this.el.nativeElement.closest('.mat-mdc-dialog-container') as HTMLElement;
    if (!container) return;
    this.resizing = true;
    this.startX = e.clientX;
    this.startY = e.clientY;
    this.startW = container.offsetWidth;
    this.startH = container.offsetHeight;
    document.addEventListener('mousemove', this.boundDoResize);
    document.addEventListener('mouseup', this.boundStopResize);
  }

  private doResize(e: MouseEvent): void {
    if (!this.resizing) return;
    const container = this.el.nativeElement.closest('.mat-mdc-dialog-container') as HTMLElement;
    if (!container) return;
    const dw = e.clientX - this.startX;
    const dh = e.clientY - this.startY;
    const w = Math.max(360, this.startW + dw);
    const h = Math.max(200, this.startH + dh);
    container.style.width = w + 'px';
    container.style.height = h + 'px';
    container.style.maxWidth = '95vw';
    container.style.maxHeight = '90vh';
  }

  private stopResize(): void {
    this.resizing = false;
    document.removeEventListener('mousemove', this.boundDoResize);
    document.removeEventListener('mouseup', this.boundStopResize);
  }

  @HostListener('document:mouseup')
  onDocMouseUp(): void {
    if (this.resizing) this.stopResize();
  }

  loadSegment(): void {
    this.loading = true;
    this.error = null;
    this.apiService.getAClineSegment(this.data.segmentId).subscribe({
      next: (seg) => {
        this.segment = seg;
        this.loading = false;
      },
      error: (err) => {
        this.error = err.error?.detail || err.message || 'Не удалось загрузить участок';
        this.loading = false;
      }
    });
  }

  get lineSections(): LineSection[] {
    return this.segment?.line_sections ?? [];
  }

  /** Длина участка по пролётам (в км); совпадает с суммой длин секций при корректных данных */
  lengthKm(): number {
    return this.segment?.length ?? 0;
  }

  /** Длина секции: total_length на бэкенде в км — показываем в км или м */
  sectionLengthDisplay(sec: LineSection): string {
    const v = sec.total_length;
    if (v == null) return '—';
    if (v >= 1) return `${v.toFixed(2)} км`;
    if (v > 0) return `${Math.round(v * 1000)} м`;
    return '0 м';
  }

  /** Диапазон опор секции в формате «оп.X-оп.Y» (без дублирования слова «Опора») */
  sectionPoleRange(sec: LineSection): string {
    const spans = sec.spans ?? [];
    if (spans.length === 0) return '—';
    const fromNum = this.poleLabelToOp(spans[0].from_connectivity_node?.pole_number ?? spans[0].from_connectivity_node_id);
    const toNum = this.poleLabelToOp(spans[spans.length - 1].to_connectivity_node?.pole_number ?? spans[spans.length - 1].to_connectivity_node_id);
    return `оп.${fromNum}-оп.${toNum}`;
  }

  /** «Опора 1» / «1» → «1» для использования в «оп.X» (убираем дублирование слова Опора) */
  poleLabelToOp(poleNumber: string | number | undefined): string {
    if (poleNumber == null) return '?';
    const s = String(poleNumber).trim();
    if (s.toLowerCase().startsWith('опора')) return s.slice(5).trim() || s;
    return s;
  }

  /** Наименование участка для отображения: «Опора 1 - Опора 3» → «оп.1-оп.3» */
  segmentNameDisplay(): string {
    const name = this.segment?.name ?? '';
    if (!name) return '—';
    return name.replace(/Опора\s+/gi, 'оп.').replace(/\s*-\s*/g, '-').trim() || name;
  }

  /** Строка вида «оп.X-оп.Y АС-70» для секции */
  sectionLabel(sec: LineSection): string {
    const range = this.sectionPoleRange(sec);
    const wire = sec.conductor_type || '—';
    return range !== '—' ? `${range} ${wire}` : wire;
  }

  onClose(): void {
    this.dialogRef.close();
  }
}
