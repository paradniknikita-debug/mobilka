import { Component, OnInit, Inject, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatSelectChange } from '@angular/material/select';
import { ApiService } from '../../../core/services/api.service';
import { MapService } from '../../../core/services/map.service';
import { PowerLine, PowerLineCreate } from '../../../core/models/power-line.model';
import { PoleCreate } from '../../../core/models/pole.model';
import { SubstationCreate } from '../../../core/models/substation.model';
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
  substationForm: FormGroup;
  
  selectedObjectType: ObjectType | null = null;
  powerLines: PowerLine[] = [];
  filteredPowerLines!: Observable<PowerLine[]>;
  
  isSubmitting = false;
  showImportOption = false;
  
  // Режим редактирования для опор
  isEditMode = false;
  poleId?: number;
  powerLineId?: number;
  isLoading = false;

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

  // Стандартные значения напряжения для подстанций (кВ)
  voltageLevels = [
    0.4,
    6,
    10,
    35,
    110,
    220,
    330,
    500,
    750
  ];

  constructor(
    private fb: FormBuilder,
    private dialogRef: MatDialogRef<CreateObjectDialogComponent>,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar,
    private cdr: ChangeDetectorRef,
    @Inject(MAT_DIALOG_DATA) public data: any
  ) {
    console.log('CreateObjectDialogComponent constructor, data:', JSON.stringify(data, null, 2));
    
    // Устанавливаем selectedObjectType сразу в конструкторе, если передан defaultObjectType
    if (data?.defaultObjectType) {
      this.selectedObjectType = data.defaultObjectType as ObjectType;
      console.log('✓ Установлен selectedObjectType в конструкторе:', this.selectedObjectType);
      
      if (data.defaultObjectType === 'pole' && data.powerLineId) {
        this.powerLineId = data.powerLineId;
        console.log('✓ Установлен powerLineId в конструкторе:', this.powerLineId);
      }
    } else {
      console.log('⚠ defaultObjectType не передан, selectedObjectType останется null');
    }
    
    this.objectTypeForm = this.fb.group({
      objectType: [data?.defaultObjectType || '', Validators.required]
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

    // Автогенерация UID при инициализации (только если не передан defaultObjectType для опоры)
    if (!data?.defaultObjectType || data.defaultObjectType !== 'pole') {
      this.generateMRID();
    } else if (data.defaultObjectType === 'pole') {
      // Генерируем MRID для опоры сразу в конструкторе
      this.generateMRID();
    }

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

    this.substationForm = this.fb.group({
      name: ['', [Validators.required, Validators.maxLength(100)]],
      code: ['', [Validators.required, Validators.maxLength(20)]],
      voltage_level: [null, [Validators.required, this.voltageValidator.bind(this)]],
      latitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      longitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      address: [''],
      branch_id: [1, Validators.required], // TODO: Получить реальный branch_id
      description: ['']
    });
  }

  ngOnInit(): void {
    console.log('CreateObjectDialogComponent ngOnInit, data:', this.data);
    console.log('selectedObjectType в ngOnInit:', this.selectedObjectType);
    
    // Проверяем режим редактирования опоры
    if (this.data?.isEdit && this.data?.objectType === 'pole' && this.data?.poleId && this.data?.powerLineId) {
      this.isEditMode = true;
      this.poleId = this.data.poleId;
      this.powerLineId = this.data.powerLineId;
      this.selectedObjectType = 'pole';
      this.objectTypeForm.patchValue({ objectType: 'pole' });
      console.log('Режим редактирования опоры, poleId:', this.poleId, 'powerLineId:', this.powerLineId);
      this.cdr.detectChanges();
    } else if (this.data?.defaultObjectType) {
      // Автоматически выбираем тип объекта, если передан defaultObjectType
      // Это происходит когда пользователь ПКМ на линии и выбирает "Создать опору"
      // selectedObjectType уже установлен в конструкторе, но убеждаемся что он установлен
      if (!this.selectedObjectType) {
        this.selectedObjectType = this.data.defaultObjectType as ObjectType;
      }
      this.objectTypeForm.patchValue({ objectType: this.data.defaultObjectType });
      console.log('Установлен defaultObjectType:', this.data.defaultObjectType, 'selectedObjectType:', this.selectedObjectType);
      
      // Если это опора и передан powerLineId, сохраняем его для установки после загрузки списка
      if (this.data.defaultObjectType === 'pole' && this.data.powerLineId) {
        if (!this.powerLineId) {
          this.powerLineId = this.data.powerLineId;
        }
        console.log('Установлен powerLineId для опоры:', this.powerLineId);
        // Генерируем MRID сразу, так как тип объекта уже выбран
        this.generateMRID();
      }
      
      // Принудительно обновляем шаблон, чтобы форма опоры отобразилась сразу
      this.cdr.detectChanges();
    }
    
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
        console.log('Загружены ЛЭП, количество:', lines.length, 'powerLineId для установки:', this.powerLineId);
        console.log('Все ЛЭП:', lines.map(l => ({ id: l.id, name: l.name, code: l.code })));
        
        // Если передан powerLineId (при создании опоры из контекстного меню линии), устанавливаем его в форму
        if (this.powerLineId && !this.isEditMode) {
          const selectedLine = this.powerLines.find(line => line.id === this.powerLineId);
          console.log('Поиск линии с ID', this.powerLineId, 'найден:', selectedLine);
          if (selectedLine) {
            // Используем setTimeout для гарантии, что форма готова
            setTimeout(() => {
              this.poleForm.patchValue({ power_line_id: selectedLine });
              console.log('Линия установлена в форму:', selectedLine);
              this.cdr.detectChanges();
            }, 0);
          } else {
            console.warn('Линия с ID', this.powerLineId, 'не найдена в списке');
            console.warn('Доступные ID линий:', lines.map(l => l.id));
          }
        }
        
        // Если режим редактирования, загружаем данные опоры после загрузки ЛЭП
        if (this.isEditMode && this.poleId && this.powerLineId) {
          setTimeout(() => {
            this.loadPole();
          }, 100);
        }
      },
      error: (error) => {
        console.error('Ошибка загрузки ЛЭП:', error);
        // Показываем ошибку только если это не сетевая проблема
        if (error.status !== 0) {
          this.snackBar.open('Ошибка загрузки списка ЛЭП: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', {
            duration: 5000
          });
        } else {
          // Сетевая ошибка - показываем предупреждение
          this.snackBar.open('Не удалось загрузить список ЛЭП. Проверьте подключение к серверу.', 'Закрыть', {
            duration: 5000
          });
        }
      }
    });
  }
  
  loadPole(): void {
    if (!this.poleId || !this.powerLineId) return;
    
    this.isLoading = true;
    this.apiService.getPoleByPowerLine(this.powerLineId, this.poleId).subscribe({
      next: (pole) => {
        // Находим ЛЭП для установки в форму
        const powerLine = this.powerLines.find(p => p.id === this.powerLineId);
        
        // Заполняем форму данными опоры
        this.poleForm.patchValue({
          pole_number: pole.pole_number || '',
          power_line_id: powerLine || this.powerLineId,
          latitude: pole.latitude || '',
          longitude: pole.longitude || '',
          pole_type: pole.pole_type || '',
          mrid: pole.mrid || '',
          height: pole.height || null,
          foundation_type: (pole as any).foundation_type || '',
          material: pole.material || '',
          year_installed: pole.installation_date ? new Date(pole.installation_date).getFullYear() : null,
          condition: pole.condition || 'good',
          notes: (pole as any).notes || ''
        });
        this.isLoading = false;
      },
      error: (error) => {
        console.error('Ошибка загрузки опоры:', error);
        this.snackBar.open('Ошибка загрузки данных опоры: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isLoading = false;
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
    return powerLine ? `${powerLine.name}${powerLine.code ? ` (${powerLine.code})` : ''}` : '';
  }

  private _filterPowerLines(name: string): PowerLine[] {
    const filterValue = name.toLowerCase();
    return this.powerLines.filter(line => 
      line.name.toLowerCase().includes(filterValue) || 
      (line.code && line.code.toLowerCase().includes(filterValue))
    );
  }

  onObjectTypeSelected(event: MatSelectChange): void {
    const selectedType = event.value as ObjectType;
    this.selectedObjectType = selectedType;
    if (selectedType === 'pole' && !this.isEditMode) {
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
    } else if (this.selectedObjectType === 'substation' && this.substationForm.valid) {
      this.createSubstation();
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

    console.log('Отправка данных для ' + (this.isEditMode ? 'обновления' : 'создания') + ' опоры:', poleData);

    // Используем API для создания или обновления опоры
    const poleObservable = this.isEditMode && this.poleId && this.powerLineId
      ? this.apiService.updatePole(this.powerLineId, this.poleId, poleData)
      : this.apiService.createPole(powerLineId, poleData);
    
    poleObservable.subscribe({
      next: (pole) => {
        // Обновляем данные карты и sidebar
        this.mapService.refreshData();
        const message = this.isEditMode ? 'Опора успешно обновлена' : 'Опора успешно создана';
        console.log(message + ':', pole);
        this.snackBar.open(message, 'Закрыть', {
          duration: 3000
        });
        this.dialogRef.close({ success: true, pole });
      },
      error: (error) => {
        const action = this.isEditMode ? 'обновления' : 'создания';
        console.error(`Ошибка ${action} опоры:`, error);
        console.error('Детали ошибки:', {
          status: error.status,
          statusText: error.statusText,
          error: error.error,
          message: error.message
        });
        
        let errorMessage = `Ошибка ${action} опоры`;
        
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

  getFormErrors(formGroup: FormGroup): any {
    const errors: any = {};
    Object.keys(formGroup.controls).forEach(key => {
      const control = formGroup.get(key);
      if (control && control.errors) {
        errors[key] = control.errors;
      }
    });
    return errors;
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
      return null; // Если значение пустое, валидация пройдёт (required проверит отдельно)
    }
    const str = String(control.value).replace(',', '.');
    const num = parseFloat(str);
    if (isNaN(num)) {
      return { invalidNumber: true };
    }
    if (num < 0) {
      return { negativeNumber: true };
    }
    // Проверяем, что значение находится в списке стандартных значений (с учетом погрешностей float)
    const numRounded = Math.round(num * 10) / 10;
    const isStandard = this.voltageLevels.some(v => Math.abs(v - numRounded) < 0.01);
    if (!isStandard) {
      return { invalidVoltage: true };
    }
    return null;
  }

  createPowerLine(): void {
    console.log('=== НАЧАЛО СОЗДАНИЯ ЛЭП ===');
    console.log('Форма валидна:', this.powerLineForm.valid);
    console.log('Ошибки формы:', this.getFormErrors(this.powerLineForm));
    
    if (this.powerLineForm.invalid) {
      console.warn('Форма невалидна, показываем ошибки');
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

    console.log('=== СОЗДАНИЕ ЛЭП ===');
    console.log('1. Данные формы:', formValue);
    console.log('2. Сформированные данные для отправки:', powerLineData);
    console.log('3. API URL:', this.apiService['apiUrl']); // Временно для отладки

    this.apiService.createPowerLine(powerLineData).subscribe({
      next: (createdPowerLine) => {
        console.log('ЛЭП успешно создана:', createdPowerLine);
        this.isSubmitting = false;
        this.snackBar.open('ЛЭП успешно создана', 'Закрыть', {
          duration: 3000
        });
        // Добавляем изменение в очередь синхронизации (на случай если нужно синхронизировать с Flutter)
        // this.syncService.addChange('power_line', 'create', createdPowerLine);
        // Обновляем данные карты и sidebar
        this.mapService.refreshData();
        this.dialogRef.close(createdPowerLine);
      },
      error: (error) => {
        console.error('=== ОШИБКА СОЗДАНИЯ ЛЭП ===');
        console.error('1. Полный объект ошибки:', error);
        console.error('2. Статус ошибки:', error.status);
        console.error('3. Текст ошибки:', error.statusText);
        console.error('4. URL запроса:', error.url);
        console.error('5. Тело ошибки:', error.error);
        console.error('6. Заголовки ответа:', error.headers);
        console.error('7. Полный объект ошибки (JSON):', JSON.stringify(error, null, 2));
        
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
    let form: FormGroup | undefined;
    if (this.selectedObjectType === 'powerline') {
      form = this.powerLineForm;
    } else if (this.selectedObjectType === 'substation') {
      form = this.substationForm;
    } else {
      form = this.poleForm;
    }
    
    if (!form) {
      return '';
    }
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
      return `Напряжение должно быть одним из стандартных значений: ${this.voltageLevels.join(', ')} кВ`;
    }
    if (field?.hasError('invalidVoltageLevel')) {
      return `Напряжение должно быть одним из стандартных значений: ${this.voltageLevels.join(', ')} кВ`;
    }
    return '';
  }

  createSubstation(): void {
    if (this.substationForm.invalid) {
      this.markFormGroupTouched(this.substationForm);
      return;
    }

    this.isSubmitting = true;
    const formValue = this.substationForm.value;

    const substationData: SubstationCreate = {
      name: formValue.name.trim(),
      code: formValue.code.trim(),
      voltage_level: parseFloat(formValue.voltage_level) || 0,
      latitude: parseFloat(formValue.latitude) || 0,
      longitude: parseFloat(formValue.longitude) || 0,
      address: formValue.address?.trim() || undefined,
      branch_id: formValue.branch_id || 1,
      description: formValue.description?.trim() || undefined
    };

    this.apiService.createSubstation(substationData).subscribe({
      next: (createdSubstation) => {
        console.log('Подстанция успешно создана:', createdSubstation);
        this.isSubmitting = false;
        this.snackBar.open('Подстанция успешно создана', 'Закрыть', {
          duration: 3000
        });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, data: createdSubstation });
      },
      error: (error) => {
        console.error('Ошибка создания подстанции:', error);
        this.isSubmitting = false;
        let errorMessage = 'Ошибка создания подстанции';
        if (error.error?.detail) {
          errorMessage = error.error.detail;
        } else if (error.message) {
          errorMessage = error.message;
        }
        this.snackBar.open(errorMessage, 'Закрыть', {
          duration: 5000
        });
      }
    });
  }
}

