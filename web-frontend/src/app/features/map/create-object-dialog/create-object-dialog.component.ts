import { Component, OnInit, Inject, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialog } from '@angular/material/dialog';
import { PoleAttachmentsManagerDialogComponent } from '../pole-attachments-manager-dialog/pole-attachments-manager-dialog.component';
import { PoleCardAttachmentItem } from '../../../core/models/pole-card-attachment.model';
import { MatSelectChange } from '@angular/material/select';
import { ApiService } from '../../../core/services/api.service';
import { AuthService } from '../../../core/services/auth.service';
import { MapService } from '../../../core/services/map.service';
import { CardCommentMessage } from '../../../core/models/card-comment.model';
import {
  appendCardCommentMessage,
  formatCardCommentDateTime,
  parseCardCommentMessages,
  serializeCardCommentMessages
} from '../../../core/utils/card-comment.codec';
import { PowerLine, PowerLineCreate } from '../../../core/models/power-line.model';
import { Pole, PoleCreate } from '../../../core/models/pole.model';
import { SubstationCreate } from '../../../core/models/substation.model';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Observable, forkJoin, of } from 'rxjs';
import { map, startWith, switchMap, catchError } from 'rxjs/operators';

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
  equipmentForm: FormGroup;
  
  selectedObjectType: ObjectType | null = null;
  powerLines: PowerLine[] = [];
  filteredPowerLines!: Observable<PowerLine[]>;
  
  isSubmitting = false;
  showImportOption = false;
  
  // Режим редактирования для опор и подстанций
  isEditMode = false;
  poleId?: number;
  substationId?: number;
  lineId?: number;
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

  // Марки провода для автосоздания пролёта
  conductorTypes = ['AC-70', 'AC-95', 'AC-120', 'AC-150', 'AC-185', 'AC-240', 'AC-300', 'AC-400', 'СИП-2', 'СИП-4', 'А'];
  // Материал провода
  conductorMaterials = ['алюминий', 'медь', 'сталь', 'алмаг'];

  /** Последняя опора в выбранной линии (по sequence_number); если отпаечная — показываем выбор направления */
  lastPoleInLine: { id: number; is_tap_pole?: boolean } | null = null;
  showBranchChoice = false;
  /** При открытии «Начать отпайку» — id отпаечной опоры, от которой строим новую ветку */
  tapPoleIdToUse?: number;

  /** Список веток для выбора: магистраль + все отпайки (от одной опоры может быть несколько веток) */
  tapBranchesInLine: { value: string; label: string; tooltip?: string }[] = [];
  /** Для обратной совместимости и подписи: отпаечные опоры по id (pole_number для лейбла) */
  tapPolesInLine: { id: number; pole_number: string }[] = [];

  /** Явный выбор «новая ветка от якоря» при startNewTap; совпадает с Flutter. */
  readonly branchNewTapSentinel = '__new_tap__';

  /** Связь подстанции с линиями: выбранная ЛЭП для установки как начало/конец */
  lineForStartId: number | null = null;
  lineForEndId: number | null = null;
  linkingLineStart = false;
  linkingLineEnd = false;

  /** Подстанция в конце отпайки: выбранный участок для установки ТП в конце */
  selectedTapSegmentForEnd: { lineId: number; segmentId: number } | null = null;
  linkingTapEnd = false;

  /** Вложения карточки опоры (только в режиме редактирования). */
  poleAttachments: PoleCardAttachmentItem[] = [];

  /** История текстовых комментариев карточки (JSON в поле card_comment). */
  poleCardCommentMessages: CardCommentMessage[] = [];
  newCardCommentDraft = '';

  readonly formatCardCommentAt = formatCardCommentDateTime;

  // Кэшированные вычисления для карточки подстанции,
  // чтобы не гонять тяжёлые циклы в геттерах при каждом цикле change detection
  private _linesWhereSubstationIsStart: PowerLine[] = [];
  private _linesWhereSubstationIsEnd: PowerLine[] = [];
  private _linesWhereSubstationIsStartNames = '';
  private _linesWhereSubstationIsEndNames = '';
  private _tapSegmentsOptions: { lineId: number; lineName: string; segmentId: number; segmentName: string; toPoleDisplayName?: string }[] = [];
  private _segmentsWhereSubstationIsTapEnd: { lineId: number; lineName: string; segmentId: number; segmentName: string; toPoleDisplayName?: string }[] = [];
  private _segmentsWhereSubstationIsTapEndNames = '';

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
    private dialog: MatDialog,
    private apiService: ApiService,
    private authService: AuthService,
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
      
      if (data.defaultObjectType === 'pole' && data.lineId) {
        this.lineId = data.lineId;
        console.log('✓ Установлен lineId в конструкторе:', this.lineId);
      }
    } else {
      console.log('⚠ defaultObjectType не передан, selectedObjectType останется null');
    }
    
    this.objectTypeForm = this.fb.group({
      objectType: [data?.defaultObjectType || '', Validators.required]
    });

    this.poleForm = this.fb.group({
      pole_number: ['', [Validators.required, Validators.maxLength(20)]],
      line_id: ['', Validators.required],
      latitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      longitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      pole_type: ['', Validators.required],
      sequence_number: [null, [this.sequenceNumberValidator.bind(this)]], // Порядок в линии (1, 2, 3…). Пусто — авто.
      mrid: ['', CreateObjectDialogComponent.uuidValidator], // Опциональный UID с валидацией формата
      is_tap: [false],
      branch_type: ['main'], // Направление после отпаечной опоры: main | tap
      tap_pole_id: [null as number | null], // для обратной совместимости и startNewTap
      branch_selection: [null as string | null], // null = магистраль; branchNewTapSentinel = новая ветка; "id:idx" = ветка
      conductor_type: [''],
      conductor_material: [''],
      conductor_section: [''],
      height: [null, [this.nonNegativeNumberValidator.bind(this)]],
      foundation_type: [''],
      material: [''],
      year_installed: [null, [this.yearValidator.bind(this)]],
      condition: ['good'],
      notes: [''],
      structural_defect: [''],
      structural_defect_criticality: [null as string | null]
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
      uid: [''], // UID в формате системы (как у опор и др.); пусто = автогенерация на бэкенде
      dispatcher_name: [''], // Диспетчерское наименование (по желанию)
      voltage_level: [null, [Validators.required, this.voltageValidator.bind(this)]],
      latitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      longitude: ['', [Validators.required, this.coordinateValidator.bind(this)]],
      address: [''],
      branch_id: [null], // опционально; если в БД нет записей в branches — не передаём
      description: ['']
    });
    this.generateSubstationUID();

    this.equipmentForm = this.fb.group({
      name: ['', [Validators.required, Validators.maxLength(100)]],
      equipment_type: ['', Validators.required],
      pole_id: [data?.poleId ?? null, Validators.required],
      nominal_current: [''],
      nominal_voltage: [''],
      mark: [''],
      manufacturer: [''],
      model: [''],
      serial_number: [''],
      year_manufactured: [null],
      installation_date: [''],
      condition: ['good'],
      notes: ['']
    });
    // Если пришёл poleId из контекстного меню, фиксируем его и не даём менять
    if (data?.poleId) {
      this.equipmentForm.get('pole_id')?.patchValue(data.poleId);
      this.equipmentForm.get('pole_id')?.disable({ emitEvent: false });
    }
  }

  ngOnInit(): void {
    console.log('CreateObjectDialogComponent ngOnInit, data:', this.data);
    console.log('selectedObjectType в ngOnInit:', this.selectedObjectType);
    
    // Проверяем режим редактирования опоры
    if (this.data?.isEdit && this.data?.objectType === 'pole' && this.data?.poleId && this.data?.lineId) {
      this.isEditMode = true;
      this.poleId = this.data.poleId;
      this.lineId = this.data.lineId;
      this.selectedObjectType = 'pole';
      this.objectTypeForm.patchValue({ objectType: 'pole' });
      console.log('Режим редактирования опоры, poleId:', this.poleId, 'lineId:', this.lineId);
      this.cdr.detectChanges();
    } else if (this.data?.isEdit && this.data?.objectType === 'substation' && this.data?.substationId) {
      this.isEditMode = true;
      this.substationId = this.data.substationId;
      this.selectedObjectType = 'substation';
      this.objectTypeForm.patchValue({ objectType: 'substation' });
      this.loadSubstation();
      this.cdr.detectChanges();
    } else if (this.data?.isEdit && this.data?.objectType === 'equipment' && this.data?.equipmentId) {
      this.isEditMode = true;
      this.selectedObjectType = 'equipment';
      this.objectTypeForm.patchValue({ objectType: 'equipment' });
      this.loadEquipment(this.data.equipmentId);
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
      
      // Если это опора и передан lineId, сохраняем его для установки после загрузки списка
      if (this.data.defaultObjectType === 'pole' && this.data.lineId) {
        if (!this.lineId) {
          this.lineId = this.data.lineId;
        }
        if (this.data.tapPoleId) {
          this.tapPoleIdToUse = this.data.tapPoleId;
        }
        console.log('Установлен lineId для опоры:', this.lineId);
        // Генерируем MRID сразу, так как тип объекта уже выбран
        this.generateMRID();
      }
      
      // Принудительно обновляем шаблон, чтобы форма опоры отобразилась сразу
      this.cdr.detectChanges();
    }
    
    this.loadPowerLines();

    // Фильтрация ЛЭП для автокомплита
    this.filteredPowerLines = this.poleForm.get('line_id')!.valueChanges.pipe(
      startWith(''),
      map(value => {
        const name = typeof value === 'string' ? value : value?.name || '';
        return name ? this._filterPowerLines(name) : this.powerLines.slice();
      })
    );

    // При смене ЛЭП — загружаем опоры и определяем, показывать ли выбор «магистраль/отпайка»
    this.poleForm.get('line_id')?.valueChanges.subscribe(val => {
      const lineId = typeof val === 'object' && val !== null && 'id' in val ? (val as { id: number }).id : null;
      if (lineId) {
        this.updateLastPoleInLine(lineId, this.tapPoleIdToUse);
        this.tapPoleIdToUse = undefined; // используем только при первом открытии
      } else {
        this.lastPoleInLine = null;
        this.showBranchChoice = false;
        this.cdr.detectChanges();
      }
    });
  }

  private loadEquipment(equipmentId: number): void {
    this.isLoading = true;
    this.apiService.getEquipment(equipmentId).subscribe({
      next: (eq) => {
        // pole_id редактировать не даём
        this.equipmentForm.patchValue({
          name: eq.name || '',
          equipment_type: eq.equipment_type || '',
          pole_id: eq.pole_id,
          nominal_current: '',
          nominal_voltage: '',
          mark: '',
          manufacturer: eq.manufacturer || '',
          model: eq.model || '',
          serial_number: eq.serial_number || '',
          year_manufactured: eq.year_manufactured ?? null,
          installation_date: eq.installation_date ? (eq.installation_date as any).toString().slice(0, 10) : '',
          condition: eq.condition || 'good',
          notes: eq.notes || ''
        });
        this.equipmentForm.get('pole_id')?.disable({ emitEvent: false });
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.snackBar.open('Ошибка загрузки оборудования', 'Закрыть', { duration: 4000 });
        this.cdr.detectChanges();
      }
    });
  }

  /**
   * Подпись отпайки в списке: якорь + номер ветки + цепочка опор (первая → последняя),
   * чтобы отличать ветки с одного узла. Полный путь — в tooltip.
   */
  private buildTapBranchOption(
    tapPoleId: number,
    branchIndex: number,
    tapPoleNames: Record<number, string>,
    allPoles: any[]
  ): { label: string; tooltip: string } {
    const anchor = (tapPoleNames[tapPoleId] ?? `Опора ${tapPoleId}`).trim();
    const onBranch = allPoles
      .filter(
        (p: any) =>
          p.tap_pole_id != null &&
          Number(p.tap_pole_id) === tapPoleId &&
          (p.tap_branch_index != null ? Number(p.tap_branch_index) : 1) === branchIndex
      )
      .sort((a: any, b: any) => (a.sequence_number ?? 0) - (b.sequence_number ?? 0));
    const names = onBranch.map((p: any) =>
      p.pole_number && String(p.pole_number).trim()
        ? String(p.pole_number).trim()
        : `оп.${p.id}`
    );
    const chain = names.join(' → ');
    const first = names[0] ?? '—';
    const last = names.length > 0 ? names[names.length - 1] : '—';
    const tooltip =
      `Якорь: ${anchor} (id ${tapPoleId}), индекс ветки ${branchIndex}. ` +
      (chain ? `Все опоры ветки: ${chain}.` : 'На ветке пока нет учтённых опор.');
    if (names.length === 0) {
      return { label: `${anchor} · ветка ${branchIndex} — (пока без опор)`, tooltip };
    }
    if (names.length === 1) {
      return { label: `${anchor} · ветка ${branchIndex} — к ${first}`, tooltip };
    }
    return {
      label: `${anchor} · ветка ${branchIndex}: ${first} → ${last} (${names.length} оп.)`,
      tooltip
    };
  }

  updateLastPoleInLine(lineId: number, tapPoleId?: number): void {
    this.apiService.getPolesByPowerLine(lineId).subscribe({
      next: (poles) => {
        const list = (poles as any[]) || [];
        const tapPoles = list.filter((p: any) => p.is_tap_pole === true);
        this.tapPolesInLine = tapPoles.map((p: any) => ({ id: p.id, pole_number: p.pole_number || `Опора ${p.id}` }));
        const tapPoleNames: Record<number, string> = {};
        tapPoles.forEach((p: any) => { tapPoleNames[p.id] = p.pole_number || `Опора ${p.id}`; });
        const branchSet = new Set<string>();
        list.forEach((p: any) => {
          if (p.tap_pole_id != null) {
            const bi = p.tap_branch_index != null ? p.tap_branch_index : 1;
            branchSet.add(`${p.tap_pole_id}:${bi}`);
          }
        });
        this.tapBranchesInLine = Array.from(branchSet)
          .map(s => {
            const [pid, bi] = s.split(':').map(Number);
            const opt = this.buildTapBranchOption(pid, bi, tapPoleNames, list);
            return { value: s, label: opt.label, tooltip: opt.tooltip };
          })
          .sort((a, b) => a.value.localeCompare(b.value));
        this.showBranchChoice = this.tapBranchesInLine.length > 0 || this.tapPolesInLine.length > 0;

        if (tapPoleId != null) {
          const tapPole = list.find((p: any) => p.id === tapPoleId);
          this.lastPoleInLine = tapPole ?? null;
          if (this.showBranchChoice && this.data?.startNewTap !== true) {
            this.poleForm.patchValue({ branch_type: 'tap', tap_pole_id: tapPoleId, branch_selection: `${tapPoleId}:1` });
          } else if (this.data?.startNewTap === true && tapPoleId != null) {
            this.poleForm.patchValue({
              branch_type: 'tap',
              tap_pole_id: tapPoleId,
              branch_selection: this.branchNewTapSentinel
            });
          }
        } else {
          const withSeq = list
            .filter((p: { sequence_number?: number | null }) => p.sequence_number != null)
            .sort((a: { sequence_number?: number }, b: { sequence_number?: number }) => (b.sequence_number ?? 0) - (a.sequence_number ?? 0));
          this.lastPoleInLine = withSeq[0] ?? null;
          if (this.showBranchChoice && !this.poleForm.get('branch_selection')?.value) {
            this.poleForm.patchValue({ branch_type: 'main', tap_pole_id: null, branch_selection: null });
          }
        }
        this.cdr.detectChanges();
      },
      error: () => {
        this.lastPoleInLine = null;
        this.tapPolesInLine = [];
        this.tapBranchesInLine = [];
        this.showBranchChoice = false;
        this.cdr.detectChanges();
      }
    });
  }

  /** Загружает список отпаечных опор и веток линии для выбора при редактировании (направление «По отпайке») */
  loadTapPolesForLine(lineId: number): void {
    this.apiService.getPolesByPowerLine(lineId).subscribe({
      next: (poles) => {
        const list = (poles as any[]) || [];
        const tapPoles = list.filter((p: any) => p.is_tap_pole === true);
        this.tapPolesInLine = tapPoles.map((p: any) => ({ id: p.id, pole_number: p.pole_number || `Опора ${p.id}` }));
        const tapPoleNames: Record<number, string> = {};
        tapPoles.forEach((p: any) => { tapPoleNames[p.id] = p.pole_number || `Опора ${p.id}`; });
        const branchSet = new Set<string>();
        list.forEach((p: any) => {
          if (p.tap_pole_id != null) {
            const bi = p.tap_branch_index != null ? p.tap_branch_index : 1;
            branchSet.add(`${p.tap_pole_id}:${bi}`);
          }
        });
        this.tapBranchesInLine = Array.from(branchSet)
          .map(s => {
            const [pid, bi] = s.split(':').map(Number);
            const opt = this.buildTapBranchOption(pid, bi, tapPoleNames, list);
            return { value: s, label: opt.label, tooltip: opt.tooltip };
          })
          .sort((a, b) => a.value.localeCompare(b.value));
        this.cdr.detectChanges();
      },
      error: () => {
        this.tapPolesInLine = [];
        this.tapBranchesInLine = [];
        this.cdr.detectChanges();
      }
    });
  }

  loadPowerLines(): void {
    this.apiService.getPowerLines().subscribe({
      next: (lines) => {
        this.powerLines = Array.isArray(lines) ? lines.filter(l => l != null && typeof l === 'object') : [];
        const count = this.powerLines.length;
        console.log('Загружены ЛЭП, количество:', count, 'lineId для установки:', this.lineId);
        if (count > 0) {
          console.log('Все ЛЭП:', this.powerLines.map(l => l && (typeof l === 'object') ? { id: l.id, name: (l as any).name } : null));
        }

        // Если передан lineId (при создании опоры из контекстного меню линии), устанавливаем его в форму
        if (this.lineId && !this.isEditMode) {
          const selectedLine = this.powerLines.find(line => line && line.id === this.lineId);
          console.log('Поиск линии с ID', this.lineId, 'найден:', selectedLine);
          if (selectedLine) {
            // Используем setTimeout для гарантии, что форма готова
            setTimeout(() => {
              this.poleForm.patchValue({ line_id: selectedLine });
              console.log('Линия установлена в форму:', selectedLine);
              this.updateLastPoleInLine(selectedLine.id, this.tapPoleIdToUse);
              this.cdr.detectChanges();
            }, 0);
          } else {
            console.warn('Линия с ID', this.lineId, 'не найдена в списке');
            if (count > 0) {
              console.warn('Доступные ID линий:', this.powerLines.map(l => l?.id));
            }
          }
        }

        // Если режим редактирования, загружаем данные опоры после загрузки ЛЭП
        if (this.isEditMode && this.poleId && this.lineId) {
          setTimeout(() => {
            this.loadPole();
          }, 100);
        }

        // Для карточки подстанции пересчитываем связи «подстанция ↔ линии/отпайки»
        this.recomputeSubstationLinks();

        this.cdr.detectChanges();
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

  /** Пересчитывает кэшированные списки/строки для блока связей подстанции с линиями и отпаечными участками. */
  private recomputeSubstationLinks(): void {
    if (!this.substationId || !Array.isArray(this.powerLines) || !this.powerLines.length) {
      this._linesWhereSubstationIsStart = [];
      this._linesWhereSubstationIsEnd = [];
      this._linesWhereSubstationIsStartNames = '';
      this._linesWhereSubstationIsEndNames = '';
      this._tapSegmentsOptions = [];
      this._segmentsWhereSubstationIsTapEnd = [];
      this._segmentsWhereSubstationIsTapEndNames = '';
      return;
    }

    const start: PowerLine[] = [];
    const end: PowerLine[] = [];
    const tapOpts: { lineId: number; lineName: string; segmentId: number; segmentName: string; toPoleDisplayName?: string }[] = [];
    const tapEnd: { lineId: number; lineName: string; segmentId: number; segmentName: string; toPoleDisplayName?: string }[] = [];

    const sid = this.substationId;

    for (const line of this.powerLines) {
      if (!line || typeof line !== 'object') continue;
      const anyLine = line as any;

      if (anyLine.substation_start_id === sid) {
        start.push(line);
      }
      if (anyLine.substation_end_id === sid) {
        end.push(line);
      }

      const segments = anyLine.acline_segments;
      const arr = Array.isArray(segments) ? segments : [];
      for (const s of arr) {
        if (!s || typeof s !== 'object') continue;
        const anySeg = s as any;
        // Отпаечные участки всегда считаем кандидатами, но только настоящие отпайки (branch_type === 'tap' или есть tap_pole_id).
        if (anySeg.is_tap && ((anySeg.branch_type ?? '') === 'tap' || anySeg.tap_pole_id != null)) {
          // Человек должен видеть нормальное имя отпайки, а не внутренний ID/служебный tap_number.
          let segLabel = anySeg.name ?? `Участок ${anySeg.id}`;
          const tapNumber = (anySeg.tap_number ?? '').toString().trim();
          const toPoleDisplayName = (anySeg.to_pole_display_name ?? '').toString().trim();
          if (toPoleDisplayName) {
            segLabel = `отпайка к ${toPoleDisplayName}`;
          } else if (tapNumber) {
            segLabel = `отпайка ${tapNumber}`;
          }

          tapOpts.push({
            lineId: line.id,
            lineName: anyLine.name ?? '',
            segmentId: anySeg.id,
            segmentName: segLabel,
            toPoleDisplayName: anySeg.to_pole_display_name ?? undefined
          });
          if (anySeg.to_substation_id === sid) {
            tapEnd.push({
              lineId: line.id,
              lineName: anyLine.name ?? '',
              segmentId: anySeg.id,
              segmentName: segLabel,
              toPoleDisplayName: anySeg.to_pole_display_name ?? undefined
            });
          }
        }
      }
    }

    this._linesWhereSubstationIsStart = start;
    this._linesWhereSubstationIsEnd = end;
    this._linesWhereSubstationIsStartNames = start.map(l => (l as any).name ?? '').filter(Boolean).join(', ');
    this._linesWhereSubstationIsEndNames = end.map(l => (l as any).name ?? '').filter(Boolean).join(', ');
    this._tapSegmentsOptions = tapOpts;
    this._segmentsWhereSubstationIsTapEnd = tapEnd;
    this._segmentsWhereSubstationIsTapEndNames = tapEnd
      .map(seg => `${seg.lineName} — ${seg.segmentName}`)
      .join(', ');
  }
  
  loadPole(): void {
    if (!this.poleId || !this.lineId) return;
    
    this.isLoading = true;
    this.apiService.getPoleByPowerLine(this.lineId, this.poleId).subscribe({
      next: (pole) => {
        // Находим ЛЭП для установки в форму
        const powerLine = this.powerLines.find(p => p.id === this.lineId);
        
        // Заполняем форму данными опоры
        const tapId = (pole as any).tap_pole_id ?? null;
        const tapBi = (pole as any).tap_branch_index ?? 1;
        const branchSel = tapId != null ? `${tapId}:${tapBi}` : null;
        this.poleForm.patchValue({
          pole_number: pole.pole_number || '',
          line_id: powerLine || this.lineId,
          latitude: (pole as any).y_position ?? (pole as any).latitude ?? '',
          longitude: (pole as any).x_position ?? (pole as any).longitude ?? '',
          pole_type: pole.pole_type || '',
          sequence_number: pole.sequence_number ?? null,
          mrid: pole.mrid || '',
          is_tap: (pole as any).is_tap_pole ?? false,
          branch_type: (pole as any).branch_type === 'tap' ? 'tap' : 'main',
          tap_pole_id: tapId,
          branch_selection: branchSel,
          conductor_type: (pole as any).conductor_type ?? '',
          conductor_material: (pole as any).conductor_material ?? '',
          conductor_section: (pole as any).conductor_section ?? '',
          height: pole.height || null,
          foundation_type: (pole as any).foundation_type || '',
          material: pole.material || '',
          year_installed: pole.installation_date ? new Date(pole.installation_date).getFullYear() : null,
          condition: pole.condition || 'good',
          notes: (pole as any).notes || '',
          structural_defect: (pole as any).structural_defect || '',
          structural_defect_criticality: (pole as any).structural_defect_criticality ?? null,
        });
        this.poleCardCommentMessages = parseCardCommentMessages((pole as any).card_comment);
        this.poleAttachments = this.parseCardAttachments((pole as any).card_comment_attachment);
        this.isLoading = false;
        // В режиме редактирования показываем выбор направления и загружаем список отпаечных опор
        if (this.isEditMode && this.lineId) {
          this.showBranchChoice = true;
          this.loadTapPolesForLine(this.lineId);
        }
        this.cdr.detectChanges();
      },
      error: (error) => {
        console.error('Ошибка загрузки опоры:', error);
        this.snackBar.open('Ошибка загрузки данных опоры: ' + (error.error?.detail || error.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isLoading = false;
      }
    });
  }

  loadSubstation(): void {
    if (!this.substationId) return;
    this.isLoading = true;
    this.apiService.getSubstation(this.substationId).subscribe({
      next: (sub) => {
        this.substationForm.patchValue({
          name: sub.name || '',
          uid: sub.mrid || '',
          dispatcher_name: sub.dispatcher_name ?? '',
          voltage_level: sub.voltage_level ?? null,
          latitude: (sub as any).latitude ?? sub.latitude ?? '',
          longitude: (sub as any).longitude ?? sub.longitude ?? '',
          address: sub.address ?? '',
          branch_id: sub.branch_id ?? null,
          description: (sub as any).description ?? ''
        });
        this.isLoading = false;
        // После загрузки подстанции можно пересчитать связи с линиями
        this.recomputeSubstationLinks();
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.snackBar.open('Ошибка загрузки подстанции: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  /** Разбор JSON вложений карточки опоры. */
  parseCardAttachments(json: string | null | undefined): PoleCardAttachmentItem[] {
    if (!json || !json.trim()) return [];
    try {
      const data = JSON.parse(json) as any;
      const arr: any[] = Array.isArray(data) ? data : data?.items && Array.isArray(data.items) ? data.items : [];
      return arr
        .filter((item) => item && (item.url || item.p))
        .map((item) => ({
          t: item.t || 'photo',
          url: item.url || item.p,
          thumbnail: item.thumbnail || item.thumbnail_url,
          thumbnail_url: item.thumbnail_url || item.thumbnail,
          filename: item.filename,
          added_at: item.added_at,
          added_by_id: item.added_by_id ?? item.added_by,
          added_by_name: item.added_by_name
        }));
    } catch {
      return [];
    }
  }

  sendCardComment(): void {
    const text = this.newCardCommentDraft?.trim();
    if (!text) {
      return;
    }
    const user = this.authService.getCurrentUser();
    if (!user) {
      this.snackBar.open('Войдите в систему, чтобы отправить комментарий', 'Закрыть', { duration: 4000 });
      return;
    }
    this.poleCardCommentMessages = appendCardCommentMessage(this.poleCardCommentMessages, text, user);
    this.newCardCommentDraft = '';
    this.cdr.markForCheck();
  }

  trackCommentById(_index: number, m: CardCommentMessage): string {
    return m.id || String(_index);
  }

  /** Имя для шапки пузырька без повторения слова «комментарий». */
  commentAuthorLabel(m: CardCommentMessage): string {
    const n = m.user_name?.trim();
    if (n) return n;
    if (m.user_id != null) return `id ${m.user_id}`;
    return '—';
  }

  openPoleAttachmentsManager(): void {
    if (!this.poleId) return;
    this.dialog
      .open(PoleAttachmentsManagerDialogComponent, {
        width: '880px',
        maxWidth: '95vw',
        maxHeight: '90vh',
        data: { poleId: this.poleId, items: [...this.poleAttachments] }
      })
      .afterClosed()
      .subscribe((result: PoleCardAttachmentItem[] | undefined) => {
        if (result) {
          this.poleAttachments = result;
          this.cdr.markForCheck();
        }
      });
  }

  getAttachmentUrl(relativeUrl: string): string {
    return this.apiService.getAttachmentUrl(relativeUrl);
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
    const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
    this.powerLineForm.patchValue({ mrid: uuid });
  }

  /** Генерирует UID в том же формате, что и для остальных сущностей (UUID) */
  generateSubstationUID(): void {
    const s = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
    this.substationForm?.patchValue({ uid: s });
  }

  displayPowerLine(powerLine: PowerLine): string {
    return powerLine ? powerLine.name : '';
  }

  private _filterPowerLines(name: string): PowerLine[] {
    const filterValue = name.toLowerCase();
    const lines = this.powerLines || [];
    return lines.filter(line => line && typeof line === 'object' && (line.name ?? '').toLowerCase().includes(filterValue));
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
    } else if (this.selectedObjectType === 'equipment' && this.equipmentForm.valid) {
      if (this.isEditMode && this.data?.equipmentId) {
        this.updateEquipment(this.data.equipmentId);
      } else {
        this.createEquipment();
      }
    }
  }

  createEquipment(): void {
    if (this.equipmentForm.invalid) {
      this.markFormGroupTouched(this.equipmentForm);
      return;
    }
    this.isSubmitting = true;
    // В getRawValue() попадают значения и отключённых контролов (pole_id фиксируем из контекстного меню)
    const formValue = this.equipmentForm.getRawValue();

    let notes: string = (formValue.notes || '').trim();
    const techParts: string[] = [];
    if (formValue.nominal_current) {
      techParts.push(`Iном=${String(formValue.nominal_current).trim()}`);
    }
    if (formValue.nominal_voltage) {
      techParts.push(`Uном=${String(formValue.nominal_voltage).trim()}`);
    }
    if (formValue.mark) {
      techParts.push(`Марка=${String(formValue.mark).trim()}`);
    }
    if (techParts.length) {
      const techLine = `Характеристики: ${techParts.join(', ')}`;
      notes = notes ? `${techLine}\n${notes}` : techLine;
    }

    const resolvedPoleId = this.data?.poleId != null ? this.data.poleId : formValue.pole_id;

    const body = {
      pole_id: resolvedPoleId,
      name: String(formValue.name || '').trim(),
      equipment_type: String(formValue.equipment_type || '').trim(),
      manufacturer: formValue.manufacturer?.trim() || undefined,
      model: formValue.model?.trim() || undefined,
      serial_number: formValue.serial_number?.trim() || undefined,
      year_manufactured: formValue.year_manufactured != null && formValue.year_manufactured !== '' ? Number(formValue.year_manufactured) : undefined,
      installation_date: formValue.installation_date || undefined,
      condition: formValue.condition || undefined,
      notes: notes || undefined
    };

    if (!body.name) {
      this.snackBar.open('Укажите наименование оборудования', 'Закрыть', { duration: 4000 });
      this.isSubmitting = false;
      return;
    }
    if (!body.equipment_type) {
      this.snackBar.open('Укажите тип оборудования', 'Закрыть', { duration: 4000 });
      this.isSubmitting = false;
      return;
    }
    const poleId = Number(resolvedPoleId);
    if (!poleId || isNaN(poleId)) {
      this.snackBar.open('Не удалось определить опору для оборудования', 'Закрыть', { duration: 4000 });
      this.isSubmitting = false;
      return;
    }
    // Автоматически рассчитываем положение оборудования относительно опоры:
    // берём соседнюю опору по последовательности и размещаем оборудование
    // между ними (на небольшом расстоянии от текущей опоры вдоль линии).
    this.apiService.getPole(poleId).pipe(
      switchMap(pole => {
        if (!pole || pole.line_id == null) {
          return of({ pole, poles: [] as Pole[] });
        }
        return this.apiService.getPolesByPowerLine(pole.line_id).pipe(
          map(poles => ({ pole, poles }))
        );
      }),
      catchError(err => {
        console.error('Ошибка загрузки опор для расчёта положения оборудования:', err);
        // В случае ошибки размещаем оборудование в точке опоры (без смещения).
        return of(null);
      }),
      switchMap(result => {
        let x_position: number | undefined;
        let y_position: number | undefined;

        if (result && result.pole) {
          const pole = result.pole as any;
          const poles = (result.poles || []) as any[];
          const lat0 = Number(pole.y_position ?? pole.latitude ?? 0);
          const lng0 = Number(pole.x_position ?? pole.longitude ?? 0);

          // Находим соседа по sequence_number в пределах одной ветки (магистраль или отпайка)
          let neighborLat = lat0;
          let neighborLng = lng0;
          const sameBranch = poles.filter(p => {
            // Опоры принадлежат одной линии
            if (p.id === pole.id) return false;
            const tapPoleId = p.tap_pole_id ?? null;
            const tapBranchIndex = p.tap_branch_index ?? null;
            const curTapPoleId = pole.tap_pole_id ?? null;
            const curTapBranchIndex = pole.tap_branch_index ?? null;
            // Для отпайки: та же отпаечная опора и ветка
            if (curTapPoleId != null) {
              return tapPoleId === curTapPoleId && (tapBranchIndex ?? 1) === (curTapBranchIndex ?? 1);
            }
            // Для магистрали: только магистральные опоры (без tap_pole_id)
            return tapPoleId == null;
          });

          const withSeq = sameBranch
            .filter(p => p.sequence_number != null)
            .sort((a, b) => (a.sequence_number ?? 0) - (b.sequence_number ?? 0));

          const idx = withSeq.findIndex(p => p.id === pole.id);
          let neighbor: any | null = null;
          if (idx >= 0) {
            // Пытаемся взять следующую по последовательности, иначе предыдущую
            neighbor = withSeq[idx + 1] ?? withSeq[idx - 1] ?? null;
          } else if (withSeq.length > 0) {
            neighbor = withSeq[0];
          }

          if (neighbor) {
            neighborLat = Number(neighbor.y_position ?? neighbor.latitude ?? lat0);
            neighborLng = Number(neighbor.x_position ?? neighbor.longitude ?? lng0);
            // Смещаем оборудование на 25% отрезка от текущей опоры к соседней
            const k = 0.25;
            y_position = lat0 + (neighborLat - lat0) * k;
            x_position = lng0 + (neighborLng - lng0) * k;
          } else {
            // Нет соседей — небольшое смещение на север от опоры
            y_position = lat0 + 0.00005;
            x_position = lng0;
          }
        } else {
          x_position = undefined;
          y_position = undefined;
        }

        const bodyWithPos: any = {
          ...body,
          x_position,
          y_position
        };

        return this.apiService.createEquipment(poleId, bodyWithPos as any);
      })
    ).subscribe({
      next: (created) => {
        this.isSubmitting = false;
        this.snackBar.open('Оборудование создано', 'Закрыть', { duration: 3000 });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, data: created });
      },
      error: (error) => {
        console.error('Ошибка создания оборудования:', error);
        this.isSubmitting = false;
        let errorMessage = 'Ошибка создания оборудования';
        if (error.error?.detail) {
          if (typeof error.error.detail === 'string') {
            errorMessage = error.error.detail;
          } else {
            errorMessage = JSON.stringify(error.error.detail);
          }
        } else if (error.message) {
          errorMessage = error.message;
        }
        this.snackBar.open(errorMessage, 'Закрыть', { duration: 6000, panelClass: ['error-snackbar'] });
      }
    });
  }

  updateEquipment(equipmentId: number): void {
    if (this.equipmentForm.invalid) {
      this.markFormGroupTouched(this.equipmentForm);
      return;
    }
    this.isSubmitting = true;
    const formValue = this.equipmentForm.getRawValue();

    let notes: string = (formValue.notes || '').trim();
    const techParts: string[] = [];
    if (formValue.nominal_current) {
      techParts.push(`Iном=${String(formValue.nominal_current).trim()}`);
    }
    if (formValue.nominal_voltage) {
      techParts.push(`Uном=${String(formValue.nominal_voltage).trim()}`);
    }
    if (formValue.mark) {
      techParts.push(`Марка=${String(formValue.mark).trim()}`);
    }
    if (techParts.length) {
      const techLine = `Характеристики: ${techParts.join(', ')}`;
      notes = notes ? `${techLine}\n${notes}` : techLine;
    }

    const body = {
      pole_id: formValue.pole_id,
      name: String(formValue.name || '').trim(),
      equipment_type: String(formValue.equipment_type || '').trim(),
      manufacturer: formValue.manufacturer?.trim() || undefined,
      model: formValue.model?.trim() || undefined,
      serial_number: formValue.serial_number?.trim() || undefined,
      year_manufactured: formValue.year_manufactured != null && formValue.year_manufactured !== '' ? Number(formValue.year_manufactured) : undefined,
      installation_date: formValue.installation_date || undefined,
      condition: formValue.condition || undefined,
      notes: notes || undefined
    };

    this.apiService.updateEquipment(equipmentId, body as any).subscribe({
      next: (updated) => {
        this.isSubmitting = false;
        this.snackBar.open('Оборудование обновлено', 'Закрыть', { duration: 3000 });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, data: updated });
      },
      error: (error) => {
        console.error('Ошибка обновления оборудования:', error);
        this.isSubmitting = false;
        let errorMessage = 'Ошибка обновления оборудования';
        if (error.error?.detail) {
          if (typeof error.error.detail === 'string') {
            errorMessage = error.error.detail;
          } else {
            errorMessage = JSON.stringify(error.error.detail);
          }
        } else if (error.message) {
          errorMessage = error.message;
        }
        this.snackBar.open(errorMessage, 'Закрыть', { duration: 6000, panelClass: ['error-snackbar'] });
      }
    });
  }

  createPole(): void {
    if (this.poleForm.invalid) {
      this.markFormGroupTouched(this.poleForm);
      return;
    }

    this.isSubmitting = true;
    const formValue = this.poleForm.value;
    
    // Получаем ID выбранной ЛЭП
    let lineId: number;
    if (typeof formValue.line_id === 'object' && formValue.line_id !== null) {
      lineId = formValue.line_id.id;
    } else if (typeof formValue.line_id === 'number') {
      lineId = formValue.line_id;
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

    const seqNum = formValue.sequence_number != null && formValue.sequence_number !== ''
      ? parseInt(String(formValue.sequence_number), 10) : undefined;
    if (seqNum !== undefined && (isNaN(seqNum) || seqNum < 1)) {
      this.snackBar.open('Порядок опоры должен быть целым числом ≥ 1', 'Закрыть', { duration: 5000 });
      this.isSubmitting = false;
      return;
    }

    // Ветка: branch_selection → JSON (магистраль / новая ветка / продолжение ветки)
    const hasBranchUi =
      this.showBranchChoice &&
      (this.tapBranchesInLine.length > 0 || this.tapPolesInLine.length > 0);

    let tapPoleId: number | null = null;
    let tapBranchIndex: number | undefined;
    let branchType: 'main' | 'tap' | undefined;
    let startNewTap = false;

    if (hasBranchUi) {
      const sel = formValue.branch_selection;
      if (sel == null || sel === '') {
        branchType = 'main';
      } else if (sel === this.branchNewTapSentinel) {
        if (!this.isEditMode && this.data?.tapPoleId != null) {
          tapPoleId = this.data.tapPoleId as number;
          startNewTap = true;
          branchType = 'tap';
        } else {
          branchType = 'main';
        }
      } else if (typeof sel === 'string' && sel.includes(':')) {
        const parts = sel.split(':');
        const pid = parseInt(parts[0], 10);
        const tbi = parseInt(parts[1], 10);
        if (!isNaN(pid) && !isNaN(tbi)) {
          tapPoleId = pid;
          tapBranchIndex = tbi;
          branchType = 'tap';
        }
      }
    } else if (!this.isEditMode && this.data?.startNewTap === true && this.data?.tapPoleId != null) {
      tapPoleId = this.data.tapPoleId as number;
      startNewTap = true;
      branchType = 'tap';
    }

    if (branchType == null) {
      branchType = 'main';
    }

    // CIM: x_position = долгота, y_position = широта (форма ввода — широта/долгота)
    const poleData: PoleCreate = {
      line_id: lineId,
      pole_number: formValue.pole_number.trim(),
      sequence_number: seqNum,
      x_position: longitude,
      y_position: latitude,
      pole_type: formValue.pole_type,
      mrid: formValue.mrid && formValue.mrid.trim() ? formValue.mrid.trim() : undefined,
      is_tap: !!formValue.is_tap,
      branch_type: branchType,
      tap_pole_id: tapPoleId ?? undefined,
      tap_branch_index: tapBranchIndex,
      start_new_tap: startNewTap ? true : undefined,
      conductor_type: formValue.conductor_type?.trim() || undefined,
      conductor_material: formValue.conductor_material?.trim() || undefined,
      conductor_section: formValue.conductor_section != null && String(formValue.conductor_section).trim() !== '' ? String(formValue.conductor_section).trim() : undefined,
      height: (() => {
        const height = normalizeNumber(formValue.height);
        return height !== undefined && height >= 0 ? height : undefined;
      })(),
      foundation_type: formValue.foundation_type?.trim() || undefined,
      material: formValue.material || undefined,
      year_installed: formValue.year_installed ? parseInt(String(formValue.year_installed)) : undefined,
      condition: formValue.condition || 'good',
      notes: formValue.notes?.trim() || undefined,
      structural_defect: formValue.structural_defect?.trim() || undefined,
      structural_defect_criticality:
        formValue.structural_defect?.trim() && formValue.structural_defect_criticality
          ? formValue.structural_defect_criticality
          : undefined,
      card_comment: serializeCardCommentMessages(this.poleCardCommentMessages),
      card_comment_attachment: this.poleAttachments.length ? JSON.stringify(this.poleAttachments) : undefined
    };

    console.log('Отправка данных для ' + (this.isEditMode ? 'обновления' : 'создания') + ' опоры:', poleData);

    // Используем API для создания или обновления опоры
    const poleObservable = this.isEditMode && this.poleId && this.lineId
      ? this.apiService.updatePole(this.lineId, this.poleId, poleData)
      : this.apiService.createPole(lineId, poleData);
    
    poleObservable.subscribe({
      next: (pole) => {
        const message = this.isEditMode ? 'Опора успешно обновлена' : 'Опора успешно создана';
        const hint = this.isEditMode && this.showBranchChoice
          ? ' При смене направления выполните «Пересборка топологии» по ЛЭП (ПКМ по линии в дереве).'
          : '';
        console.log(message + ':', pole);
        this.snackBar.open(message + hint, 'Закрыть', {
          duration: this.isEditMode && this.showBranchChoice ? 6000 : 3000
        });
        this.mapService.refreshData();
        this.apiService.createChangeLogEntry({
          source: 'web',
          action: this.isEditMode ? 'update' : 'create',
          entity_type: 'pole',
          entity_id: pole.id,
          payload: { name: pole.pole_number, mrid: pole.mrid }
        }).subscribe({ error: () => {} });
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

  /** Неотрицательное число (0 и больше), для высоты и т.п. */
  nonNegativeNumberValidator(control: any): { [key: string]: any } | null {
    if (!control.value && control.value !== 0) return null;
    const str = String(control.value).replace(',', '.');
    const num = parseFloat(str);
    if (isNaN(num)) return { invalidNumber: true };
    if (num < 0) return { negativeNumber: true };
    if (num > 200) return { maxValue: { max: 200 } }; // высота опоры до 200 м
    return null;
  }

  /** Год в разумных пределах (1900–текущий+5) */
  yearValidator(control: any): { [key: string]: any } | null {
    if (!control.value && control.value !== 0) return null;
    const y = parseInt(String(control.value), 10);
    if (isNaN(y)) return { invalidNumber: true };
    const currentYear = new Date().getFullYear();
    if (y < 1900 || y > currentYear + 5) return { yearRange: true };
    return null;
  }

  /** Порядок опоры: пусто — ок (авто), иначе целое ≥ 1 */
  sequenceNumberValidator(control: any): { [key: string]: any } | null {
    if (!control.value && control.value !== 0) return null;
    const n = parseInt(String(control.value), 10);
    if (isNaN(n)) return { invalidNumber: true };
    if (n < 1) return { minValue: true };
    return null;
  }

  /** Подпись поля «ветка»: что выбрано — Магистраль или Отпайка от опоры X — ветка N */
  get newTapBranchOptionLabel(): string {
    const id = this.data?.tapPoleId;
    if (id == null) {
      return 'Новая ветка';
    }
    const p = this.tapPolesInLine.find(x => x.id === id);
    return `Новая ветка от ${p?.pole_number ?? 'опора ' + id}`;
  }

  get tapBranchLabel(): string {
    const sel = this.poleForm?.get('branch_selection')?.value;
    if (sel == null || sel === '') {
      return 'Магистраль';
    }
    if (sel === this.branchNewTapSentinel) {
      return this.newTapBranchOptionLabel;
    }
    const tb = this.tapBranchesInLine.find(b => b.value === sel);
    return tb ? tb.label : 'Ветка';
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
    // Длина линии не задаётся вручную — рассчитывается автоматически по пролётам
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
        this.apiService.createChangeLogEntry({
          source: 'web',
          action: 'create',
          entity_type: 'power_line',
          entity_id: createdPowerLine.id,
          payload: { name: createdPowerLine.name, mrid: createdPowerLine.mrid }
        }).subscribe({ error: () => {} });
        // Обновляем дерево/карту; закрываем с объектом ЛЭП
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
    } else if (this.selectedObjectType === 'equipment') {
      form = this.equipmentForm;
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
    if (field?.hasError('yearRange')) {
      const y = new Date().getFullYear();
      return `Год должен быть в диапазоне 1900–${y + 5}`;
    }
    if (field?.hasError('maxValue')) {
      const err = field.errors?.['maxValue'];
      return err?.max != null ? `Максимальное значение: ${err.max}` : 'Значение слишком велико';
    }
    if (field?.hasError('minValue')) {
      return 'Минимальное значение: 1';
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
      voltage_level: parseFloat(formValue.voltage_level) || 0,
      latitude: parseFloat(formValue.latitude) || 0,
      longitude: parseFloat(formValue.longitude) || 0,
      address: formValue.address?.trim() || undefined,
      branch_id: formValue.branch_id ?? undefined,
      description: formValue.description?.trim() || undefined
    };
    if (formValue.uid && String(formValue.uid).trim()) {
      substationData.mrid = String(formValue.uid).trim();
    }
    if (formValue.dispatcher_name != null && String(formValue.dispatcher_name).trim()) {
      substationData.dispatcher_name = String(formValue.dispatcher_name).trim();
    }

    const obs = this.isEditMode && this.substationId
      ? this.apiService.updateSubstation(this.substationId, substationData)
      : this.apiService.createSubstation(substationData);

    obs.subscribe({
      next: (createdOrUpdated) => {
        this.isSubmitting = false;
        const message = this.isEditMode ? 'Подстанция успешно обновлена' : 'Подстанция успешно создана';
        this.snackBar.open(message, 'Закрыть', { duration: 3000 });
        this.apiService.createChangeLogEntry({
          source: 'web',
          action: this.isEditMode ? 'update' : 'create',
          entity_type: 'substation',
          entity_id: createdOrUpdated.id,
          payload: { name: createdOrUpdated.name, mrid: createdOrUpdated.mrid }
        }).subscribe({ error: () => {} });
        this.mapService.refreshData();
        this.dialogRef.close({ success: true, data: createdOrUpdated });
      },
      error: (error) => {
        console.error(this.isEditMode ? 'Ошибка обновления подстанции:' : 'Ошибка создания подстанции:', error);
        this.isSubmitting = false;
        let errorMessage = this.isEditMode ? 'Ошибка обновления подстанции' : 'Ошибка создания подстанции';
        if (error.error?.detail) {
          errorMessage = error.error.detail;
        } else if (error.message) {
          errorMessage = error.message;
        }
        this.snackBar.open(errorMessage, 'Закрыть', { duration: 5000 });
      }
    });
  }

  /** ЛЭП, у которых эта подстанция указана в начале линии */
  get linesWhereSubstationIsStart(): PowerLine[] {
    return this._linesWhereSubstationIsStart;
  }

  /** Строка имён ЛЭП «в начале» для отображения в шаблоне */
  get linesWhereSubstationIsStartNames(): string {
    return this._linesWhereSubstationIsStartNames;
  }

  /** ЛЭП, у которых эта подстанция указана в конце линии */
  get linesWhereSubstationIsEnd(): PowerLine[] {
    return this._linesWhereSubstationIsEnd;
  }

  /** Строка имён ЛЭП «в конце» для отображения в шаблоне */
  get linesWhereSubstationIsEndNames(): string {
    return this._linesWhereSubstationIsEndNames;
  }

  setSubstationAsLineStart(): void {
    if (!this.substationId || this.lineForStartId == null) return;
    this.linkingLineStart = true;
    this.apiService.updatePowerLine(this.lineForStartId, { substation_start_id: this.substationId }).subscribe({
      next: () => {
        this.linkingLineStart = false;
        this.lineForStartId = null;
        this.loadPowerLines();
        this.mapService.refreshData();
        this.snackBar.open('Подстанция установлена как начало линии', 'Закрыть', { duration: 3000 });
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.linkingLineStart = false;
        this.snackBar.open('Ошибка: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.cdr.detectChanges();
      }
    });
  }

  setSubstationAsLineEnd(): void {
    if (!this.substationId || this.lineForEndId == null) return;
    this.linkingLineEnd = true;
    this.apiService.updatePowerLine(this.lineForEndId, { substation_end_id: this.substationId }).subscribe({
      next: () => {
        this.linkingLineEnd = false;
        this.lineForEndId = null;
        this.loadPowerLines();
        this.mapService.refreshData();
        this.snackBar.open('Подстанция установлена как конец линии', 'Закрыть', { duration: 3000 });
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.linkingLineEnd = false;
        this.snackBar.open('Ошибка: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.cdr.detectChanges();
      }
    });
  }

  clearSubstationFromLineStart(lineId: number): void {
    if (!this.substationId) return;
    this.linkingLineStart = true;
    this.apiService.updatePowerLine(lineId, { substation_start_id: null }).subscribe({
      next: () => {
        this.linkingLineStart = false;
        this.loadPowerLines();
        this.mapService.refreshData();
        this.snackBar.open('Связь «начало линии» снята', 'Закрыть', { duration: 3000 });
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.linkingLineStart = false;
        this.snackBar.open('Ошибка: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.cdr.detectChanges();
      }
    });
  }

  clearSubstationFromLineEnd(lineId: number): void {
    if (!this.substationId) return;
    this.linkingLineEnd = true;
    this.apiService.updatePowerLine(lineId, { substation_end_id: null }).subscribe({
      next: () => {
        this.linkingLineEnd = false;
        this.loadPowerLines();
        this.mapService.refreshData();
        this.snackBar.open('Связь «конец линии» снята', 'Закрыть', { duration: 3000 });
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.linkingLineEnd = false;
        this.snackBar.open('Ошибка: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.cdr.detectChanges();
      }
    });
  }

  /** Список отпаечных участков (сегментов) для выбора «ТП в конце отпайки» */
  get tapSegmentsOptions(): { lineId: number; lineName: string; segmentId: number; segmentName: string; toPoleDisplayName?: string }[] {
    return this._tapSegmentsOptions;
  }

  /** Участки (отпайки), в конце которых уже указана эта подстанция */
  get segmentsWhereSubstationIsTapEnd(): { lineId: number; lineName: string; segmentId: number; segmentName: string; toPoleDisplayName?: string }[] {
    return this._segmentsWhereSubstationIsTapEnd;
  }

  /** Строка «ЛЭП — участок» для отображения текущих привязок ТП в конце отпаек */
  get segmentsWhereSubstationIsTapEndNames(): string {
    return this._segmentsWhereSubstationIsTapEndNames;
  }

  setSubstationAsTapEnd(): void {
    if (!this.substationId || !this.selectedTapSegmentForEnd) return;
    const { lineId, segmentId } = this.selectedTapSegmentForEnd;
    this.linkingTapEnd = true;
    this.apiService.setSegmentEndSubstation(lineId, segmentId, { to_substation_id: this.substationId }).subscribe({
      next: () => {
        this.linkingTapEnd = false;
        this.selectedTapSegmentForEnd = null;
        this.loadPowerLines();
        this.mapService.refreshData();
        this.snackBar.open('Подстанция установлена в конец отпайки', 'Закрыть', { duration: 3000 });
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.linkingTapEnd = false;
        this.snackBar.open('Ошибка: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.cdr.detectChanges();
      }
    });
  }

  clearSubstationFromTapEnd(lineId: number, segmentId: number): void {
    if (!this.substationId) return;
    this.linkingTapEnd = true;
    this.apiService.setSegmentEndSubstation(lineId, segmentId, { to_substation_id: null }).subscribe({
      next: () => {
        this.linkingTapEnd = false;
        this.loadPowerLines();
        this.mapService.refreshData();
        this.snackBar.open('Связь «ТП в конце отпайки» снята', 'Закрыть', { duration: 3000 });
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.linkingTapEnd = false;
        this.snackBar.open('Ошибка: ' + (err?.error?.detail || err?.message || 'Неизвестная ошибка'), 'Закрыть', { duration: 5000 });
        this.cdr.detectChanges();
      }
    });
  }
}

