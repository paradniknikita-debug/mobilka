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

  lengthKm(): number {
    return this.segment?.length ?? 0;
  }

  sectionLengthDisplay(sec: LineSection): string {
    if (sec.total_length != null) {
      return sec.total_length >= 1000
        ? `${(sec.total_length / 1000).toFixed(2)} км`
        : `${sec.total_length.toFixed(0)} м`;
    }
    return '—';
  }

  onClose(): void {
    this.dialogRef.close();
  }
}
