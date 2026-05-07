import { Component, Inject, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MapService } from '../../../core/services/map.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { PowerLine } from '../../../core/models/power-line.model';

@Component({
  selector: 'app-edit-power-line-dialog',
  templateUrl: './edit-power-line-dialog.component.html',
  styleUrls: ['./edit-power-line-dialog.component.scss']
})
export class EditPowerLineDialogComponent implements OnInit {
  powerLineForm: FormGroup;
  isSubmitting = false;
  powerLine: PowerLine | null = null;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { lineId: number },
    private dialogRef: MatDialogRef<EditPowerLineDialogComponent>,
    private fb: FormBuilder,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {
    this.powerLineForm = this.fb.group({
      name: ['', [Validators.required, Validators.maxLength(100)]],
      voltage_level: [null],
      length: [null],
      dispatcher_name: [''],
      branch_name: [''],
      region_name: [''],
      region_uid: ['c3d4e5f6-7890-1234-cdef-345678901234'],
      balance_ownership: [''],
      parent_object_ref: [''],
      alcs_ref: [''],
      status: ['active'],
      description: ['']
    });
  }

  ngOnInit(): void {
    this.loadPowerLine();
  }

  loadPowerLine(): void {
    this.apiService.getPowerLine(this.data.lineId).subscribe({
      next: (powerLine) => {
        this.powerLine = powerLine;
        this.powerLineForm.patchValue({
          name: powerLine.name,
          voltage_level: powerLine.voltage_level,
          length: powerLine.length,
          dispatcher_name: powerLine.dispatcher_name || '',
          branch_name: powerLine.branch_name || '',
          region_name: powerLine.region_name || '',
          region_uid: powerLine.region_uid || 'c3d4e5f6-7890-1234-cdef-345678901234',
          balance_ownership: powerLine.balance_ownership || '',
          parent_object_ref: powerLine.parent_object_ref || '',
          alcs_ref: powerLine.alcs_ref || '',
          status: powerLine.status,
          description: powerLine.description || ''
        });
      },
      error: (error) => {
        console.error('Ошибка загрузки ЛЭП:', error);
        this.snackBar.open('Ошибка загрузки данных ЛЭП', 'Закрыть', { duration: 3000 });
        this.dialogRef.close();
      }
    });
  }

  onSubmit(): void {
    if (this.powerLineForm.invalid) {
      return;
    }

    this.isSubmitting = true;
    const formValue = this.powerLineForm.value;

    this.apiService.updatePowerLine(this.data.lineId, formValue).subscribe({
      next: (updated) => {
        this.snackBar.open('ЛЭП успешно обновлена', 'Закрыть', { duration: 3000 });
        this.apiService.createChangeLogEntry({
          source: 'web',
          action: 'update',
          entity_type: 'power_line',
          entity_id: updated.id,
          payload: { name: updated.name, mrid: updated.mrid }
        }).subscribe({ error: () => {} });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, powerLine: updated });
      },
      error: (error) => {
        console.error('Ошибка обновления ЛЭП:', error);
        this.snackBar.open('Ошибка обновления ЛЭП: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isSubmitting = false;
      }
    });
  }

  onCancel(): void {
    this.dialogRef.close();
  }
}

