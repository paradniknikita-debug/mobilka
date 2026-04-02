import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import {
  CimExportOptions,
  cloneCimExportOptions,
  defaultCimExportOptions,
} from '../cim-export-options.model';

export interface CimExportSettingsDialogData {
  mode: 'xml' | '552';
  options: CimExportOptions;
}

@Component({
  selector: 'app-cim-export-settings-dialog',
  templateUrl: './cim-export-settings-dialog.component.html',
  styleUrls: ['./cim-export-settings-dialog.component.scss'],
})
export class CimExportSettingsDialogComponent {
  draft: CimExportOptions;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: CimExportSettingsDialogData,
    private dialogRef: MatDialogRef<CimExportSettingsDialogComponent, CimExportOptions | undefined>
  ) {
    this.draft = cloneCimExportOptions(data.options);
  }

  get dialogTitle(): string {
    return this.data.mode === 'xml'
      ? 'Настройки экспорта CIM XML'
      : 'Настройки экспорта 552 DifferenceModel';
  }

  selectAll(): void {
    this.draft = defaultCimExportOptions();
  }

  selectNone(): void {
    const o = this.draft as unknown as Record<string, boolean>;
    Object.keys(defaultCimExportOptions()).forEach((k) => {
      o[k] = false;
    });
  }

  onElectricalModelChange(enabled: boolean): void {
    if (!enabled) {
      this.draft.includeEquipment = false;
      this.draft.includeDefects = false;
    }
  }

  onEquipmentChange(enabled: boolean): void {
    if (!enabled) {
      this.draft.includeDefects = false;
    }
  }

  onSubstationsChange(enabled: boolean): void {
    if (!enabled) {
      this.draft.includeSubstationVoltageLevels = false;
    }
  }

  onPowerLinesChange(enabled: boolean): void {
    if (!enabled) {
      this.draft.includeElectricalModel = false;
      this.draft.includeEquipment = false;
      this.draft.includeDefects = false;
    }
  }

  save(): void {
    this.dialogRef.close(cloneCimExportOptions(this.draft));
  }

  cancel(): void {
    this.dialogRef.close(undefined);
  }
}
