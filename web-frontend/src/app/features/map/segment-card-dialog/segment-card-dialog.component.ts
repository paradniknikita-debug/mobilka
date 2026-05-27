import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { AClineSegment, ConnectivityNode, LineSection, Span } from '../../../core/models/cim.model';
import { Substation } from '../../../core/models/substation.model';

export interface SegmentCardDialogData {
  segmentId: number;
  lineId?: number;
  segmentName?: string;
}

@Component({
  selector: 'app-segment-card-dialog',
  templateUrl: './segment-card-dialog.component.html',
  styleUrls: ['./segment-card-dialog.component.scss']
})
export class SegmentCardDialogComponent {
  segment: AClineSegment | null = null;
  substations: Substation[] = [];
  selectedSubstationIdForTap: number | null = null;
  loading = true;
  error: string | null = null;
  savingTapSubstation = false;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: SegmentCardDialogData,
    private dialogRef: MatDialogRef<SegmentCardDialogComponent>,
    private apiService: ApiService
  ) {
    this.loadSegment();
  }

  loadSegment(): void {
    this.loading = true;
    this.error = null;
    this.apiService.getAClineSegment(this.data.segmentId).subscribe({
      next: (seg) => {
        this.segment = seg;
        this.loading = false;
        if (seg?.is_tap) {
          this.apiService.getSubstations().subscribe({
            next: (list) => { this.substations = list; }
          });
        }
      },
      error: (err) => {
        this.error = err.error?.detail || err.message || 'Не удалось загрузить участок';
        this.loading = false;
      }
    });
  }

  get lineSections(): LineSection[] {
    const sections = this.segment?.line_sections ?? [];
    return [...sections].sort((a, b) => (a.sequence_number ?? 0) - (b.sequence_number ?? 0));
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

  /** Диапазон опор секции: имя секции с бэкенда (по CN/ПС) или цепочка пролётов */
  sectionLabel(sec: LineSection): string {
    const fromName = this.sectionRangeFromName(sec.name);
    if (fromName) {
      return fromName;
    }
    return this.sectionPoleRange(sec);
  }

  /** «Опора 3 - РВ-10 (AC-70)» → «оп.3-РВ-10» */
  private sectionRangeFromName(name: string | undefined | null): string | null {
    const raw = (name || '').trim();
    if (!raw) return null;
    const withoutWire = raw.replace(/\s*\([^)]*\)\s*$/, '').trim();
    if (!withoutWire.includes('-')) return null;
    return withoutWire
      .replace(/Опора\s+/gi, 'оп.')
      .replace(/\s*-\s*/g, '-')
      .trim();
  }

  /** Диапазон по пролётам секции (отсортированным по sequence_number) */
  sectionPoleRange(sec: LineSection): string {
    const spans = this.sortedSpans(sec);
    if (spans.length === 0) return '—';
    const fromLabel = this.nodeDisplayLabel(spans[0].from_connectivity_node, spans[0], 'from');
    const toLabel = this.nodeDisplayLabel(spans[spans.length - 1].to_connectivity_node, spans[spans.length - 1], 'to');
    return `${fromLabel}-${toLabel}`;
  }

  private sortedSpans(sec: LineSection): Span[] {
    return [...(sec.spans ?? [])].sort(
      (a, b) => (a.sequence_number ?? 0) - (b.sequence_number ?? 0)
    );
  }

  private nodeDisplayLabel(
    node: ConnectivityNode | undefined | null,
    span: Span,
    end: 'from' | 'to'
  ): string {
    const poleNum =
      node?.pole_number ??
      (end === 'from' ? (span as any).from_pole_number : (span as any).to_pole_number);
    if (poleNum != null && String(poleNum).trim()) {
      return `оп.${this.poleLabelToOp(poleNum)}`;
    }
    const nodeName = (node?.name || '').trim();
    if (nodeName) {
      if (/^узел\s+/i.test(nodeName)) {
        const rest = nodeName.replace(/^узел\s+/i, '').trim();
        return rest ? `оп.${this.poleLabelToOp(rest)}` : nodeName;
      }
      return nodeName.replace(/Опора\s+/gi, 'оп.');
    }
    const poleId = end === 'from' ? span.from_pole_id : span.to_pole_id;
    return poleId != null ? `оп.${poleId}` : '?';
  }

  /** «Опора 1» / «1» → «1» для использования в «оп.X» */
  poleLabelToOp(poleNumber: string | number | undefined): string {
    if (poleNumber == null) return '?';
    const s = String(poleNumber).trim();
    if (s.toLowerCase().startsWith('опора')) return s.slice(5).trim() || s;
    if (s.toLowerCase().startsWith('оп.')) return s.slice(3).trim() || s;
    return s;
  }

  /** Наименование участка для отображения: «Опора 1 - Опора 3» → «оп.1-оп.3» */
  segmentNameDisplay(): string {
    const name = this.segment?.name ?? '';
    if (!name) return '—';
    return name.replace(/Опора\s+/gi, 'оп.').replace(/\s*-\s*/g, '-').trim() || name;
  }

  onClose(): void {
    this.dialogRef.close();
  }

  /** Название подстанции по id для отображения «ТП в конце» */
  getSubstationNameById(id: number | null | undefined): string {
    if (id == null) return '—';
    const s = this.substations.find(x => x.id === id);
    return s ? (s.name || s.dispatcher_name || `ПС ${id}`) : `ПС ${id}`;
  }

  setTapSubstation(): void {
    const plId = this.data.lineId;
    if (plId == null || !this.segment || this.selectedSubstationIdForTap == null) return;
    this.savingTapSubstation = true;
    this.apiService.setSegmentEndSubstation(plId, this.data.segmentId, { to_substation_id: this.selectedSubstationIdForTap }).subscribe({
      next: () => {
        this.savingTapSubstation = false;
        this.segment = { ...this.segment!, to_substation_id: this.selectedSubstationIdForTap };
      },
      error: () => { this.savingTapSubstation = false; }
    });
  }

  clearTapSubstation(): void {
    const plId = this.data.lineId;
    if (plId == null || !this.segment) return;
    this.savingTapSubstation = true;
    this.apiService.setSegmentEndSubstation(plId, this.data.segmentId, { to_substation_id: null }).subscribe({
      next: () => {
        this.savingTapSubstation = false;
        this.segment = { ...this.segment!, to_substation_id: null };
        this.selectedSubstationIdForTap = null;
      },
      error: () => { this.savingTapSubstation = false; }
    });
  }
}
