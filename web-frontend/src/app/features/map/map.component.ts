import { Component, OnInit, OnDestroy } from '@angular/core';
import { MapService, MapData } from '../../core/services/map.service';
import { SidebarService } from '../../core/services/sidebar.service';
import { GeoJSONCollection, GeoJSONFeature } from '../../core/models/geojson.model';
import { environment } from '../../../environments/environment';
import * as L from 'leaflet';
import { Subject } from 'rxjs';
import { takeUntil, switchMap } from 'rxjs/operators';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatDialog } from '@angular/material/dialog';
import { CreateObjectDialogComponent } from './create-object-dialog/create-object-dialog.component';
import { PoleConnectivityDialogComponent } from './pole-connectivity-dialog/pole-connectivity-dialog.component';
import { PoleSequenceDialogComponent } from './pole-sequence-dialog/pole-sequence-dialog.component';
import { CreateSpanDialogComponent } from './create-span-dialog/create-span-dialog.component';
import { ImagePreviewDialogComponent } from './image-preview-dialog/image-preview-dialog.component';
import { ApiService } from '../../core/services/api.service';
import { CardCommentMessage } from '../../core/models/card-comment.model';
import { formatCardCommentDateTime, parseCardCommentMessages } from '../../core/utils/card-comment.codec';
import { Pole } from '../../core/models/pole.model';
import { Equipment } from '../../core/models/equipment.model';
import { colorForVoltageKv, lineWeightForBranch } from '../../core/map/voltage-level-colors';

@Component({
  selector: 'app-map',
  templateUrl: './map.component.html',
  styleUrls: ['./map.component.scss']
})
export class MapComponent implements OnInit, OnDestroy {
  readonly formatCardCommentAt = formatCardCommentDateTime;

  map: L.Map | null = null;
  mapData: MapData | null = null;
  isLoading = true;
  errorMessage: string | null = null;
  
  // Окно свойств опоры
  selectedPole: any = null;
  showPoleProperties = false;
  // Окно свойств оборудования
  selectedEquipment: any = null;
  showEquipmentProperties = false;
  
  // Текущий зум карты
  currentZoom: number = 10;
  
  // Состояние sidebar
  isSidebarOpen: boolean = true;
  sidebarWidth: number = 350;
  // Режим карты: отображать только объекты с дефектами
  showOnlyDefective = false;
  
  // Инвертированный зум (1 = минимальный зум/большой масштаб, 28 = максимальный зум/маленький масштаб)
  get invertedZoom(): number {
    return 28 - this.currentZoom;
  }
  
  // Расстояние в метрах для текущего зума
  get zoomDistance(): string {
    return this.getZoomDistance(this.currentZoom);
  }
  
  // Расчет расстояния в метрах для уровня зума
  private getZoomDistance(zoom: number): string {
    if (!this.map) {
      return '';
    }
    
    // Получаем центр карты для более точного расчета
    const center = this.map.getCenter();
    const lat = center.lat;
    
    // Формула расчета разрешения в метрах на пиксель для Web Mercator
    // resolution = 156543.03392 * Math.cos(lat * Math.PI / 180) / Math.pow(2, zoom)
    const resolution = 156543.03392 * Math.cos(lat * Math.PI / 180) / Math.pow(2, zoom);
    const metersPerPixel = resolution;
    
    // Берем ширину карты для расчета видимого расстояния
    const mapWidth = this.map.getSize().x || 1000;
    const distanceMeters = metersPerPixel * mapWidth;
    
    // Форматируем вывод
    if (distanceMeters >= 1000) {
      return `${(distanceMeters / 1000).toFixed(1)} км`;
    } else if (distanceMeters >= 100) {
      return `${Math.round(distanceMeters)} м`;
    } else if (distanceMeters >= 10) {
      return `${distanceMeters.toFixed(1)} м`;
    } else if (distanceMeters >= 1) {
      return `${distanceMeters.toFixed(2)} м`;
    } else {
      return `${(distanceMeters * 100).toFixed(0)} см`;
    }
  }
  
  private destroy$ = new Subject<void>();
  private layers: L.Layer[] = [];

  // Маркеры для разных типов объектов
  private powerLineLayers: L.Layer[] = [];
  private substationConnectionLayers: L.Layer[] = []; // Линии подстанция ↔ первая/последняя опора ЛЭП и отпаек к ТП
  private poleMarkers: L.Marker[] = [];
  private poleLabels: L.Layer[] = []; // Подписи опор
  private tapMarkers: L.Marker[] = [];
  private substationMarkers: L.Marker[] = [];
  private equipmentMarkers: L.Marker[] = []; // Отдельные маркеры оборудования на линии
  /** Точечные маркеры оборудования как отдельных объектов с собственными координатами */
  private equipmentPointMarkers: L.Marker[] = [];
  /** Маркеры оборудования из GeoJSON (между опорами, с иконкой и углом — как во Flutter) */
  private equipmentGeoJsonMarkers: L.Marker[] = [];
  /** Выделенный участок линии (при клике в дереве): подсветка жирной линией и чёрными точками опор */
  private selectedSegment: { lineId: number; segmentId: number | null } | null = null;
  private segmentHighlightLayers: L.Layer[] = [];

  // Оборудование по опорам для отрисовки SVG-значков на карте
  private allEquipment: Equipment[] = [];
  private equipmentByPoleId = new Map<number, Equipment[]>();
  // Спецификация терминалов SVG (координаты в системе viewBox).
  private readonly equipmentTerminalSpec: Record<string, {
    viewBox: [number, number, number, number];
    t1: [number, number];
    t2?: [number, number] | null;
    anchor?: [number, number] | null;
    rotationOffsetDeg?: number;
    // Для SVG, где геометрия задана в локальной системе вокруг (0,0) и затем сдвинута transform=translate(...).
    localOriginToViewBox?: [number, number] | null;
    localRotateDeg?: number;
    iconScale?: number;
  }> = {
    zn: {
      viewBox: [0, 0, 240, 200],
      t1: [-80, 0],
      t2: null,
      anchor: [-80, 0],
      rotationOffsetDeg: 90,
      localOriginToViewBox: [100, 100],
    },
    arrester: {
      viewBox: [0, 0, 200, 200],
      // В arrester.svg: горизонталь к линии — M -80 0 L -40 0 (после translate(100,100) в группе).
      // Якорь — левый конец «провода» (-80, 0), чтобы полюс садился на трассе.
      t1: [-80, 0],
      t2: null,
      anchor: [-80, 0],
      rotationOffsetDeg: 90,
      localOriginToViewBox: [100, 100],
    },
    disconnector: {
      viewBox: [0, 0, 200, 200],
      t1: [0, -40],
      t2: [0, 40],
      anchor: null,
      rotationOffsetDeg: 0,
      localOriginToViewBox: [100, 100],
      // В исходном SVG есть rotate(90) внутри transform.
      // Применяем ту же локальную ротацию к терминалам/anchor из спецификации.
      localRotateDeg: 90,
    },
    breaker: {
      viewBox: [0, 0, 200, 200],
      t1: [-40, 0],
      t2: [40, 0],
      anchor: null,
      rotationOffsetDeg: 0,
      localOriginToViewBox: [100, 100],
    },
    recloser: {
      viewBox: [0, 0, 200, 200],
      t1: [-40, 0],
      t2: [40, 0],
      anchor: null,
      rotationOffsetDeg: 0,
      localOriginToViewBox: [100, 100],
    },
  };

  constructor(
    private mapService: MapService,
    private sidebarService: SidebarService,
    private snackBar: MatSnackBar,
    private dialog: MatDialog,
    private apiService: ApiService
  ) {}

  ngOnInit(): void {
    this.initMap();
    this.loadMapData();
    
    // Подписываемся на события центрирования из sidebar
    this.mapService.centerOnFeature$
      .pipe(takeUntil(this.destroy$))
      .subscribe(({ coordinates, zoom, bounds }: {
        type: string;
        coordinates: [number, number];
        zoom?: number | null;
        currentZoomForLogic?: number;
        bounds?: [[number, number], [number, number]];
      }) => {
        if (this.map) {
          this.mapService.setCurrentZoom(this.map.getZoom());
        }
        if (bounds != null && this.map) {
          this.map.fitBounds(bounds, { animate: true, duration: 0.5, padding: [40, 40] });
          this.currentZoom = this.map.getZoom();
          this.mapService.setCurrentZoom(this.currentZoom);
        } else {
          this.centerOnPole(coordinates[0], coordinates[1], zoom);
        }
      });

    // Центрирование на оборудовании при клике по дереву объектов (зум на иконке оборудования, а не на опоре)
    this.mapService.centerOnEquipment$
      .pipe(takeUntil(this.destroy$))
      .subscribe(({ poleId, equipmentId }) => {
        const center = this.getEquipmentCenterLatLng(poleId, equipmentId);
        if (center && this.map) {
          this.centerOnPole(center.lat, center.lng, 18);
        }
      });
    
    // Подписываемся на изменения состояния sidebar
    this.sidebarService.getSidebarVisible()
      .pipe(takeUntil(this.destroy$))
      .subscribe(visible => {
        this.isSidebarOpen = visible;
      });
    
    this.sidebarService.getSidebarWidth()
      .pipe(takeUntil(this.destroy$))
      .subscribe(width => {
        this.sidebarWidth = width;
      });
    
    // Инициализируем состояние sidebar
    this.isSidebarOpen = this.sidebarService.isSidebarOpen();
    this.sidebarWidth = this.sidebarService.getCurrentSidebarWidth();

    // Пересборка топологии по запросу из дерева (ПКМ по ЛЭП)
    this.mapService.requestRebuildTopology$
      .pipe(takeUntil(this.destroy$))
      .subscribe(lineId => this.autoCreateSpans(lineId));

    this.mapService.requestSelectSegment$
      .pipe(takeUntil(this.destroy$))
      .subscribe(({ lineId, segmentId, bounds }) => {
        if (this.map) {
          this.map.fitBounds(bounds as L.LatLngBoundsLiteral, { animate: true, duration: 0.5, padding: [40, 40] });
          this.selectedSegment = { lineId, segmentId };
          this.renderSegmentHighlight();
        }
      });

    this.mapService.clearSegmentSelection$
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        this.selectedSegment = null;
        this.clearSegmentHighlight();
      });

    // Показать панель свойств опоры при клике по опоре в дереве объектов
    this.mapService.showPoleProperties$
      .pipe(takeUntil(this.destroy$))
      .subscribe((feature: GeoJSONFeature) => {
        if (feature?.geometry?.type === 'Point' && feature.geometry.coordinates?.length >= 2) {
          // Панели свойств должны быть взаимоисключающими:
          // при выборе опоры закрываем карточку оборудования.
          this.showEquipmentProperties = false;
          this.selectedEquipment = null;

          const coords = feature.geometry.coordinates as number[];
          const lng = coords[0];
          const lat = coords[1];
          // Оборудование по опоре может приходить из REST/синхрона отдельно; в GeoJSON пока его нет
          this.showPoleProperties = true;
          this.selectedPole = {
            ...feature.properties,
            latitude: lat,
            longitude: lng,
            segment_name: feature.properties['segment_name'] ||
              feature.properties['power_line_name'] ||
              `ЛЭП ID: ${this.lineIdFromProps(feature.properties as Record<string, any> | undefined) ?? 'N/A'}`
          };
          const poleId = feature.properties['id'];
          if (poleId != null) {
            this.apiService.getPole(poleId).subscribe({
              next: (pole) => {
                Object.assign(this.selectedPole as any, pole, {
                  equipment: (pole as any).equipment || [],
                  connectivity_node: (pole as any).connectivity_node ?? null,
                  latitude: (this.selectedPole as any).latitude ?? (pole as any).y_position,
                  longitude: (this.selectedPole as any).longitude ?? (pole as any).x_position
                });
              }
            });
            this.apiService.getPoleTerminals(poleId).subscribe({
              next: (terms) => {
                (this.selectedPole as any).terminals = terms || [];
              }
            });
          }
        }
      });

    this.mapService.showEquipmentProperties$
      .pipe(takeUntil(this.destroy$))
      .subscribe((feature: GeoJSONFeature) => {
        this.openEquipmentProperties(feature);
      });

    // Обновление данных карты при refreshData() (после создания/удаления опор, отпаек и т.д.)
    this.mapService.dataRefresh
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        this.loadMapData();
      });

    // Автообновление карты отключено; данные обновляются по dataRefresh (после действий пользователя) или по явному обновлению.
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
    if (this.map) {
      this.map.remove();
    }
  }

  initMap(): void {
    const center = environment.map.defaultCenter;
    
    this.map = L.map('map', {
      center: [center.lat, center.lng],
      zoom: environment.map.defaultZoom,
      minZoom: environment.map.minZoom,
      maxZoom: environment.map.maxZoom,
      maxBounds: L.latLngBounds(L.latLng(-85, -180), L.latLng(85, 180)),
      maxBoundsViscosity: 1
    });

    // Добавляем тайлы OpenStreetMap
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '',
      maxZoom: 19
    }).addTo(this.map);

    // Подписываемся на изменение зума
    this.map.on('zoomend', () => {
      if (this.map) {
        this.currentZoom = this.map.getZoom();
        // Обновляем зум в сервисе для доступа из других компонентов
        this.mapService.setCurrentZoom(this.currentZoom);
        // Важно: терминалы оборудования считаются в пикселях.
        // При изменении зума пересобираем геометрию, чтобы стыки "опора -> полюс -> опора"
        // оставались точными и без разрыва на любом масштабе.
        if (this.mapData) {
          this.renderMapData(this.mapData);
        }
        this.updatePoleLabels();
        this.updateEquipmentVisibility();
      }
    });
    
    // Также обновляем при изменении зума (zoom) - для более быстрой синхронизации
    this.map.on('zoom', () => {
      if (this.map) {
        const newZoom = this.map.getZoom();
        this.currentZoom = newZoom;
        this.mapService.setCurrentZoom(newZoom);
      }
    });

    // Инициализируем текущий зум
    this.currentZoom = this.map.getZoom();
    // Обновляем зум в сервисе
    this.mapService.setCurrentZoom(this.currentZoom);

    this.map.on('click', () => {
      this.mapService.clearSegmentSelection();
    });
  }

  loadMapData(): void {
    this.isLoading = true;
    this.errorMessage = null;

    this.apiService.getAllEquipment()
      .pipe(
        switchMap((eqList) => {
          this.allEquipment = Array.isArray(eqList) ? eqList : [];
          this.equipmentByPoleId.clear();
          this.allEquipment.forEach((eq) => {
            if (!eq || eq.pole_id == null) return;
            const pid = Number(eq.pole_id);
            if (!this.equipmentByPoleId.has(pid)) {
              this.equipmentByPoleId.set(pid, []);
            }
            this.equipmentByPoleId.get(pid)!.push(eq);
          });
          return this.mapService.loadAllMapData();
        }),
        takeUntil(this.destroy$)
      )
      .subscribe({
        next: (data) => {
          this.mapData = data;
          this.renderMapData(data);
          this.isLoading = false;
          console.log('✅ Данные карты загружены');
        },
        error: (error) => {
          console.error('❌ Ошибка загрузки данных карты:', error);
          this.errorMessage = 'Ошибка загрузки данных карты';
          this.isLoading = false;
          
          this.snackBar.open('Ошибка загрузки данных карты', 'Повторить', {
            duration: 5000,
            horizontalPosition: 'center',
            verticalPosition: 'top'
          }).onAction().subscribe(() => {
            this.loadMapData();
          });
        }
      });
  }

  renderMapData(data: MapData): void {
    if (!this.map) return;

    // Сохраняем текущий зум и позицию карты перед обновлением
    const currentZoom = this.map.getZoom();
    const currentCenter = this.map.getCenter();

    // Очищаем предыдущие слои
    this.clearLayers();

    // Рендерим ЛЭП (линии) — строим по координатам опор, чтобы линия проходила ровно через центры точек
    if (data.powerLines?.features) {
      this.renderPowerLines(data.powerLines, data.poles?.features ?? [], data.powerLinesList ?? []);
    }
    
    // Рендерим опоры (точки)
    if (data.poles?.features) {
      this.renderPoles(data.poles);
      // Оборудование между опорами — как во Flutter: по списку линий и опорам с line_id
      this.renderEquipmentBetweenPoles(data.poles?.features ?? [], data.powerLinesList ?? []);
    }
    
    // Рендерим отпайки (точки)
    if (data.taps?.features) {
      this.renderTaps(data.taps);
    }
    
    // Рендерим подстанции (точки)
    if (data.substations?.features) {
      this.renderSubstations(data.substations);
    }

    // Рисуем соединения отпаек с подстанциями по пролётам (Span: from_pole_id → substation CN)
    if (data.spans?.features) {
      this.renderTapSubstationConnections(data.spans, data.substations);
    }
 
    // Рендерим оборудование как отдельные точки с собственными координатами (если заданы)
    this.renderEquipmentPoints();

    // Соединения подстанция ↔ первая/последняя опора ЛЭП (если подстанция привязана как начало/конец линии)
    if (data.powerLinesList?.length && data.substations?.features && data.poles?.features) {
      this.renderSubstationConnections(data);
    }

    // Восстанавливаем зум и позицию карты после обновления данных
    if (this.map && currentCenter) {
      this.map.setView(currentCenter, currentZoom, { animate: false });
    }
    if (this.selectedSegment) {
      this.renderSegmentHighlight();
    }
    this.updateEquipmentVisibility();
  }

  /**
   * Линии ЛЭП: как во Flutter (_buildPowerLinePolylines).
   * Если для линии есть ≥2 опоры с координатами — не используем объединённую LineString из API
   * (она склеивает все отпайки в один порядок), а строим магистраль и отпайки по опорам.
   * Иначе — рисуем готовую геометрию из GeoJSON.
   */
  renderPowerLines(
    geoJson: any,
    polesFeatures: GeoJSONFeature[] = [],
    powerLinesList?: Array<{ id: number; voltage_level?: number | null }>
  ): void {
    if (!this.map || !geoJson.features) return;

    const countByLine = new Map<number, number>();
    polesFeatures.forEach((f: GeoJSONFeature) => {
      const lid = this.poleLineId(f);
      if (lid == null || f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      countByLine.set(lid, (countByLine.get(lid) ?? 0) + 1);
    });
    const lineIdsFromPoles = new Set<number>();
    countByLine.forEach((n, lid) => {
      if (n >= 2) lineIdsFromPoles.add(lid);
    });

    const lineIdsWithGeometry = new Set<number>();

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      const geom = feature.geometry as any;
      if (!geom || geom.type !== 'LineString' || !Array.isArray(geom.coordinates)) return;

      const lineId = Number(feature.properties?.['id'] ?? this.lineIdFromProps(feature.properties as Record<string, any> | undefined));
      if (Number.isFinite(lineId) && lineIdsFromPoles.has(lineId)) {
        return;
      }

      const coordinates = geom.coordinates as number[][];
      if (!coordinates.length) return;
      if (Number.isFinite(lineId)) lineIdsWithGeometry.add(lineId);

      const latlngs = coordinates.map((coord) => [coord[1], coord[0]] as L.LatLngExpression);
      const isTap = feature.properties['branch_type'] === 'tap';
      const vlProp = Number(feature.properties['voltage_level']);
      const vlList = Number.isFinite(lineId) ? this.voltageKvForPowerLineFromList(lineId, powerLinesList) : null;
      const vlEff = Number.isFinite(vlProp) && vlProp > 0 ? vlProp : vlList;
      const lineColor = colorForVoltageKv(Number.isFinite(vlEff) ? vlEff : null);

      const polyline = L.polyline(latlngs, {
        color: lineColor,
        weight: lineWeightForBranch(!!isTap),
        opacity: 0.85,
        lineCap: 'round',
        lineJoin: 'round'
      }).bindPopup(`
          <strong>${feature.properties['name'] || 'ЛЭП'}</strong><br>
          Напряжение: ${feature.properties['voltage_level']} кВ<br>
          Опор: ${feature.properties['pole_count'] || 0}${isTap ? '<br>(отпайка)' : ''}
        `);

      polyline.addTo(this.map!);
      this.powerLineLayers.push(polyline);
    });

    this.appendPowerLinePolylinesFromPoles(polesFeatures, powerLinesList, lineIdsFromPoles, lineIdsWithGeometry);
  }

  private poleLineId(f: GeoJSONFeature): number | null {
    const v = this.lineIdFromProps(f.properties as Record<string, any> | undefined);
    if (v == null) return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }

  /**
   * Канонический id ЛЭП в GeoJSON: используем line_id.
   * legacy power_line_id читаем только для обратной совместимости.
   */
  private lineIdFromProps(props: Record<string, any> | undefined): number | null {
    if (!props) return null;
    const v = props['line_id'] ?? props['power_line_id'];
    if (v == null) return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }

  private voltageKvForPowerLineFromList(
    lineId: number,
    powerLinesList?: Array<{ id: number; voltage_level?: number | null }>
  ): number | null {
    const pl = powerLinesList?.find((p) => p.id === lineId);
    if (!pl || pl.voltage_level == null) return null;
    const v = Number(pl.voltage_level);
    return Number.isFinite(v) ? v : null;
  }

  private sortMainPolesFlutter(a: GeoJSONFeature, b: GeoJSONFeature): number {
    const absentSeq = 1 << 20;
    const sa = Number(a.properties?.['sequence_number']);
    const sb = Number(b.properties?.['sequence_number']);
    const ra = Number.isFinite(sa) ? sa : absentSeq;
    const rb = Number.isFinite(sb) ? sb : absentSeq;
    if (ra !== rb) return ra - rb;
    const oa = this.poleOrderFromNumber(a.properties?.['pole_number']);
    const ob = this.poleOrderFromNumber(b.properties?.['pole_number']);
    if (oa !== ob) return oa - ob;
    return String(a.properties?.['pole_number'] ?? '').localeCompare(String(b.properties?.['pole_number'] ?? ''));
  }

  private sortBranchNodesFlutter(a: GeoJSONFeature, b: GeoJSONFeature): number {
    const absentSeq = 1 << 20;
    const sa = Number(a.properties?.['sequence_number']);
    const sb = Number(b.properties?.['sequence_number']);
    const ra = Number.isFinite(sa) ? sa : absentSeq;
    const rb = Number.isFinite(sb) ? sb : absentSeq;
    if (ra !== rb) return ra - rb;
    const ida = Number(a.properties?.['id']) || 0;
    const idb = Number(b.properties?.['id']) || 0;
    return ida - idb;
  }

  /** Как map_page.dart areNeighborsInBranch — соседство по номерам для fallback без tap_pole_id. */
  private areNeighborsInBranchPoleNumbers(a: string, b: string): boolean {
    const hasSlashA = a.includes('/');
    const hasSlashB = b.includes('/');
    if (!hasSlashA && !hasSlashB) return false;
    if (hasSlashA !== hasSlashB) {
      const tap = hasSlashA ? a : b;
      const main = hasSlashA ? b : a;
      return main === tap.split('/')[0]?.trim();
    }
    const partsA = a.split('/');
    const partsB = b.split('/');
    if (partsA.length < 2 || partsB.length < 2 || partsA[0].trim() !== partsB[0].trim()) return false;
    const sufA = Number(partsA[1]?.trim());
    const sufB = Number(partsB[1]?.trim());
    if (!Number.isFinite(sufA) || !Number.isFinite(sufB)) return false;
    return Math.abs(sufA - sufB) === 1;
  }

  /**
   * Магистраль и отпайки по опорам (логика как во Flutter). Отдельные сегменты — прямые между опорами.
   */
  private appendPowerLinePolylinesFromPoles(
    polesFeatures: GeoJSONFeature[],
    powerLinesList: Array<{ id: number; voltage_level?: number | null }> | undefined,
    lineIdsFromPoles: Set<number>,
    lineIdsWithGeometry: Set<number>
  ): void {
    if (!this.map) return;

    const polesByLine = new Map<number, GeoJSONFeature[]>();
    polesFeatures.forEach((f: GeoJSONFeature) => {
      const lid = this.poleLineId(f);
      if (lid == null || !lineIdsFromPoles.has(lid)) return;
      if (lineIdsWithGeometry.has(lid)) return;
      if (f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      if (!polesByLine.has(lid)) polesByLine.set(lid, []);
      polesByLine.get(lid)!.push(f);
    });

    polesByLine.forEach((list, lineId) => {
      if (list.length < 2) return;

      const vl = this.voltageKvForPowerLineFromList(lineId, powerLinesList);
      const lineColor = colorForVoltageKv(vl);

      const byId = new Map<number, GeoJSONFeature>();
      list.forEach((p) => {
        const pid = p.properties?.['id'];
        if (pid != null) byId.set(Number(pid), p);
      });

      const segmentKeys = new Set<string>();

      const pushSegmentPolyline = (p1: GeoJSONFeature, p2: GeoJSONFeature, isTap: boolean) => {
        const c1 = p1.geometry?.coordinates as number[] | undefined;
        const c2 = p2.geometry?.coordinates as number[] | undefined;
        if (!c1?.length || !c2?.length) return;
        const latlngs: L.LatLngExpression[] = [
          [c1[1], c1[0]],
          [c2[1], c2[0]]
        ];
        const polyline = L.polyline(latlngs, {
          color: lineColor,
          weight: lineWeightForBranch(isTap),
          opacity: 0.85,
          lineCap: 'round',
          lineJoin: 'round'
        });
        polyline.addTo(this.map!);
        this.powerLineLayers.push(polyline);
      };

      const addSegmentByNodes = (a: GeoJSONFeature, b: GeoJSONFeature) => {
        const idA = Number(a.properties?.['id']);
        const idB = Number(b.properties?.['id']);
        if (!Number.isFinite(idA) || !Number.isFinite(idB) || idA === idB) return;
        const key = idA < idB ? `id:${idA}|${idB}` : `id:${idB}|${idA}`;
        if (segmentKeys.has(key)) return;
        segmentKeys.add(key);
        pushSegmentPolyline(a, b, true);
      };

      // Магистраль: опоры без «/» в номере
      const mainList = list.filter((e) => !String(e.properties?.['pole_number'] ?? '').includes('/'));
      mainList.sort((a, b) => this.sortMainPolesFlutter(a, b));
      if (mainList.length >= 2) {
        const pts = mainList
          .map((e) => {
            const c = e.geometry!.coordinates as number[];
            return [c[1], c[0]] as L.LatLngExpression;
          });
        const polyline = L.polyline(pts, {
          color: lineColor,
          weight: lineWeightForBranch(false),
          opacity: 0.85,
          lineCap: 'round',
          lineJoin: 'round'
        });
        polyline.addTo(this.map!);
        this.powerLineLayers.push(polyline);
      }

      const tapList = list.filter((e) => String(e.properties?.['pole_number'] ?? '').includes('/'));
      if (tapList.length === 0) return;

      const tapsWithMeta = tapList.filter((e) => e.properties?.['tap_pole_id'] != null);

      if (tapsWithMeta.length > 0) {
        const byBranch = new Map<string, GeoJSONFeature[]>();
        tapsWithMeta.forEach((t) => {
          const k = this.branchKeyFromPole(
            lineId,
            t.properties?.['tap_pole_id'],
            t.properties?.['tap_branch_index'],
            t.properties?.['pole_number']
          );
          if (!k) return;
          if (!byBranch.has(k)) byBranch.set(k, []);
          byBranch.get(k)!.push(t);
        });
        byBranch.forEach((branchNodes) => {
          if (branchNodes.length === 0) return;
          branchNodes.sort((a, b) => this.sortBranchNodesFlutter(a, b));
          const anchorId = Number(branchNodes[0]?.properties?.['tap_pole_id']);
          const anchor = Number.isFinite(anchorId) ? byId.get(anchorId) : undefined;
          if (anchor && branchNodes[0]) {
            addSegmentByNodes(anchor, branchNodes[0]);
          }
          for (let i = 1; i < branchNodes.length; i++) {
            addSegmentByNodes(branchNodes[i - 1]!, branchNodes[i]!);
          }
        });
      }

      const tapsForFallback =
        tapsWithMeta.length > 0
          ? tapList.filter((e) => e.properties?.['tap_pole_id'] == null)
          : tapList;

      const byPoleNumber = new Map<string, GeoJSONFeature>();
      list.forEach((e) => {
        const pn = String(e.properties?.['pole_number'] ?? '').trim();
        if (pn) byPoleNumber.set(pn, e);
      });

      const addSegmentByPoleNames = (keyA: string, keyB: string) => {
        if (keyA === keyB) return;
        if (!this.areNeighborsInBranchPoleNumbers(keyA, keyB)) return;
        const stable = keyA < keyB ? `${keyA}|${keyB}` : `${keyB}|${keyA}`;
        const dedupKey = `pn:${stable}`;
        if (segmentKeys.has(dedupKey)) return;
        segmentKeys.add(dedupKey);
        const pa = byPoleNumber.get(keyA);
        const pb = byPoleNumber.get(keyB);
        if (!pa || !pb) return;
        pushSegmentPolyline(pa, pb, true);
      };

      tapsForFallback.forEach((e) => {
        const pn = String(e.properties?.['pole_number'] ?? '').trim();
        const parts = pn.split('/');
        if (parts.length < 2) return;
        const root = parts[0]!.trim();
        const suffix = Number(parts[1]?.trim());
        if (!Number.isFinite(suffix) || suffix < 1) return;
        const prevKey = suffix === 1 ? root : `${root}/${suffix - 1}`;
        const nextKey = `${root}/${suffix + 1}`;
        if (byPoleNumber.has(prevKey)) {
          addSegmentByPoleNames(pn, prevKey);
        } else if (byPoleNumber.has(root)) {
          addSegmentByPoleNames(pn, root);
        }
        if (byPoleNumber.has(nextKey)) addSegmentByPoleNames(pn, nextKey);
      });
    });
  }

  renderPoles(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
        const hasEquipmentDefect = feature.properties['has_equipment_defect'] === true;
        if (this.showOnlyDefective && !hasEquipmentDefect) {
          return;
        }
        const coordinates = feature.geometry.coordinates as number[];
        const lat = Number(coordinates[1]);
        const lng = Number(coordinates[0]);
        // L.latLng — фиксированная копия координат (не съезжает при зуме)
        const latlng = L.latLng(lat, lng);
        
        const hasConnectivityNode = feature.properties['connectivity_node_id'];
        const poleNumber = feature.properties['pole_number'];
        const sequenceNumber = feature.properties['sequence_number'];
        const isTapPole = !!feature.properties['is_tap_pole'];
        const tapBranchHasPoles = !!feature.properties['tap_branch_has_poles'];
        // Подпись опоры теперь рисуется отдельными label-маркерами (updatePoleLabels),
        // поэтому сами маркеры — только точки без текста, чтобы не было дублирования.
        const labelText = '';
        
        // Обычные опоры: синий с узлом, оранжевый без. Отпаечные: крупнее, контур оранжевый (не начата) или зелёный (есть опоры по отпайке)
        let markerColor = hasConnectivityNode ? '#2196F3' : '#FF9800';
        let sizePx = 8;
        let borderColor = 'white';
        let borderWidth = 2;
        if (isTapPole) {
          sizePx = 12;
          borderWidth = 3;
          borderColor = tapBranchHasPoles ? '#4CAF50' : '#FF9800'; // зелёный = отпайка построена, оранжевый = нет
        }

        const poleDefectCriticality = this.normalizeCriticality(feature.properties['equipment_defect_max_criticality']);
        if (hasEquipmentDefect) {
          borderColor = this.criticalityColor(poleDefectCriticality);
          borderWidth = Math.max(borderWidth, 3);
        }

        const defectBadge = hasEquipmentDefect
          ? `<div class="map-defect-badge map-defect-badge--${poleDefectCriticality ?? 'none'}">!</div>`
          : '';
        const markerHtml = `
          <div class="pole-marker-wrap">
            <div style="background-color: ${markerColor}; width: ${sizePx}px; height: ${sizePx}px; border-radius: 50%; border: ${borderWidth}px solid ${borderColor}; cursor: pointer; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>
            ${defectBadge}
          </div>
        `;

        const iconW = labelText ? (isTapPole ? 24 : 20) : sizePx + borderWidth * 2;
        const iconH = labelText ? (isTapPole ? 36 : 30) : sizePx + borderWidth * 2;
        // Якорь — центр круга, чтобы точка не «съезжала» при изменении зума
        const anchorY = labelText ? (sizePx / 2 + borderWidth) : (sizePx + borderWidth * 2) / 2;
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'pole-marker' + (isTapPole ? ' pole-marker-tap' : ''),
            html: markerHtml,
            iconSize: [iconW, iconH],
            iconAnchor: [iconW / 2, anchorY]
          })
        });
        // Попап при клике убран — информация только в панели свойств справа внизу

        marker.on('click', () => {
          // Взаимоисключение панелей: при открытии опоры закрываем оборудование.
          this.showEquipmentProperties = false;
          this.selectedEquipment = null;
          this.showPoleProperties = true;
          this.selectedPole = {
            ...feature.properties,
            latitude: lat,
            longitude: lng,
            segment_name: feature.properties['segment_name'] || 
                         feature.properties['power_line_name'] || 
                         `ЛЭП ID: ${this.lineIdFromProps(feature.properties as Record<string, any> | undefined) ?? 'N/A'}`
          };
          this.centerOnPole(lat, lng, 18);
          const lineId = this.lineIdFromProps(feature.properties as Record<string, any> | undefined);
          const poleId = feature.properties['id'];
          if (lineId != null && poleId != null) {
            this.mapService.requestSelectPoleInTree(
              lineId,
              poleId,
              feature.properties['segment_id'] ?? undefined
            );
          }

          // Подгружаем полные данные опоры для карточки (поля как во Flutter)
          if (poleId != null) {
            this.apiService.getPole(poleId).subscribe({
              next: (pole) => {
                Object.assign(this.selectedPole as any, pole, {
                  equipment: (pole as any).equipment || [],
                  connectivity_node: (pole as any).connectivity_node ?? null,
                  latitude: (this.selectedPole as any).latitude ?? (pole as any).y_position,
                  longitude: (this.selectedPole as any).longitude ?? (pole as any).x_position
                });
              }
            });
            this.apiService.getPoleTerminals(poleId).subscribe({
              next: (terms) => {
                (this.selectedPole as any).terminals = terms || [];
              }
            });
          }
        });

        marker.addTo(this.map!);
        this.poleMarkers.push(marker);

        (marker as any).poleData = {
          coordinates: L.latLng(lat, lng),
          poleNumber: feature.properties['pole_number'] || 'N/A'
        };
        (marker as any).poleFeature = feature;
      }
    });
  }

  /**
   * Путь к SVG-ассету для линейного оборудования (те же файлы, что во Flutter).
   */
  private getLineEquipmentAssetPath(iconKey: string, outline = false): string {
    const assetBase = '/assets/equipment';
    if (iconKey === 'breaker' && outline) return `${assetBase}/breaker/breaker_outline.svg`;
    const sub: Record<string, string> = {
      recloser: 'recloser/recloser.svg',
      breaker: 'breaker/breaker.svg',
      zn: 'zn/zn.svg',
      disconnector: 'disconnector/disconnector.svg',
      arrester: 'arrester/arrester.svg'
    };
    return sub[iconKey] ? `${assetBase}/${sub[iconKey]}` : '';
  }

  /** Иконка на линии в цвете напряжения (mask + background), контур выключателя — отдельным слоем. */
  private buildLineEquipmentMarkerHtml(iconKey: string, lineColor: string): string {
    const iconSize = 64;
    const path = this.getLineEquipmentAssetPath(iconKey);
    if (!path) return '';
    const useOutline = iconKey === 'breaker';
    const outlineHtml = useOutline
      ? `<img src="${this.getLineEquipmentAssetPath(iconKey, true)}" class="equipment-on-line-outline" width="${iconSize}" height="${iconSize}" alt="">`
      : '';
    const escapedPath = path.replace(/'/g, "\\'");
    const mainHtml = `<div class="equipment-on-line-img equipment-on-line-fill" style="width:${iconSize}px;height:${iconSize}px;-webkit-mask-image:url('${escapedPath}');mask-image:url('${escapedPath}');-webkit-mask-size:contain;mask-size:contain;-webkit-mask-repeat:no-repeat;mask-repeat:no-repeat;-webkit-mask-position:center;mask-position:center;background-color:${lineColor};"></div>`;
    const recloserBadge = iconKey === 'recloser' ? '<div class="equipment-recloser-badge"></div>' : '';
    return outlineHtml + mainHtml + recloserBadge;
  }

  /**
   * Ключ иконки для оборудования на линии (null = не рисовать на линии).
   * Учитываем русские и английские типы/имена с сервера — как во Flutter и бэкенде.
   */
  private getLineEquipmentIconKey(eq: Equipment): string | null {
    const t = (eq.equipment_type || '').toLowerCase().trim();
    const n = (eq.name || '').toLowerCase();
    const traverseHints = ['траверс', 'traverse', 'cross_arm', 'crossarm', 'т-образ'];
    if (traverseHints.some(h => n.includes(h)) || traverseHints.some(h => t.includes(h))) {
      return null;
    }
    if (t.includes('реклоузер') || n.includes('реклоузер') || t === 'recloser' || n.includes('recloser')) return 'recloser';
    if (t.includes('выключател') || n.includes('выключател') || t === 'breaker' || n.includes('breaker')) return 'breaker';
    if (
      t.includes('зн') ||
      n.includes('зн') ||
      n.includes('zn') ||
      t.includes('заземлен') ||
      n.includes('заземл') ||
      t === 'grounding_switch' ||
      t.includes('grounding') ||
      n.includes('ground')
    ) return 'zn';
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
    ) return 'arrester';
    const noIcon = ['фундамент', 'foundation', 'изолятор', 'траверс', 'грозоотвод', 'грозотрос'];
    if (noIcon.some(x => t.includes(x) || n.includes(x))) return null;
    return null;
  }

  /** Подпись для тултипа/чипа: без «ОПН: ОПН-10», если марка уже содержит тип. */
  equipmentTooltipText(eq: Equipment): string {
    const t = (eq.equipment_type || '').trim();
    const n = (eq.name || '').trim();
    if (!n && !t) return '';
    if (!n) return t;
    if (!t) return n;
    const tl = t.toLowerCase();
    const nl = n.toLowerCase();
    if (nl.startsWith(tl) || (tl.length >= 2 && nl.includes(tl))) return n;
    return `${t}: ${n}`;
  }

  /** Одна строка в карточке опоры (вместо name + дублирующего типа). */
  equipmentChipLine(eq: Equipment): string {
    return this.equipmentTooltipText(eq) || '—';
  }

  private toViewBoxPoint(iconKey: string, p: [number, number]): [number, number] {
    const spec = this.equipmentTerminalSpec[iconKey];
    if (!spec) return p;
    let x = p[0];
    let y = p[1];
    const localRotateDeg = spec.localRotateDeg ?? 0;
    if (localRotateDeg !== 0) {
      const a = localRotateDeg * Math.PI / 180;
      const cosA = Math.cos(a);
      const sinA = Math.sin(a);
      const rx = x * cosA - y * sinA;
      const ry = x * sinA + y * cosA;
      x = rx;
      y = ry;
    }
    if (!spec.localOriginToViewBox) return [x, y];
    return [x + spec.localOriginToViewBox[0], y + spec.localOriginToViewBox[1]];
  }

  private rotatePointAround(px: number, py: number, cx: number, cy: number, angleRad: number): [number, number] {
    const dx = px - cx;
    const dy = py - cy;
    const cosA = Math.cos(angleRad);
    const sinA = Math.sin(angleRad);
    return [cx + dx * cosA - dy * sinA, cy + dx * sinA + dy * cosA];
  }

  private poleOrderFromNumber(poleNumber: any): number {
    const raw = (poleNumber ?? '').toString().trim();
    if (!raw) return Number.MAX_SAFE_INTEGER;
    if (!raw.includes('/')) {
      const n = Number(raw);
      return Number.isFinite(n) ? n : Number.MAX_SAFE_INTEGER;
    }
    const parts = raw.split('/');
    if (parts.length < 2) return Number.MAX_SAFE_INTEGER;
    const n = Number(parts[1].trim());
    return Number.isFinite(n) ? n : Number.MAX_SAFE_INTEGER;
  }

  private tapRootFromPoleNumber(poleNumber: any): string | null {
    const raw = String(poleNumber ?? '').trim();
    if (!raw.includes('/')) return null;
    const root = raw.split('/')[0]?.trim();
    return root ? root : null;
  }

  // Единый ключ ветки: если нет tap_branch_index, используем корень N из номера N/M,
  // чтобы ветки 3/1 и 3/2 не сливались в Angular в одну.
  private branchKeyFromPole(lineId: any, tapPoleId: any, tapBranchIndex: any, poleNumber: any): string | null {
    const lid = Number(lineId);
    if (!Number.isFinite(lid)) return null;
    const tapIdNum = tapPoleId == null ? null : Number(tapPoleId);
    const tapId = Number.isFinite(tapIdNum as number) ? tapIdNum : null;
    const branchNum = tapBranchIndex == null ? null : Number(tapBranchIndex);
    if (tapId != null) {
      if (Number.isFinite(branchNum as number)) {
        return `${lid}:${tapId}:b:${branchNum}`;
      }
      const root = this.tapRootFromPoleNumber(poleNumber);
      if (root) {
        return `${lid}:${tapId}:r:${root}`;
      }
      return `${lid}:${tapId}:b:1`;
    }
    return `${lid}:main:0`;
  }

  private viewBoxPointToIconPixels(iconKey: string, p: [number, number], iconSize: number): [number, number] {
    const spec = this.equipmentTerminalSpec[iconKey];
    if (!spec) return [iconSize / 2, iconSize / 2];

    const [minX, minY, vbW, vbH] = spec.viewBox;
    const scale = Math.min(iconSize / vbW, iconSize / vbH);
    const drawW = vbW * scale;
    const drawH = vbH * scale;
    const offsetX = (iconSize - drawW) / 2;
    const offsetY = (iconSize - drawH) / 2;

    const [vxRaw, vyRaw] = this.toViewBoxPoint(iconKey, p);
    let px = offsetX + (vxRaw - minX) * scale;
    let py = offsetY + (vyRaw - minY) * scale;

    const iconScale = spec.iconScale ?? 1;
    if (iconScale !== 1) {
      const cx = iconSize / 2;
      const cy = iconSize / 2;
      px = cx + (px - cx) * iconScale;
      py = cy + (py - cy) * iconScale;
    }
    return [px, py];
  }

  /**
   * Пиксели точки anchor в div 64×64 до CSS rotate.
   * Маркер: iconAnchor = эти координаты, transform-origin = туда же, rotate() — вокруг полюса на линии,
   * поэтому не вращаем anchor вокруг центра иконки (иначе полюс «уезжает» с трассы).
   */
  private getRotatedAnchorPx(iconKey: string, _lineAngleRad: number, iconSize: number): [number, number] {
    const spec = this.equipmentTerminalSpec[iconKey];
    const center: [number, number] = [iconSize / 2, iconSize / 2];
    if (!spec) return center;
    const anchorVb = spec.anchor ?? null;
    if (!anchorVb) return center;
    return this.viewBoxPointToIconPixels(iconKey, anchorVb, iconSize);
  }

  private getIconRotationDeg(iconKey: string, lineAngleDeg: number): number {
    const spec = this.equipmentTerminalSpec[iconKey];
    const extra = spec?.rotationOffsetDeg ?? 0;
    return lineAngleDeg + extra;
  }

  private modelAngleRadForIcon(iconKey: string, lineAngleRad: number): number {
    // Для разъединителя фиксируем осевой угол (без направления p1->p2),
    // чтобы на всех линиях символ выглядел одинаково.
    if (iconKey === 'disconnector') {
      let a = lineAngleRad % Math.PI;
      if (a < 0) a += Math.PI;
      return a;
    }
    return lineAngleRad;
  }

  /**
   * Угол пролёта в экранных координатах: всегда от опоры с меньшим id к большему
   * (совпадает с Flutter — одна «сторона» символа относительно трассы).
   */
  private screenLineAngleRadCanonical(p1: GeoJSONFeature, p2: GeoJSONFeature, mapRef: L.Map): number {
    const id1 = Number(p1.properties?.['id']);
    const id2 = Number(p2.properties?.['id']);
    const swap = Number.isFinite(id1) && Number.isFinite(id2) && id1 > id2;
    const plow = swap ? p2 : p1;
    const phigh = swap ? p1 : p2;
    const cl = plow.geometry?.coordinates as number[] | undefined;
    const ch = phigh.geometry?.coordinates as number[] | undefined;
    if (!cl?.length || !ch?.length) {
      const c1 = p1.geometry?.coordinates as number[] | undefined;
      const c2 = p2.geometry?.coordinates as number[] | undefined;
      if (!c1?.length || !c2?.length) return 0;
      const s1 = mapRef.latLngToContainerPoint(L.latLng(Number(c1[1]), Number(c1[0])));
      const s2 = mapRef.latLngToContainerPoint(L.latLng(Number(c2[1]), Number(c2[0])));
      return Math.atan2(s2.y - s1.y, s2.x - s1.x);
    }
    const pLowScreen = mapRef.latLngToContainerPoint(L.latLng(Number(cl[1]), Number(cl[0])));
    const pHighScreen = mapRef.latLngToContainerPoint(L.latLng(Number(ch[1]), Number(ch[0])));
    return Math.atan2(pHighScreen.y - pLowScreen.y, pHighScreen.x - pLowScreen.x);
  }

  private latLngDist2(a: L.LatLng, b: L.LatLng): number {
    const dLat = a.lat - b.lat;
    const dLng = a.lng - b.lng;
    return dLat * dLat + dLng * dLng;
  }

  /**
   * Вычисляет координаты полюсов оборудования в карте (lat/lng).
   * Точки терминалов берём из явной SVG-спецификации (viewBox + t1/t2),
   * затем поворачиваем на угол пролёта и проецируем в карту.
   */
  private getEquipmentTerminalsLatLng(
    center: L.LatLng,
    iconKey: string,
    lineAngleRad: number
  ): L.LatLng[] {
    const spec = this.equipmentTerminalSpec[iconKey];
    if (!spec) {
      return [center];
    }
    if (!this.map) return [center];
    const iconSize = 64;
    const centerPx = this.map.latLngToContainerPoint(center);

    const t1PxLocal = this.viewBoxPointToIconPixels(iconKey, spec.t1, iconSize);
    const t2Raw = spec.t2 ?? null;
    const t2PxLocal = t2Raw ? this.viewBoxPointToIconPixels(iconKey, t2Raw, iconSize) : null;

    const angle = lineAngleRad + ((spec.rotationOffsetDeg ?? 0) * Math.PI / 180);
    const c = iconSize / 2;

    const [t1xRot, t1yRot] = this.rotatePointAround(t1PxLocal[0], t1PxLocal[1], c, c, angle);
    const t1Px = L.point(centerPx.x + (t1xRot - c), centerPx.y + (t1yRot - c));
    const t1 = this.map.containerPointToLatLng(t1Px);

    if (!t2PxLocal) return [t1];

    const [t2xRot, t2yRot] = this.rotatePointAround(t2PxLocal[0], t2PxLocal[1], c, c, angle);
    const t2Px = L.point(centerPx.x + (t2xRot - c), centerPx.y + (t2yRot - c));
    const t2 = this.map.containerPointToLatLng(t2Px);

    return [t1, t2];
  }

  /** Оборудование на пролёте (p1→p2): у первой опоры линии — включаем её ТОЛЬКО на первом пролёте. */
  private combinedLineEquipmentForSegment(
    p1: GeoJSONFeature,
    p2: GeoJSONFeature,
    isFirstSegmentOfLine: boolean
  ): Equipment[] {
    const sortEq = (list: Equipment[]) =>
      list
        .map((eq) => ({ eq, key: this.getLineEquipmentIconKey(eq) }))
        .filter((x) => x.key != null)
        .sort((a, b) => (a.eq.id ?? 0) - (b.eq.id ?? 0))
        .map((x) => x.eq);
    const id1 = Number(p1.properties?.['id']);
    const id2 = Number(p2.properties?.['id']);
    const fromP1 = isFirstSegmentOfLine
      ? sortEq(this.equipmentByPoleId.get(id1) || [])
      : [];
    const fromP2 = sortEq(this.equipmentByPoleId.get(id2) || []);
    return [...fromP1, ...fromP2].sort((a, b) => (a.id ?? 0) - (b.id ?? 0));
  }

  /** Равномерно по длине пролёта: t = (j+1)/(n+1), без скученности у опор. */
  private tUniformOnSegment(j: number, n: number): number {
    if (n <= 0) return 0.5;
    return (j + 1) / (n + 1);
  }

  /**
   * Вычисляет координаты центра иконки оборудования на карте (для центрирования при клике по дереву).
   * Совпадает с отрисовкой: сегмент пролёта, объединённый список оборудования, t = (j+1)/(n+1).
   */
  private getEquipmentCenterLatLng(poleId: number, equipmentId: number): L.LatLng | null {
    const data = this.mapData;
    if (!data?.poles?.features?.length || !data?.powerLinesList?.length) return null;
    const poleFeature = data.poles.features.find(
      (f: GeoJSONFeature) => f.properties?.['id'] != null && Number(f.properties['id']) === poleId
    );
    if (!poleFeature?.geometry || poleFeature.geometry.type !== 'Point') return null;
    const lineId = this.lineIdFromProps(poleFeature.properties as Record<string, any> | undefined);
    if (lineId == null) return null;
    const polesForLine = data.poles.features.filter(
      (f: GeoJSONFeature) => this.lineIdFromProps(f.properties as Record<string, any> | undefined) == lineId
    );
    const byId = new Map<number, GeoJSONFeature>();
    polesForLine.forEach((f: GeoJSONFeature) => {
      const id = f.properties?.['id'];
      if (id != null && !byId.has(Number(id))) byId.set(Number(id), f);
    });
    const orderedPoles = Array.from(byId.values()).sort((a, b) => {
      const sa = Number(a.properties?.['sequence_number']);
      const sb = Number(b.properties?.['sequence_number']);
      if (Number.isFinite(sa) && Number.isFinite(sb) && sa !== sb) return sa - sb;
      const oa = this.poleOrderFromNumber(a.properties?.['pole_number']);
      const ob = this.poleOrderFromNumber(b.properties?.['pole_number']);
      if (oa !== ob) return oa - ob;
      return String(a.properties?.['pole_number'] ?? '').localeCompare(String(b.properties?.['pole_number'] ?? ''));
    });
    if (orderedPoles.length < 2) {
      const c = poleFeature.geometry?.coordinates as number[] | undefined;
      if (!c?.length || c.length < 2) return null;
      return L.latLng(Number(c[1]), Number(c[0]));
    }
    for (let i = 0; i < orderedPoles.length - 1; i++) {
      const p1 = orderedPoles[i];
      const p2 = orderedPoles[i + 1];
      const combined = this.combinedLineEquipmentForSegment(p1, p2, i === 0);
      const idx = combined.findIndex((eq) => eq.id != null && Number(eq.id) === equipmentId);
      if (idx < 0) continue;
      const c1 = p1.geometry?.coordinates as number[] | undefined;
      const c2 = p2.geometry?.coordinates as number[] | undefined;
      if (!c1?.length || !c2?.length) return null;
      const lng1 = Number(c1[0]);
      const lat1 = Number(c1[1]);
      const lng2 = Number(c2[0]);
      const lat2 = Number(c2[1]);
      const dx = lng2 - lng1;
      const dy = lat2 - lat1;
      const n = combined.length;
      const t = this.tUniformOnSegment(idx, n);
      const lng = lng1 + dx * t;
      const lat = lat1 + dy * t;
      return L.latLng(lat, lng);
    }
    const c = poleFeature.geometry?.coordinates as number[] | undefined;
    if (!c?.length || c.length < 2) return null;
    return L.latLng(Number(c[1]), Number(c[0]));
  }

  /**
   * Строит список точек сегмента для отрисовки линии: опора1 → полюса оборудования → (опора2 не включается, добавляется при склейке).
   * Соединения: опора → T1 первого оборудования → T2 → T1 следующего → ... → опора2.
   */
  private buildSegmentConnectionPaths(
    p1: GeoJSONFeature,
    p2: GeoJSONFeature,
    segmentIndex: number,
    _lineId: number
  ): L.LatLng[][] {
    if (!this.map) return [];
    const c1 = p1.geometry?.coordinates as number[] | undefined;
    const c2 = p2.geometry?.coordinates as number[] | undefined;
    if (!c1?.length || !c2?.length) return [];
    const lng1 = c1[0] as number;
    const lat1 = c1[1] as number;
    const lng2 = c2[0] as number;
    const lat2 = c2[1] as number;
    const dx = lng2 - lng1;
    const dy = lat2 - lat1;
    const lineAngleScreen = this.screenLineAngleRadCanonical(p1, p2, this.map);

    const paths: L.LatLng[][] = [];
    let currentPoint = L.latLng(lat1, lng1);

    const combined = this.combinedLineEquipmentForSegment(p1, p2, segmentIndex === 0);
    const n = combined.length;
    combined.forEach((eq, j) => {
      const iconKey = this.getLineEquipmentIconKey(eq);
      if (!iconKey) return;
      const t = this.tUniformOnSegment(j, n);
      const lng = lng1 + dx * t;
      const lat = lat1 + dy * t;
      const center = L.latLng(lat, lng);
      const lineAngleRad = this.modelAngleRadForIcon(
        iconKey,
        lineAngleScreen,
      );
      let terminals = this.getEquipmentTerminalsLatLng(center, iconKey, lineAngleRad);
      if (terminals.length >= 2 && this.latLngDist2(currentPoint, terminals[0]) > this.latLngDist2(currentPoint, terminals[1])) {
        terminals = [terminals[1], terminals[0]];
      }
      if (terminals.length >= 2) {
        // Для двухполюсного оборудования не рисуем провод между T1 и T2:
        // рисуем только до T1 и продолжаем от T2.
        paths.push([currentPoint, terminals[0]]);
        currentPoint = terminals[1];
      } else {
        // Для однотерминального оборудования (например, ЗН/разрядник по вашей спецификации)
        // не делаем излом линии: магистраль остаётся прямой между опорами.
        // Смещается только маркер оборудования (через anchor/terminal), без изменения траектории провода.
      }
    });
    paths.push([currentPoint, L.latLng(lat2, lng2)]);
    return paths;
  }

  /**
   * Оборудование между опорами — логика как во Flutter: по списку ЛЭП и опорам с line_id,
   * одна цепочка опор на линию, сегменты между соседними, оборудование без дублей.
   */
  private renderEquipmentBetweenPoles(
    polesFeatures: GeoJSONFeature[],
    powerLinesList: { id: number; voltage_level?: number | null }[]
  ): void {
    if (!this.map || !polesFeatures?.length) return;
    const mapRef = this.map;

    this.equipmentGeoJsonMarkers.forEach(m => this.map?.removeLayer(m));
    this.equipmentGeoJsonMarkers = [];

    const poleByIdGlobal = new Map<number, GeoJSONFeature>();
    polesFeatures.forEach((f: GeoJSONFeature) => {
      const pid = f.properties?.['id'];
      if (pid != null) poleByIdGlobal.set(Number(pid), f);
    });

    // Для каждой линии pl группируем опоры по веткам (магистраль/отпайки),
    // чтобы не смешивать соседство опор из разных веток.
    const polesByBranchKey = new Map<string, GeoJSONFeature[]>();
    polesFeatures.forEach((f: GeoJSONFeature) => {
      if (f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      const lineId = this.lineIdFromProps(f.properties as Record<string, any> | undefined);
      if (lineId == null) return;
      const tapPoleIdRaw = f.properties?.['tap_pole_id'];
      const tapBranchIndexRaw = f.properties?.['tap_branch_index'];
      const k = this.branchKeyFromPole(lineId, tapPoleIdRaw, tapBranchIndexRaw, f.properties?.['pole_number']);
      if (!k) return;
      if (!polesByBranchKey.has(k)) polesByBranchKey.set(k, []);
      polesByBranchKey.get(k)!.push(f);
    });

    powerLinesList.forEach((pl) => {
      const branchEntries = Array.from(polesByBranchKey.entries()).filter(([k]) => k.startsWith(`${pl.id}:`));
      branchEntries.forEach(([branchKey, branchPoles]) => {
        let poles = branchPoles;
        const byId = new Map<number, GeoJSONFeature>();
        poles.forEach((f: GeoJSONFeature) => {
          const id = f.properties?.['id'];
          if (id != null && !byId.has(Number(id))) byId.set(Number(id), f);
        });
        poles = Array.from(byId.values()).sort((a, b) => {
          const sa = Number(a.properties?.['sequence_number']);
          const sb = Number(b.properties?.['sequence_number']);
          if (Number.isFinite(sa) && Number.isFinite(sb) && sa !== sb) return sa - sb;
          const oa = this.poleOrderFromNumber(a.properties?.['pole_number']);
          const ob = this.poleOrderFromNumber(b.properties?.['pole_number']);
          if (oa !== ob) return oa - ob;
          return String(a.properties?.['pole_number'] ?? '').localeCompare(String(b.properties?.['pole_number'] ?? ''));
        });
        // Отпайка: в списке только опоры ветки (3/1, 3/2…), якорь (опора 3) в другом ключе — добавляем для сегмента 3→3/1 и оборудования на нём.
        const keyParts = branchKey.split(':');
        if (keyParts[1] !== 'main') {
          const anchorId = Number(keyParts[1]);
          if (Number.isFinite(anchorId)) {
            const firstId = Number(poles[0]?.properties?.['id']);
            if (firstId !== anchorId) {
              const anchorFeat = poleByIdGlobal.get(anchorId);
              if (anchorFeat) {
                poles = [anchorFeat, ...poles];
              }
            }
          }
        }
        if (poles.length < 2) return;

        for (let i = 0; i < poles.length - 1; i++) {
          const p1 = poles[i];
          const p2 = poles[i + 1];
        const c1 = p1.geometry?.coordinates as number[] | undefined;
        const c2 = p2.geometry?.coordinates as number[] | undefined;
        if (!c1?.length || !c2?.length) continue;

        const lng1 = Number(c1[0]);
        const lat1 = Number(c1[1]);
        const lng2 = Number(c2[0]);
        const lat2 = Number(c2[1]);
        const dx = lng2 - lng1;
        const dy = lat2 - lat1;
        const lineAngleBaseRad = this.screenLineAngleRadCanonical(p1, p2, mapRef);
        const iconSize = 64;
        const iconAnchorCenter = iconSize / 2;
        const getIconRotation = (iconKey: string) => {
          const modelAngleRad = this.modelAngleRadForIcon(iconKey, lineAngleBaseRad);
          const modelAngleDeg = modelAngleRad * 180 / Math.PI;
          return this.getIconRotationDeg(iconKey, modelAngleDeg);
        };
        const getIconAnchor = (_iconKey: string): [number, number] => [iconAnchorCenter, iconAnchorCenter];
        const lineColor = colorForVoltageKv(
          pl.voltage_level != null && !Number.isNaN(Number(pl.voltage_level)) ? Number(pl.voltage_level) : NaN
        );
        const combined = this.combinedLineEquipmentForSegment(p1, p2, i === 0);
        const nEq = combined.length;
        const lineId = pl.id;

        combined.forEach((eq, j) => {
          const iconKey = this.getLineEquipmentIconKey(eq);
          if (!iconKey) return;
          const hasDefect = this.hasEquipmentDefect(eq);
          if (this.showOnlyDefective && !hasDefect) return;
          const eqCriticality = this.normalizeCriticality((eq as any).criticality);
          const t = this.tUniformOnSegment(j, nEq);
          const lng = lng1 + dx * t;
          const lat = lat1 + dy * t;
          const centerLatLng = L.latLng(lat, lng);
          const modelAngleRad = this.modelAngleRadForIcon(iconKey, lineAngleBaseRad);
          const terminals = this.getEquipmentTerminalsLatLng(centerLatLng, iconKey, modelAngleRad);
          const isSingleTerminal = terminals.length === 1;
          const poleIdForClick = Number(eq.pole_id);
          const poleFeature =
            (!Number.isNaN(poleIdForClick) &&
              (poles.find((pf) => Number(pf.properties?.['id']) === poleIdForClick) ||
                poleByIdGlobal.get(poleIdForClick))) ||
            p2;
          const inner = this.buildLineEquipmentMarkerHtml(iconKey, lineColor);
          const rot = getIconRotation(iconKey);
          const anchor = isSingleTerminal
            ? this.getRotatedAnchorPx(iconKey, modelAngleRad, iconSize)
            : getIconAnchor(iconKey);
          const transformOrigin = `${anchor[0]}px ${anchor[1]}px`;
          const equipmentDefectBadge = hasDefect
            ? `<div class="map-defect-badge map-defect-badge--${eqCriticality ?? 'none'}">!</div>`
            : '';
          const defectClass = hasDefect ? ` equipment-geojson-marker--defect equipment-geojson-marker--${eqCriticality ?? 'none'}` : '';
          const html = `<div class="equipment-geojson-marker equipment-on-line${defectClass}" style="transform: rotate(${rot}deg); transform-origin: ${transformOrigin}; width: ${iconSize}px; height: ${iconSize}px; position: relative; display: flex; align-items: center; justify-content: center;">${inner}${equipmentDefectBadge}</div>`;
          // Для однотерминального оборудования линия остаётся прямой:
          // на ось пролёта ставим именно терминал (через iconAnchor/transform-origin),
          // а не переносим сам маркер с центра.
          const markerLatLng = centerLatLng;
          const marker = L.marker(markerLatLng, {
            icon: L.divIcon({ className: 'equipment-geojson-icon', html, iconSize: [iconSize, iconSize], iconAnchor: anchor }),
            interactive: true
          });
          marker.bindTooltip(this.equipmentTooltipText(eq), { permanent: false, direction: 'top' });
          (marker as any).poleFeature = poleFeature;
          (marker as any).lineId = lineId;
          marker.on('click', () => {
            const feat = (marker as any).poleFeature as GeoJSONFeature | undefined;
            this.openEquipmentProperties({
              type: 'Feature',
              properties: {
                ...(feat?.properties ?? {}),
                ...eq,
                line_id: lineId
              },
              geometry: feat?.geometry
            } as GeoJSONFeature);
          });
          marker.addTo(this.map!);
          this.equipmentGeoJsonMarkers.push(marker);
          });
        }
      });
    });
  }

  /**
   * Отрисовывает оборудование как отдельные точечные объекты с собственными координатами
   * (не только «поверх» опоры). Если координаты не заданы, оборудование пропускается.
   */
  private renderEquipmentPoints(): void {
    if (!this.map || !this.allEquipment?.length) {
      return;
    }

    // Удаляем старые маркеры оборудования
    this.equipmentPointMarkers.forEach(m => this.map?.removeLayer(m));
    this.equipmentPointMarkers = [];

    this.allEquipment.forEach((eq: Equipment) => {
      const lat = (eq as any).y_position;
      const lng = (eq as any).x_position;
      if (lat == null || lng == null) {
        return;
      }
      // Фундамент не рисуем в точке опоры (как во Flutter — на линии не отображаются)
      const t = (eq.equipment_type || '').toLowerCase();
      const n = (eq.name || '').toLowerCase();
      if (t.includes('фундамент') || t.includes('foundation') || n.includes('фундамент') || n.includes('foundation')) {
        return;
      }
      // Линейное оборудование рисуется только между опорами, не в точке
      if (this.getLineEquipmentIconKey(eq) != null) {
        return;
      }
      const hasDefect = this.hasEquipmentDefect(eq);
      if (this.showOnlyDefective && !hasDefect) {
        return;
      }
      // Не рисуем в точке опоры оборудование без своей иконки (грозоотвод, изолятор, траверс и т.д.) — не дублируем маркер опоры
      const noIconAtPole = ['изолятор', 'траверс', 'грозоотвод', 'грозотрос'];
      if (noIconAtPole.some(x => t.includes(x) || n.includes(x))) {
        return;
      }

      const eqCriticality = this.normalizeCriticality((eq as any).criticality);
      const htmlBase = this.buildEquipmentIconsHtml([eq]);
      const defectBadge = hasDefect
        ? `<div class="map-defect-badge map-defect-badge--${eqCriticality ?? 'none'}">!</div>`
        : '';
      const html = `<div class="equipment-point-wrap equipment-point-wrap--${eqCriticality ?? 'none'} ${hasDefect ? 'equipment-point-wrap--defect' : ''}">${htmlBase}${defectBadge}</div>`;
      if (!html) {
        return;
      }

      const marker = L.marker([Number(lat), Number(lng)], {
        icon: L.divIcon({
          className: 'equipment-point-marker',
          html,
          iconSize: [28, 28],
          iconAnchor: [14, 14]
        }),
        interactive: true
      });
      marker.on('click', () => {
        this.openEquipmentProperties({
          type: 'Feature',
          properties: { ...eq, equipment_id: (eq as any).id },
          geometry: { type: 'Point', coordinates: [Number(lng), Number(lat)] }
        } as GeoJSONFeature);
      });

      marker.addTo(this.map!);
      this.equipmentPointMarkers.push(marker);
    });
  }

  /**
   * Оборудование из GeoJSON (логика как во Flutter): точки между опорами с иконкой и углом поворота.
   */
  private renderEquipmentFromGeoJSON(geoJson: GeoJSONCollection): void {
    if (!this.map || !geoJson?.features?.length) return;

    this.equipmentGeoJsonMarkers.forEach(m => this.map?.removeLayer(m));
    this.equipmentGeoJsonMarkers = [];

    const iconKeyToSvg = (key: string): string => {
      switch (key) {
        case 'recloser': return this.svgRecloser();
        case 'breaker': return this.svgBreaker();
        case 'zn': return this.svgGroundingSwitch();
        case 'disconnector': return this.svgDisconnector();
        case 'arrester': return this.svgSurgeArrester();
        default: return this.svgGenericEquipment();
      }
    };

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry?.type !== 'Point' || !feature.geometry.coordinates?.length) return;
      const props = feature.properties || {};
      const iconKey = props['icon'];
      if (!iconKey) return;

      const coords = feature.geometry.coordinates as number[];
      const lng = Number(coords[0]);
      const lat = Number(coords[1]);
      const angleRad = typeof props['angle_rad'] === 'number' ? props['angle_rad'] : 0;
      const angleDeg = (angleRad * 180 / Math.PI);

      const svg = iconKeyToSvg(iconKey);
      const html = `<div class="equipment-geojson-marker" style="transform: rotate(${angleDeg}deg); width: 32px; height: 32px; display: flex; align-items: center; justify-content: center;">${svg}</div>`;

      const marker = L.marker([lat, lng], {
        icon: L.divIcon({
          className: 'equipment-geojson-icon',
          html,
          iconSize: [32, 32],
          iconAnchor: [16, 16]
        }),
        interactive: true
      });

      const eqType = props['equipment_type'] || '';
      const name = props['name'] || '';
      marker.bindTooltip(`${eqType}${name ? ': ' + name : ''}`, { permanent: false, direction: 'top' });
      marker.on('click', () => {
        this.openEquipmentProperties({
          type: 'Feature',
          properties: { ...props },
          geometry: feature.geometry
        } as GeoJSONFeature);
      });
      marker.addTo(this.map!);
      this.equipmentGeoJsonMarkers.push(marker);
    });
  }

  /** Строит HTML-группу элементов оборудования, рисуемых вдоль линии. */
  private buildEquipmentInlineHtml(equipment: Equipment[]): string {
    if (!equipment || !equipment.length) return '';
    const parts: string[] = [];
    for (const eq of equipment) {
      const t = (eq.equipment_type || '').toLowerCase().trim();
      let cls = 'generic';
      if (t === 'breaker') cls = 'breaker';
      else if (t === 'disconnector') cls = 'disconnector';
      else if (t === 'recloser') cls = 'recloser';
      else if (t === 'grounding_switch') cls = 'grounding';
      else if (t === 'surge_arrester') cls = 'arrester';
      parts.push(`<div class="equipment-inline equipment-inline--${cls}"></div>`);
    }
    return `<div class="equipment-inline-group">${parts.join('')}</div>`;
  }

  /** Строит HTML с маленькими SVG-иконками оборудования на опоре (по типам, без дублей). */
  private buildEquipmentIconsHtml(equipment: Equipment[]): string {
    if (!equipment || !equipment.length) return '';
    const types = Array.from(
      new Set(
        equipment
          .map(eq => (eq.equipment_type || '').toLowerCase().trim())
          .filter(t => !!t)
      )
    );
    const icons: string[] = [];

    const has = (t: string) => types.some(x => x === t);

    if (has('breaker')) {
      icons.push(this.svgBreaker());
    }
    if (has('disconnector')) {
      icons.push(this.svgDisconnector());
    }
    if (has('recloser')) {
      icons.push(this.svgRecloser());
    }
    if (has('grounding_switch')) {
      icons.push(this.svgGroundingSwitch());
    }
    if (has('surge_arrester')) {
      icons.push(this.svgSurgeArrester());
    }

    // Если тип неизвестен, показываем универсальный значок
    if (!icons.length && types.length) {
      icons.push(this.svgGenericEquipment());
    }

    return icons.join('');
  }

  private svgWrapper(path: string): string {
    return `
      <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
        ${path}
      </svg>
    `;
  }

  private svgBreaker(): string {
    // Выключатель: прямоугольник с диагональной линией
    return this.svgWrapper(`
      <rect x="2" y="3" width="12" height="10" rx="2" ry="2" fill="#ffffff" stroke="#1976d2" stroke-width="1.4"/>
      <line x1="4" y1="11" x2="12" y2="5" stroke="#1976d2" stroke-width="1.4" stroke-linecap="round"/>
    `);
  }

  private svgDisconnector(): string {
    // Разъединитель: две клеммы и разомкнутый нож
    return this.svgWrapper(`
      <circle cx="4" cy="8" r="1.3" fill="#ffffff" stroke="#388e3c" stroke-width="1.2"/>
      <circle cx="12" cy="8" r="1.3" fill="#ffffff" stroke="#388e3c" stroke-width="1.2"/>
      <line x1="5.5" y1="6" x2="10.5" y2="10" stroke="#388e3c" stroke-width="1.4" stroke-linecap="round"/>
    `);
  }

  private svgRecloser(): string {
    // Реклозер: круг со стрелкой по окружности
    return this.svgWrapper(`
      <circle cx="8" cy="8" r="4.5" fill="#ffffff" stroke="#f57c00" stroke-width="1.4"/>
      <path d="M5 8a3 3 0 0 1 4.5-2.6" fill="none" stroke="#f57c00" stroke-width="1.2" stroke-linecap="round"/>
      <polyline points="9 4.3 9.5 6.3 7.5 5.8" fill="none" stroke="#f57c00" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
    `);
  }

  private svgGroundingSwitch(): string {
    // Заземляющий нож: вертикальная линия и "земля"
    return this.svgWrapper(`
      <line x1="8" y1="2.5" x2="8" y2="9" stroke="#455a64" stroke-width="1.4" stroke-linecap="round"/>
      <line x1="4" y1="11" x2="12" y2="11" stroke="#455a64" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="5" y1="12.5" x2="11" y2="12.5" stroke="#455a64" stroke-width="1" stroke-linecap="round"/>
    `);
  }

  private svgSurgeArrester(): string {
    // Разрядник: молния
    return this.svgWrapper(`
      <polyline points="6 2 10 2 7 8 10 8 6 14" fill="none" stroke="#e53935" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    `);
  }

  private svgGenericEquipment(): string {
    // Универсальный прямоугольник
    return this.svgWrapper(`
      <rect x="3" y="4" width="10" height="8" rx="2" ry="2" fill="#ffffff" stroke="#616161" stroke-width="1.3"/>
    `);
  }

  /** Открыть диалог создания опоры «от отпаечной» (следующая опора будет по отпайке) */
  openCreatePoleFromTapPole(feature: GeoJSONFeature): void {
    const lineId = this.lineIdFromProps(feature.properties as Record<string, any> | undefined);
    const tapPoleId = feature.properties['id'];
    if (lineId == null || tapPoleId == null) return;
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '520px',
      data: {
        defaultObjectType: 'pole',
        lineId: lineId as number,
        tapPoleId: tapPoleId as number,
        startNewTap: true
      }
    });
    dialogRef.afterClosed().subscribe(() => {
      this.mapService.refreshData();
    });
  }

  /** Открыть диалог «Начать отпайку» от выбранной отпаечной опоры (всегда создаётся новая ветка: 3/1, 3/2 и т.д.) */
  openCreatePoleFromTapPolePanel(): void {
    if (!this.selectedPole || this.selectedPole.is_tap_pole !== true) return;
    const feature: GeoJSONFeature = {
      type: 'Feature',
      properties: this.selectedPole,
      geometry: { type: 'Point', coordinates: [this.selectedPole.longitude ?? 0, this.selectedPole.latitude ?? 0] }
    };
    this.openCreatePoleFromTapPole(feature);
  }

  private renderTapSubstationConnections(
    spansGeoJson: GeoJSONCollection,
    substationsGeoJson?: GeoJSONCollection
  ): void {
    if (!this.map || !spansGeoJson.features) return;

    // Кандидаты соединений «отпайка -> подстанция».
    // Рисуем строго одну связь на подстанцию (самый новый span), чтобы не показывать residual-дубли.
    const chosenBySubstationId = new Map<number, GeoJSONFeature>();
    const substationPoints: Array<{ id: number; lat: number; lng: number }> = [];
    (substationsGeoJson?.features || []).forEach((f: GeoJSONFeature) => {
      if (f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      const id = Number(f.properties?.['id']);
      if (!Number.isFinite(id)) return;
      const c = f.geometry.coordinates as number[];
      substationPoints.push({ id, lat: Number(c[1]), lng: Number(c[0]) });
    });

    const nearestSubstationId = (lat: number, lng: number): number | null => {
      let bestId: number | null = null;
      let bestDist = Number.POSITIVE_INFINITY;
      for (const s of substationPoints) {
        const dLat = s.lat - lat;
        const dLng = s.lng - lng;
        const d2 = dLat * dLat + dLng * dLng;
        if (d2 < bestDist) {
          bestDist = d2;
          bestId = s.id;
        }
      }
      // Порог ~1-1.5 км в градусах, чтобы не притягивать далёкие ПС.
      return bestDist <= 0.0002 ? bestId : null;
    };

    (spansGeoJson.features as GeoJSONFeature[]).forEach((feature: GeoJSONFeature) => {
      const props = feature.properties || {};
      const fromPoleId = props['from_pole_id'];
      const toPoleId = props['to_pole_id'];
      const isTapSeg = props['segment_is_tap'] === true
        || props['branch_type'] === 'tap'
        || props['tap_pole_id'] != null;
      if (fromPoleId == null || toPoleId != null || !isTapSeg) return;

      let sid = props['to_substation_id'] != null ? Number(props['to_substation_id']) : null;
      if (sid == null && feature.geometry?.type === 'LineString') {
        const coords = feature.geometry.coordinates as number[][];
        if (Array.isArray(coords) && coords.length) {
          const end = coords[coords.length - 1];
          sid = nearestSubstationId(Number(end[1]), Number(end[0]));
        }
      }
      if (sid == null || !Number.isFinite(sid)) return;

      const current = chosenBySubstationId.get(sid);
      const curId = Number(current?.properties?.['id'] ?? 0);
      const newId = Number(props['id'] ?? 0);
      if (!current || newId > curId) {
        chosenBySubstationId.set(sid, feature);
      }
    });

    Array.from(chosenBySubstationId.values()).forEach((feature: GeoJSONFeature) => {
      if (feature.geometry?.type !== 'LineString') return;
      const props = feature.properties || {};
      const fromPoleId = props['from_pole_id'];
      const toPoleId = props['to_pole_id'];
      // Нас интересуют пролёты «опора → подстанция» (to_pole_id == null)
      if (fromPoleId == null || toPoleId != null) return;
      const coords = feature.geometry.coordinates as number[][];
      if (!Array.isArray(coords) || coords.length < 2) return;
      const latlngs = coords.map(c => [c[1], c[0]] as L.LatLngExpression);
      const vlRaw = Number(props['voltage_level']);
      const line = L.polyline(latlngs, {
        color: colorForVoltageKv(Number.isFinite(vlRaw) ? vlRaw : null),
        weight: lineWeightForBranch(true),
        opacity: 0.85,
        dashArray: '6, 6'
      });
      line.addTo(this.map!);
      this.substationConnectionLayers.push(line);
    });
  }

  renderTaps(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
        const coordinates = feature.geometry.coordinates as number[];
        const latlng = L.latLng(Number(coordinates[1]), Number(coordinates[0]));
        
        const vl = Number(feature.properties['voltage_level']);
        const tapBg = colorForVoltageKv(Number.isFinite(vl) ? vl : null);
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'tap-marker',
            html: `<div style="background-color: ${tapBg}; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white;"></div>`,
            iconSize: [20, 20],
            iconAnchor: [10, 10]
          })
        }).bindPopup(`
          <strong>Отпайка ${feature.properties['tap_number'] || 'N/A'}</strong><br>
          Тип: ${feature.properties['tap_type'] || 'N/A'}<br>
          Напряжение: ${feature.properties['voltage_level'] || 'N/A'} кВ
        `);

        marker.addTo(this.map!);
        this.tapMarkers.push(marker);
      }
    });
  }

  renderSubstations(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
        const coordinates = feature.geometry.coordinates as number[];
        const latlng = L.latLng(Number(coordinates[1]), Number(coordinates[0]));
        
        const vl = Number(feature.properties['voltage_level']);
        const subBg = colorForVoltageKv(Number.isFinite(vl) ? vl : null);
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'substation-marker',
            html: `<div style="background-color: ${subBg}; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white;"></div>`,
            iconSize: [20, 20],
            iconAnchor: [10, 10]
          })
        });
        const subName = feature.properties?.['name'] || feature.properties?.['dispatcher_name'] || 'Подстанция';
        marker.bindTooltip(String(subName), {
          permanent: true,
          direction: 'bottom',
          offset: [0, 12],
          className: 'substation-name-label'
        });

        marker.on('click', () => {
          // Центрируем карту на подстанции и сообщаем sidebar выбрать её в дереве
          this.centerOnPole(latlng.lat, latlng.lng, 16);
          const substationId = feature.properties['id'];
          if (substationId != null) {
            this.mapService.requestSelectSubstationInTree(Number(substationId));
          }
        });

        marker.addTo(this.map!);
        this.substationMarkers.push(marker);
      }
    });
  }

  /** Рисует линии от подстанции до первой/последней опоры ЛЭП, если подстанция привязана как начало или конец линии. */
  renderSubstationConnections(data: MapData): void {
    if (!this.map || !data.powerLinesList || !data.substations?.features?.length || !data.poles?.features?.length) return;
    // Если ПС уже выступает концом отпайки (tap), не рисуем для неё магистральные
    // связи start/end, чтобы избежать визуальных дублей "ПС связана сразу с несколькими линиями".
    const tapEndSubstationIds = new Set<number>();
    (data.spans?.features || []).forEach((f: GeoJSONFeature) => {
      const p = f.properties || {};
      const isTapSpanToSubstation =
        p['segment_is_tap'] === true &&
        p['from_pole_id'] != null &&
        p['to_pole_id'] == null &&
        p['to_substation_id'] != null;
      if (isTapSpanToSubstation) {
        tapEndSubstationIds.add(Number(p['to_substation_id']));
      }
    });

    const substationById = new Map<number, GeoJSONFeature>();
    data.substations.features.forEach((f: GeoJSONFeature) => {
      const id = f.properties?.['id'];
      if (id != null) substationById.set(Number(id), f);
    });

    const polesByLine = new Map<number, GeoJSONFeature[]>();
    data.poles.features.forEach((f: GeoJSONFeature) => {
      const lineId = this.lineIdFromProps(f.properties as Record<string, any> | undefined);
      const tapId = f.properties?.['tap_pole_id'] ?? null;
      if (lineId == null || tapId != null) return; // только магистраль (без отпаек)
      if (f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      if (!polesByLine.has(lineId)) polesByLine.set(lineId, []);
      polesByLine.get(lineId)!.push(f);
    });
    polesByLine.forEach(poles => {
      poles.sort((a, b) => (a.properties?.['sequence_number'] ?? 0) - (b.properties?.['sequence_number'] ?? 0));
    });

    data.powerLinesList.forEach((pl: { id: number; name?: string; substation_start_id?: number | null; substation_end_id?: number | null; voltage_level?: number | null }) => {
      const lineId = pl.id;
      const poles = polesByLine.get(lineId);
      if (!poles?.length) return;

      const firstPole = poles[0];
      const lastPole = poles[poles.length - 1];
      const getPoleLatLng = (p: GeoJSONFeature): L.LatLngExpression | null => {
        const c = p.geometry?.coordinates as number[] | undefined;
        if (!c || c.length < 2) return null;
        return [c[1], c[0]];
      };

      if (pl.substation_start_id != null) {
        if (tapEndSubstationIds.has(Number(pl.substation_start_id))) {
          // Эта ПС уже привязана как конец отпайки — не дублируем магистральной связью.
          return;
        }
        const sub = substationById.get(pl.substation_start_id);
        if (sub?.geometry?.type === 'Point' && sub.geometry.coordinates?.length >= 2) {
          const subCoords = sub.geometry.coordinates as number[];
          const subLatLng: L.LatLngExpression = [subCoords[1], subCoords[0]];
          const poleLatLng = getPoleLatLng(firstPole);
          if (poleLatLng) {
            const vlRaw = pl.voltage_level != null ? Number(pl.voltage_level) : NaN;
            const line = L.polyline([subLatLng, poleLatLng], {
              color: colorForVoltageKv(Number.isFinite(vlRaw) ? vlRaw : null),
              weight: lineWeightForBranch(false),
              opacity: 0.85,
              dashArray: '6, 6'
            }).bindPopup(`Подстанция → ЛЭП «${pl.name ?? lineId}»`);
            line.addTo(this.map!);
            this.substationConnectionLayers.push(line);
          }
        }
      }
      if (pl.substation_end_id != null && pl.substation_end_id !== pl.substation_start_id) {
        if (tapEndSubstationIds.has(Number(pl.substation_end_id))) {
          return;
        }
        const sub = substationById.get(pl.substation_end_id);
        if (sub?.geometry?.type === 'Point' && sub.geometry.coordinates?.length >= 2) {
          const subCoords = sub.geometry.coordinates as number[];
          const subLatLng: L.LatLngExpression = [subCoords[1], subCoords[0]];
          const poleLatLng = getPoleLatLng(lastPole);
          if (poleLatLng) {
            const vlRaw = pl.voltage_level != null ? Number(pl.voltage_level) : NaN;
            const line = L.polyline([poleLatLng, subLatLng], {
              color: colorForVoltageKv(Number.isFinite(vlRaw) ? vlRaw : null),
              weight: lineWeightForBranch(false),
              opacity: 0.85,
              dashArray: '6, 6'
            }).bindPopup(`ЛЭП «${pl.name ?? lineId}» → Подстанция`);
            line.addTo(this.map!);
            this.substationConnectionLayers.push(line);
          }
        }
      }
    });
  }

  clearLayers(): void {
    this.powerLineLayers.forEach(layer => this.map?.removeLayer(layer));
    this.substationConnectionLayers.forEach(layer => this.map?.removeLayer(layer));
    this.poleMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.poleLabels.forEach(label => this.map?.removeLayer(label));
    this.tapMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.substationMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.equipmentMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.equipmentPointMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.equipmentGeoJsonMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.clearSegmentHighlight();

    this.powerLineLayers = [];
    this.substationConnectionLayers = [];
    this.poleMarkers = [];
    this.poleLabels = [];
    this.tapMarkers = [];
    this.substationMarkers = [];
    this.equipmentMarkers = [];
    this.equipmentPointMarkers = [];
    this.equipmentGeoJsonMarkers = [];
  }

  private clearSegmentHighlight(): void {
    this.segmentHighlightLayers.forEach(layer => this.map?.removeLayer(layer));
    this.segmentHighlightLayers = [];
  }

  private renderSegmentHighlight(): void {
    if (!this.map || !this.mapData || !this.selectedSegment) return;
    this.clearSegmentHighlight();
    const { lineId, segmentId } = this.selectedSegment;

    const poles = (this.mapData.poles?.features || []).filter((f: GeoJSONFeature) => {
      const pl = this.lineIdFromProps(f.properties as Record<string, any> | undefined);
      const seg = f.properties?.['segment_id'] ?? f.properties?.['acline_segment_id'];
      return pl === lineId && (segmentId === null ? seg == null : seg === segmentId);
    });
    const spans = (this.mapData.spans?.features || []).filter((f: GeoJSONFeature) => {
      const pl = this.lineIdFromProps(f.properties as Record<string, any> | undefined);
      const seg = f.properties?.['segment_id'] ?? f.properties?.['acline_segment_id'];
      return pl === lineId && (segmentId === null ? seg == null : seg === segmentId);
    });

    spans.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'LineString') {
        const fromId = feature.properties?.['from_pole_id'];
        const toId = feature.properties?.['to_pole_id'];
        let latlngs: L.LatLngExpression[];
        if (fromId != null && toId != null && poles.length >= 2) {
          const fromPole = poles.find((f: GeoJSONFeature) => f.properties?.['id'] === fromId);
          const toPole = poles.find((f: GeoJSONFeature) => f.properties?.['id'] === toId);
          if (fromPole?.geometry?.type === 'Point' && toPole?.geometry?.type === 'Point') {
            const c1 = fromPole.geometry.coordinates as number[];
            const c2 = toPole.geometry.coordinates as number[];
            latlngs = [[c1[1], c1[0]], [c2[1], c2[0]]];
          } else {
            const coords = feature.geometry.coordinates as number[][];
            latlngs = coords.map(c => [c[1], c[0]] as L.LatLngExpression);
          }
        } else {
          const coords = feature.geometry.coordinates as number[][];
          latlngs = coords.map(c => [c[1], c[0]] as L.LatLngExpression);
        }
        const outline = L.polyline(latlngs, { color: '#000', weight: 8, opacity: 0.8 });
        const fill = L.polyline(latlngs, { color: '#f44336', weight: 3, opacity: 0.9 });
        outline.addTo(this.map!);
        fill.addTo(this.map!);
        this.segmentHighlightLayers.push(outline, fill);
      }
    });
    // Круги на опорах при подсветке участка не рисуем — оставляем только подсветку линии
  }

  updatePoleLabels(): void {
    if (!this.map) return;

    // Удаляем старые подписи
    this.poleLabels.forEach(label => this.map?.removeLayer(label));
    this.poleLabels = [];

    // Показываем подписи только при зуме от 15 до 20; позиция берётся из маркера (getLatLng), чтобы не съезжало при зуме
    if (this.currentZoom >= 15 && this.currentZoom <= 20) {
      this.poleMarkers.forEach(marker => {
        const poleData = (marker as any).poleData;
        if (poleData) {
          const latlng = marker.getLatLng();
          const label = L.marker(latlng, {
            icon: L.divIcon({
              className: 'pole-label',
              html: `<div class="pole-label-text">${poleData.poleNumber}</div>`,
              iconSize: [100, 20],
              iconAnchor: [50, 0]
            }),
            interactive: false,
            zIndexOffset: -1000
          });
          label.addTo(this.map!);
          this.poleLabels.push(label);
        }
      });
    }
  }

  /** Показывать оборудование при зуме >= minZoomToShowEquipment; скрывать при отдалении ниже порога. */
  private updateEquipmentVisibility(): void {
    if (!this.map) return;
    const threshold = (environment.map as any).minZoomToShowEquipment ?? 14;
    const show = this.currentZoom >= threshold;
    this.equipmentGeoJsonMarkers.forEach(m => {
      if (show) { if (!this.map!.hasLayer(m)) m.addTo(this.map!); }
      else { this.map!.removeLayer(m); }
    });
    this.equipmentPointMarkers.forEach(m => {
      if (show) { if (!this.map!.hasLayer(m)) m.addTo(this.map!); }
      else { this.map!.removeLayer(m); }
    });
  }

  onToggleDefectFilter(value: boolean): void {
    this.showOnlyDefective = !!value;
    if (this.mapData) {
      this.renderMapData(this.mapData);
    }
  }

  private normalizeCriticality(value: any): 'high' | 'medium' | 'low' | null {
    if (value == null) return null;
    const v = String(value).trim().toLowerCase();
    if (!v) return null;
    if (v === 'high' || v === 'critical' || v === 'высокая' || v === 'высокий') return 'high';
    if (v === 'medium' || v === 'med' || v === 'средняя' || v === 'средний') return 'medium';
    if (v === 'low' || v === 'низкая' || v === 'низкий') return 'low';
    return null;
  }

  private criticalityColor(criticality: 'high' | 'medium' | 'low' | null): string {
    if (criticality === 'high') return '#D32F2F';
    if (criticality === 'medium') return '#F57C00';
    if (criticality === 'low') return '#2E7D32';
    return '#9E9E9E';
  }

  private hasEquipmentDefect(eq: any): boolean {
    const d = (eq?.defect ?? '').toString().trim();
    if (d) return true;
    return this.getEquipmentDefect(eq) != null;
  }

  centerOnObjects(): void {
    if (!this.map || !this.mapData) return;

    try {
      const bounds = L.latLngBounds([]);
      let hasBounds = false;

      // Добавляем все маркеры в bounds
      [...this.poleMarkers, ...this.tapMarkers, ...this.substationMarkers].forEach(marker => {
        try {
          if (marker && marker.getLatLng) {
            bounds.extend(marker.getLatLng());
            hasBounds = true;
          }
        } catch (e) {
          // Игнорируем ошибки отдельных маркеров
        }
      });

      // Добавляем точки из полилиний
      this.powerLineLayers.forEach(layer => {
        if (layer instanceof L.Polyline) {
          try {
            const latlngs = layer.getLatLngs();
            if (Array.isArray(latlngs)) {
              latlngs.forEach((latlng: any) => {
                if (Array.isArray(latlng)) {
                  latlng.forEach((ll: L.LatLng) => {
                    try {
                      bounds.extend(ll);
                      hasBounds = true;
                    } catch (e) {
                      // Игнорируем ошибки
                    }
                  });
                } else if (latlng && latlng.lat && latlng.lng) {
                  bounds.extend(latlng);
                  hasBounds = true;
                }
              });
            }
          } catch (e) {
            // Игнорируем ошибки слоев
          }
        }
      });

      if (hasBounds && this.map) {
        this.map.fitBounds(bounds, { padding: [50, 50], maxZoom: 15 });
      }
    } catch (error) {
      console.error('Ошибка центрирования карты:', error);
    }
  }

  /** Обновить данные карты и дерева (после синхронизации во Flutter или других изменений на сервере). */
  refreshData(): void {
    this.mapService.refreshData();
  }

  openCreateDialog(): void {
    // Снимаем фокус с активного элемента перед открытием диалога
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
    
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '560px',
      maxWidth: '95vw',
      maxHeight: '90vh',
      disableClose: false,
      autoFocus: false,
      restoreFocus: false,
      panelClass: 'create-object-dialog-panel'
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result?.success) {
        // Обновляем карту и дерево после создания/редактирования (пролёты, сегменты, опоры)
        setTimeout(() => {
          this.loadMapData();
          this.mapService.refreshData();
        }, 400);
      }
    });
  }

  /** Широта опоры для панели свойств: из properties или из координат клика по маркеру */
  getPoleLat(): number | null {
    if (!this.selectedPole) return null;
    const v = this.selectedPole.y_position ?? (this.selectedPole as any).latitude;
    return v != null ? Number(v) : null;
  }

  /** Долгота опоры для панели свойств */
  getPoleLon(): number | null {
    if (!this.selectedPole) return null;
    const v = this.selectedPole.x_position ?? (this.selectedPole as any).longitude;
    return v != null ? Number(v) : null;
  }

  /** Полный URL вложения для отображения (фото/аудио) */
  getAttachmentUrl(relativeUrl: string): string {
    return this.apiService.getAttachmentUrl(relativeUrl);
  }

  /** Разбор JSON вложений карточки. Возвращает массив с url и опционально thumbnail. */
  parseCardAttachments(json: string | null | undefined): { t: string; url: string; thumbnail?: string }[] {
    if (!json || !json.trim()) return [];
    try {
      const arr = JSON.parse(json) as any[];
      if (!Array.isArray(arr)) return [];
      return arr
        .filter((item) => item && typeof item.url === 'string' && item.url.trim().length > 0)
        .map((item) => ({ t: item.t || 'photo', url: item.url, thumbnail: item.thumbnail }));
    } catch {
      return [];
    }
  }

  /** Вложения из MinIO (поле card_comment_attachment) — одна таблица для фото, видео, голоса и файлов. */
  get poleCardAttachments(): { t: string; url: string; thumbnail?: string }[] {
    return this.parseCardAttachments((this.selectedPole as any)?.card_comment_attachment);
  }

  attachmentTypeLabel(t: string): string {
    const m: Record<string, string> = {
      photo: 'Фото',
      schema: 'Схема',
      voice: 'Голос',
      video: 'Видео',
      file: 'Файл'
    };
    const k = (t || '').toLowerCase().trim();
    return m[k] || (t ? t : 'Вложение');
  }

  /** Открыть предпросмотр изображения в модальном окне на странице (с загрузкой через API и авторизацией). */
  openImagePreview(url: string): void {
    this.dialog.open(ImagePreviewDialogComponent, {
      data: { url },
      maxWidth: '95vw',
      maxHeight: '90vh',
      panelClass: 'image-preview-dialog-panel'
    });
  }

  /** Имя файла для скачивания из URL вложения (последний сегмент пути). */
  getAttachmentFilename(url: string): string {
    if (!url || !url.trim()) return 'attachment';
    const segment = url.replace(/\/+$/, '').split('/').pop();
    return segment || 'attachment';
  }

  /** Скачать вложение на диск. */
  downloadAttachment(att: { t: string; url: string }): void {
    const filename = this.getAttachmentFilename(att.url);
    this.apiService.getAttachmentBlob(att.url).subscribe({
      next: (blob) => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);
        this.snackBar.open('Файл сохранён', 'Закрыть', { duration: 2000 });
      },
      error: () => {
        this.snackBar.open('Ошибка загрузки файла', 'Закрыть', { duration: 3000 });
      }
    });
  }

  /** История комментариев карточки (поле card_comment — JSON или старый plain text). */
  get poleCardCommentThread(): CardCommentMessage[] {
    return parseCardCommentMessages(this.selectedPole?.card_comment);
  }

  trackCc(_index: number, m: CardCommentMessage): string {
    return m.id || String(_index);
  }

  commentAuthorLabel(m: CardCommentMessage): string {
    const n = m.user_name?.trim();
    if (n) return n;
    if (m.user_id != null) return `id ${m.user_id}`;
    return '—';
  }

  /** Оборудование для карточки опоры без фундамента (фундамент показывается отдельным полем). */
  getPoleEquipmentForCard(): any[] {
    const list = this.selectedPole?.equipment;
    if (!Array.isArray(list)) return [];
    return list.filter((eq: any) => {
      const t = (eq?.equipment_type || '').toLowerCase().trim();
      return t !== 'фундамент' && t !== 'foundation';
    });
  }

  /** Дефект оборудования: сначала поле defect, иначе пытаемся вытащить из notes (старые данные из Flutter). */
  getEquipmentDefect(eq: any): string | null {
    if (!eq) return null;
    const direct = (eq.defect ?? '').toString().trim();
    if (direct) return direct;
    const notes = (eq.notes ?? '').toString();
    if (!notes) return null;
    const m = notes.match(/дефект:\s*([^;]+)(;|$)/i);
    return m ? m[1].trim() : null;
  }

  /** Критичность оборудования: сначала поле criticality, иначе пытаемся вытащить из notes (high|medium|low). */
  getEquipmentCriticality(eq: any): string | null {
    if (!eq) return null;
    const direct = (eq.criticality ?? '').toString().trim().toLowerCase();
    if (direct === 'high' || direct === 'medium' || direct === 'low') return direct;
    const notes = (eq.notes ?? '').toString();
    if (!notes) return null;
    const m = notes.match(/критичность:\s*(high|medium|low)/i);
    return m ? m[1].toLowerCase() : null;
  }

  closePoleProperties(): void {
    this.showPoleProperties = false;
    this.selectedPole = null;
    this.showEquipmentProperties = false;
    this.selectedEquipment = null;
  }

  openEditEquipmentDialog(): void {
    const equipmentId = this.selectedEquipment?.equipment_id ?? this.selectedEquipment?.id;
    if (equipmentId == null) {
      this.snackBar.open('Оборудование не выбрано', 'Закрыть', { duration: 2500 });
      return;
    }
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '560px',
      maxWidth: '95vw',
      maxHeight: '90vh',
      disableClose: false,
      autoFocus: false,
      restoreFocus: false,
      panelClass: 'create-object-dialog-panel',
      data: {
        isEdit: true,
        objectType: 'equipment',
        equipmentId: Number(equipmentId)
      }
    });
    dialogRef.afterClosed().subscribe((result) => {
      if (result?.success) {
        this.loadMapData();
      }
    });
  }

  private openEquipmentProperties(feature: GeoJSONFeature): void {
    const props = feature?.properties || {};
    const eqId = props['equipment_id'] ?? props['id'];
    const poleId = props['pole_id'];
    const lineId = this.lineIdFromProps(props as Record<string, any> | undefined);
    const coords = feature?.geometry?.type === 'Point' ? (feature.geometry.coordinates as number[]) : null;
    const lngRaw = coords && coords.length >= 2 ? coords[0] : props['x_position'];
    const latRaw = coords && coords.length >= 2 ? coords[1] : props['y_position'];
    const lng = Number(lngRaw);
    const lat = Number(latRaw);

    this.showPoleProperties = false;
    this.selectedPole = null;
    this.showEquipmentProperties = true;
    this.selectedEquipment = {
      ...props,
      id: eqId ?? props['id'],
      equipment_id: eqId ?? props['equipment_id'],
      pole_id: poleId,
      line_id: lineId,
      x_position: Number.isFinite(lng) ? lng : null,
      y_position: Number.isFinite(lat) ? lat : null
    };

    if (lineId != null && poleId != null) {
      this.mapService.requestSelectPoleInTree(Number(lineId), Number(poleId), props['segment_id'] ?? undefined);
    }
    if (eqId != null) {
      this.apiService.getEquipment(Number(eqId)).subscribe({
        next: (eq) => Object.assign(this.selectedEquipment as any, eq)
      });
    }
  }

  openConnectivityNodeDialog(): void {
    if (!this.selectedPole || !this.selectedPole.id) {
      this.snackBar.open('Выберите опору', 'Закрыть', { duration: 2000 });
      return;
    }

    // Загружаем полную информацию об опоре
    this.apiService.getPole(this.selectedPole.id).subscribe({
      next: (pole: Pole) => {
        const dialogRef = this.dialog.open(PoleConnectivityDialogComponent, {
          width: '500px',
          data: { pole },
          autoFocus: false,
          restoreFocus: false
        });

        dialogRef.afterClosed().subscribe((result) => {
          if (result?.success) {
            // Обновляем данные на карте
            this.loadMapData();
            // Обновляем выбранную опору
            if (result.connectivityNode) {
              this.selectedPole.connectivity_node_id = result.connectivityNode.id;
            } else {
              this.selectedPole.connectivity_node_id = undefined;
            }
          }
        });
      },
      error: (error) => {
        console.error('Ошибка загрузки опоры:', error);
        this.snackBar.open('Ошибка загрузки опоры', 'Закрыть', { duration: 3000 });
      }
    });
  }

  openPoleSequenceDialog(): void {
    if (!this.selectedPole || !this.selectedPole.line_id) {
      this.snackBar.open('Выберите опору, принадлежащую линии', 'Закрыть', { duration: 2000 });
      return;
    }

    const dialogRef = this.dialog.open(PoleSequenceDialogComponent, {
      width: '600px',
      maxHeight: '80vh',
      data: { lineId: this.selectedPole.line_id },
      autoFocus: false,
      restoreFocus: false
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result?.success) {
        // Обновляем данные на карте
        this.loadMapData();
        this.snackBar.open('Последовательность опор обновлена', 'Закрыть', { duration: 3000 });
      }
    });
  }

  openCreateSpanDialog(): void {
    if (!this.selectedPole || !this.selectedPole.line_id) {
      this.snackBar.open('Выберите опору, принадлежащую линии', 'Закрыть', { duration: 2000 });
      return;
    }

    const dialogRef = this.dialog.open(CreateSpanDialogComponent, {
      width: '600px',
      maxHeight: '90vh',
      data: { 
        lineId: this.selectedPole.line_id,
        fromPoleId: this.selectedPole.id
      },
      autoFocus: false,
      restoreFocus: false
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result?.success) {
        // Обновляем данные на карте
        this.loadMapData();
        this.snackBar.open('Пролёт успешно создан', 'Закрыть', { duration: 3000 });
      }
    });
  }

  autoCreateSpans(lineId?: number): void {
    const id = lineId ?? this.selectedPole?.line_id;
    if (!id) {
      this.snackBar.open('Укажите линию или выберите опору на карте', 'Закрыть', { duration: 2000 });
      return;
    }

    if (!confirm('Пересобрать топологию линии: создать/обновить пролёты между опорами по порядку последовательности?')) {
      return;
    }

    this.apiService.autoCreateSpans(id).subscribe({
      next: (response) => {
        this.snackBar.open(
          `Топология обновлена. Пролётов: ${response.created_count ?? response.spans?.length ?? 0}`,
          'Закрыть',
          { duration: 3000 }
        );
        this.loadMapData();
        this.mapService.refreshData();
      },
      error: (error) => {
        console.error('Ошибка пересборки топологии:', error);
        let errorMessage = 'Ошибка пересборки топологии';
        
        if (error.error?.detail) {
          errorMessage = typeof error.error.detail === 'string' 
            ? error.error.detail 
            : JSON.stringify(error.error.detail);
        }
        
        this.snackBar.open(errorMessage, 'Закрыть', { duration: 5000 });
      }
    });
  }

  centerOnPole(latitude: number, longitude: number, zoom?: number | null): void {
    if (this.map) {
      const currentZoom = this.map.getZoom();
      let targetZoomValue: number;
      
      // Если zoom === null, не меняем зум (используем текущий)
      // Если zoom === undefined, используем значение по умолчанию (16)
      // Если zoom - число, используем его
      if (zoom === null) {
        // Не меняем зум, только центрируем
        targetZoomValue = currentZoom;
        this.map.setView([latitude, longitude], currentZoom, {
          animate: true,
          duration: 0.5
        });
      } else if (zoom === undefined) {
        // Используем значение по умолчанию
        targetZoomValue = 16;
        this.map.setView([latitude, longitude], 16, {
          animate: true,
          duration: 0.5
        });
      } else {
        // Используем указанный зум
        targetZoomValue = zoom;
        this.map.setView([latitude, longitude], zoom, {
          animate: true,
          duration: 0.5
        });
      }
      
      // Обновляем зум в сервисе сразу после установки (до завершения анимации)
      // Это гарантирует, что следующий клик получит правильный зум
      this.currentZoom = targetZoomValue;
      this.mapService.setCurrentZoom(targetZoomValue);
      
      // Также обновляем после завершения анимации для точности
      setTimeout(() => {
        if (this.map) {
          const finalZoom = this.map.getZoom();
          this.currentZoom = finalZoom;
          this.mapService.setCurrentZoom(finalZoom);
        }
      }, 600); // Немного больше чем duration анимации (500ms)
    }
  }

  zoomIn(): void {
    if (this.map) {
      this.map.zoomIn();
    }
  }

  zoomOut(): void {
    if (this.map) {
      this.map.zoomOut();
    }
  }
}

