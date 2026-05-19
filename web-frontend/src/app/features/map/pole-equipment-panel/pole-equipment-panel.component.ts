import { Component, Input, OnChanges, SimpleChanges } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { ApiService } from '../../../core/services/api.service';
import { POLE_EQUIPMENT_CATEGORIES, PoleEquipmentCategory } from '../../../core/data/pole-equipment.data';
import { CRITICALITY_LABELS } from '../../../core/data/defect-reference.data';
import { PoleEquipmentDraft, equipmentToDraft } from '../../../core/models/pole-equipment-draft.model';
import { buildEquipmentCreateBody } from '../../../core/utils/equipment-form.util';
import {
  AddEquipmentDialogComponent,
  AddEquipmentDialogData,
  AddEquipmentDialogResult,
} from '../add-equipment-dialog/add-equipment-dialog.component';

@Component({
  selector: 'app-pole-equipment-panel',
  templateUrl: './pole-equipment-panel.component.html',
  styleUrls: ['./pole-equipment-panel.component.scss'],
})
export class PoleEquipmentPanelComponent implements OnChanges {
  @Input() poleId: number | null = null;
  @Input() lineVoltageKv: number | null = null;

  readonly categories = POLE_EQUIPMENT_CATEGORIES;
  readonly criticalityLabels = CRITICALITY_LABELS;
  items: PoleEquipmentDraft[] = [];
  loading = false;

  constructor(
    private dialog: MatDialog,
    private api: ApiService,
    private snackBar: MatSnackBar,
  ) {}

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['poleId']) {
      this.reload();
    }
  }

  reload(): void {
    if (!this.poleId) {
      return;
    }
    this.loading = true;
    this.api.getPoleEquipment(this.poleId).subscribe({
      next: (rows) => {
        this.items = (rows || []).map((eq) => equipmentToDraft(eq));
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.snackBar.open('Не удалось загрузить оборудование опоры', 'Закрыть', { duration: 4000 });
      },
    });
  }

  visibleItems(): PoleEquipmentDraft[] {
    return this.items.filter((i) => !i.markedDelete);
  }

  hasPendingChanges(): boolean {
    return this.items.some((i) => i.markedDelete || !i.serverId);
  }

  categoryHasItem(cat: PoleEquipmentCategory): boolean {
    return this.visibleItems().some((i) => i.categoryTitle === cat.title);
  }

  addEquipment(cat: PoleEquipmentCategory): void {
    if (cat.singleInstance && this.categoryHasItem(cat)) {
      this.snackBar.open(`${cat.title} уже добавлен`, 'Закрыть', { duration: 3000 });
      return;
    }
    this.openDialog(cat);
  }

  editItem(item: PoleEquipmentDraft): void {
    const cat = this.categories.find((c) => c.title === item.categoryTitle) ?? {
      title: item.categoryTitle,
      equipmentType: item.equipmentType,
    };
    this.openDialog(cat, item);
  }

  removeItem(item: PoleEquipmentDraft): void {
    if (item.serverId) {
      item.markedDelete = true;
    } else {
      this.items = this.items.filter((i) => i.localKey !== item.localKey);
    }
  }

  criticalityLabel(c: string | null | undefined): string {
    if (!c) return '';
    return this.criticalityLabels[c] || c;
  }

  /** Сохранить черновики и изменения после создания/обновления опоры. */
  persistAll(poleId: number): Observable<void> {
    const ops: Observable<unknown>[] = [];
    for (const item of this.items) {
      if (item.markedDelete && item.serverId) {
        ops.push(this.api.deleteEquipment(item.serverId).pipe(catchError(() => of(null))));
        continue;
      }
      if (item.markedDelete) continue;

      const body = buildEquipmentCreateBody(item, poleId, this.lineVoltageKv);
      if (item.serverId) {
        ops.push(
          this.api.updateEquipment(item.serverId, body).pipe(catchError(() => of(null))),
        );
      } else {
        const qty = Math.max(1, item.quantity || 1);
        for (let i = 0; i < qty; i++) {
          const one = { ...body, name: qty > 1 ? `${body.name} (${i + 1})` : body.name };
          ops.push(
            this.api.createEquipment(poleId, one).pipe(catchError(() => of(null))),
          );
        }
      }
    }
    if (!ops.length) return of(void 0);
    return forkJoin(ops).pipe(map(() => void 0));
  }

  private openDialog(cat: PoleEquipmentCategory, draft?: PoleEquipmentDraft): void {
    const data: AddEquipmentDialogData = {
      category: cat,
      draft,
      lineVoltageKv: this.lineVoltageKv,
    };
    this.dialog
      .open<AddEquipmentDialogComponent, AddEquipmentDialogData, AddEquipmentDialogResult>(
        AddEquipmentDialogComponent,
        { width: '480px', data },
      )
      .afterClosed()
      .subscribe((result) => {
        if (!result?.draft) return;
        const idx = this.items.findIndex((i) => i.localKey === result.draft.localKey);
        if (idx >= 0) {
          this.items[idx] = { ...result.draft, serverId: this.items[idx].serverId };
        } else {
          this.items.push(result.draft);
        }
      });
  }
}
