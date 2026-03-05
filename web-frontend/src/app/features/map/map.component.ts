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
import { ApiService } from '../../core/services/api.service';
import { Pole } from '../../core/models/pole.model';
import { Equipment } from '../../core/models/equipment.model';

@Component({
  selector: 'app-map',
  templateUrl: './map.component.html',
  styleUrls: ['./map.component.scss']
})
export class MapComponent implements OnInit, OnDestroy {
  map: L.Map | null = null;
  mapData: MapData | null = null;
  isLoading = true;
  errorMessage: string | null = null;
  
  // Окно свойств опоры
  selectedPole: any = null;
  showPoleProperties = false;
  
  // Текущий зум карты
  currentZoom: number = 10;
  
  // Состояние sidebar
  isSidebarOpen: boolean = true;
  sidebarWidth: number = 350;
  
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
  private poleSequenceLines: L.Polyline[] = []; // Линии последовательности опор
  private equipmentMarkers: L.Marker[] = []; // Отдельные маркеры оборудования на линии
  /** Точечные маркеры оборудования как отдельных объектов с собственными координатами */
  private equipmentPointMarkers: L.Marker[] = [];
  /** Выделенный участок линии (при клике в дереве): подсветка жирной линией и чёрными точками опор */
  private selectedSegment: { powerLineId: number; segmentId: number | null } | null = null;
  private segmentHighlightLayers: L.Layer[] = [];

  // Оборудование по опорам для отрисовки SVG-значков на карте
  private allEquipment: Equipment[] = [];
  private equipmentByPoleId = new Map<number, Equipment[]>();

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
      .subscribe(powerLineId => this.autoCreateSpans(powerLineId));

    this.mapService.requestSelectSegment$
      .pipe(takeUntil(this.destroy$))
      .subscribe(({ powerLineId, segmentId, bounds }) => {
        if (this.map) {
          this.map.fitBounds(bounds as L.LatLngBoundsLiteral, { animate: true, duration: 0.5, padding: [40, 40] });
          this.selectedSegment = { powerLineId, segmentId };
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
              `ЛЭП ID: ${feature.properties['power_line_id'] || 'N/A'}`
          };
          const poleId = feature.properties['id'];
          if (poleId != null) {
            this.apiService.getPole(poleId).subscribe({
              next: (pole) => {
                (this.selectedPole as any).equipment = (pole as any).equipment || [];
                (this.selectedPole as any).connectivity_node = (pole as any).connectivity_node || null;
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

    // Обновление данных карты при refreshData() (после создания/удаления опор, отпаек и т.д.)
    this.mapService.dataRefresh
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        this.loadMapData();
      });
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
      maxZoom: environment.map.maxZoom
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
        this.updatePoleLabels();
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
      this.renderPowerLines(data.powerLines, data.poles?.features ?? []);
    }
    
    // Рендерим опоры (точки)
    if (data.poles?.features) {
      this.renderPoles(data.poles);
      // Рендерим линии последовательности опор
      this.renderPoleSequence(data.poles);
      // Рисуем оборудование как элементы линии возле опор
      this.renderEquipmentOnLines(data.poles);
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
      this.renderTapSubstationConnections(data.spans);
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
  }

  /** Рисует линии ЛЭП. Координаты берутся из опор (polesFeatures), чтобы линия проходила ровно через центры маркеров опор. */
  renderPowerLines(geoJson: any, polesFeatures: GeoJSONFeature[] = []): void {
    if (!this.map || !geoJson.features) return;

    // Быстрый доступ к опоре по id
    const polesById = new Map<number, GeoJSONFeature>();
    polesFeatures.forEach((f: GeoJSONFeature) => {
      const id = f.properties?.['id'];
      if (id != null) {
        polesById.set(Number(id), f);
      }
    });

    // Группы по линии и ветке:
    // - магистраль: key = lineId:main:0
    // - отпайка:    key = lineId:tapPoleId:branchIndex
    const key = (lineId: number, tapPoleId: number | null, tapBranchIndex: number | null) =>
      `${lineId}:${tapPoleId ?? 'main'}:${tapBranchIndex ?? 0}`;

    const polesByBranch = new Map<string, GeoJSONFeature[]>();
    polesFeatures.forEach((f: GeoJSONFeature) => {
      if (f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      const lineId = f.properties?.['power_line_id'];
      if (lineId == null) return;
      const tapPoleId = f.properties?.['tap_pole_id'] ?? null;
      const tapBranchIndex = f.properties?.['tap_branch_index'] ?? null;
      const k = key(lineId, tapPoleId, tapBranchIndex);
      if (!polesByBranch.has(k)) polesByBranch.set(k, []);
      polesByBranch.get(k)!.push(f);
    });

    // Сортировка внутри веток по sequence_number
    polesByBranch.forEach((poles) => {
      poles.sort((a, b) => {
        return (a.properties?.['sequence_number'] ?? 0) - (b.properties?.['sequence_number'] ?? 0);
      });
    });

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type !== 'LineString') return;

      const lineId = feature.properties?.['id'] ?? feature.properties?.['power_line_id'];
      const tapPoleId = feature.properties?.['tap_pole_id'] ?? null;
      const tapBranchIndex = feature.properties?.['tap_branch_index'] ?? null;
      const branchKey = lineId != null ? key(lineId, tapPoleId, tapBranchIndex) : null;
      let latlngs: L.LatLngExpression[] | undefined;

      if (branchKey && polesByBranch.has(branchKey)) {
        const poles = polesByBranch.get(branchKey)!;
        const pts: L.LatLngExpression[] = [];

        const parts = branchKey.split(':');
        const tapToken = parts[1];
        const tapId = tapToken !== 'main' ? Number(tapToken) : null;

        // Для отпайки первым ставим саму отпаечную опору, затем опоры ветки
        if (tapId != null) {
          const basePole = polesById.get(tapId);
          if (basePole && basePole.geometry?.type === 'Point' && Array.isArray(basePole.geometry.coordinates)) {
            const bc = basePole.geometry.coordinates as number[];
            pts.push([bc[1], bc[0]]);
          }
        }

        poles
          .filter((p: GeoJSONFeature) => p.geometry?.type === 'Point' && Array.isArray(p.geometry.coordinates))
          .forEach((p: GeoJSONFeature) => {
            const c = p.geometry!.coordinates as number[];
            pts.push([c[1], c[0]]);
          });

        if (pts.length >= 2) {
          latlngs = pts;
        }
      }
      if (!latlngs || latlngs.length < 2) {
        const coordinates = feature.geometry.coordinates as number[][];
        latlngs = coordinates.map(coord => [coord[1], coord[0]] as L.LatLngExpression);
      }

      if (latlngs.length < 2) return;

      const isTap = feature.properties['branch_type'] === 'tap';
      const lineColor = isTap ? '#4CAF50' : '#f44336';

      const polyline = L.polyline(latlngs, {
        color: lineColor,
        weight: 3,
        opacity: 0.8
      }).bindPopup(`
          <strong>${feature.properties['name'] || 'ЛЭП'}</strong><br>
          Напряжение: ${feature.properties['voltage_level']} кВ<br>
          Опор: ${feature.properties['pole_count'] || 0}${isTap ? '<br>(отпайка)' : ''}
        `);

      polyline.addTo(this.map!);
      this.powerLineLayers.push(polyline);
    });
  }

  renderPoles(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
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
        
        let markerHtml = `<div style="background-color: ${markerColor}; width: ${sizePx}px; height: ${sizePx}px; border-radius: 50%; border: ${borderWidth}px solid ${borderColor}; cursor: pointer; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`;
        
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
          this.showPoleProperties = true;
          this.selectedPole = {
            ...feature.properties,
            latitude: lat,
            longitude: lng,
            segment_name: feature.properties['segment_name'] || 
                         feature.properties['power_line_name'] || 
                         `ЛЭП ID: ${feature.properties['power_line_id'] || 'N/A'}`
          };
          this.centerOnPole(lat, lng, 18);
          const powerLineId = feature.properties['power_line_id'];
          const poleId = feature.properties['id'];
          if (powerLineId != null && poleId != null) {
            this.mapService.requestSelectPoleInTree(
              powerLineId,
              poleId,
              feature.properties['segment_id'] ?? undefined
            );
          }

          // Подгружаем оборудование для панели свойств
          if (poleId != null) {
            this.apiService.getPole(poleId).subscribe({
              next: (pole) => {
                (this.selectedPole as any).equipment = (pole as any).equipment || [];
                (this.selectedPole as any).connectivity_node = (pole as any).connectivity_node || null;
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
   * Отрисовывает оборудование как элементы линии возле опор:
   * маленькие схематичные значки, размещённые рядом с точкой опоры.
   */
  private renderEquipmentOnLines(geoJson: any): void {
    if (!this.map || !geoJson?.features) return;

    // Удаляем старые маркеры оборудования
    this.equipmentMarkers.forEach(m => this.map?.removeLayer(m));
    this.equipmentMarkers = [];

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type !== 'Point') return;
      const poleId: number | null = feature.properties?.['id'] != null ? Number(feature.properties['id']) : null;
      if (poleId == null) return;
      const equipmentForPole: Equipment[] = this.equipmentByPoleId.get(poleId) || [];
      if (!equipmentForPole.length) return;

      const coordinates = feature.geometry.coordinates as number[];
      const lat = Number(coordinates[1]);
      const lng = Number(coordinates[0]);
      const latlng = L.latLng(lat, lng);

      const html = this.buildEquipmentInlineHtml(equipmentForPole);
      if (!html) return;

      const marker = L.marker(latlng, {
        icon: L.divIcon({
          className: 'equipment-inline-marker',
          html,
          iconSize: [40, 10],
          iconAnchor: [20, 5]
        }),
        interactive: false
      });

      marker.addTo(this.map!);
      this.equipmentMarkers.push(marker);
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

      const html = this.buildEquipmentIconsHtml([eq]);
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

      marker.addTo(this.map!);
      this.equipmentPointMarkers.push(marker);
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
    const powerLineId = feature.properties['power_line_id'];
    const tapPoleId = feature.properties['id'];
    if (powerLineId == null || tapPoleId == null) return;
    const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
      width: '520px',
      data: {
        defaultObjectType: 'pole',
        powerLineId: powerLineId as number,
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

  private renderTapSubstationConnections(spansGeoJson: GeoJSONCollection): void {
    if (!this.map || !spansGeoJson.features) return;

    (spansGeoJson.features as GeoJSONFeature[]).forEach((feature: GeoJSONFeature) => {
      if (feature.geometry?.type !== 'LineString') return;
      const props = feature.properties || {};
      const fromPoleId = props['from_pole_id'];
      const toPoleId = props['to_pole_id'];
      // Нас интересуют пролёты «опора → подстанция» (to_pole_id == null)
      if (fromPoleId == null || toPoleId != null) return;
      const coords = feature.geometry.coordinates as number[][];
      if (!Array.isArray(coords) || coords.length < 2) return;
      const latlngs = coords.map(c => [c[1], c[0]] as L.LatLngExpression);
      const line = L.polyline(latlngs, {
        color: '#9C27B0',
        weight: 3,
        opacity: 0.8,
        dashArray: '6, 6'
      });
      line.addTo(this.map!);
      this.substationConnectionLayers.push(line);
    });
  }

  renderPoleSequence(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    // Группируем опоры по линии и по ветке (магистраль vs отпайка), чтобы не смешивать в одну линию
    // Учитываем номер ветки отпайки (tap_branch_index), чтобы 3/1 и 3/2 не соединялись одной линией.
    const key = (lineId: number, tapPoleId: number | null, tapBranchIndex: number | null) =>
      `${lineId}:${tapPoleId ?? 'main'}:${tapBranchIndex ?? 0}`;
    const polesByBranch: { [k: string]: any[] } = {};
    const polesById: { [id: number]: GeoJSONFeature } = {};

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      const id = feature.properties?.['id'];
      if (id != null) {
        polesById[Number(id)] = feature;
      }
    });

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      const powerLineId = feature.properties['power_line_id'];
      const tapPoleId = feature.properties['tap_pole_id'] ?? null;
      if (powerLineId != null && feature.properties['sequence_number'] != null) {
        const tapBranchIndex = feature.properties['tap_branch_index'] ?? null;
        const k = key(powerLineId, tapPoleId, tapBranchIndex);
        if (!polesByBranch[k]) polesByBranch[k] = [];
        polesByBranch[k].push(feature);
      }
    });

    Object.keys(polesByBranch).forEach(branchKey => {
      const poles = polesByBranch[branchKey];
      poles.sort((a, b) => (a.properties['sequence_number'] || 0) - (b.properties['sequence_number'] || 0));

      const coordinates: L.LatLngExpression[] = [];

      // Для отпайки первым добавляем саму отпаечную опору (tap_pole_id), затем опоры ветки
      const parts = branchKey.split(':');
      const tapToken = parts[1];
      const tapId = tapToken !== 'main' ? Number(tapToken) : null;
      if (tapId != null && polesById[tapId]) {
        const base = polesById[tapId];
        if (base.geometry?.type === 'Point') {
          const bc = base.geometry.coordinates as number[];
          coordinates.push([bc[1], bc[0]]);
        }
      }

      poles
        .filter((pole: any) => pole.geometry?.type === 'Point')
        .forEach((pole: any) => {
          const c = pole.geometry.coordinates as number[];
          coordinates.push([c[1], c[0]] as L.LatLngExpression);
        });

      if (coordinates.length > 1 && this.map) {
        const sequenceLine = L.polyline(coordinates, {
          color: '#4CAF50',
          weight: 2,
          opacity: 0.6,
          dashArray: '5, 10'
        }).bindTooltip(`Последовательность опор (${poles.length} опор)`, {
          permanent: false,
          direction: 'top'
        });
        sequenceLine.addTo(this.map);
        this.poleSequenceLines.push(sequenceLine);
      }
    });
  }

  renderTaps(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
        const coordinates = feature.geometry.coordinates as number[];
        const latlng = L.latLng(Number(coordinates[1]), Number(coordinates[0]));
        
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'tap-marker',
            html: '<div style="background-color: #FF9800; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white;"></div>',
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
        
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'substation-marker',
            html: '<div style="background-color: #9C27B0; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white;"></div>',
            iconSize: [20, 20],
            iconAnchor: [10, 10]
          })
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

    const substationById = new Map<number, GeoJSONFeature>();
    data.substations.features.forEach((f: GeoJSONFeature) => {
      const id = f.properties?.['id'];
      if (id != null) substationById.set(Number(id), f);
    });

    const polesByLine = new Map<number, GeoJSONFeature[]>();
    data.poles.features.forEach((f: GeoJSONFeature) => {
      const lineId = f.properties?.['power_line_id'];
      const tapId = f.properties?.['tap_pole_id'] ?? null;
      if (lineId == null || tapId != null) return; // только магистраль (без отпаек)
      if (f.geometry?.type !== 'Point' || !f.geometry.coordinates?.length) return;
      if (!polesByLine.has(lineId)) polesByLine.set(lineId, []);
      polesByLine.get(lineId)!.push(f);
    });
    polesByLine.forEach(poles => {
      poles.sort((a, b) => (a.properties?.['sequence_number'] ?? 0) - (b.properties?.['sequence_number'] ?? 0));
    });

    data.powerLinesList.forEach((pl: { id: number; name?: string; substation_start_id?: number | null; substation_end_id?: number | null }) => {
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
        const sub = substationById.get(pl.substation_start_id);
        if (sub?.geometry?.type === 'Point' && sub.geometry.coordinates?.length >= 2) {
          const subCoords = sub.geometry.coordinates as number[];
          const subLatLng: L.LatLngExpression = [subCoords[1], subCoords[0]];
          const poleLatLng = getPoleLatLng(firstPole);
          if (poleLatLng) {
            const line = L.polyline([subLatLng, poleLatLng], {
              color: '#9C27B0',
              weight: 3,
              opacity: 0.8,
              dashArray: '6, 6'
            }).bindPopup(`Подстанция → ЛЭП «${pl.name ?? lineId}»`);
            line.addTo(this.map!);
            this.substationConnectionLayers.push(line);
          }
        }
      }
      if (pl.substation_end_id != null && pl.substation_end_id !== pl.substation_start_id) {
        const sub = substationById.get(pl.substation_end_id);
        if (sub?.geometry?.type === 'Point' && sub.geometry.coordinates?.length >= 2) {
          const subCoords = sub.geometry.coordinates as number[];
          const subLatLng: L.LatLngExpression = [subCoords[1], subCoords[0]];
          const poleLatLng = getPoleLatLng(lastPole);
          if (poleLatLng) {
            const line = L.polyline([poleLatLng, subLatLng], {
              color: '#9C27B0',
              weight: 3,
              opacity: 0.8,
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
    this.poleSequenceLines.forEach(line => this.map?.removeLayer(line));
    this.equipmentMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.equipmentPointMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.clearSegmentHighlight();

    this.powerLineLayers = [];
    this.substationConnectionLayers = [];
    this.poleMarkers = [];
    this.poleLabels = [];
    this.tapMarkers = [];
    this.substationMarkers = [];
    this.poleSequenceLines = [];
    this.equipmentMarkers = [];
    this.equipmentPointMarkers = [];
  }

  private clearSegmentHighlight(): void {
    this.segmentHighlightLayers.forEach(layer => this.map?.removeLayer(layer));
    this.segmentHighlightLayers = [];
  }

  private renderSegmentHighlight(): void {
    if (!this.map || !this.mapData || !this.selectedSegment) return;
    this.clearSegmentHighlight();
    const { powerLineId, segmentId } = this.selectedSegment;

    const poles = (this.mapData.poles?.features || []).filter((f: GeoJSONFeature) => {
      const pl = f.properties?.['power_line_id'];
      const seg = f.properties?.['segment_id'] ?? f.properties?.['acline_segment_id'];
      return pl === powerLineId && (segmentId === null ? seg == null : seg === segmentId);
    });
    const spans = (this.mapData.spans?.features || []).filter((f: GeoJSONFeature) => {
      const pl = f.properties?.['power_line_id'];
      const seg = f.properties?.['segment_id'] ?? f.properties?.['acline_segment_id'];
      return pl === powerLineId && (segmentId === null ? seg == null : seg === segmentId);
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
    poles.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
        const c = feature.geometry.coordinates as number[];
        const latlng = L.latLng(Number(c[1]), Number(c[0]));
        const circle = L.circleMarker(latlng, {
          radius: 6,
          color: '#000',
          fillColor: '#fff',
          fillOpacity: 1,
          weight: 2
        });
        circle.addTo(this.map!);
        this.segmentHighlightLayers.push(circle);
      }
    });
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

  refreshData(): void {
    this.loadMapData();
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

  closePoleProperties(): void {
    this.showPoleProperties = false;
    this.selectedPole = null;
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
      data: { powerLineId: this.selectedPole.line_id },
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
        powerLineId: this.selectedPole.line_id,
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

  autoCreateSpans(powerLineId?: number): void {
    const lineId = powerLineId ?? this.selectedPole?.line_id;
    if (!lineId) {
      this.snackBar.open('Укажите линию или выберите опору на карте', 'Закрыть', { duration: 2000 });
      return;
    }

    if (!confirm('Пересобрать топологию линии: создать/обновить пролёты между опорами по порядку последовательности?')) {
      return;
    }

    this.apiService.autoCreateSpans(lineId).subscribe({
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

