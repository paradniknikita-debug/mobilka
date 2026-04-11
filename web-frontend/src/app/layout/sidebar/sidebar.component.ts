import { Component, OnInit, OnDestroy, ViewChild, ChangeDetectorRef } from '@angular/core';
import { MapService } from '../../core/services/map.service';
import { MapData } from '../../core/services/map.service';
import { GeoJSONFeature } from '../../core/models/geojson.model';
import { Subject } from 'rxjs';
import { takeUntil, debounceTime } from 'rxjs/operators';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatMenuTrigger, MatMenu } from '@angular/material/menu';
import { Overlay } from '@angular/cdk/overlay';
import { DeleteObjectDialogComponent, DeleteObjectData } from '../../features/map/delete-object-dialog/delete-object-dialog.component';
import { CreateObjectDialogComponent } from '../../features/map/create-object-dialog/create-object-dialog.component';
import { CreateSpanDialogComponent } from '../../features/map/create-span-dialog/create-span-dialog.component';
import { CreateSegmentDialogComponent } from '../../features/map/create-segment-dialog/create-segment-dialog.component';
import { SegmentCardDialogComponent, SegmentCardDialogData } from '../../features/map/segment-card-dialog/segment-card-dialog.component';
import { EditPowerLineDialogComponent } from '../../features/map/edit-power-line-dialog/edit-power-line-dialog.component';
import { RebuildTopologyDialogComponent } from '../../features/map/rebuild-topology-dialog/rebuild-topology-dialog.component';
import { ApiService } from '../../core/services/api.service';
import { PowerLine } from '../../core/models/power-line.model';
import { Equipment } from '../../core/models/equipment.model';

// Структура данных для иерархичного дерева
interface PowerLineTreeItem {
  powerLine: GeoJSONFeature;
  segments: Array<{
    segmentId: number | null;
    segmentName: string | null;
    branchType: string | null;
    poles: GeoJSONFeature[];
    spans: GeoJSONFeature[];
  }>;
  allPoles: GeoJSONFeature[];
  polesWithoutSegment: GeoJSONFeature[];
  spansWithoutSegment: GeoJSONFeature[];
}

/** Элемент автодополнения поиска: по имени и UID */
export interface TreeSearchSuggestion {
  type: 'power_line' | 'segment' | 'pole' | 'span';
  label: string;
  item: PowerLineTreeItem;
  segment?: { segmentId: number | null; segmentName: string | null; branchType?: string | null; poles: GeoJSONFeature[]; spans: GeoJSONFeature[] };
  pole?: GeoJSONFeature;
  span?: GeoJSONFeature;
}

@Component({
  selector: 'app-sidebar',
  templateUrl: './sidebar.component.html',
  styleUrls: ['./sidebar.component.scss']
})
export class SidebarComponent implements OnInit, OnDestroy {
  @ViewChild('menuTrigger', { static: false }) menuTrigger!: MatMenuTrigger;
  
  mapData: MapData | null = null;
  isLoading = true;
  private destroy$ = new Subject<void>();
  private powerLinesWithPolesCache: PowerLineTreeItem[] | null = null;

  constructor(
    private mapService: MapService,
    private dialog: MatDialog,
    private cdr: ChangeDetectorRef,
    private snackBar: MatSnackBar,
    private apiService: ApiService
  ) {}

  ngOnInit(): void {
    this.loadMapData();
    
    // Подписываемся на обновления данных
    this.mapService.dataRefresh
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        this.loadMapData();
      });

    // При клике на опору на карте — раскрываем дерево до этой опоры
    this.mapService.requestSelectPoleInTree$
      .pipe(takeUntil(this.destroy$))
      .subscribe(({ lineId, segmentId, poleId }) => {
        this.expandedPowerLines.add(lineId);
        if (segmentId != null) {
          const segKey = this.expandSegmentKeyForLine(lineId, segmentId);
          if (segKey) {
            this.expandedSegments.add(segKey);
          }
        }
        this.expandedPolesFolders.add(`${lineId}-all-poles`);
        this.selectedPoleIdFromMap = poleId;
        this.cdr.detectChanges();
      });

    // При клике на подстанцию на карте — выделяем её в дереве
    this.mapService.requestSelectSubstationInTree$
      .pipe(takeUntil(this.destroy$))
      .subscribe(({ substationId }) => {
        this.selectedSubstationIdFromMap = substationId;
        this.cdr.detectChanges();
      });

    this.searchInput$
      .pipe(debounceTime(250), takeUntil(this.destroy$))
      .subscribe(q => {
        this.treeSearchSuggestions = q.length < 1 ? [] : this.collectSearchSuggestions(q);
        this.cdr.detectChanges();
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  loadMapData(): void {
    this.isLoading = true;
    this.mapService.loadAllMapData()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (data) => {
          this.mapData = data;
          // Сбрасываем кэш при обновлении данных
          this.powerLinesWithPolesCache = null;
          this.isLoading = false;
          // Загружаем оборудование для дерева (группировка по опорам)
          this.loadAllEquipmentForTree();
        },
        error: (error) => {
          const detail = error?.error?.detail || error?.message || String(error);
          console.error('Ошибка загрузки данных для sidebar:', error);
          if (typeof detail === 'string') console.error('Детали:', detail);
          else if (detail) console.error('Детали:', JSON.stringify(detail));
          this.isLoading = false;
        }
      });
  }

  // ===== Оборудование для дерева по опорам =====

  allEquipment: Equipment[] = [];
  private equipmentByPoleId = new Map<number, Equipment[]>();
  contextMenuEquipment: Equipment | null = null;

  private loadAllEquipmentForTree(): void {
    this.apiService.getAllEquipment().pipe(takeUntil(this.destroy$)).subscribe({
      next: (list: Equipment[]) => {
        this.allEquipment = Array.isArray(list) ? list : [];
        const map = new Map<number, Equipment[]>();
        for (const eq of this.allEquipment) {
          if (!eq || typeof eq !== 'object' || eq.pole_id == null) continue;
          const arr = map.get(eq.pole_id) || [];
          arr.push(eq);
          map.set(eq.pole_id, arr);
        }
        this.equipmentByPoleId = map;
        this.cdr.detectChanges();
      },
      error: () => {
        // Не критично для работы дерева
      }
    });
  }

  getPoleEquipment(poleId: number): Equipment[] {
    const list = this.equipmentByPoleId.get(poleId) ?? [];
    return list.filter(
      eq =>
        !this.isFoundationEquipment(eq) && this.isCommutationEquipmentForTree(eq)
    );
  }

  /** Фундамент не показываем в дереве объектов — только в карточке опоры. */
  private isFoundationEquipment(eq: Equipment): boolean {
    const t = (eq.equipment_type || '').toLowerCase().trim();
    return t === 'фундамент' || t === 'foundation';
  }

  /**
   * В дереве объектов — только коммутационная аппаратура (как на карте: выключатели,
   * разъединители, ЗН, реклоузеры, разрядники). Без траверсов, изоляторов, грозоотводов и т.п.
   */
  private isCommutationEquipmentForTree(eq: Equipment): boolean {
    return this.getEquipmentIconKey(eq) != null;
  }

  getPoleEquipmentByType(poleId: number, type: 'breaker' | 'disconnector' | 'recloser' | 'grounding_switch' | 'surge_arrester'): Equipment[] {
    const list = this.getPoleEquipment(poleId);
    return list.filter(eq => (eq.equipment_type || '').toLowerCase() === type);
  }

  /** Ключ иконки оборудования для дерева (те же типы, что на карте). */
  getEquipmentIconKey(eq: Equipment): string | null {
    const t = (eq.equipment_type || '').toLowerCase().trim();
    const n = (eq.name || '').toLowerCase();
    if (t.includes('реклоузер') || n.includes('реклоузер') || t === 'recloser' || n.includes('recloser')) return 'recloser';
    if (t.includes('выключател') || n.includes('выключател') || t === 'breaker' || n.includes('breaker')) return 'breaker';
    if (t.includes('зн') || t.includes('заземлен') || t === 'grounding_switch' || t.includes('grounding')) return 'zn';
    if (t.includes('разъединитель') || t.includes('разъеденитель') || t.includes('разъедин') || t === 'disconnector' || t.includes('disconnector')) return 'disconnector';
    if (
      t.includes('разрядник') ||
      n.includes('разряд') ||
      n.includes('опн') ||
      t.includes('опн') ||
      t.includes('opn') ||
      n.includes('opn') ||
      t === 'surge_arrester' ||
      t.includes('arrester') ||
      t.includes('surge') ||
      n.includes('arrester') ||
      n.includes('surge')
    ) {
      return 'arrester';
    }
    const noIcon = ['фундамент', 'foundation', 'изолятор', 'траверс', 'грозоотвод', 'грозотрос'];
    if (noIcon.some(x => t.includes(x))) return null;
    return null;
  }

  /** Подпись в дереве без дублирования «ОПН» + «ОПН-10». */
  equipmentTreeLabel(eq: Equipment): string {
    const t = (eq.equipment_type || '').trim();
    const n = (eq.name || '').trim();
    if (!n && !t) return 'Оборудование';
    if (!n) return t;
    if (!t) return n;
    const tl = t.toLowerCase();
    const nl = n.toLowerCase();
    if (nl.startsWith(tl) || (tl.length >= 2 && nl.includes(tl))) return n;
    return `${n} (${t})`;
  }

  /** Путь к SVG-ассету оборудования (те же файлы, что на карте). */
  getEquipmentAssetPath(iconKey: string): string {
    const sub: Record<string, string> = {
      recloser: 'recloser/recloser.svg',
      breaker: 'breaker/breaker.svg',
      zn: 'zn/zn.svg',
      disconnector: 'disconnector/disconnector.svg',
      arrester: 'arrester/arrester.svg'
    };
    return sub[iconKey] ? `assets/equipment/${sub[iconKey]}` : '';
  }

  /** Название типа оборудования по CIM-модели (для дерева и формирования CIM). */
  getEquipmentCimName(eq: Equipment): string {
    const key = this.getEquipmentIconKey(eq);
    if (key === 'zn') return 'ground_disconnector';
    if (key === 'arrester') return 'surge_arrester';
    if (key === 'breaker') return 'breaker';
    if (key === 'disconnector') return 'disconnector';
    if (key === 'recloser') return 'recloser';
    return eq.equipment_type || 'equipment';
  }

  get powerLinesFeatures(): GeoJSONFeature[] {
    return this.mapData?.powerLines?.features || [];
  }

  get substationsFeatures(): GeoJSONFeature[] {
    return this.mapData?.substations?.features || [];
  }

  get polesFeatures(): GeoJSONFeature[] {
    return this.mapData?.poles?.features || [];
  }

  get tapsFeatures(): GeoJSONFeature[] {
    return this.mapData?.taps?.features || [];
  }

  get spansFeatures(): GeoJSONFeature[] {
    return this.mapData?.spans?.features || [];
  }

  // Группировка опор по ЛЭП (line_id в GeoJSON; fallback на power_line_id для совместимости)
  getPolesByPowerLine(lineId: number): GeoJSONFeature[] {
    const pid = Number(lineId);
    const poles = this.polesFeatures.filter(feature => {
      const plId = feature.properties['line_id'] ?? feature.properties['power_line_id'];
      if (plId == null) return false;
      return Number(plId) === pid;
    });
    return this.sortPolesByNumber(poles);
  }

  /** Фича для дерева: из GeoJSON с геометрией, если есть, иначе минимальная из модели ЛЭП. */
  private powerLineToTreeFeature(pl: PowerLine): GeoJSONFeature {
    const fromGeo = this.powerLinesFeatures.find(f => f.properties['id'] === pl.id);
    if (fromGeo?.geometry?.coordinates) {
      return fromGeo;
    }
    return {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [0, 0] },
      properties: {
        id: pl.id,
        name: pl.name ?? '',
        voltage_level: pl.voltage_level ?? 0,
        status: pl.status ?? 'active'
      }
    };
  }

  // Получение всех ЛЭП с сегментами и опорами (по списку GET /power-lines, как во Flutter)
  getPowerLinesWithSegmentsAndPoles(): PowerLineTreeItem[] {
    if (!this.mapData) {
      return [];
    }
    const list = this.mapData.powerLinesList;
    if (!list?.length) {
      return [];
    }

    if (this.powerLinesWithPolesCache !== null) {
      return this.powerLinesWithPolesCache;
    }

    const result: PowerLineTreeItem[] = [];
    for (const pl of list) {
      const lineId = pl.id;
      const powerLine = this.powerLineToTreeFeature(pl);
      const linePoles = this.getPolesByPowerLine(lineId);
      const allSpans = this.spansFeatures.filter(f => {
        const plId = f.properties['line_id'] ?? f.properties['power_line_id'];
        return plId != null && Number(plId) === Number(lineId);
      });

      const segmentsMap = new Map<number | string, {poles: GeoJSONFeature[], spans: GeoJSONFeature[]}>();
      const polesWithoutSegment: GeoJSONFeature[] = [];
      const spansWithoutSegment: GeoJSONFeature[] = [];

      linePoles.forEach(pole => {
        const segmentId = pole.properties['segment_id'];
        if (segmentId != null) {
          const key = segmentId;
          if (!segmentsMap.has(key)) {
            segmentsMap.set(key, {poles: [], spans: []});
          }
          segmentsMap.get(key)!.poles.push(pole);
        } else {
          polesWithoutSegment.push(pole);
        }
      });

      allSpans.forEach((span: GeoJSONFeature) => {
        const segmentId = span.properties['segment_id'] ?? span.properties['acline_segment_id'];
        if (segmentId != null) {
          const key = segmentId;
          if (!segmentsMap.has(key)) {
            segmentsMap.set(key, {poles: [], spans: []});
          }
          segmentsMap.get(key)!.spans.push(span);
        } else {
          spansWithoutSegment.push(span);
        }
      });

      const segments: Array<{
        segmentId: number | null;
        segmentName: string | null;
        branchType: string | null;
        poles: GeoJSONFeature[];
        spans: GeoJSONFeature[];
      }> = [];
      segmentsMap.forEach((data, segmentId) => {
        const segmentName = data.poles[0]?.properties['segment_name'] ??
          data.spans[0]?.properties['segment_name'] ?? null;
        const branchType = data.poles[0]?.properties['branch_type'] ??
          data.spans[0]?.properties['branch_type'] ?? null;
        segments.push({
          segmentId: typeof segmentId === 'string' ? parseInt(segmentId, 10) : segmentId,
          segmentName,
          branchType,
          poles: data.poles,
          spans: data.spans
        });
      });
      segments.sort((a, b) => {
        if (a.segmentId === null) return 1;
        if (b.segmentId === null) return -1;
        return a.segmentId - b.segmentId;
      });

      // Опоры внутри линии сортируем по номеру/алфавиту, чтобы в папке «Опоры» не было хаоса
      const allPoles = this.sortPolesByNumber([
        ...segments.flatMap(s => s.poles),
        ...polesWithoutSegment
      ]);
      result.push({
        powerLine,
        segments,
        allPoles,
        polesWithoutSegment,
        spansWithoutSegment
      });
    }

    this.powerLinesWithPolesCache = result;
    return result;
  }

  /** Сортировка опор по номеру (естественная: 1, 2, 3, 10; учитывает буквы). */
  private sortPolesByNumber(poles: GeoJSONFeature[]): GeoJSONFeature[] {
    if (!poles || poles.length <= 1) {
      return poles;
    }
    const collator = new Intl.Collator('ru', { numeric: true, sensitivity: 'base' });
    return [...poles].sort((a, b) => {
      const aVal = a.properties['pole_number'] ?? a.properties['sequence_number'] ?? '';
      const bVal = b.properties['pole_number'] ?? b.properties['sequence_number'] ?? '';
      return collator.compare(String(aVal ?? ''), String(bVal ?? ''));
    });
  }
  
  // Старый метод для обратной совместимости (можно удалить, если не используется)
  getPowerLinesWithPoles(): Array<{powerLine: GeoJSONFeature, poles: GeoJSONFeature[]}> {
    const treeItems = this.getPowerLinesWithSegmentsAndPoles();
    return treeItems.map(item => ({
      powerLine: item.powerLine,
      poles: [
        ...item.segments.flatMap(s => s.poles),
        ...item.polesWithoutSegment
      ]
    }));
  }

  // Состояния раскрытия для дерева
  expandedPowerLines = new Set<number>();
  expandedSegments = new Set<string>();
  expandedPolesFolders = new Set<string>();
  /** ID опоры, выбранной по клику на карте (для подсветки в дереве) */
  selectedPoleIdFromMap: number | null = null;
  /** ID подстанции, выбранной по клику на карте (для подсветки в дереве) */
  selectedSubstationIdFromMap: number | null = null;

  /** Подпись участка в формате «оп.4-оп.5»: убираем префикс «Опора » из номеров опор */
  shortPoleLabelForSegment(s: string | number | undefined): string {
    if (s == null) return '?';
    const str = String(s).trim();
    if (str.toLowerCase().startsWith('опора')) return str.slice(5).trim() || str;
    return str;
  }

  /**
   * Конец участка в дереве: номера опор — с префиксом «оп.»; подстанции и текстовые имена — без «оп.»
   * (иначе «старт» → «оп.старт»).
   */
  private segmentEndpointLabelForTree(raw: string | null | undefined): string {
    if (raw == null || raw === '') return '';
    const t = String(raw).trim();
    if (/^\d+$/.test(t)) {
      return `оп.${t}`;
    }
    if (/^\d+\s*\/\s*\d+/i.test(t) || /^\d+\/\d+/i.test(t)) {
      return `оп.${t.replace(/\s+/g, '')}`;
    }
    return t;
  }

  /**
   * Подпись участка: «оп.1-оп.3» или «оп.3 - тптыв» (конец на ПС: to_pole_id у пролёта null).
   * Раньше при ПС в конце отпайки last не находился, срабатывал fallback по списку опор сегмента
   * (часто только отпаечная опора) — получалось «оп.3-оп.3».
   */
  getSegmentDisplayName(item: PowerLineTreeItem, segment: { segmentId: number | null; segmentName: string | null; poles: GeoJSONFeature[]; spans?: GeoJSONFeature[] }): string {
    // Имя участка с бэкенда (ACLineSegment): конец может быть именем оборудования («РЛНД-10»), а не номером опоры.
    const rawFromApi = (segment.segmentName || '').trim();
    if (rawFromApi) {
      return this.normalizeSegmentNameFromApi(rawFromApi);
    }
    const spans = segment.spans ?? [];
    if (spans.length >= 1) {
      const sortedSpans = [...spans].sort((a, b) => (a.properties['sequence_number'] ?? 0) - (b.properties['sequence_number'] ?? 0));
      const firstSpan = sortedSpans[0];
      const lastSpan = sortedSpans[sortedSpans.length - 1];
      const fromPoleId = firstSpan.properties['from_pole_id'];
      const toPoleId = lastSpan.properties['to_pole_id'];
      const allPoles = item.allPoles ?? [];
      const fromPole = fromPoleId != null ? allPoles.find((p: GeoJSONFeature) => p.properties['id'] === fromPoleId) : undefined;
      const toPole = toPoleId != null ? allPoles.find((p: GeoJSONFeature) => p.properties['id'] === toPoleId) : undefined;
      let first = fromPole
        ? this.shortPoleLabelForSegment(fromPole.properties['pole_number'] ?? fromPole.properties['sequence_number'])
        : this.startLabelFromSpanNumber(String(firstSpan.properties['span_number'] ?? ''));
      let last: string | null = toPole
        ? this.shortPoleLabelForSegment(toPole.properties['pole_number'] ?? toPole.properties['sequence_number'])
        : null;
      if (last == null && toPoleId == null) {
        last = this.endLabelFromSpanNumber(String(lastSpan.properties['span_number'] ?? ''));
      }
      if (first != null && last != null) {
        const a = this.segmentEndpointLabelForTree(first);
        const b = this.segmentEndpointLabelForTree(last);
        if (toPoleId == null) {
          return `${a} - ${b}`;
        }
        return `${a}-${b}`;
      }
    }
    const poles = segment.poles || [];
    if (poles.length === 0) return `Участок ${segment.segmentId ?? '?'}`;
    const sorted = [...poles].sort((a, b) => (a.properties['sequence_number'] ?? 0) - (b.properties['sequence_number'] ?? 0));
    const first = this.shortPoleLabelForSegment(sorted[0].properties['pole_number'] ?? sorted[0].properties['sequence_number']);
    const last = this.shortPoleLabelForSegment(sorted[sorted.length - 1].properties['pole_number'] ?? sorted[sorted.length - 1].properties['sequence_number']);
    return `${this.segmentEndpointLabelForTree(first)}-${this.segmentEndpointLabelForTree(last)}`;
  }

  /**
   * Имя участка с API / GeoJSON: «Опора 3» → «оп.3»; «Опора старт» → «старт» (не «оп.старт»).
   */
  private normalizeSegmentNameFromApi(name: string): string {
    let t = name
      .replace(/\bОпора\s+(?=\d)/gi, 'оп.')
      .replace(/\bОпора\s+([^\d\s][^\n\r-]*)/gi, '$1')
      .replace(/\s*-\s*/g, ' - ')
      .trim();
    t = t.replace(/\bоп\.\s*(?=[^\d\n\r])/gi, ''); // на случай «оп. старт» от старого бэкенда
    return t.replace(/\s+/g, ' ').trim();
  }

  /** «Пролёт оп.3-оп.3/1» → номер начала для подписи: «3» (даёт «оп.3») */
  private startLabelFromSpanNumber(spanNumber: string): string | null {
    const s = spanNumber.replace(/^\s*пролёт\s+/i, '').trim();
    const dash = s.indexOf('-');
    if (dash < 0) {
      return null;
    }
    let head = s.slice(0, dash).trim();
    if (head.toLowerCase().startsWith('оп.')) {
      head = head.slice(3).trim();
    } else if (head.toLowerCase().startsWith('опора')) {
      head = head.slice(5).trim();
    }
    return head || null;
  }

  /** «Пролёт оп.3/3-тптыв» или «оп.3/3-тптыв» → «тптыв» (конец на подстанции) */
  private endLabelFromSpanNumber(spanNumber: string): string | null {
    const s = spanNumber.replace(/^\s*пролёт\s+/i, '').trim();
    const dash = s.lastIndexOf('-');
    if (dash < 0) {
      return null;
    }
    return s.slice(dash + 1).trim() || null;
  }

  /** Подпись пролёта в формате «Пролёт 1-2» (без суффикса «(отпайка)») */
  getSpanDisplayName(span: GeoJSONFeature): string {
    const sn = (span.properties['span_number'] ?? '')?.toString().trim();
    const normalized = sn ? sn.replace(/^пролёт\s+/i, '') : '';
    return 'Пролёт ' + (normalized || 'N/A');
  }

  /**
   * История для кнопок «Назад»/«Вперёд».
   * Сейчас сохраняется только состояние раскрытия дерева (какие линии/участки/папки развёрнуты).
   * Отмена созданий/удалений/редактирований (например, «создал опору → Назад → опора удалилась»)
   * не реализована: для этого нужен журнал действий (create/update/delete с типом и id сущности)
   * и при «Назад» — выполнять обратное действие (delete созданного, restore для update, re-create для delete),
   * желательно с кэшем данных и согласованием с бэкендом.
   */
  private treeUndoStack: Array<{ lines: Set<number>; segments: Set<string>; folders: Set<string> }> = [];
  private treeRedoStack: Array<{ lines: Set<number>; segments: Set<string>; folders: Set<string> }> = [];
  treeSearchQuery = '';
  /** Подсказки при вводе (поиск по имени и UID) */
  treeSearchSuggestions: TreeSearchSuggestion[] = [];
  private searchInput$ = new Subject<string>();

  private saveTreeStateForUndo(): void {
    this.treeRedoStack = [];
    this.treeUndoStack.push({
      lines: new Set(this.expandedPowerLines),
      segments: new Set(this.expandedSegments),
      folders: new Set(this.expandedPolesFolders)
    });
    if (this.treeUndoStack.length > 50) this.treeUndoStack.shift();
  }

  treeUndo(): void {
    if (!this.canTreeUndo()) return;
    this.treeRedoStack.push({
      lines: new Set(this.expandedPowerLines),
      segments: new Set(this.expandedSegments),
      folders: new Set(this.expandedPolesFolders)
    });
    const prev = this.treeUndoStack.pop()!;
    this.expandedPowerLines = prev.lines;
    this.expandedSegments = prev.segments;
    this.expandedPolesFolders = prev.folders;
    this.cdr.detectChanges();
  }

  treeRedo(): void {
    if (!this.canTreeRedo()) return;
    this.treeUndoStack.push({
      lines: new Set(this.expandedPowerLines),
      segments: new Set(this.expandedSegments),
      folders: new Set(this.expandedPolesFolders)
    });
    const next = this.treeRedoStack.pop()!;
    this.expandedPowerLines = next.lines;
    this.expandedSegments = next.segments;
    this.expandedPolesFolders = next.folders;
    this.cdr.detectChanges();
  }

  canTreeUndo(): boolean {
    return this.treeUndoStack.length > 0;
  }

  canTreeRedo(): boolean {
    return this.treeRedoStack.length > 0;
  }

  treeCollapseAll(): void {
    this.saveTreeStateForUndo();
    this.expandedPowerLines.clear();
    this.expandedSegments.clear();
    this.expandedPolesFolders.clear();
    this.cdr.detectChanges();
  }

  treeSearch(): void {
    const q = (this.treeSearchQuery || '').trim().toLowerCase();
    if (!q) return;
    const suggestions = this.collectSearchSuggestions(q);
    if (suggestions.length > 0) {
      this.applySearchResult(suggestions[0]);
    } else {
      this.snackBar.open('Ничего не найдено', 'Закрыть', { duration: 2000 });
    }
  }

  onSearchInput(): void {
    this.searchInput$.next((this.treeSearchQuery || '').trim().toLowerCase());
  }

  /** Собирает до 15 подсказок по запросу (по имени и UID). */
  collectSearchSuggestions(q: string): TreeSearchSuggestion[] {
    if (!q) return [];
    const items = this.getPowerLinesWithSegmentsAndPoles();
    const out: TreeSearchSuggestion[] = [];
    const limit = 15;
    for (const item of items) {
      const plId = item.powerLine.properties['id'];
      const name = (item.powerLine.properties['name'] || '').toString().toLowerCase();
      const mrid = (item.powerLine.properties['mrid'] || '').toString().toLowerCase();
      if (name.includes(q) || mrid.includes(q)) {
        out.push({ type: 'power_line', label: (item.powerLine.properties['name'] || 'ЛЭП') + ` (${item.powerLine.properties['voltage_level']} кВ)`, item });
        if (out.length >= limit) return out;
      }
      for (const seg of item.segments) {
        const segName = (seg.segmentName || '').toString().toLowerCase();
        if (segName.includes(q)) {
          out.push({ type: 'segment', label: seg.segmentName || `Участок ${seg.segmentId}`, item, segment: seg });
          if (out.length >= limit) return out;
        }
        for (const pole of seg.poles) {
          const pName = (pole.properties['pole_number'] || '').toString().toLowerCase();
          const pMrid = (pole.properties['mrid'] || '').toString().toLowerCase();
          if (pName.includes(q) || pMrid.includes(q)) {
            out.push({ type: 'pole', label: (pole.properties['pole_number'] || 'Опора') + (pMrid ? ` · ${pole.properties['mrid']}` : ''), item, segment: seg, pole });
            if (out.length >= limit) return out;
          }
        }
        for (const span of seg.spans) {
          const sName = (span.properties['span_number'] || '').toString().toLowerCase();
          const sMrid = (span.properties['mrid'] || '').toString().toLowerCase();
          if (sName.includes(q) || sMrid.includes(q)) {
            out.push({ type: 'span', label: (span.properties['span_number'] || 'Пролёт') + (sMrid ? ` · ${span.properties['mrid']}` : ''), item, segment: seg, span });
            if (out.length >= limit) return out;
          }
        }
      }
      for (const pole of item.allPoles) {
        const pName = (pole.properties['pole_number'] || '').toString().toLowerCase();
        const pMrid = (pole.properties['mrid'] || '').toString().toLowerCase();
        if (pName.includes(q) || pMrid.includes(q)) {
          out.push({ type: 'pole', label: (pole.properties['pole_number'] || 'Опора') + (pMrid ? ` · ${pole.properties['mrid']}` : ''), item, pole });
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }

  applySearchResult(s: TreeSearchSuggestion): void {
    const zoomPole = 18;
    const zoomSpan = 17;
    const plId = s.item.powerLine.properties['id'];
    this.expandedPowerLines.add(plId);
    if (s.segment) {
      const segIdx = s.item.segments.findIndex(
        x => x.segmentId === s.segment!.segmentId && (x.segmentName || '') === (s.segment!.segmentName || '')
      );
      if (segIdx >= 0) {
        this.expandedSegments.add(this.segmentExpandKey(plId, s.segment.segmentId, segIdx));
      }
    }
    this.expandedPolesFolders.add(`${plId}-all-poles`);
    if (s.pole) this.selectedPoleIdFromMap = s.pole.properties['id'];
    if (s.type === 'power_line') {
      const bounds = this.getBoundsFromFeatures([s.item.powerLine, ...s.item.allPoles]);
      if (bounds) this.mapService.requestCenterOnFeature('power_line', bounds[0], undefined, undefined, bounds);
    } else if (s.type === 'segment' && s.segment) {
      const bounds = this.getBoundsFromFeatures([...s.segment.poles, ...s.segment.spans]);
      if (bounds) this.mapService.requestCenterOnFeature('segment', bounds[0], undefined, undefined, bounds);
    } else if (s.type === 'pole' && s.pole) {
      const coords = this.getPointCoordinates(s.pole);
      if (coords) this.mapService.requestCenterOnFeature('pole', [coords.lat, coords.lng], zoomPole);
    } else if (s.type === 'span' && s.span) {
      const center = this.getLineCenter(s.span);
      if (center) this.mapService.requestCenterOnFeature('span', [center.lat, center.lng], zoomSpan);
    }
    this.treeSearchSuggestions = [];
    this.cdr.detectChanges();
  }

  /** Собирает bbox по геометрии фич (Point и LineString). Возвращает [[minLat, minLng], [maxLat, maxLng]] или null. */
  private getBoundsFromFeatures(features: GeoJSONFeature[]): [[number, number], [number, number]] | null {
    const lats: number[] = [];
    const lngs: number[] = [];
    for (const f of features) {
      const g = f.geometry;
      if (!g || !g.coordinates) continue;
      if (g.type === 'Point') {
        const c = g.coordinates as number[];
        if (c.length >= 2) {
          lngs.push(Number(c[0]));
          lats.push(Number(c[1]));
        }
      } else if (g.type === 'LineString') {
        const coords = g.coordinates as number[][];
        for (const c of coords) {
          if (c.length >= 2) {
            lngs.push(Number(c[0]));
            lats.push(Number(c[1]));
          }
        }
      }
    }
    if (lats.length === 0 || lngs.length === 0) return null;
    const minLat = Math.min(...lats);
    const maxLat = Math.max(...lats);
    const minLng = Math.min(...lngs);
    const maxLng = Math.max(...lngs);
    const pad = 0.0001;
    return [[minLat - pad, minLng - pad], [maxLat + pad, maxLng + pad]];
  }

  private getPointCoordinates(feature: GeoJSONFeature): { lat: number; lng: number } | null {
    const g = feature?.geometry;
    if (!g || g.type !== 'Point') return null;
    const c = g.coordinates as number[];
    if (c.length < 2) return null;
    return { lng: Number(c[0]), lat: Number(c[1]) };
  }

  private getLineCenter(feature: GeoJSONFeature): { lat: number; lng: number } | null {
    const g = feature?.geometry;
    if (!g || g.type !== 'LineString') return null;
    const coords = g.coordinates as number[][];
    if (!coords.length) return null;
    // Геометрическая середина пролёта (центр между опорами), не индекс в массиве
    let sumLng = 0, sumLat = 0;
    for (const c of coords) {
      if (c.length >= 2) {
        sumLng += Number(c[0]);
        sumLat += Number(c[1]);
      }
    }
    const n = coords.length;
    if (n === 0) return null;
    return { lng: sumLng / n, lat: sumLat / n };
  }

  togglePowerLine(lineId: number): void {
    this.saveTreeStateForUndo();
    if (this.expandedPowerLines.has(lineId)) {
      this.expandedPowerLines.delete(lineId);
    } else {
      this.expandedPowerLines.add(lineId);
    }
  }

  isPowerLineExpanded(lineId: number): boolean {
    return this.expandedPowerLines.has(lineId);
  }

  /** Уникальный ключ раскрытия участка в дереве (несколько участков с одним segmentId/null не должны сливаться). */
  segmentExpandKey(lineId: number, segmentId: number | null, segmentIndex: number): string {
    return `${lineId}-${segmentId ?? 'null'}-${segmentIndex}`;
  }

  private expandSegmentKeyForLine(lineId: number, segmentId: number | null): string | null {
    const items = this.getPowerLinesWithSegmentsAndPoles();
    const item = items.find(i => Number(i.powerLine.properties['id']) === Number(lineId));
    if (!item) {
      return null;
    }
    const idx = item.segments.findIndex(s => s.segmentId === segmentId);
    if (idx < 0) {
      return null;
    }
    return this.segmentExpandKey(lineId, segmentId, idx);
  }

  toggleSegment(lineId: number, segmentId: number | null, segmentIndex: number): void {
    this.saveTreeStateForUndo();
    const key = this.segmentExpandKey(lineId, segmentId, segmentIndex);
    if (this.expandedSegments.has(key)) {
      this.expandedSegments.delete(key);
    } else {
      this.expandedSegments.add(key);
    }
  }

  isSegmentExpanded(lineId: number, segmentId: number | null, segmentIndex: number): boolean {
    return this.expandedSegments.has(this.segmentExpandKey(lineId, segmentId, segmentIndex));
  }

  togglePolesFolder(lineId: number, folderKey: string): void {
    this.saveTreeStateForUndo();
    const key = `${lineId}-${folderKey}`;
    if (this.expandedPolesFolders.has(key)) {
      this.expandedPolesFolders.delete(key);
    } else {
      this.expandedPolesFolders.add(key);
    }
  }

  isPolesFolderExpanded(lineId: number, folderKey: string): boolean {
    const key = `${lineId}-${folderKey}`;
    return this.expandedPolesFolders.has(key);
  }

  /** Клик по строке оборудования в дереве: центрируем карту на иконке оборудования, а не на опоре. */
  onEquipmentClick(eq: Equipment, pole: GeoJSONFeature, event: Event): void {
    event.stopPropagation();
    const poleId = pole.properties?.['id'];
    const equipmentId = eq?.id;
    if (poleId != null && equipmentId != null) {
      this.mapService.requestCenterOnEquipment(Number(poleId), Number(equipmentId));
    }
  }

  onFeatureClick(feature: GeoJSONFeature, event?: Event): void {
    if (event) {
      event.stopPropagation();
    }
    
    if (feature.geometry.type === 'Point') {
      const coordinates = feature.geometry.coordinates as number[];
      const lat = coordinates[1];
      const lng = coordinates[0];
      const isPlaceholder = lat === 0 && lng === 0 && !feature.properties['pole_number'] && !feature.properties['dispatcher_name'];
      if (isPlaceholder) {
        return;
      }

      // Если это опора, применяем логику зума и показываем панель свойств опоры (как при клике на карте)
      if (feature.properties['pole_number']) {
        this.mapService.requestCenterOnFeature('pole', [lat, lng], 18);
        this.mapService.requestShowPoleProperties(feature);
        this.selectedPoleIdFromMap = feature.properties['id'] ?? null;
      } else if (feature.properties['dispatcher_name']) {
        this.mapService.requestCenterOnFeature('substation', [lat, lng], 18);
      } else {
        this.mapService.requestCenterOnFeature('point', [lat, lng]);
      }
    } else if (feature.geometry.type === 'LineString') {
      const coordinates = feature.geometry.coordinates as number[][];
      if (coordinates.length > 0) {
        if (feature.properties['span_number']) {
          // Пролёт: зум ~500 м (уровень 17)
          const midIndex = Math.floor(coordinates.length / 2);
          const midCoord = coordinates[midIndex];
          this.mapService.requestCenterOnFeature('span', [midCoord[1], midCoord[0]], 17);
        } else {
          // ЛЭП целиком: подгоняем bounds по линии
          const bounds = this.getBoundsFromFeatures([feature]);
          if (bounds) {
            this.mapService.requestCenterOnFeature('powerLine', bounds[0], undefined, undefined, bounds);
          }
        }
      }
    }
  }

  /** Клик по участку в дереве: центрировать карту на всю линию и выделить участок. */
  onSegmentClick(item: PowerLineTreeItem, segment: { segmentId: number | null; segmentName: string | null; branchType?: string | null; poles: GeoJSONFeature[]; spans: GeoJSONFeature[] }): void {
    const plId = item.powerLine.properties['id'];
    // Зум подгоняем под всю линию (линия + все опоры), участок выделяется на карте
    const bounds = this.getBoundsFromFeatures([item.powerLine, ...item.allPoles]);
    if (bounds) {
      this.mapService.requestSelectSegment(plId, segment.segmentId ?? null, bounds);
    }
  }

  contextMenuPosition = { x: '0px', y: '0px' };
  contextMenuFeature: GeoJSONFeature | null = null;
  contextMenuType: 'powerLine' | 'segment' | 'span' | 'pole' | 'substation' | 'folder' | 'root' | 'equipment' | null = null;
  contextMenuLineId: number | null = null;
  contextMenuSegmentId: number | null = null;

  onFeatureRightClick(feature: GeoJSONFeature, event: MouseEvent, forceType?: 'substation' | 'powerLine'): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuFeature = feature;
    
    // Явный тип из шаблона (подстанция/ЛЭП) имеет приоритет
    if (forceType === 'substation') {
      this.contextMenuType = 'substation';
      this.contextMenuLineId = null;
    } else if (forceType === 'powerLine') {
      this.contextMenuType = 'powerLine';
      this.contextMenuLineId = feature.properties['id'];
    } else if (feature.properties['span_number']) {
      // Пролёт
      this.contextMenuType = 'span';
      this.contextMenuLineId = feature.properties['line_id'] ?? feature.properties['power_line_id'];
      this.contextMenuSegmentId = feature.properties['acline_segment_id'] || feature.properties['segment_id'];
    } else if (feature.properties['pole_number']) {
      // Опора
      this.contextMenuType = 'pole';
      this.contextMenuLineId = feature.properties['line_id'] ?? feature.properties['power_line_id'];
    } else if (feature.properties['name'] && feature.properties['dispatcher_name'] && !feature.properties['code']) {
      // Подстанция (по свойствам)
      this.contextMenuType = 'substation';
      this.contextMenuLineId = null;
    } else if (feature.properties['name'] && !feature.properties['pole_number'] && !feature.properties['tap_number'] && !feature.properties['dispatcher_name']) {
      // ЛЭП
      this.contextMenuType = 'powerLine';
      this.contextMenuLineId = feature.properties['id'];
    } else {
      this.contextMenuType = null;
    }
    
    // Принудительно проверяем изменения и открываем меню
    this.cdr.detectChanges();
    // Используем requestAnimationFrame для гарантии, что DOM обновлён
    requestAnimationFrame(() => {
      setTimeout(() => {
        if (this.menuTrigger) {
          try {
            // Пытаемся получить нативный элемент кнопки и кликнуть по нему
            const element = (this.menuTrigger as any)._element?.nativeElement || 
                          (this.menuTrigger as any)._elementRef?.nativeElement;
            if (element) {
              // Кликаем программно на кнопку
              element.click();
            } else {
              // Если не получилось через click, пытаемся открыть напрямую
              if (this.menuTrigger.menu) {
                this.menuTrigger.openMenu();
              } else {
                console.warn('MatMenuTrigger.menu не инициализирован');
              }
            }
          } catch (error) {
            console.error('Ошибка открытия меню:', error);
          }
        } else {
          console.warn('MatMenuTrigger не найден');
        }
      }, 10);
    });
  }

  onSegmentRightClick(segmentId: number | null, lineId: number, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'segment';
    this.contextMenuSegmentId = segmentId;
    this.contextMenuLineId = lineId;
    this.contextMenuFeature = null;
    
    this.cdr.detectChanges();
    requestAnimationFrame(() => {
      setTimeout(() => {
        if (this.menuTrigger) {
          try {
            const element = (this.menuTrigger as any)._element?.nativeElement ||
              (this.menuTrigger as any)._elementRef?.nativeElement;
            if (element) {
              element.click();
            } else if (this.menuTrigger.menu) {
              this.menuTrigger.openMenu();
            } else {
              console.warn('MatMenuTrigger.menu не инициализирован');
            }
          } catch (error) {
            console.error('Ошибка открытия меню:', error);
          }
        } else {
          console.warn('MatMenuTrigger не найден');
        }
      }, 10);
    });
  }

  onFolderRightClick(folderType: 'poles' | 'spans', lineId: number, segmentId: number | null, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'folder';
    this.contextMenuLineId = lineId;
    this.contextMenuSegmentId = segmentId;
    this.contextMenuFeature = null;
    
    this.cdr.detectChanges();
    requestAnimationFrame(() => {
      setTimeout(() => {
        if (this.menuTrigger) {
          try {
            const element = (this.menuTrigger as any)._element?.nativeElement ||
              (this.menuTrigger as any)._elementRef?.nativeElement;
            if (element) {
              element.click();
            } else if (this.menuTrigger.menu) {
              this.menuTrigger.openMenu();
            } else {
              console.warn('MatMenuTrigger.menu не инициализирован');
            }
          } catch (error) {
            console.error('Ошибка открытия меню:', error);
          }
        } else {
          console.warn('MatMenuTrigger не найден');
        }
      }, 10);
    });
  }

  onRootRightClick(event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'root';
    this.contextMenuFeature = null;
    this.contextMenuLineId = null;
    this.contextMenuSegmentId = null;
    
    this.cdr.detectChanges();
    requestAnimationFrame(() => {
      setTimeout(() => {
        if (this.menuTrigger) {
          try {
            const element = (this.menuTrigger as any)._element?.nativeElement ||
              (this.menuTrigger as any)._elementRef?.nativeElement;
            if (element) {
              element.click();
            } else if (this.menuTrigger.menu) {
              this.menuTrigger.openMenu();
            } else {
              console.warn('MatMenuTrigger.menu не инициализирован');
            }
          } catch (error) {
            console.error('Ошибка открытия меню:', error);
          }
        } else {
          console.warn('MatMenuTrigger не найден');
        }
      }, 10);
    });
  }

  onCreateSubstation(): void {
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '560px',
      panelClass: 'create-object-dialog-panel',
      data: { defaultObjectType: 'substation' }
    });
    
    dialogRef.afterClosed().subscribe(result => {
      if (result && result.success) {
        this.mapService.refreshData();
      }
    });
  }

  onCreateObject(): void {
    if (this.contextMenuType === 'root') {
      // В корне - создаём только линию
      const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
        width: '560px',
        panelClass: 'create-object-dialog-panel',
        data: { defaultObjectType: 'powerline' }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'powerLine' && this.contextMenuLineId) {
      // В линии - создаём опору
      console.log('Открытие диалога создания опоры для линии ID:', this.contextMenuLineId);
      const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
        width: '560px',
        panelClass: 'create-object-dialog-panel',
        data: {
          defaultObjectType: 'pole',
          lineId: this.contextMenuLineId
        }
      });
      console.log('Диалог открыт с данными:', { defaultObjectType: 'pole', lineId: this.contextMenuLineId });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'segment' && this.contextMenuLineId) {
      // В участке - создаём пролёт
      const dialogRef = this.dialog.open(CreateSpanDialogComponent, {
        width: '600px',
        data: { 
          lineId: this.contextMenuLineId,
          segmentId: this.contextMenuSegmentId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'folder' && this.contextMenuLineId) {
      // В папке опор - создаём опору
      const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
        width: '560px',
        panelClass: 'create-object-dialog-panel',
        data: {
          defaultObjectType: 'pole',
          lineId: this.contextMenuLineId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    }
  }

  onCreateSegment(): void {
    if (this.contextMenuType === 'powerLine' && this.contextMenuLineId) {
      // Создаём участок (AClineSegment) в линии
      const dialogRef = this.dialog.open(CreateSegmentDialogComponent, {
        width: '600px',
        data: { 
          lineId: this.contextMenuLineId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    }
  }

  onRebuildTopology(): void {
    if (this.contextMenuType === 'powerLine' && this.contextMenuLineId != null) {
      const dialogRef = this.dialog.open(RebuildTopologyDialogComponent, {
        width: '480px',
        data: { lineId: this.contextMenuLineId }
      });
      dialogRef.afterClosed().subscribe((result) => {
        if (result) {
          this.mapService.refreshData();
        }
      });
    }
  }

  onEditObject(): void {
    // Для участков contextMenuFeature может быть null, проверяем contextMenuSegmentId
    if (!this.contextMenuFeature && !(this.contextMenuType === 'segment' && this.contextMenuSegmentId)) return;
    
    if (this.contextMenuType === 'powerLine' && this.contextMenuLineId) {
      // Редактирование ЛЭП
      const dialogRef = this.dialog.open(EditPowerLineDialogComponent, {
        width: '600px',
        data: { 
          lineId: this.contextMenuLineId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'pole' && this.contextMenuFeature) {
      // Редактирование опоры
      const poleId = this.contextMenuFeature.properties['id'];
      const lineId = this.contextMenuFeature.properties['line_id'] ?? this.contextMenuFeature.properties['power_line_id'] ?? this.contextMenuLineId;
      
      if (poleId && lineId) {
        const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
          width: '560px',
          panelClass: 'create-object-dialog-panel',
          data: {
            objectType: 'pole',
            poleId: poleId,
            lineId: lineId,
            isEdit: true
          }
        });
        
        dialogRef.afterClosed().subscribe(result => {
          if (result && result.success) {
            this.mapService.refreshData();
          }
        });
      }
    } else if (this.contextMenuType === 'span' && this.contextMenuFeature) {
      // Редактирование пролёта
      const spanId = this.contextMenuFeature.properties['id'];
      const lineId = this.contextMenuFeature.properties['line_id'] ?? this.contextMenuFeature.properties['power_line_id'];
      const segmentId = this.contextMenuFeature.properties['acline_segment_id'] || this.contextMenuFeature.properties['segment_id'];
      
      if (spanId && lineId) {
        const dialogRef = this.dialog.open(CreateSpanDialogComponent, {
          width: '600px',
          data: { 
            lineId: lineId,
            segmentId: segmentId,
            spanId: spanId,
            isEdit: true
          }
        });
        
        dialogRef.afterClosed().subscribe(result => {
          if (result && result.success) {
            this.mapService.refreshData();
          }
        });
      }
    } else if (this.contextMenuType === 'substation' && this.contextMenuFeature) {
      const substationId = this.contextMenuFeature.properties['id'];
      if (substationId) {
        const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
          width: '700px',
          maxWidth: '90vw',
          data: {
            objectType: 'substation',
            substationId: substationId,
            isEdit: true
          }
        });
        dialogRef.afterClosed().subscribe(result => {
          if (result && result.success) {
            this.mapService.refreshData();
          }
        });
      }
    }
  }

  /** Отпаечная опора — показываем «Начать отпайку» (создать новую ветку от этой опоры) */
  isContextMenuPoleTap(): boolean {
    if (this.contextMenuType !== 'pole' || !this.contextMenuFeature) return false;
    return !!this.contextMenuFeature.properties['is_tap_pole'];
  }

  onStartTapFromPole(): void {
    if (this.contextMenuType !== 'pole' || !this.contextMenuFeature) return;
    const lineId = this.contextMenuFeature.properties['line_id'] ?? this.contextMenuFeature.properties['power_line_id'];
    const tapPoleId = this.contextMenuFeature.properties['id'];
    if (lineId == null || tapPoleId == null) return;
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '560px',
      panelClass: 'create-object-dialog-panel',
      data: {
        defaultObjectType: 'pole',
        lineId: lineId as number,
        tapPoleId: tapPoleId as number,
        startNewTap: true
      }
    });
    dialogRef.afterClosed().subscribe(result => {
      if (result && result.success) {
        this.mapService.refreshData();
      }
    });
  }

  /** Создать оборудование на опоре из контекстного меню по опоре */
  onCreateEquipmentFromPole(): void {
    if (this.contextMenuType !== 'pole' || !this.contextMenuFeature) return;
    const poleId = this.contextMenuFeature.properties['id'];
    const lineId = this.contextMenuFeature.properties['line_id'] ?? this.contextMenuFeature.properties['power_line_id'] ?? this.contextMenuLineId;
    if (poleId == null || lineId == null) {
      return;
    }
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '560px',
      panelClass: 'create-object-dialog-panel',
      data: {
        defaultObjectType: 'equipment',
        poleId: poleId as number,
        lineId: lineId as number
      }
    });
    dialogRef.afterClosed().subscribe(result => {
      if (result && result.success) {
        this.mapService.refreshData();
      }
    });
  }

  /** Правый клик по оборудованию в дереве */
  onEquipmentRightClick(eq: Equipment, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'equipment';
    this.contextMenuEquipment = eq;
    this.contextMenuLineId = null;
    this.contextMenuSegmentId = null;

    this.cdr.detectChanges();
    requestAnimationFrame(() => {
      setTimeout(() => {
        if (this.menuTrigger) {
          try {
            const element = (this.menuTrigger as any)._element?.nativeElement ||
              (this.menuTrigger as any)._elementRef?.nativeElement;
            if (element) {
              element.click();
            } else if (this.menuTrigger.menu) {
              this.menuTrigger.openMenu();
            }
          } catch (error) {
            console.error('Ошибка открытия меню оборудования:', error);
          }
        }
      }, 10);
    });
  }

  onEditEquipment(): void {
    if (!this.contextMenuEquipment) return;
    const eq = this.contextMenuEquipment;
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '560px',
      panelClass: 'create-object-dialog-panel',
      data: { objectType: 'equipment', isEdit: true, equipmentId: eq.id, poleId: eq.pole_id }
    });
    dialogRef.afterClosed().subscribe(res => {
      if (res && res.success) {
        this.mapService.refreshData();
        this.loadAllEquipmentForTree();
      }
    });
  }

  onDeleteEquipment(): void {
    if (!this.contextMenuEquipment) return;
    const eq = this.contextMenuEquipment;
    this.apiService.deleteEquipment(eq.id).pipe(takeUntil(this.destroy$)).subscribe({
      next: () => {
        this.snackBar.open('Оборудование удалено', 'Закрыть', { duration: 2500 });
        this.mapService.refreshData();
        this.loadAllEquipmentForTree();
      },
      error: () => {
        this.snackBar.open('Ошибка удаления оборудования', 'Закрыть', { duration: 4000 });
      }
    });
  }

  openSegmentCard(segmentId: number, lineId: number, segmentName?: string | null): void {
    if (segmentId == null) return;
    const data: SegmentCardDialogData = {
      segmentId,
      lineId,
      segmentName: segmentName ?? undefined
    };
    this.dialog.open(SegmentCardDialogComponent, {
      width: '620px',
      height: '520px',
      maxWidth: '95vw',
      maxHeight: '90vh',
      panelClass: 'segment-card-dialog-panel',
      data
    });
  }

  onDeleteObject(): void {
    // Удаление участка (segment): тип задаётся контекстным меню, не feature
    if (this.contextMenuType === 'segment' && this.contextMenuSegmentId != null && this.contextMenuLineId != null) {
      const treeItems = this.getPowerLinesWithSegmentsAndPoles();
      const item = treeItems.find(i => i.powerLine.properties['id'] === this.contextMenuLineId);
      const segmentName = item?.segments.find(s => s.segmentId === this.contextMenuSegmentId)?.segmentName
        || `Участок ${this.contextMenuSegmentId}`;
      const deleteData: DeleteObjectData = {
        objectType: 'segment',
        objectId: this.contextMenuSegmentId,
        objectName: segmentName,
        lineId: this.contextMenuLineId
      };
      const dialogRef = this.dialog.open(DeleteObjectDialogComponent, {
        width: '400px',
        data: deleteData,
        autoFocus: false,
        restoreFocus: false
      });
      dialogRef.afterClosed().subscribe(result => {
        if (result) this.mapService.refreshData();
      });
      return;
    }

    if (!this.contextMenuFeature) return;
    
    // Определяем тип объекта по contextMenuType для надёжности (подстанция может без dispatcher_name)
    let objectType: 'pole' | 'powerLine' | 'substation' | 'tap' | 'span' = 'pole';
    let objectId: number | null = null;
    let objectName: string = '';
    
    if (this.contextMenuType === 'substation' && this.contextMenuFeature.properties['id'] != null) {
      objectType = 'substation';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['name'] || 'Подстанция';
    } else if (this.contextMenuFeature.properties['span_number']) {
      objectType = 'span';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['span_number'] || 'N/A';
    } else if (this.contextMenuFeature.properties['pole_number']) {
      objectType = 'pole';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['pole_number'] || 'N/A';
    } else if (this.contextMenuType !== 'substation' && this.contextMenuFeature.properties['name'] && this.contextMenuFeature.properties['dispatcher_name']) {
      objectType = 'substation';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['name'] || 'N/A';
    } else if (this.contextMenuFeature.properties['name'] && !this.contextMenuFeature.properties['pole_number'] && !this.contextMenuFeature.properties['tap_number'] && this.contextMenuFeature.properties['dispatcher_name'] === undefined) {
      objectType = 'powerLine';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['name'] || 'N/A';
    }
    
    if (objectId === null || objectId === undefined) {
      return;
    }
    
    const deleteData: DeleteObjectData = {
      objectType,
      objectId,
      objectName
    };
    
    if (objectType === 'powerLine') {
      const treeItems = this.getPowerLinesWithSegmentsAndPoles();
      const item = treeItems.find(i => i.powerLine.properties['id'] === objectId);
      if (item) {
        const polesCount = item.allPoles.length;
        const spansCount = item.segments.reduce((s, seg) => s + seg.spans.length, 0) + (item.spansWithoutSegment?.length ?? 0);
        if (polesCount > 0 || spansCount > 0) {
          deleteData.hasChildren = true;
          const parts: string[] = [];
          if (polesCount > 0) parts.push(polesCount === 1 ? '1 опора' : polesCount + ' опор');
          if (spansCount > 0) parts.push(spansCount === 1 ? '1 пролёт' : spansCount + ' пролётов');
          deleteData.childrenSummary = parts.join(', ');
        }
      }
    }
    
    if (objectType === 'span' && this.contextMenuLineId) {
      deleteData.lineId = this.contextMenuLineId;
    }
    
    const dialogRef = this.dialog.open(DeleteObjectDialogComponent, {
      width: '400px',
      data: deleteData,
      autoFocus: false,
      restoreFocus: false
    });
    
    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.mapService.refreshData();
      }
    });
  }
}

