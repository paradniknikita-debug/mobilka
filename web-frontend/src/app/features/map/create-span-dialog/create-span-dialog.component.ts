import { Component, Inject, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MapService } from '../../../core/services/map.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Pole } from '../../../core/models/pole.model';
import { SpanCreate } from '../../../core/models/cim.model';
import { LineSection } from '../../../core/models/cim.model';

@Component({
  selector: 'app-create-span-dialog',
  templateUrl: './create-span-dialog.component.html',
  styleUrls: ['./create-span-dialog.component.scss']
})
export class CreateSpanDialogComponent implements OnInit {
  powerLineId: number;
  spanId?: number;
  isEditMode = false;
  poles: Pole[] = [];
  lineSections: LineSection[] = [];
  
  spanForm: FormGroup;
  isLoading = false;
  isCreating = false;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { 
      powerLineId: number; 
      fromPoleId?: number; 
      toPoleId?: number;
      segmentId?: number;
      spanId?: number;
      isEdit?: boolean;
    },
    private dialogRef: MatDialogRef<CreateSpanDialogComponent>,
    private fb: FormBuilder,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {
    this.powerLineId = data.powerLineId;
    this.spanId = data.spanId;
    this.isEditMode = data.isEdit || false;
    
    this.spanForm = this.fb.group({
      from_pole_id: [data.fromPoleId || '', Validators.required],
      to_pole_id: [data.toPoleId || '', Validators.required],
      span_number: [''], // Будет автоматически сгенерировано
      length: ['', [Validators.required, this.positiveNumberValidator.bind(this)]],
      conductor_type: [''],
      conductor_material: [''],
      conductor_section: [''],
      tension: ['', this.positiveNumberValidator.bind(this)],
      sag: ['', this.positiveNumberValidator.bind(this)],
      notes: ['']
    });

    // Автоматическое формирование наименования при изменении опор
    this.spanForm.get('from_pole_id')?.valueChanges.subscribe(() => {
      this.updateSpanName();
    });
    this.spanForm.get('to_pole_id')?.valueChanges.subscribe(() => {
      this.updateSpanName();
    });
  }

  ngOnInit(): void {
    this.loadPoles();
    this.loadLineSections();
    
    // Если режим редактирования, загружаем данные пролёта после загрузки опор
    if (this.isEditMode && this.spanId) {
      // Используем setTimeout, чтобы дождаться загрузки опор
      setTimeout(() => {
        this.loadSpan();
      }, 500);
    }
  }

  loadSpan(): void {
    if (!this.spanId) return;
    
    this.isLoading = true;
    this.apiService.getSpan(this.powerLineId, this.spanId).subscribe({
      next: (span) => {
        // Получаем ID опор из ответа API
        // Используем from_pole_id/to_pole_id если есть, иначе из connectivity_node
        let fromPoleId: number | null = null;
        let toPoleId: number | null = null;
        
        // Сначала проверяем прямые поля (для обратной совместимости)
        if (span.from_pole_id) {
          fromPoleId = span.from_pole_id;
        } else if (span.from_connectivity_node?.pole_id) {
          fromPoleId = span.from_connectivity_node.pole_id;
        } else if (span.from_connectivity_node_id) {
          // Ищем опору по connectivity_node_id
          const fromPole = this.poles.find(p => {
            if (p.connectivity_node && p.connectivity_node.id === span.from_connectivity_node_id) {
              return true;
            }
            if ((p as any).connectivity_nodes && Array.isArray((p as any).connectivity_nodes)) {
              return (p as any).connectivity_nodes.some((cn: any) => cn.id === span.from_connectivity_node_id);
            }
            return false;
          });
          if (fromPole) {
            fromPoleId = fromPole.id;
          }
        }
        
        if (span.to_pole_id) {
          toPoleId = span.to_pole_id;
        } else if (span.to_connectivity_node?.pole_id) {
          toPoleId = span.to_connectivity_node.pole_id;
        } else if (span.to_connectivity_node_id) {
          // Ищем опору по connectivity_node_id
          const toPole = this.poles.find(p => {
            if (p.connectivity_node && p.connectivity_node.id === span.to_connectivity_node_id) {
              return true;
            }
            if ((p as any).connectivity_nodes && Array.isArray((p as any).connectivity_nodes)) {
              return (p as any).connectivity_nodes.some((cn: any) => cn.id === span.to_connectivity_node_id);
            }
            return false;
          });
          if (toPole) {
            toPoleId = toPole.id;
          }
        }
        
        // Заполняем форму данными пролёта (сохраняем текущие значения опор)
        this.spanForm.patchValue({
          from_pole_id: fromPoleId || this.spanForm.get('from_pole_id')?.value || '',
          to_pole_id: toPoleId || this.spanForm.get('to_pole_id')?.value || '',
          span_number: span.span_number || '',
          length: span.length || '',
          conductor_type: span.conductor_type || '',
          conductor_material: span.conductor_material || '',
          conductor_section: span.conductor_section || '',
          tension: span.tension || '',
          sag: span.sag || '',
          notes: span.notes || ''
        });
        this.isLoading = false;
      },
      error: (error) => {
        console.error('Ошибка загрузки пролёта:', error);
        this.snackBar.open('Ошибка загрузки данных пролёта: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isLoading = false;
      }
    });
  }

  loadPoles(): void {
    this.isLoading = true;
    this.apiService.getPolesSequence(this.powerLineId).subscribe({
      next: (poles) => {
        // Загружаем все опоры линии (не фильтруем по connectivity_node_id, так как он может быть создан автоматически)
        this.poles = poles || [];
        console.log(`Загружено опор: ${this.poles.length}`, this.poles);
        this.isLoading = false;
        // Обновляем наименование после загрузки опор, если опоры уже выбраны
        if (this.spanForm.get('from_pole_id')?.value && this.spanForm.get('to_pole_id')?.value) {
          this.updateSpanName();
        }
      },
      error: (error) => {
        console.error('Ошибка загрузки опор:', error);
        this.snackBar.open('Ошибка загрузки опор: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isLoading = false;
      }
    });
  }

  loadLineSections(): void {
    // LineSection создаётся автоматически при создании пролёта через API
    // Пока не требуется загрузка секций
  }

  positiveNumberValidator(control: any): { [key: string]: any } | null {
    if (!control.value && control.value !== 0) {
      return null; // Пустое значение допустимо
    }
    const str = String(control.value).replace(',', '.');
    const num = parseFloat(str);
    if (isNaN(num)) {
      return { invalidNumber: true };
    }
    if (num < 0) {
      return { negativeNumber: true };
    }
    return null;
  }

  calculateDistance(): void {
    const fromPoleId = this.spanForm.get('from_pole_id')?.value;
    const toPoleId = this.spanForm.get('to_pole_id')?.value;
    
    if (!fromPoleId || !toPoleId) {
      return;
    }

    const fromPole = this.poles.find(p => p.id === fromPoleId);
    const toPole = this.poles.find(p => p.id === toPoleId);

    if (fromPole && toPole) {
      // Расчёт расстояния по формуле Гаверсинуса
      const distance = this.calculateHaversineDistance(
        fromPole.latitude, fromPole.longitude,
        toPole.latitude, toPole.longitude
      );
      
      this.spanForm.patchValue({ length: distance.toFixed(2) });
      this.updateSpanName();
    }
  }

  updateSpanName(): void {
    const fromPoleId = this.spanForm.get('from_pole_id')?.value;
    const toPoleId = this.spanForm.get('to_pole_id')?.value;
    
    if (!fromPoleId || !toPoleId) {
      this.spanForm.patchValue({ span_number: '' });
      return;
    }

    const fromPole = this.poles.find(p => p.id === fromPoleId);
    const toPole = this.poles.find(p => p.id === toPoleId);

    if (fromPole && toPole) {
      // Формируем наименование по шаблону: "Пролёт *начальная опора* - *конечная опора*"
      const spanName = `Пролёт ${fromPole.pole_number} - ${toPole.pole_number}`;
      this.spanForm.patchValue({ span_number: spanName });
    }
  }

  calculateHaversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371000; // Радиус Земли в метрах
    const phi1 = lat1 * Math.PI / 180;
    const phi2 = lat2 * Math.PI / 180;
    const deltaPhi = (lat2 - lat1) * Math.PI / 180;
    const deltaLambda = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
              Math.cos(phi1) * Math.cos(phi2) *
              Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Расстояние в метрах
  }

  onSubmit(): void {
    if (this.spanForm.invalid) {
      this.markFormGroupTouched(this.spanForm);
      return;
    }

    const fromPoleId = this.spanForm.get('from_pole_id')?.value;
    const toPoleId = this.spanForm.get('to_pole_id')?.value;
    
    if (fromPoleId === toPoleId) {
      this.snackBar.open('Начальная и конечная опоры не могут быть одинаковыми', 'Закрыть', { duration: 3000 });
      return;
    }

    const fromPole = this.poles.find(p => p.id === fromPoleId);
    const toPole = this.poles.find(p => p.id === toPoleId);

    if (!fromPole || !toPole) {
      this.snackBar.open('Не удалось найти выбранные опоры', 'Закрыть', { duration: 3000 });
      return;
    }

    // ConnectivityNode будет создан автоматически на бэкенде, если его нет

    this.isCreating = true;
    
    const formValue = this.spanForm.value;
    const normalizeNumber = (value: any): number | undefined => {
      if (!value && value !== 0) return undefined;
      const str = String(value).replace(',', '.');
      const num = parseFloat(str);
      return isNaN(num) ? undefined : num;
    };

    // Автоматически формируем наименование, если оно не заполнено
    let spanNumber = formValue.span_number?.trim();
    if (!spanNumber && fromPole && toPole) {
      spanNumber = `Пролёт ${fromPole.pole_number} - ${toPole.pole_number}`;
    }

    // Используем старый API для создания пролёта (обратная совместимость)
    // API автоматически создаст необходимые CIM структуры (LineSection, AClineSegment)
    const spanData: any = {
      power_line_id: this.powerLineId,
      from_pole_id: fromPoleId,
      to_pole_id: toPoleId,
      span_number: spanNumber || `Пролёт ${fromPole?.pole_number || fromPoleId} - ${toPole?.pole_number || toPoleId}`,
      length: normalizeNumber(formValue.length),
      conductor_type: formValue.conductor_type?.trim() || undefined,
      conductor_material: formValue.conductor_material?.trim() || undefined,
      conductor_section: formValue.conductor_section?.trim() || undefined,
      tension: normalizeNumber(formValue.tension),
      sag: normalizeNumber(formValue.sag),
      notes: formValue.notes?.trim() || undefined
    };

    // Используем API для создания или обновления пролёта
    const spanObservable = this.isEditMode && this.spanId
      ? this.apiService.updateSpan(this.powerLineId, this.spanId, spanData)
      : this.apiService.createSpan(this.powerLineId, spanData, this.data.segmentId);
    
    spanObservable.subscribe({
      next: (span) => {
        const message = this.isEditMode ? 'Пролёт успешно обновлён' : 'Пролёт успешно создан';
        this.snackBar.open(message, 'Закрыть', { duration: 3000 });
        // Обновляем данные на карте
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, span });
      },
      error: (error) => {
        const action = this.isEditMode ? 'обновления' : 'создания';
        console.error(`Ошибка ${action} пролёта:`, error);
        let errorMessage = `Ошибка ${action} пролёта`;
        
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
        this.isCreating = false;
      }
    });
  }

  markFormGroupTouched(formGroup: FormGroup): void {
    Object.keys(formGroup.controls).forEach(key => {
      const control = formGroup.get(key);
      control?.markAsTouched();
    });
  }

  getFieldError(fieldName: string): string {
    const field = this.spanForm.get(fieldName);
    if (field?.hasError('required')) {
      return 'Это поле обязательно для заполнения';
    }
    if (field?.hasError('negativeNumber')) {
      return 'Значение не может быть отрицательным';
    }
    if (field?.hasError('invalidNumber')) {
      return 'Некорректное числовое значение';
    }
    return '';
  }

  close(): void {
    this.dialogRef.close();
  }

  displayPole(pole: Pole): string {
    if (!pole) return '';
    return `${pole.pole_number}${pole.sequence_number ? ` (#${pole.sequence_number})` : ''}`;
  }
}

