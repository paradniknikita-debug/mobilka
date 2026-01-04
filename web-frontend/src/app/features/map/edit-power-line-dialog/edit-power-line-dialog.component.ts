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
    @Inject(MAT_DIALOG_DATA) public data: { powerLineId: number },
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
      branch_name: [''],
      region_name: [''],
      status: ['active'],
      description: ['']
    });
  }

  ngOnInit(): void {
    this.loadPowerLine();
  }

  loadPowerLine(): void {
    this.apiService.getPowerLine(this.data.powerLineId).subscribe({
      next: (powerLine) => {
        this.powerLine = powerLine;
        this.powerLineForm.patchValue({
          name: powerLine.name,
          voltage_level: powerLine.voltage_level,
          length: powerLine.length,
          branch_name: '', // Эти поля не хранятся в PowerLine, только в description
          region_name: '',
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

    this.apiService.updatePowerLine(this.data.powerLineId, formValue).subscribe({
      next: (updated) => {
        this.snackBar.open('ЛЭП успешно обновлена', 'Закрыть', { duration: 3000 });
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

