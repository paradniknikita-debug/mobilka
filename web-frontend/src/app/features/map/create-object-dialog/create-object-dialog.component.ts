import { Component, OnInit, Inject, ChangeDetectorRef, ViewChild } from '@angular/core';
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
import { EquipmentCatalogItem } from '../../../core/models/equipment-catalog.model';
import { PoleEquipmentPanelComponent } from '../pole-equipment-panel/pole-equipment-panel.component';

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
  equipmentUid: string | null = null;
  equipmentPoleDisplayName = '';
  equipmentCatalogItems: EquipmentCatalogItem[] = [];
  equipmentNeighborPoleOptions: { value: string; label: string }[] = [];

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

  // Распространённые марки опор (СНГ) для быстрого выбора.
  // Поле остаётся редактируемым вручную.
  poleBrandsCis = [
    'СВ95-2',
    'СВ95-3',
    'СВ105-3.6',
    'СВ110-3.5',
    'СВ110-5',
    'СВ164-12',
    'СК22-1',
    'СК26-1',
    'УСО-1А',
    'У110-1',
    'ПБ35-1',
    'ПБ110-1'
  ];

  /** Марки опор в автодополнении с фильтром по вводу. */
  get filteredPoleBrands(): string[] {
    const q = (this.poleForm?.get('construction')?.value ?? '')
      .toString()
      .trim()
      .toLowerCase();
    if (!q) return this.poleBrandsCis;
    return this.poleBrandsCis.filter((b) => b.toLowerCase().includes(q));
  }

  get filteredPoleConductorMarks(): string[] {
    const q = (this.poleForm?.get('conductor_type')?.value ?? '')
      .toString()
      .trim()
      .toLowerCase();
    const source = this.lineConductorMarks.length ? this.lineConductorMarks : this.conductorTypes;
    if (!q) return source.slice(0, 30);
    return source.filter((m) => m.toLowerCase().includes(q)).slice(0, 30);
  }

  // Состояния опоры
  conditions = [
    'good',
    'satisfactory',
    'poor'
  ];

  // Марки провода для автосоздания пролёта (fallback, если справочник недоступен)
  conductorTypes = ['AC-70', 'AC-95', 'AC-120', 'AC-150', 'AC-185', 'AC-240', 'AC-300', 'AC-400', 'СИП-2', 'СИП-4', 'А'];
  // Материал провода
  conductorMaterials = ['алюминий', 'медь', 'сталь', 'алмаг'];
  /** Марки провода из справочника line-conductor-catalog */
  lineConductorMarks: string[] = [];

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

  /** Карточка оборудования (редактирование / создание). */
  equipmentCardCommentMessages: CardCommentMessage[] = [];
  equipmentAttachments: PoleCardAttachmentItem[] = [];
  newEquipmentCardCommentDraft = '';

  /** Класс напряжения ЛЭП опоры, кВ — номинал коммутационного оборудования совпадает с ним. */
  equipmentLineVoltageKv: number | null = null;
  poleEquipmentLineVoltageKv: number | null = null;

  @ViewChild('poleEquipmentPanel') poleEquipmentPanel?: PoleEquipmentPanelComponent;

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
      construction: [''],
      rated_voltage: [null],
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
      region_uid: ['c3d4e5f6-7890-1234-cdef-345678901234'],
      dispatcher_name: [''],
      balance_ownership: [''],
      parent_object_ref: [''],
      alcs_ref: [''],
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
      tm_code: [''],
      object_subtype: [''],
      parent_object_ref: [''],
      parent_main_equipment_pole_ref: [''],
      nominal_breaking_current_ka: [null],
      own_trip_time_sec: [null],
      emergency_current_a: [null],
      continuous_current_a: [null],
      arrester_type: ['opn'],
      nameplate: [''],
      identified_object_description: [''],
      installation_display_name: [''],
      psr_subtype: ['retractable'],
      manufacturer: [''],
      model: [''],
      serial_number: [''],
      year_manufactured: [null],
      installation_date: [''],
      condition: ['good'],
      defect: [''],
      criticality: [null as string | null],
      notes: [''],
      rated_current: [null],
      i_th: [null],
      ip_max: [null],
      t_th: [null],
      normal_open: [true],
      retained: [true]
    });
    // Если пришёл poleId из контекстного меню, фиксируем его и не даём менять
    if (data?.poleId) {
      this.equipmentForm.get('pole_id')?.patchValue(data.poleId);
      this.equipmentForm.get('pole_id')?.disable({ emitEvent: false });
    }
  }

  ngOnInit(): void {
    this.loadLineConductorCatalog();
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
      this.refreshPoleEquipmentLineVoltage();
    });

    this.equipmentForm.get('equipment_type')?.valueChanges.subscribe((value) => {
      const type = String(value || '').trim();
      if (type === 'grounding_switch') {
        this.equipmentForm.patchValue({ psr_subtype: 'short_circuiter' }, { emitEvent: false });
      } else if (type === 'breaker' && !this.equipmentForm.get('object_subtype')?.value) {
        this.equipmentForm.patchValue({ object_subtype: 'vacuum_breaker' }, { emitEvent: false });
      } else if (type === 'disconnector' && !this.equipmentForm.get('psr_subtype')?.value) {
        this.equipmentForm.patchValue({ psr_subtype: 'retractable' }, { emitEvent: false });
      }
      this.loadEquipmentCatalogForType(type);
      this.refreshEquipmentLineVoltageFromPole();
    });
    this.equipmentForm.get('pole_id')?.valueChanges.subscribe((value) => {
      const poleId = Number(value);
      if (Number.isFinite(poleId) && poleId > 0) {
        this.loadEquipmentPoleDisplayName(poleId);
        this.updateEquipmentNeighborOptions(poleId);
      } else {
        this.equipmentPoleDisplayName = '';
        this.equipmentNeighborPoleOptions = [];
      }
      this.refreshEquipmentLineVoltageFromPole();
    });
    const initialPoleId = Number(this.data?.poleId ?? this.equipmentForm.getRawValue()?.pole_id);
    if (Number.isFinite(initialPoleId) && initialPoleId > 0) {
      this.loadEquipmentPoleDisplayName(initialPoleId);
      this.updateEquipmentNeighborOptions(initialPoleId);
    }
    this.refreshEquipmentLineVoltageFromPole();
  }

  private loadEquipmentPoleDisplayName(poleId: number): void {
    this.apiService.getPole(poleId).subscribe({
      next: (pole) => {
        const number = String((pole as any)?.pole_number ?? '').trim();
        this.equipmentPoleDisplayName = number ? number : `Опора ${poleId}`;
      },
      error: () => {
        this.equipmentPoleDisplayName = `Опора ${poleId}`;
      }
    });
  }

  private mapEquipmentTypeToCatalogCode(type: string): string | null {
    const v = (type || '').trim().toLowerCase();
    if (!v) return null;
    switch (v) {
      case 'grounding_switch':
        return 'zn';
      case 'surge_arrester':
        return 'arrester';
      default:
        return v;
    }
  }

  private normalizeCatalogText(value: string | null | undefined): string {
    return String(value || '')
      .trim()
      .toLowerCase()
      .replace(/\s+/g, ' ');
  }

  isElectricalEquipmentType(type?: string | null): boolean {
    const v = this.normalizeCatalogText(type ?? this.equipmentForm.get('equipment_type')?.value);
    const nonElectrical = new Set([
      'фундамент',
      'траверса',
      'изолятор',
      'грозоотвод',
      'foundation',
      'traverse',
      'insulator',
      'lightning_rod',
      'lightning_protection',
      'ground_wire'
    ]);
    return !!v && !nonElectrical.has(v);
  }

  isNominalVoltageLockedByLine(): boolean {
    return this.equipmentLineVoltageKv != null && this.isElectricalEquipmentType();
  }

  private applyNominalVoltageFromLineLock(): void {
    const ctl = this.equipmentForm.get('nominal_voltage');
    if (!ctl) {
      return;
    }
    if (this.isNominalVoltageLockedByLine()) {
      const v = this.equipmentLineVoltageKv as number;
      ctl.patchValue(String(v), { emitEvent: false });
      ctl.disable({ emitEvent: false });
    } else {
      ctl.enable({ emitEvent: false });
    }
  }

  private refreshEquipmentLineVoltageFromPole(): void {
    const rawPid = this.equipmentForm.getRawValue()?.pole_id ?? this.data?.poleId;
    const poleId = Number(rawPid);
    if (!Number.isFinite(poleId) || poleId <= 0) {
      this.equipmentLineVoltageKv = null;
      this.applyNominalVoltageFromLineLock();
      return;
    }
    this.apiService
      .getPole(poleId)
      .pipe(
        switchMap((pole: any) => {
          const lid = pole?.line_id;
          if (!lid) {
            return of(null);
          }
          return this.apiService.getPowerLine(Number(lid));
        }),
        catchError(() => of(null))
      )
      .subscribe((pl: any) => {
        const v = pl?.voltage_level != null ? Number(pl.voltage_level) : NaN;
        this.equipmentLineVoltageKv = Number.isFinite(v) ? v : null;
        this.applyNominalVoltageFromLineLock();
        this.cdr.markForCheck();
      });
  }

  private refreshPoleEquipmentLineVoltage(): void {
    const lineVal = this.poleForm?.get('line_id')?.value;
    const lineId =
      typeof lineVal === 'object' && lineVal !== null && 'id' in lineVal
        ? (lineVal as { id: number }).id
        : this.lineId ?? null;
    if (!lineId) {
      this.poleEquipmentLineVoltageKv = null;
      return;
    }
    const line = this.powerLines.find((l) => l.id === lineId);
    const v = line?.voltage_level != null ? Number(line.voltage_level) : NaN;
    this.poleEquipmentLineVoltageKv = Number.isFinite(v) ? v : null;
  }

  isSwitchLikeEquipmentType(type?: string | null): boolean {
    const v = this.normalizeCatalogText(type ?? this.equipmentForm.get('equipment_type')?.value);
    return v === 'disconnector' || v === 'grounding_switch' || v === 'зн' || v === 'разъединитель';
  }

  /** Марки из каталога с фильтрацией по вводу в поле «Марка (табличка)». */
  get filteredEquipmentCatalog(): EquipmentCatalogItem[] {
    const q = this.normalizeCatalogText(this.equipmentForm.get('nameplate')?.value);
    if (!q) return this.equipmentCatalogItems;
    return this.equipmentCatalogItems.filter((item) => {
      const label = this.normalizeCatalogText(this.catalogLabel(item));
      const brand = this.normalizeCatalogText(item.brand);
      const model = this.normalizeCatalogText(item.model);
      return (
        label.includes(q) ||
        brand.includes(q) ||
        model.includes(q) ||
        `${brand} ${model}`.trim().includes(q)
      );
    });
  }

  private catalogLabel(item: EquipmentCatalogItem): string {
    const full = item.full_name?.trim();
    if (full) return full;
    return `${item.brand} ${item.model}`.trim();
  }

  private parseAttrsJson(attrsJson?: string | null): Record<string, any> {
    if (!attrsJson || !attrsJson.trim()) return {};
    try {
      const parsed = JSON.parse(attrsJson);
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch {
      return {};
    }
  }

  private toNumber(value: any): number | null {
    if (value == null || value === '') return null;
    const n = Number(String(value).replace(',', '.'));
    return Number.isFinite(n) ? n : null;
  }

  private toBool(value: any): boolean | null {
    if (value == null || value === '') return null;
    if (typeof value === 'boolean') return value;
    const v = String(value).trim().toLowerCase();
    if (v === 'true' || v === '1') return true;
    if (v === 'false' || v === '0') return false;
    return null;
  }

  private normalizeSwitchBrandKey(value: string | null | undefined): string {
    return String(value || '')
      .trim()
      .toUpperCase()
      .replace(/\s+/g, '')
      .replace(/,/g, '.');
  }

  private applyKnownSwitchBrandPreset(nameplateRaw: string): boolean {
    const raw = this.normalizeSwitchBrandKey(nameplateRaw);
    if (!raw) return false;

    const patch: any = {};
    let matched = false;

    const kzMatch = raw.match(/^(КЗ|KZ|K3)-?(\d+(?:\.\d+)?)\/(\d+)$/i);
    if (kzMatch) {
      const nominalKv = this.toNumber(kzMatch[2]);
      const ratedCurrent = this.toNumber(kzMatch[3]);
      if (nominalKv != null) patch.nominal_voltage = nominalKv;
      if (ratedCurrent != null) patch.rated_current = ratedCurrent;
      patch.psr_subtype = 'short_circuiter';
      matched = true;
    }

    const rgpGnpMatch = raw.match(/^(РГП|GNP|ГНП|RGP)-?(\d+(?:\.\d+)?)$/i);
    if (rgpGnpMatch) {
      const nominalKv = this.toNumber(rgpGnpMatch[2]);
      if (nominalKv != null) patch.nominal_voltage = nominalKv;
      patch.psr_subtype = 'short_circuiter';
      matched = true;
    }

    if (!matched || Object.keys(patch).length === 0) return false;
    this.equipmentForm.patchValue(patch);
    this.applyNominalVoltageFromLineLock();
    this.snackBar.open(
      'Характеристики подставлены по марке оборудования. При необходимости измените вручную.',
      'Закрыть',
      { duration: 2500 }
    );
    return true;
  }

  private loadEquipmentCatalogForType(type: string): void {
    const typeCode = this.mapEquipmentTypeToCatalogCode(type);
    if (!typeCode) {
      this.equipmentCatalogItems = [];
      return;
    }
    this.apiService.getEquipmentCatalog({ type_code: typeCode, is_active: true, limit: 500 }).subscribe({
      next: (rows) => {
        this.equipmentCatalogItems = rows ?? [];
        this.cdr.markForCheck();
      },
      error: () => {
        this.equipmentCatalogItems = [];
      }
    });
  }

  private loadLineConductorCatalog(): void {
    this.apiService.getLineConductorCatalog({ is_active: true, limit: 500 }).subscribe({
      next: (items) => {
        const marks = new Set<string>();
        for (const it of items || []) {
          const m = (it.mark || '').trim();
          if (m) marks.add(m);
        }
        this.lineConductorMarks = Array.from(marks).sort((a, b) => a.localeCompare(b, 'ru'));
        this.cdr.markForCheck();
      },
      error: () => {
        this.lineConductorMarks = [];
      }
    });
  }

  applyCatalogByNameplate(): void {
    const nameplate = String(this.equipmentForm.get('nameplate')?.value || '').trim();
    if (!nameplate) return;
    const key = this.normalizeCatalogText(nameplate);
    const match = this.equipmentCatalogItems.find((item) => {
      const label = this.normalizeCatalogText(this.catalogLabel(item));
      const brand = this.normalizeCatalogText(item.brand);
      const model = this.normalizeCatalogText(item.model);
      return key === label || key === brand || key === model || key === `${brand} ${model}`.trim();
    });
    if (!match) {
      this.applyKnownSwitchBrandPreset(nameplate);
      return;
    }
    const attrs = this.parseAttrsJson(match.attrs_json);
    const ratedCurrent = this.toNumber(match.current_a) ?? this.toNumber(attrs['rated_current'] ?? attrs['ratedCurrent']);
    const iTh = this.toNumber(attrs['i_th'] ?? attrs['iTh']);
    const ipMax = this.toNumber(attrs['ip_max'] ?? attrs['ipMax']);
    const tTh = this.toNumber(attrs['t_th'] ?? attrs['tTh']);
    const normalOpen = this.toBool(attrs['normal_open'] ?? attrs['normalOpen']);
    const retained = this.toBool(attrs['retained']);
    const nominalVoltageKv = this.toNumber(match.voltage_kv ?? attrs['nominal_voltage_kv'] ?? attrs['nominalVoltageKv'] ?? attrs['voltage_kv']);
    const nominalBreakingCurrentKa = this.toNumber(attrs['nominal_breaking_current_ka'] ?? attrs['nominalBreakingCurrentKa']);
    const ownTripTimeSec = this.toNumber(attrs['own_trip_time_sec'] ?? attrs['ownTripTimeSec']);
    const emergencyCurrentA = this.toNumber(attrs['emergency_current_a'] ?? attrs['emergencyCurrentA']);
    const continuousCurrentA = this.toNumber(attrs['continuous_current_a'] ?? attrs['continuousCurrentA']);
    const tmCode = attrs['tm_code'] ?? attrs['tmCode'];
    const objectSubtype = attrs['object_subtype'] ?? attrs['objectSubtype'];
    const psrSubtype = attrs['psr_subtype'] ?? attrs['psrSubtype'];
    const arresterType = attrs['arrester_type'] ?? attrs['arresterType'];

    const patch: any = {};
    if (ratedCurrent != null) patch.rated_current = ratedCurrent;
    if (iTh != null) patch.i_th = iTh;
    if (ipMax != null) patch.ip_max = ipMax;
    if (tTh != null) patch.t_th = tTh;
    if (normalOpen != null) patch.normal_open = normalOpen;
    if (retained != null) patch.retained = retained;
    if (nominalVoltageKv != null) patch.nominal_voltage = nominalVoltageKv;
    if (nominalBreakingCurrentKa != null) patch.nominal_breaking_current_ka = nominalBreakingCurrentKa;
    if (ownTripTimeSec != null) patch.own_trip_time_sec = ownTripTimeSec;
    if (emergencyCurrentA != null) patch.emergency_current_a = emergencyCurrentA;
    if (continuousCurrentA != null) patch.continuous_current_a = continuousCurrentA;
    if (tmCode != null && String(tmCode).trim() !== '') patch.tm_code = String(tmCode).trim();
    if (objectSubtype != null && String(objectSubtype).trim() !== '') patch.object_subtype = String(objectSubtype).trim();
    if (psrSubtype != null && String(psrSubtype).trim() !== '') patch.psr_subtype = String(psrSubtype).trim();
    if (arresterType != null && String(arresterType).trim() !== '') patch.arrester_type = String(arresterType).trim();
    if (Object.keys(patch).length > 0) {
      this.equipmentForm.patchValue(patch);
      this.applyNominalVoltageFromLineLock();
      this.snackBar.open('Характеристики подставлены из каталога. При необходимости измените вручную.', 'Закрыть', { duration: 2500 });
    }
  }

  private loadEquipment(equipmentId: number): void {
    this.isLoading = true;
    this.apiService.getEquipment(equipmentId).subscribe({
      next: (eq) => {
        this.equipmentUid = (eq as any).mrid || null;
        // pole_id редактировать не даём
        this.equipmentForm.patchValue({
          name: eq.name || '',
          equipment_type: eq.equipment_type || '',
          pole_id: eq.pole_id,
          nominal_current: '',
          nominal_voltage:
            (eq as any).nominal_voltage_kv != null && (eq as any).nominal_voltage_kv !== ''
              ? String((eq as any).nominal_voltage_kv)
              : '',
          nameplate: (eq as any).nameplate || '',
          identified_object_description: (eq as any).identified_object_description || '',
          installation_display_name: (eq as any).installation_display_name || '',
          psr_subtype: (eq as any).psr_subtype || 'retractable',
          tm_code: (eq as any).tm_code || '',
          object_subtype: (eq as any).object_subtype || '',
          parent_object_ref: (eq as any).parent_object_ref || '',
          parent_main_equipment_pole_ref: (eq as any).parent_main_equipment_pole_ref || '',
          nominal_breaking_current_ka: (eq as any).nominal_breaking_current_ka ?? null,
          own_trip_time_sec: (eq as any).own_trip_time_sec ?? null,
          emergency_current_a: (eq as any).emergency_current_a ?? null,
          continuous_current_a: (eq as any).continuous_current_a ?? null,
          arrester_type: (eq as any).arrester_type || 'opn',
          manufacturer: eq.manufacturer || '',
          model: eq.model || '',
          serial_number: eq.serial_number || '',
          year_manufactured: eq.year_manufactured ?? null,
          installation_date: eq.installation_date ? (eq.installation_date as any).toString().slice(0, 10) : '',
          condition: eq.condition || 'good',
          defect: (eq as any).defect || '',
          criticality: (eq as any).criticality ?? null,
          notes: eq.notes || '',
          rated_current: (eq as any).rated_current ?? null,
          i_th: (eq as any).i_th ?? null,
          ip_max: (eq as any).ip_max ?? null,
          t_th: (eq as any).t_th ?? null,
          normal_open: (eq as any).normal_open ?? null,
          retained: (eq as any).retained ?? null
        });
        this.equipmentForm.get('pole_id')?.disable({ emitEvent: false });
        const pId = Number((eq as any).pole_id ?? this.data?.poleId ?? 0);
        if (pId > 0) {
          this.updateEquipmentNeighborOptions(pId);
        }
        this.refreshEquipmentLineVoltageFromPole();
        this.equipmentCardCommentMessages = parseCardCommentMessages((eq as any).card_comment);
        this.equipmentAttachments = this.parseCardAttachments((eq as any).card_comment_attachment);
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

  sendEquipmentCardComment(): void {
    const text = this.newEquipmentCardCommentDraft?.trim();
    if (!text) {
      return;
    }
    const user = this.authService.getCurrentUser();
    if (!user) {
      this.snackBar.open('Войдите в систему, чтобы отправить комментарий', 'Закрыть', { duration: 4000 });
      return;
    }
    this.equipmentCardCommentMessages = appendCardCommentMessage(this.equipmentCardCommentMessages, text, user);
    this.newEquipmentCardCommentDraft = '';
    this.cdr.markForCheck();
  }

  openEquipmentAttachmentsManager(): void {
    const id = this.data?.equipmentId;
    if (!id) return;
    this.dialog
      .open(PoleAttachmentsManagerDialogComponent, {
        width: '880px',
        maxWidth: '95vw',
        maxHeight: '90vh',
        data: { entity: 'equipment', entityId: id, items: [...this.equipmentAttachments] }
      })
      .afterClosed()
      .subscribe((result: PoleCardAttachmentItem[] | undefined) => {
        if (result) {
          this.equipmentAttachments = result;
          this.cdr.markForCheck();
        }
      });
  }

  copyEquipmentUid(): void {
    const uid = this.equipmentUid?.trim();
    if (!uid) {
      this.snackBar.open('UID отсутствует', 'Закрыть', { duration: 2500 });
      return;
    }
    navigator.clipboard?.writeText(uid).then(
      () => this.snackBar.open('UID скопирован', 'Закрыть', { duration: 2000 }),
      () => this.snackBar.open('Не удалось скопировать UID', 'Закрыть', { duration: 2500 })
    );
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
      `Якорь: ${anchor} (id ${tapPoleId}), индекс отпайки ${branchIndex}. ` +
      (chain ? `Все опоры отпайки: ${chain}.` : 'На отпайке пока нет учтённых опор.');
    if (names.length === 0) {
      return { label: `${anchor} · отпайка ${branchIndex} — (пока без опор)`, tooltip };
    }
    if (names.length === 1) {
      return { label: `${anchor} · отпайка ${branchIndex} — к ${first}`, tooltip };
    }
    return {
      label: `${anchor} · отпайка ${branchIndex}: ${first} → ${last} (${names.length} оп.)`,
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
        this.refreshPoleEquipmentLineVoltage();

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

  private poleOrderFromNumber(poleNumber: string): number {
    const t = String(poleNumber || '').trim();
    if (!t) return Number.MAX_SAFE_INTEGER;
    if (!t.includes('/')) return Number.parseInt(t, 10) || Number.MAX_SAFE_INTEGER;
    const parts = t.split('/');
    if (parts.length < 2) return Number.MAX_SAFE_INTEGER;
    return Number.parseInt(parts[1].trim(), 10) || Number.MAX_SAFE_INTEGER;
  }

  private sortPolesForTopology(list: any[]): any[] {
    return [...list].sort((a: any, b: any) => {
      const sa = a?.sequence_number;
      const sb = b?.sequence_number;
      if (sa != null && sb != null && sa !== sb) return sa - sb;
      if (sa != null && sb == null) return -1;
      if (sa == null && sb != null) return 1;
      const oa = this.poleOrderFromNumber(a?.pole_number ?? '');
      const ob = this.poleOrderFromNumber(b?.pole_number ?? '');
      if (oa !== ob) return oa - ob;
      return Number(a?.id ?? 0) - Number(b?.id ?? 0);
    });
  }

  private computeAdjacentPoles(currentPole: any, allPoles: any[]): any[] {
    if (!currentPole) return [];
    const neighbors: any[] = [];
    const addUnique = (p: any) => {
      if (!p || Number(p.id) === Number(currentPole.id)) return;
      if (!neighbors.some((x: any) => Number(x.id) === Number(p.id))) neighbors.push(p);
    };

    const curTapPoleId = currentPole.tap_pole_id ?? null;
    const curTapBranchIndex = currentPole.tap_branch_index ?? 1;
    if (curTapPoleId != null) {
      const branch = this.sortPolesForTopology(
        allPoles.filter((p: any) => Number(p.tap_pole_id ?? -1) === Number(curTapPoleId) && Number(p.tap_branch_index ?? 1) === Number(curTapBranchIndex))
      );
      const idx = branch.findIndex((p: any) => Number(p.id) === Number(currentPole.id));
      if (idx > 0) {
        addUnique(branch[idx - 1]);
      } else {
        addUnique(allPoles.find((p: any) => Number(p.id) === Number(curTapPoleId)));
      }
      if (idx >= 0 && idx < branch.length - 1) addUnique(branch[idx + 1]);
    } else {
      const main = this.sortPolesForTopology(allPoles.filter((p: any) => (p.tap_pole_id ?? null) == null));
      const idx = main.findIndex((p: any) => Number(p.id) === Number(currentPole.id));
      if (idx > 0) addUnique(main[idx - 1]);
      if (idx >= 0 && idx < main.length - 1) addUnique(main[idx + 1]);
      const firstTapByBranch = new Map<string, any>();
      allPoles
        .filter((p: any) => Number(p.tap_pole_id ?? -1) === Number(currentPole.id))
        .forEach((p: any) => {
          const k = `${Number(p.tap_branch_index ?? 1)}`;
          const existing = firstTapByBranch.get(k);
          if (!existing || (Number(p.sequence_number ?? Number.MAX_SAFE_INTEGER) < Number(existing.sequence_number ?? Number.MAX_SAFE_INTEGER))) {
            firstTapByBranch.set(k, p);
          }
        });
      firstTapByBranch.forEach((p: any) => addUnique(p));
    }
    return neighbors;
  }

  private updateEquipmentNeighborOptions(poleId: number): void {
    this.apiService.getPole(poleId).pipe(
      switchMap((pole: any) => {
        if (!pole || pole.line_id == null) return of({ pole, poles: [] as any[] });
        return this.apiService.getPolesByPowerLine(pole.line_id).pipe(
          map((poles: any[]) => ({ pole, poles: poles || [] as any[] }))
        );
      }),
      catchError(() => of({ pole: null, poles: [] as any[] }))
    ).subscribe(({ pole, poles }) => {
      const adjacent = this.computeAdjacentPoles(pole, poles);
      this.equipmentNeighborPoleOptions = adjacent.map((p: any) => {
        const num = String(p.pole_number || '').trim();
        const value = num || String(p.id);
        return { value, label: num ? `${num} (ID ${p.id})` : `ID ${p.id}` };
      });
      this.cdr.markForCheck();
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
          construction: (pole as any).construction || '',
          rated_voltage: (pole as any).rated_voltage ?? null,
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
          original_filename: item.original_filename,
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
        data: { entity: 'pole', entityId: this.poleId, items: [...this.poleAttachments] }
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
    const isElectricalType = this.isElectricalEquipmentType(formValue.equipment_type);

    const notesParts: string[] = [];
    const plainNotes: string = (formValue.notes || '').trim();
    if (plainNotes) notesParts.push(plainNotes);
    if (formValue.nominal_current != null && String(formValue.nominal_current).trim() !== '') {
      notesParts.push(`Номинальный ток (legacy): ${String(formValue.nominal_current).trim()}`);
    }
    if (formValue.nominal_voltage != null && String(formValue.nominal_voltage).trim() !== '') {
      notesParts.push(`Номинальное напряжение, кВ: ${String(formValue.nominal_voltage).trim()}`);
    }
    if (formValue.tm_code != null && String(formValue.tm_code).trim() !== '') {
      notesParts.push(`Код ТМ: ${String(formValue.tm_code).trim()}`);
    }
    if (formValue.object_subtype != null && String(formValue.object_subtype).trim() !== '') {
      notesParts.push(`Подтип энергообъекта: ${String(formValue.object_subtype).trim()}`);
    }
    const poleCount =
      formValue.equipment_type === 'breaker' || formValue.equipment_type === 'recloser'
        ? 2
        : formValue.equipment_type === 'surge_arrester'
          ? null
          : 1;
    if (poleCount != null) notesParts.push(`Полюс оборудования: ${poleCount}`);
    if (formValue.parent_object_ref != null && String(formValue.parent_object_ref).trim() !== '') {
      notesParts.push(`Родительский объект: ${String(formValue.parent_object_ref).trim()}`);
    }
    if (formValue.parent_main_equipment_pole_ref != null && String(formValue.parent_main_equipment_pole_ref).trim() !== '') {
      notesParts.push(`Полюс основного оборудования: ${String(formValue.parent_main_equipment_pole_ref).trim()}`);
    }
    if (formValue.nominal_breaking_current_ka != null && String(formValue.nominal_breaking_current_ka).trim() !== '') {
      notesParts.push(`Номинальный ток отключения, кА: ${String(formValue.nominal_breaking_current_ka).trim()}`);
    }
    if (formValue.own_trip_time_sec != null && String(formValue.own_trip_time_sec).trim() !== '') {
      notesParts.push(`Собственное время отключения, c: ${String(formValue.own_trip_time_sec).trim()}`);
    }
    if (formValue.emergency_current_a != null && String(formValue.emergency_current_a).trim() !== '') {
      notesParts.push(`Аварийно-допустимый ток, А: ${String(formValue.emergency_current_a).trim()}`);
    }
    if (formValue.continuous_current_a != null && String(formValue.continuous_current_a).trim() !== '') {
      notesParts.push(`Длительно-допустимый ток, А: ${String(formValue.continuous_current_a).trim()}`);
    }
    if (formValue.arrester_type != null && String(formValue.arrester_type).trim() !== '') {
      notesParts.push(`Тип разрядника: ${String(formValue.arrester_type).trim()}`);
    }
    const notes: string = notesParts.join('; ');

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
      defect: (formValue.defect || '').trim() || null,
      criticality: (formValue.defect || '').trim() && formValue.criticality ? formValue.criticality : null,
      notes: notes || undefined,
      rated_current: isElectricalType && formValue.rated_current != null && formValue.rated_current !== '' ? Number(formValue.rated_current) : undefined,
      i_th: isElectricalType && formValue.i_th != null && formValue.i_th !== '' ? Number(formValue.i_th) : undefined,
      ip_max: isElectricalType && formValue.ip_max != null && formValue.ip_max !== '' ? Number(formValue.ip_max) : undefined,
      t_th: isElectricalType && formValue.t_th != null && formValue.t_th !== '' ? Number(formValue.t_th) : undefined,
      normal_open: isElectricalType ? true : undefined,
      retained: isElectricalType ? true : undefined,
      identified_object_description: (formValue.identified_object_description || '').trim() || undefined,
      nameplate: (formValue.nameplate || '').trim() || undefined,
      psr_subtype:
        formValue.equipment_type === 'disconnector' || formValue.equipment_type === 'grounding_switch'
          ? (formValue.psr_subtype || undefined)
          : undefined,
      installation_display_name: isElectricalType ? 'ЛЭП' : undefined,
      tm_code: (formValue.tm_code || '').trim() || undefined,
      object_subtype: (formValue.object_subtype || '').trim() || undefined,
      pole_count:
        formValue.equipment_type === 'breaker' || formValue.equipment_type === 'recloser'
          ? 2
          : (formValue.equipment_type === 'surge_arrester' ? undefined : 1),
      parent_object_ref: (formValue.parent_object_ref || '').trim() || undefined,
      parent_main_equipment_pole_ref: (formValue.parent_main_equipment_pole_ref || '').trim() || undefined,
      nominal_voltage_kv: formValue.nominal_voltage != null && formValue.nominal_voltage !== '' ? Number(formValue.nominal_voltage) : undefined,
      nominal_breaking_current_ka: isElectricalType &&
        formValue.nominal_breaking_current_ka != null && formValue.nominal_breaking_current_ka !== ''
          ? Number(formValue.nominal_breaking_current_ka)
          : undefined,
      own_trip_time_sec: isElectricalType &&
        formValue.own_trip_time_sec != null && formValue.own_trip_time_sec !== ''
          ? Number(formValue.own_trip_time_sec)
          : undefined,
      emergency_current_a: isElectricalType &&
        formValue.emergency_current_a != null && formValue.emergency_current_a !== ''
          ? Number(formValue.emergency_current_a)
          : undefined,
      continuous_current_a: isElectricalType &&
        formValue.continuous_current_a != null && formValue.continuous_current_a !== ''
          ? Number(formValue.continuous_current_a)
          : undefined,
      arrester_type:
        formValue.equipment_type === 'surge_arrester'
          ? ((formValue.arrester_type || '').trim() || undefined)
          : undefined,
      card_comment: serializeCardCommentMessages(this.equipmentCardCommentMessages) || undefined,
      card_comment_attachment:
        this.equipmentAttachments.length > 0 ? JSON.stringify(this.equipmentAttachments) : undefined
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

          // Находим соседей в пределах одной ветки (магистраль/отпайка).
          let neighborLat = lat0;
          let neighborLng = lng0;
          const adjacent = this.computeAdjacentPoles(pole, poles);
          let neighbor: any | null = null;
          const ref = String(formValue.parent_main_equipment_pole_ref || '').trim().toLowerCase();
          if (ref) {
            neighbor = adjacent.find((p: any) => {
              const pid = String(p?.id ?? '').trim().toLowerCase();
              const pn = String(p?.pole_number ?? '').trim().toLowerCase();
              return ref === pid || ref === pn;
            }) ?? null;
          }
          if (!neighbor && adjacent.length > 0) {
            neighbor = adjacent[0];
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
    const isElectricalType = this.isElectricalEquipmentType(formValue.equipment_type);

    const notesParts: string[] = [];
    const plainNotes: string = (formValue.notes || '').trim();
    if (plainNotes) notesParts.push(plainNotes);
    if (formValue.nominal_current != null && String(formValue.nominal_current).trim() !== '') {
      notesParts.push(`Номинальный ток (legacy): ${String(formValue.nominal_current).trim()}`);
    }
    if (formValue.nominal_voltage != null && String(formValue.nominal_voltage).trim() !== '') {
      notesParts.push(`Номинальное напряжение, кВ: ${String(formValue.nominal_voltage).trim()}`);
    }
    if (formValue.tm_code != null && String(formValue.tm_code).trim() !== '') {
      notesParts.push(`Код ТМ: ${String(formValue.tm_code).trim()}`);
    }
    if (formValue.object_subtype != null && String(formValue.object_subtype).trim() !== '') {
      notesParts.push(`Подтип энергообъекта: ${String(formValue.object_subtype).trim()}`);
    }
    const poleCount =
      formValue.equipment_type === 'breaker' || formValue.equipment_type === 'recloser'
        ? 2
        : formValue.equipment_type === 'surge_arrester'
          ? null
          : 1;
    if (poleCount != null) notesParts.push(`Полюс оборудования: ${poleCount}`);
    if (formValue.parent_object_ref != null && String(formValue.parent_object_ref).trim() !== '') {
      notesParts.push(`Родительский объект: ${String(formValue.parent_object_ref).trim()}`);
    }
    if (formValue.parent_main_equipment_pole_ref != null && String(formValue.parent_main_equipment_pole_ref).trim() !== '') {
      notesParts.push(`Полюс основного оборудования: ${String(formValue.parent_main_equipment_pole_ref).trim()}`);
    }
    if (formValue.nominal_breaking_current_ka != null && String(formValue.nominal_breaking_current_ka).trim() !== '') {
      notesParts.push(`Номинальный ток отключения, кА: ${String(formValue.nominal_breaking_current_ka).trim()}`);
    }
    if (formValue.own_trip_time_sec != null && String(formValue.own_trip_time_sec).trim() !== '') {
      notesParts.push(`Собственное время отключения, c: ${String(formValue.own_trip_time_sec).trim()}`);
    }
    if (formValue.emergency_current_a != null && String(formValue.emergency_current_a).trim() !== '') {
      notesParts.push(`Аварийно-допустимый ток, А: ${String(formValue.emergency_current_a).trim()}`);
    }
    if (formValue.continuous_current_a != null && String(formValue.continuous_current_a).trim() !== '') {
      notesParts.push(`Длительно-допустимый ток, А: ${String(formValue.continuous_current_a).trim()}`);
    }
    if (formValue.arrester_type != null && String(formValue.arrester_type).trim() !== '') {
      notesParts.push(`Тип разрядника: ${String(formValue.arrester_type).trim()}`);
    }
    const notes: string = notesParts.join('; ');

    const poleIdValue = formValue.pole_id != null && formValue.pole_id !== '' ? Number(formValue.pole_id) : undefined;
    const body = {
      ...(poleIdValue != null ? { pole_id: poleIdValue } : {}),
      name: String(formValue.name || '').trim(),
      equipment_type: String(formValue.equipment_type || '').trim(),
      manufacturer: formValue.manufacturer?.trim() || undefined,
      model: formValue.model?.trim() || undefined,
      serial_number: formValue.serial_number?.trim() || undefined,
      year_manufactured: formValue.year_manufactured != null && formValue.year_manufactured !== '' ? Number(formValue.year_manufactured) : undefined,
      installation_date: formValue.installation_date || undefined,
      condition: formValue.condition || undefined,
      defect: (formValue.defect || '').trim() || null,
      criticality: (formValue.defect || '').trim() && formValue.criticality ? formValue.criticality : null,
      notes: notes || undefined,
      rated_current: isElectricalType && formValue.rated_current != null && formValue.rated_current !== '' ? Number(formValue.rated_current) : undefined,
      i_th: isElectricalType && formValue.i_th != null && formValue.i_th !== '' ? Number(formValue.i_th) : undefined,
      ip_max: isElectricalType && formValue.ip_max != null && formValue.ip_max !== '' ? Number(formValue.ip_max) : undefined,
      t_th: isElectricalType && formValue.t_th != null && formValue.t_th !== '' ? Number(formValue.t_th) : undefined,
      normal_open: isElectricalType ? true : undefined,
      retained: isElectricalType ? true : undefined,
      identified_object_description: (formValue.identified_object_description || '').trim() || undefined,
      nameplate: (formValue.nameplate || '').trim() || undefined,
      psr_subtype:
        formValue.equipment_type === 'disconnector' || formValue.equipment_type === 'grounding_switch'
          ? (formValue.psr_subtype || undefined)
          : undefined,
      installation_display_name: isElectricalType ? 'ЛЭП' : undefined,
      tm_code: (formValue.tm_code || '').trim() || undefined,
      object_subtype: (formValue.object_subtype || '').trim() || undefined,
      pole_count:
        formValue.equipment_type === 'breaker' || formValue.equipment_type === 'recloser'
          ? 2
          : (formValue.equipment_type === 'surge_arrester' ? undefined : 1),
      parent_object_ref: (formValue.parent_object_ref || '').trim() || undefined,
      parent_main_equipment_pole_ref: (formValue.parent_main_equipment_pole_ref || '').trim() || undefined,
      nominal_voltage_kv: formValue.nominal_voltage != null && formValue.nominal_voltage !== '' ? Number(formValue.nominal_voltage) : undefined,
      nominal_breaking_current_ka: isElectricalType &&
        formValue.nominal_breaking_current_ka != null && formValue.nominal_breaking_current_ka !== ''
          ? Number(formValue.nominal_breaking_current_ka)
          : undefined,
      own_trip_time_sec: isElectricalType &&
        formValue.own_trip_time_sec != null && formValue.own_trip_time_sec !== ''
          ? Number(formValue.own_trip_time_sec)
          : undefined,
      emergency_current_a: isElectricalType &&
        formValue.emergency_current_a != null && formValue.emergency_current_a !== ''
          ? Number(formValue.emergency_current_a)
          : undefined,
      continuous_current_a: isElectricalType &&
        formValue.continuous_current_a != null && formValue.continuous_current_a !== ''
          ? Number(formValue.continuous_current_a)
          : undefined,
      arrester_type:
        formValue.equipment_type === 'surge_arrester'
          ? ((formValue.arrester_type || '').trim() || undefined)
          : undefined,
      card_comment: serializeCardCommentMessages(this.equipmentCardCommentMessages) || undefined,
      card_comment_attachment:
        this.equipmentAttachments.length > 0 ? JSON.stringify(this.equipmentAttachments) : undefined
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

  private finishPoleSave(pole: Pole, message: string, hint: string): void {
    this.isSubmitting = false;
    this.snackBar.open(message + hint, 'Закрыть', {
      duration: this.isEditMode && this.showBranchChoice ? 6000 : 3000,
    });
    this.mapService.refreshData();
    this.apiService
      .createChangeLogEntry({
        source: 'web',
        action: this.isEditMode ? 'update' : 'create',
        entity_type: 'pole',
        entity_id: pole.id,
        payload: { name: pole.pole_number, mrid: pole.mrid },
      })
      .subscribe({ error: () => {} });
    this.dialogRef.close({ success: true, pole });
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
      construction: formValue.construction?.trim() || undefined,
      rated_voltage: normalizeNumber(formValue.rated_voltage),
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
        const panel = this.poleEquipmentPanel;
        const afterEquipment$ = panel ? panel.persistAll(pole.id) : of(void 0);
        afterEquipment$.subscribe({
          next: () => this.finishPoleSave(pole, message, hint),
          error: () => {
            this.snackBar.open(
              message + ', но не всё оборудование удалось сохранить',
              'Закрыть',
              { duration: 5000 },
            );
            this.finishPoleSave(pole, message, hint);
          },
        });
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

  /** Подпись поля «отпайка»: Магистраль или отпайка от опоры X — отпайка N */
  get newTapBranchOptionLabel(): string {
    const id = this.data?.tapPoleId;
    if (id == null) {
      return 'Новая отпайка';
    }
    const p = this.tapPolesInLine.find(x => x.id === id);
    return `Новая отпайка от ${p?.pole_number ?? 'опора ' + id}`;
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
    return tb ? tb.label : 'Отпайка';
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
    if (formValue.region_uid?.trim()) {
      powerLineData.region_uid = formValue.region_uid.trim();
    }
    if (formValue.dispatcher_name?.trim()) {
      powerLineData.dispatcher_name = formValue.dispatcher_name.trim();
    }
    if (formValue.balance_ownership?.trim()) {
      powerLineData.balance_ownership = formValue.balance_ownership.trim();
    }
    if (formValue.parent_object_ref?.trim()) {
      powerLineData.parent_object_ref = formValue.parent_object_ref.trim();
    }
    if (formValue.alcs_ref?.trim()) {
      powerLineData.alcs_ref = formValue.alcs_ref.trim();
    }
    if (formValue.status) {
      powerLineData.status = formValue.status;
    }
    if (formValue.description?.trim()) {
      powerLineData.description = formValue.description.trim();
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

