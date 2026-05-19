import { Component, Inject, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import {
  CRITICALITY_LABELS,
  DEFECT_ITEMS,
  OTHER_DEFECT_KEY,
  defaultCriticalityForDefect,
  defectsForCategory,
} from '../../../core/data/defect-reference.data';
import { PoleEquipmentCategory, isElectricalEquipmentType } from '../../../core/data/pole-equipment.data';
import { PoleEquipmentDraft } from '../../../core/models/pole-equipment-draft.model';
import { EquipmentCatalogItem } from '../../../core/models/equipment-catalog.model';

export interface AddEquipmentDialogData {
  category: PoleEquipmentCategory;
  draft?: PoleEquipmentDraft;
  lineVoltageKv?: number | null;
}

export interface AddEquipmentDialogResult {
  draft: PoleEquipmentDraft;
}

@Component({
  selector: 'app-add-equipment-dialog',
  templateUrl: './add-equipment-dialog.component.html',
  styleUrls: ['./add-equipment-dialog.component.scss'],
})
export class AddEquipmentDialogComponent implements OnInit {
  form: FormGroup;
  defectOptions = DEFECT_ITEMS;
  readonly otherDefectKey = OTHER_DEFECT_KEY;
  readonly criticalityLabels = CRITICALITY_LABELS;
  catalogBrands: string[] = [];
  isElectrical = false;

  constructor(
    private fb: FormBuilder,
    private api: ApiService,
    public dialogRef: MatDialogRef<AddEquipmentDialogComponent, AddEquipmentDialogResult>,
    @Inject(MAT_DIALOG_DATA) public data: AddEquipmentDialogData,
  ) {
    const d = data.draft;
    const defectVal = d?.defect ?? '';
    this.form = this.fb.group({
      name: [d?.name ?? '', [Validators.required, Validators.maxLength(200)]],
      quantity: [
        { value: data.category.singleInstance ? 1 : d?.quantity ?? 1, disabled: !!data.category.singleInstance },
        [Validators.required, Validators.min(1)],
      ],
      defectSelect: [
        defectVal && DEFECT_ITEMS.some((x) => x.name === defectVal)
          ? defectVal
          : defectVal
            ? OTHER_DEFECT_KEY
            : '',
      ],
      otherDefect: [defectVal && !DEFECT_ITEMS.some((x) => x.name === defectVal) ? defectVal : ''],
      criticality: [d?.criticality ?? null],
      nameplate: [d?.nameplate ?? ''],
      ratedCurrent: [d?.ratedCurrent ?? null],
      iTh: [d?.iTh ?? null],
      ipMax: [d?.ipMax ?? null],
      tTh: [d?.tTh ?? null],
    });
    this.isElectrical = isElectricalEquipmentType(data.category.equipmentType);
    this.defectOptions = defectsForCategory(data.category.title);
  }

  ngOnInit(): void {
    this.loadCatalogBrands();
    this.form.get('defectSelect')?.valueChanges.subscribe((v) => {
      if (v === this.otherDefectKey) return;
      const crit = v ? defaultCriticalityForDefect(v, this.data.category.title) : null;
      if (crit) this.form.patchValue({ criticality: crit }, { emitEvent: false });
    });
  }

  private loadCatalogBrands(): void {
    const type = this.data.category.equipmentType;
    const typeCode = this.mapEquipmentTypeToCatalogCode(type);
    if (!typeCode) return;
    this.api.getEquipmentCatalog({ type_code: typeCode, is_active: true, limit: 500 }).subscribe({
      next: (items) => {
        const brands = new Set<string>();
        (items || []).forEach((it: EquipmentCatalogItem) => {
          const b = (it.brand || it.full_name || '').trim();
          if (b) brands.add(b);
        });
        this.catalogBrands = [...brands].sort((a, b) => a.localeCompare(b, 'ru'));
      },
      error: () => {
        this.catalogBrands = [];
      },
    });
  }

  get dialogTitle(): string {
    return this.data.draft ? `Редактировать: ${this.data.category.title}` : `Добавить: ${this.data.category.title}`;
  }

  cancel(): void {
    this.dialogRef.close();
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const raw = this.form.getRawValue();
    let defect: string | null = null;
    if (raw.defectSelect === this.otherDefectKey) {
      defect = String(raw.otherDefect || '').trim() || null;
    } else if (raw.defectSelect) {
      defect = String(raw.defectSelect).trim();
    }
    const draft: PoleEquipmentDraft = {
      localKey: this.data.draft?.localKey ?? `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      serverId: this.data.draft?.serverId,
      categoryTitle: this.data.category.title,
      equipmentType: this.data.category.equipmentType,
      name: String(raw.name || '').trim(),
      quantity: Number(raw.quantity) || 1,
      defect,
      criticality: raw.criticality || (defect ? defaultCriticalityForDefect(defect, this.data.category.title) : null),
      nameplate: raw.nameplate?.trim() || null,
      ratedCurrent: raw.ratedCurrent != null && raw.ratedCurrent !== '' ? Number(raw.ratedCurrent) : null,
      iTh: raw.iTh != null && raw.iTh !== '' ? Number(raw.iTh) : null,
      ipMax: raw.ipMax != null && raw.ipMax !== '' ? Number(raw.ipMax) : null,
      tTh: raw.tTh != null && raw.tTh !== '' ? Number(raw.tTh) : null,
    };
    this.dialogRef.close({ draft });
  }

  private mapEquipmentTypeToCatalogCode(type: string): string | null {
    const v = (type || '').trim().toLowerCase();
    if (!v) return null;
    switch (v) {
      case 'grounding_switch':
        return 'zn';
      case 'surge_arrester':
      case 'разрядник':
        return 'arrester';
      case 'disconnector':
      case 'разъединитель':
        return 'disconnector';
      case 'recloser':
      case 'реклоузер':
        return 'recloser';
      default:
        return v;
    }
  }
}
