import { Component, OnInit, Inject } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatSelectChange } from '@angular/material/select';
import { ApiService } from '../../../core/services/api.service';
import { PowerLine, PowerLineCreate } from '../../../core/models/power-line.model';
import { PoleCreate } from '../../../core/models/pole.model';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Observable } from 'rxjs';
import { map, startWith } from 'rxjs/operators';

export type ObjectType = 'substation' | 'pole' | 'equipment' | 'powerline';

@Component({
  selector: 'app-create-object-dialog',
  templateUrl: './create-object-dialog.component.html',
  styleUrls: ['./create-object-dialog.component.scss']
})
export class CreateObjectDialogComponent implements OnInit {
  objectTypeForm: FormGroup;
  poleForm: FormGroup;
  powerLineForm: FormGroup;
  
  selectedObjectType: ObjectType | null = null;
  powerLines: PowerLine[] = [];
  filteredPowerLines!: Observable<PowerLine[]>;
  
  isSubmitting = false;
  showImportOption = false;

  // Типы опор для выпадающего списка
  poleTypes = [
    'анкерная',
    'промежуточная',
    'угловая',
    'концевая',
    'переходная',
    'транспозиционная'
  ];

  // Материалы опор
  materials = [
    'металл',
    'железобетон',
    'дерево',
    'композит'
  ];

  // Состояния опоры
  conditions = [
    'good',
    'satisfactory',
    'poor'
  ];

  constructor(
    private fb: FormBuilder,
    private dialogRef: MatDialogRef<CreateObjectDialogComponent>,
    private apiService: ApiService,
    private snackBar: MatSnackBar,
    @Inject(MAT_DIALOG_DATA) public data: any
  ) {
    this.objectTypeForm = this.fb.group({
      objectType: ['', Validators.required]
    });

    this.poleForm = this.fb.group({
      pole_number: ['', [Validators.required, Validators.maxLength(20)]],
      power_line_id: ['', Validators.required],
      latitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      longitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      pole_type: ['', Validators.required],
      mrid: ['', CreateObjectDialogComponent.uuidValidator], // Опциональный UID с валидацией формата
      height: [null],
      foundation_type: [''],
      material: [''],
      year_installed: [null],
      condition: ['good'],
      notes: ['']
    });

    // Автогенерация UID при инициализации
    this.generateMRID();

    this.powerLineForm = this.fb.group({
      name: ['', [Validators.required, Validators.maxLength(100)]],
      mrid: ['', CreateObjectDialogComponent.uuidValidator],
      voltage_level: [null, [this.voltageValidator.bind(this)]],
      length: [null, [this.positiveNumberValidator.bind(this)]],
      branch_name: [''], // Административная принадлежность (текстовое поле)
      region_name: [''], // Географический регион (текстовое поле)
      dispatcher_name: [''], // Диспетчерское наименование (будет в description)
      balance_ownership: [''], // Балансовая принадлежность (будет в description)
      status: ['active'],
      description: ['']
    });

    // Автогенерация UID для ЛЭП
    this.generatePowerLineMRID();
  }

  ngOnInit(): void {
    this.loadPowerLines();

    // Фильтрация ЛЭП для автокомплита
    this.filteredPowerLines = this.poleForm.get('power_line_id')!.valueChanges.pipe(
      startWith(''),
      map(value => {
        const name = typeof value === 'string' ? value : value?.name || '';
        return name ? this._filterPowerLines(name) : this.powerLines.slice();
      })
    );
  }

  loadPowerLines(): void {
    this.apiService.getPowerLines().subscribe({
      next: (lines) => {
        this.powerLines = lines;
      },
      error: (error) => {
        console.error('Ошибка загрузки ЛЭП:', error);
        // Не показываем ошибку, если это просто проблема с загрузкой списка
        // Пользователь может продолжить работу
        if (error.status !== 0) {
          this.snackBar.open('Ошибка загрузки списка ЛЭП', 'Закрыть', {
            duration: 3000
          });
        }
      }
    });
  }

  generateMRID(): void {
    // Генерация UUID v4
    const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
    this.poleForm.patchValue({ mrid: uuid });
  }

  generatePowerLineMRID(): void {
    // Генерация UUID v4
    const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
    this.powerLineForm.patchValue({ mrid: uuid });
  }

  displayPowerLine(powerLine: PowerLine): string {
    return powerLine ? `${powerLine.name} (${powerLine.code})` : '';
  }

  private _filterPowerLines(name: string): PowerLine[] {
    const filterValue = name.toLowerCase();
    return this.powerLines.filter(line => 
      line.name.toLowerCase().includes(filterValue) || 
      line.code.toLowerCase().includes(filterValue)
    );
  }

  onObjectTypeSelected(event: MatSelectChange): void {
    const selectedType = event.value as ObjectType;
    this.selectedObjectType = selectedType;
    if (selectedType === 'pole') {
      this.generateMRID();
    } else if (selectedType === 'powerline') {
      this.generatePowerLineMRID();
    }
  }

  onSubmit(): void {
    if (this.selectedObjectType === 'pole' && this.poleForm.valid) {
      this.createPole();
    } else if (this.selectedObjectType === 'powerline' && this.powerLineForm.valid) {
      this.createPowerLine();
    }
  }

  createPole(): void {
    if (this.poleForm.invalid) {
      this.markFormGroupTouched(this.poleForm);
      return;
    }

    this.isSubmitting = true;
    const formValue = this.poleForm.value;
    
    // Получаем ID выбранной ЛЭП
    let powerLineId: number;
    if (typeof formValue.power_line_id === 'object' && formValue.power_line_id !== null) {
      powerLineId = formValue.power_line_id.id;
    } else if (typeof formValue.power_line_id === 'number') {
      powerLineId = formValue.power_line_id;
    } else {
      this.snackBar.open('Необходимо выбрать ЛЭП из списка', 'Закрыть', {
        duration: 5000
      });
      this.isSubmitting = false;
      return;
    }

    // Функция для нормализации чисел (замена запятой на точку)
    const normalizeNumber = (value: any): number | undefined => {
      if (!value && value !== 0) return undefined;
      const str = String(value).replace(',', '.');
      const num = parseFloat(str);
      return isNaN(num) ? undefined : num;
    };

    // Нормализуем координаты (заменяем запятую на точку для русской локали)
    const latitude = normalizeNumber(formValue.latitude);
    const longitude = normalizeNumber(formValue.longitude);

    if (latitude === undefined || longitude === undefined) {
      this.snackBar.open('Некорректные координаты. Используйте точку или запятую как разделитель', 'Закрыть', {
        duration: 5000
      });
      this.isSubmitting = false;
      return;
    }

    const poleData: PoleCreate = {
      power_line_id: powerLineId,
      pole_number: formValue.pole_number.trim(),
      latitude: latitude,
      longitude: longitude,
      pole_type: formValue.pole_type,
      mrid: formValue.mrid && formValue.mrid.trim() ? formValue.mrid.trim() : undefined,
      height: (() => {
        const height = normalizeNumber(formValue.height);
        return height !== undefined && height >= 0 ? height : undefined;
      })(),
      foundation_type: formValue.foundation_type?.trim() || undefined,
      material: formValue.material || undefined,
      year_installed: formValue.year_installed ? parseInt(String(formValue.year_installed)) : undefined,
      condition: formValue.condition || 'good',
      notes: formValue.notes?.trim() || undefined
    };

    console.log('Отправка данных для создания опоры:', poleData);

    this.apiService.createPole(powerLineId, poleData).subscribe({
      next: (createdPole) => {
        console.log('Опора успешно создана:', createdPole);
        this.snackBar.open('Опора успешно создана', 'Закрыть', {
          duration: 3000
        });
        this.dialogRef.close(createdPole);
      },
      error: (error) => {
        console.error('Ошибка создания опоры:', error);
        console.error('Детали ошибки:', {
          status: error.status,
          statusText: error.statusText,
          error: error.error,
          message: error.message
        });
        
        let errorMessage = 'Ошибка создания опоры';
        
        // Обработка ошибок валидации FastAPI (может быть массивом)
        if (error.error?.detail) {
          if (Array.isArray(error.error.detail)) {
            // Если detail - массив ошибок валидации
            const errors = error.error.detail.map((err: any) => {
              if (typeof err === 'string') {
                return err;
              } else if (err.msg) {
                return `${err.loc?.join('.') || 'Поле'}: ${err.msg}`;
              } else if (err.message) {
                return err.message;
              }
              return JSON.stringify(err);
            });
            errorMessage = errors.join(', ');
          } else if (typeof error.error.detail === 'string') {
            errorMessage = error.error.detail;
          } else {
            errorMessage = JSON.stringify(error.error.detail);
          }
        } else if (error.error?.message) {
          errorMessage = typeof error.error.message === 'string' 
            ? error.error.message 
            : JSON.stringify(error.error.message);
        } else if (error.message) {
          errorMessage = error.message;
        }
        
        this.snackBar.open(errorMessage, 'Закрыть', {
          duration: 7000,
          panelClass: ['error-snackbar']
        });
        this.isSubmitting = false;
      }
    });
  }

  onImportClick(): void {
    // Открываем диалог выбора файла
    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.accept = '.xlsx,.xls,.csv';
    fileInput.onchange = (event: any) => {
      const file = event.target.files[0];
      if (file) {
        this.handleFileImport(file);
      }
    };
    fileInput.click();
  }

  handleFileImport(file: File): void {
    // TODO: Реализовать импорт из файла
    this.snackBar.open('Импорт из файла будет реализован позже', 'Закрыть', {
      duration: 3000
    });
  }

  markFormGroupTouched(formGroup: FormGroup): void {
    Object.keys(formGroup.controls).forEach(key => {
      const control = formGroup.get(key);
      control?.markAsTouched();
    });
  }

  cancel(): void {
    this.dialogRef.close();
  }

  static uuidValidator(control: any): { [key: string]: any } | null {
    if (!control.value) {
      return null; // Пустое значение допустимо (будет сгенерировано на бэкенде)
    }
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(control.value) ? null : { invalidUuid: true };
  }

  coordinateValidator(control: any): { [key: string]: any } | null {
    if (!control.value) {
      return { required: true };
    }
    const str = String(control.value).replace(',', '.');
    const num = parseFloat(str);
    if (isNaN(num)) {
      return { invalidCoordinate: true };
    }
    
    // Определяем, какое это поле, проверяя имя контрола
    const fieldName = (control as any)._parent?.controls ? 
      Object.keys((control as any)._parent.controls).find((key: string) => 
        (control as any)._parent.controls[key] === control
      ) : '';
    
    // Проверяем диапазон и возвращаем ошибку с информацией о диапазоне
    if (fieldName === 'latitude' && (num < -90 || num > 90)) {
      return { invalidCoordinate: { range: 'latitude' } };
    }
    if (fieldName === 'longitude' && (num < -180 || num > 180)) {
      return { invalidCoordinate: { range: 'longitude' } };
    }
    
    return null;
  }

  // Валидатор для положительных чисел
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

  // Валидатор для стандартных значений напряжения
  voltageValidator(control: any): { [key: string]: any } | null {
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
    const standardVoltages = [0.4, 6, 10, 35, 110, 220, 330, 500, 750];
    // Проверяем с учетом возможных погрешностей float (округляем до 1 знака)
    const numRounded = Math.round(num * 10) / 10;
    const isStandard = standardVoltages.some(v => Math.abs(v - numRounded) < 0.01);
    if (!isStandard) {
      return { invalidVoltage: true };
    }
    return null;
  }

  createPowerLine(): void {
    if (this.powerLineForm.invalid) {
      this.markFormGroupTouched(this.powerLineForm);
      return;
    }

    this.isSubmitting = true;
    const formValue = this.powerLineForm.value;
    
    // Формируем описание из диспетчерского наименования и балансовой принадлежности
    let description = formValue.description?.trim() || '';
    const descriptionParts: string[] = [];
    
    if (formValue.dispatcher_name?.trim()) {
      descriptionParts.push(`Диспетчерское наименование: ${formValue.dispatcher_name.trim()}`);
    }
    if (formValue.balance_ownership?.trim()) {
      descriptionParts.push(`Балансовая принадлежность: ${formValue.balance_ownership.trim()}`);
    }
    if (description) {
      descriptionParts.push(description);
    }
    
    const finalDescription = descriptionParts.length > 0 ? descriptionParts.join('\n') : undefined;

    // Функция для нормализации чисел (замена запятой на точку)
    const normalizeNumber = (value: any): number | undefined => {
      if (!value && value !== 0) return undefined;
      const str = String(value).replace(',', '.');
      const num = parseFloat(str);
      return isNaN(num) ? undefined : num;
    };

    // Формируем объект данных, исключая undefined значения
    const powerLineData: PowerLineCreate = {
      name: formValue.name.trim(),
    };
    
    // Добавляем только те поля, которые имеют значения
    if (formValue.mrid && formValue.mrid.trim()) {
      powerLineData.mrid = formValue.mrid.trim();
    }
    const normalizedVoltage = normalizeNumber(formValue.voltage_level);
    if (normalizedVoltage !== undefined && normalizedVoltage !== null) {
      powerLineData.voltage_level = normalizedVoltage;
    }
    const normalizedLength = normalizeNumber(formValue.length);
    if (normalizedLength !== undefined && normalizedLength !== null) {
      powerLineData.length = normalizedLength;
    }
    if (formValue.branch_name?.trim()) {
      powerLineData.branch_name = formValue.branch_name.trim();
    }
    if (formValue.region_name?.trim()) {
      powerLineData.region_name = formValue.region_name.trim();
    }
    if (formValue.status) {
      powerLineData.status = formValue.status;
    }
    if (finalDescription) {
      powerLineData.description = finalDescription;
    }

    console.log('Отправка данных для создания ЛЭП:', powerLineData);

    this.apiService.createPowerLine(powerLineData).subscribe({
      next: (createdPowerLine) => {
        console.log('ЛЭП успешно создана:', createdPowerLine);
        this.isSubmitting = false;
        this.snackBar.open('ЛЭП успешно создана', 'Закрыть', {
          duration: 3000
        });
        this.dialogRef.close(createdPowerLine);
      },
      error: (error) => {
        console.error('Ошибка создания ЛЭП:', error);
        console.error('Статус ошибки:', error.status);
        console.error('Текст ошибки:', error.statusText);
        console.error('Полный объект ошибки:', JSON.stringify(error, null, 2));
        
        this.isSubmitting = false;
        
        let errorMessage = 'Ошибка создания ЛЭП';
        
        // Сначала обрабатываем HTTP ошибки (4xx, 5xx) - они имеют приоритет
        if (error.status && error.status >= 400) {
          // Обработка ошибок валидации FastAPI (может быть массивом)
          if (error.error?.detail) {
            if (Array.isArray(error.error.detail)) {
              // Если detail - массив ошибок валидации
              const errors = error.error.detail.map((err: any) => {
                if (typeof err === 'string') {
                  return err;
                } else if (err.msg) {
                  return `${err.loc?.join('.') || 'Поле'}: ${err.msg}`;
                } else if (err.message) {
                  return err.message;
                }
                return JSON.stringify(err);
              });
              errorMessage = errors.join(', ');
            } else if (typeof error.error.detail === 'string') {
              errorMessage = error.error.detail;
            } else {
              errorMessage = JSON.stringify(error.error.detail);
            }
          } else if (error.error?.message) {
            errorMessage = typeof error.error.message === 'string' 
              ? error.error.message 
              : JSON.stringify(error.error.message);
          } else if (error.message) {
            errorMessage = error.message;
          } else {
            errorMessage = `Ошибка сервера: ${error.status} ${error.statusText || ''}`;
          }
          
          this.snackBar.open(errorMessage, 'Закрыть', {
            duration: 7000,
            panelClass: ['error-snackbar']
          });
          return;
        }
        
        // Обработка сетевых ошибок (0 Unknown Error, CORS, timeout) - только если нет HTTP статуса
        if (error.status === 0 || 
            error.statusText === 'Unknown Error' || 
            (error.name === 'HttpErrorResponse' && !error.status)) {
          // Проверяем, действительно ли это сетевая ошибка
          console.warn('Возможная сетевая ошибка. Проверяем, создан ли объект на сервере...');
          
          // Показываем предупреждение, но не блокируем пользователя
          errorMessage = 'Возможна проблема с подключением. Проверьте, создана ли ЛЭП в списке.';
          this.snackBar.open(errorMessage, 'Закрыть', {
            duration: 5000,
            panelClass: ['warning-snackbar']
          });
          
          // Закрываем диалог, чтобы пользователь мог проверить результат
          // Если объект создан, он увидит его в списке
          this.dialogRef.close(null);
          return;
        }
        
        // Если нет статуса, но есть сообщение
        errorMessage = error.message || 'Неизвестная ошибка';
        
        this.snackBar.open(errorMessage, 'Закрыть', {
          duration: 7000,
          panelClass: ['error-snackbar']
        });
      }
    });
  }

  getFieldError(fieldName: string): string {
    const form = this.selectedObjectType === 'powerline' ? this.powerLineForm : this.poleForm;
    const field = form.get(fieldName);
    if (field?.hasError('required')) {
      return 'Это поле обязательно для заполнения';
    }
    if (field?.hasError('min')) {
      return `Минимальное значение: ${field.errors?.['min'].min}`;
    }
    if (field?.hasError('max')) {
      return `Максимальное значение: ${field.errors?.['max'].max}`;
    }
    if (field?.hasError('maxlength')) {
      return `Максимальная длина: ${field.errors?.['maxlength'].requiredLength}`;
    }
    if (field?.hasError('invalidUuid')) {
      return 'Неверный формат UUID. Используйте формат: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
    }
    if (field?.hasError('invalidCoordinate')) {
      const error = field.errors?.['invalidCoordinate'];
      if (fieldName === 'latitude') {
        if (error && typeof error === 'object' && error.range === 'latitude') {
          return 'Широта должна быть от -90 до 90';
        }
        return 'Некорректная широта. Используйте число от -90 до 90';
      } else if (fieldName === 'longitude') {
        if (error && typeof error === 'object' && error.range === 'longitude') {
          return 'Долгота должна быть от -180 до 180';
        }
        return 'Некорректная долгота. Используйте число от -180 до 180';
      }
      return 'Некорректное значение координаты';
    }
    if (field?.hasError('negativeNumber')) {
      return 'Значение не может быть отрицательным';
    }
    if (field?.hasError('invalidNumber')) {
      return 'Некорректное числовое значение';
    }
    if (field?.hasError('invalidVoltage')) {
      const standardVoltages = [0.4, 6, 10, 35, 110, 220, 330, 500, 750];
      return `Напряжение должно быть одним из стандартных значений: ${standardVoltages.join(', ')} кВ`;
    }
    return '';
  }
}

