import { Component, Inject, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MapService } from '../../../core/services/map.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AClineSegmentCreate } from '../../../core/models/cim.model';
import { Pole } from '../../../core/models/pole.model';

@Component({
  selector: 'app-create-segment-dialog',
  templateUrl: './create-segment-dialog.component.html',
  styleUrls: ['./create-segment-dialog.component.scss']
})
export class CreateSegmentDialogComponent implements OnInit {
  segmentForm: FormGroup;
  isSubmitting = false;
  poles: Pole[] = [];
  isLoading = false;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { powerLineId: number },
    private dialogRef: MatDialogRef<CreateSegmentDialogComponent>,
    private fb: FormBuilder,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {
    this.segmentForm = this.fb.group({
      name: ['', Validators.required],
      voltage_level: [null],
      length: [null],
      from_pole_id: ['', Validators.required],
      to_pole_id: ['', Validators.required],
      is_tap: [false],
      tap_number: [''],
      description: ['']
    });
  }

  ngOnInit(): void {
    this.loadPoles();
  }

  loadPoles(): void {
    this.isLoading = true;
    this.apiService.getPolesSequence(this.data.powerLineId).subscribe({
      next: (poles) => {
        this.poles = poles || [];
        this.isLoading = false;
      },
      error: (error) => {
        console.error('Ошибка загрузки опор:', error);
        this.snackBar.open('Ошибка загрузки опор', 'Закрыть', { duration: 3000 });
        this.isLoading = false;
      }
    });
  }

  displayPole(pole: Pole): string {
    return pole.pole_number || `ID: ${pole.id}`;
  }

  onSubmit(): void {
    if (this.segmentForm.invalid) {
      return;
    }

    const fromPoleId = this.segmentForm.get('from_pole_id')?.value;
    const toPoleId = this.segmentForm.get('to_pole_id')?.value;

    if (fromPoleId === toPoleId) {
      this.snackBar.open('Начальная и конечная опоры не могут быть одинаковыми', 'Закрыть', { duration: 3000 });
      return;
    }

    this.isSubmitting = true;
    const formValue = this.segmentForm.value;

    // Получаем ConnectivityNode для опор
    const fromPole = this.poles.find(p => p.id === fromPoleId);
    const toPole = this.poles.find(p => p.id === toPoleId);

    if (!fromPole?.connectivity_node_id || !toPole?.connectivity_node_id) {
      this.snackBar.open('У выбранных опор должны быть узлы соединения', 'Закрыть', { duration: 3000 });
      this.isSubmitting = false;
      return;
    }

    const segmentData: AClineSegmentCreate = {
      name: formValue.name,
      power_line_id: this.data.powerLineId,
      voltage_level: formValue.voltage_level || 0,
      length: formValue.length || 0,
      from_connectivity_node_id: fromPole.connectivity_node_id!,
      to_connectivity_node_id: toPole.connectivity_node_id!,
      is_tap: formValue.is_tap || false,
      tap_number: formValue.tap_number || undefined
    };

    this.apiService.createAClineSegment(segmentData).subscribe({
      next: (segment) => {
        this.snackBar.open('Участок успешно создан', 'Закрыть', { duration: 3000 });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, segment });
      },
      error: (error) => {
        console.error('Ошибка создания участка:', error);
        this.snackBar.open('Ошибка создания участка: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isSubmitting = false;
      }
    });
  }

  onCancel(): void {
    this.dialogRef.close();
  }
}

