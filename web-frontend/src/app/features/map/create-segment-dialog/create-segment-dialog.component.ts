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
  
  // Режим редактирования
  isEditMode = false;
  segmentId?: number;
  powerLineId: number;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { 
      powerLineId: number;
      segmentId?: number;
      isEdit?: boolean;
    },
    private dialogRef: MatDialogRef<CreateSegmentDialogComponent>,
    private fb: FormBuilder,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {
    this.powerLineId = data.powerLineId;
    this.segmentId = data.segmentId;
    this.isEditMode = data.isEdit || false;
    
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
  
  loadSegment(): void {
    if (!this.segmentId) return;
    
    this.isLoading = true;
    this.apiService.getAClineSegment(this.segmentId).subscribe({
      next: (segment) => {
        // Находим опоры по connectivity_node_id
        const fromPole = this.poles.find(p => p.connectivity_node_id === segment.from_connectivity_node_id);
        const toPole = segment.to_connectivity_node_id 
          ? this.poles.find(p => p.connectivity_node_id === segment.to_connectivity_node_id)
          : null;
        
        // Заполняем форму данными участка (сохраняем текущие значения опор)
        this.segmentForm.patchValue({
          name: segment.name || '',
          voltage_level: segment.voltage_level || null,
          length: segment.length || null,
          from_pole_id: fromPole?.id || this.segmentForm.get('from_pole_id')?.value || '',
          to_pole_id: toPole?.id || this.segmentForm.get('to_pole_id')?.value || '',
          is_tap: segment.is_tap || false,
          tap_number: segment.tap_number || '',
          description: segment.description || ''
        });
        this.isLoading = false;
      },
      error: (error) => {
        console.error('Ошибка загрузки участка:', error);
        this.snackBar.open('Ошибка загрузки данных участка: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isLoading = false;
      }
    });
  }

  loadPoles(): void {
    this.isLoading = true;
    this.apiService.getPolesSequence(this.powerLineId).subscribe({
      next: (poles) => {
        this.poles = poles || [];
        this.isLoading = false;
        // Если режим редактирования, загружаем данные участка после загрузки опор
        if (this.isEditMode && this.segmentId) {
          setTimeout(() => {
            this.loadSegment();
          }, 100);
        }
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

    // Используем API для создания или обновления участка
    const segmentObservable = this.isEditMode && this.segmentId
      ? this.apiService.updateAClineSegment(this.segmentId, segmentData)
      : this.apiService.createAClineSegment(segmentData);
    
    segmentObservable.subscribe({
      next: (segment) => {
        const message = this.isEditMode ? 'Участок успешно обновлён' : 'Участок успешно создан';
        this.snackBar.open(message, 'Закрыть', { duration: 3000 });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, segment });
      },
      error: (error) => {
        const action = this.isEditMode ? 'обновления' : 'создания';
        console.error(`Ошибка ${action} участка:`, error);
        let errorMessage = `Ошибка ${action} участка`;
        
        if (error.error?.detail) {
          if (Array.isArray(error.error.detail)) {
            errorMessage = error.error.detail.map((err: any) => 
              typeof err === 'string' ? err : `${err.loc?.join('.')}: ${err.msg}`
            ).join(', ');
          } else {
            errorMessage = error.error.detail;
          }
        }
        
        this.snackBar.open(errorMessage, 'Закрыть', { duration: 5000 });
        this.isSubmitting = false;
      }
    });
  }

  onCancel(): void {
    this.dialogRef.close();
  }
}

