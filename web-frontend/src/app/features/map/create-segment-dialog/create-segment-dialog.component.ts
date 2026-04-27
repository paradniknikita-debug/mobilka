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
  
  /** Показывать выбор «По магистрали» / «По отпайке», если начальная опора — отпаечная */
  showBranchChoice = false;
  /** Начальная опора (для tap_pole_id при выборе «По отпайке») */
  fromPoleForBranch: Pole | null = null;
  
  // Режим редактирования
  isEditMode = false;
  segmentId?: number;
  lineId: number;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { 
      lineId: number;
      segmentId?: number;
      isEdit?: boolean;
    },
    private dialogRef: MatDialogRef<CreateSegmentDialogComponent>,
    private fb: FormBuilder,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {
    this.lineId = data.lineId;
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
      description: [''],
      branch_type: ['main'],
      conductor_type: [''],
      conductor_material: [''],
      conductor_section: [''],
      r: [null],
      x: [null],
      b: [null],
      g: [null],
      r0: [null],
      x0: [null],
      bch: [null],
      b0ch: [null],
      gch: [null],
      g0ch: [null],
      i_th: [null],
      t_th: [null],
      sections: [null],
      short_circuit_end_temperature: [null],
      is_jumper: [false]
    });
  }

  ngOnInit(): void {
    this.loadPoles();
    this.segmentForm.get('from_pole_id')?.valueChanges.subscribe((fromId: number) => {
      this.fromPoleForBranch = fromId ? (this.poles.find(p => p.id === fromId) ?? null) : null;
      this.showBranchChoice = !!(this.fromPoleForBranch && (this.fromPoleForBranch as any).is_tap_pole);
      if (this.showBranchChoice && !this.segmentForm.get('branch_type')?.value) {
        this.segmentForm.patchValue({ branch_type: 'main' });
      }
    });
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
          description: segment.description || '',
          branch_type: (segment as any).branch_type === 'tap' ? 'tap' : 'main',
          conductor_type: (segment as any).conductor_type || '',
          conductor_material: (segment as any).conductor_material || '',
          conductor_section: (segment as any).conductor_section || '',
          r: (segment as any).r ?? null,
          x: (segment as any).x ?? null,
          b: (segment as any).b ?? null,
          g: (segment as any).g ?? null,
          r0: (segment as any).r0 ?? null,
          x0: (segment as any).x0 ?? null,
          bch: (segment as any).bch ?? null,
          b0ch: (segment as any).b0ch ?? null,
          gch: (segment as any).gch ?? null,
          g0ch: (segment as any).g0ch ?? null,
          i_th: (segment as any).i_th ?? null,
          t_th: (segment as any).t_th ?? null,
          sections: (segment as any).sections ?? null,
          short_circuit_end_temperature: (segment as any).short_circuit_end_temperature ?? null,
          is_jumper: !!(segment as any).is_jumper
        });
        if (fromPole && (fromPole as any).is_tap_pole) {
          this.fromPoleForBranch = fromPole;
          this.showBranchChoice = true;
        }
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
    this.apiService.getPolesSequence(this.lineId).subscribe({
      next: (poles) => {
        this.poles = poles || [];
        this.isLoading = false;
        const fromId = this.segmentForm.get('from_pole_id')?.value;
        if (fromId) {
          this.fromPoleForBranch = this.poles.find(p => p.id === fromId) ?? null;
          this.showBranchChoice = !!(this.fromPoleForBranch && (this.fromPoleForBranch as any).is_tap_pole);
        }
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
      line_id: this.data.lineId,
      voltage_level: formValue.voltage_level || 0,
      length: formValue.length || 0,
      from_connectivity_node_id: fromPole.connectivity_node_id!,
      to_connectivity_node_id: toPole.connectivity_node_id!,
      is_tap: formValue.is_tap || false,
      tap_number: formValue.tap_number || undefined,
      branch_type: this.showBranchChoice && formValue.branch_type ? formValue.branch_type : undefined,
      tap_pole_id: this.showBranchChoice && formValue.branch_type === 'tap' && this.fromPoleForBranch
        ? this.fromPoleForBranch.id
        : undefined,
      conductor_type: formValue.conductor_type || undefined,
      conductor_material: formValue.conductor_material || undefined,
      conductor_section: formValue.conductor_section || undefined,
      r: formValue.r != null ? Number(formValue.r) : undefined,
      x: formValue.x != null ? Number(formValue.x) : undefined,
      b: formValue.b != null ? Number(formValue.b) : undefined,
      g: formValue.g != null ? Number(formValue.g) : undefined,
      r0: formValue.r0 != null ? Number(formValue.r0) : undefined,
      x0: formValue.x0 != null ? Number(formValue.x0) : undefined,
      bch: formValue.bch != null ? Number(formValue.bch) : undefined,
      b0ch: formValue.b0ch != null ? Number(formValue.b0ch) : undefined,
      gch: formValue.gch != null ? Number(formValue.gch) : undefined,
      g0ch: formValue.g0ch != null ? Number(formValue.g0ch) : undefined,
      i_th: formValue.i_th != null ? Number(formValue.i_th) : undefined,
      t_th: formValue.t_th != null ? Number(formValue.t_th) : undefined,
      sections: formValue.sections != null ? Number(formValue.sections) : undefined,
      short_circuit_end_temperature: formValue.short_circuit_end_temperature != null ? Number(formValue.short_circuit_end_temperature) : undefined,
      is_jumper: !!formValue.is_jumper
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

