import { Component, OnInit, OnDestroy } from '@angular/core';
import { MapService, MapData } from '../../core/services/map.service';
import { SidebarService } from '../../core/services/sidebar.service';
import { GeoJSONFeature } from '../../core/models/geojson.model';
import { environment } from '../../../environments/environment';
import * as L from 'leaflet';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatDialog } from '@angular/material/dialog';
import { CreateObjectDialogComponent } from './create-object-dialog/create-object-dialog.component';
import { PoleConnectivityDialogComponent } from './pole-connectivity-dialog/pole-connectivity-dialog.component';
import { PoleSequenceDialogComponent } from './pole-sequence-dialog/pole-sequence-dialog.component';
import { CreateSpanDialogComponent } from './create-span-dialog/create-span-dialog.component';
import { ApiService } from '../../core/services/api.service';
import { Pole } from '../../core/models/pole.model';

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
  private poleMarkers: L.Marker[] = [];
  private poleLabels: L.Layer[] = []; // Подписи опор
  private tapMarkers: L.Marker[] = [];
  private substationMarkers: L.Marker[] = [];
  private poleSequenceLines: L.Polyline[] = []; // Линии последовательности опор
  /** Выделенный участок линии (при клике в дереве): подсветка жирной линией и чёрными точками опор */
  private selectedSegment: { powerLineId: number; segmentId: number | null } | null = null;
  private segmentHighlightLayers: L.Layer[] = [];

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

    this.mapService.loadAllMapData()
      .pipe(takeUntil(this.destroy$))
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

    // Рендерим ЛЭП (линии)
    if (data.powerLines?.features) {
      this.renderPowerLines(data.powerLines);
    }
    
    // Рендерим опоры (точки)
    if (data.poles?.features) {
      this.renderPoles(data.poles);
      // Рендерим линии последовательности опор
      this.renderPoleSequence(data.poles);
    }
    
    // Рендерим отпайки (точки)
    if (data.taps?.features) {
      this.renderTaps(data.taps);
    }
    
    // Рендерим подстанции (точки)
    if (data.substations?.features) {
      this.renderSubstations(data.substations);
    }

    // Восстанавливаем зум и позицию карты после обновления данных
    if (this.map && currentCenter) {
      this.map.setView(currentCenter, currentZoom, { animate: false });
    }
    if (this.selectedSegment) {
      this.renderSegmentHighlight();
    }
  }

  renderPowerLines(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'LineString') {
        const coordinates = feature.geometry.coordinates as number[][];
        const latlngs = coordinates.map(coord => [coord[1], coord[0]] as L.LatLngExpression);
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
      }
    });
  }

  renderPoles(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'Point') {
        const coordinates = feature.geometry.coordinates as number[];
        const latlng: L.LatLngExpression = [coordinates[1], coordinates[0]];
        
        const hasConnectivityNode = feature.properties['connectivity_node_id'];
        const sequenceNumber = feature.properties['sequence_number'];
        const isTapPole = !!feature.properties['is_tap_pole'];
        const tapBranchHasPoles = !!feature.properties['tap_branch_has_poles'];
        
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
        
        if (sequenceNumber && !isTapPole) {
          markerHtml = `
            <div style="position: relative;">
              ${markerHtml}
              <div style="position: absolute; top: -20px; left: 50%; transform: translateX(-50%); 
                          background: rgba(33, 150, 243, 0.9); color: white; 
                          padding: 2px 6px; border-radius: 10px; font-size: 10px; font-weight: bold;
                          white-space: nowrap; box-shadow: 0 1px 3px rgba(0,0,0,0.3);">
                ${sequenceNumber}
              </div>
            </div>
          `;
        }
        if (sequenceNumber && isTapPole) {
          markerHtml = `
            <div style="position: relative;">
              ${markerHtml}
              <div style="position: absolute; top: -18px; left: 50%; transform: translateX(-50%); 
                          background: rgba(0,0,0,0.7); color: white; 
                          padding: 2px 6px; border-radius: 10px; font-size: 10px; font-weight: bold;
                          white-space: nowrap;">${sequenceNumber}</div>
            </div>
          `;
        }
        
        const iconW = sequenceNumber ? (isTapPole ? 24 : 20) : sizePx + borderWidth * 2;
        const iconH = sequenceNumber ? (isTapPole ? 36 : 30) : sizePx + borderWidth * 2;
        // Якорь — центр круга, чтобы точка не «съезжала» при изменении зума
        const anchorY = sequenceNumber ? (sizePx / 2 + borderWidth) : (sizePx + borderWidth * 2) / 2;
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
            latitude: coordinates[1],
            longitude: coordinates[0],
            segment_name: feature.properties['segment_name'] || 
                         feature.properties['power_line_name'] || 
                         `ЛЭП ID: ${feature.properties['power_line_id'] || 'N/A'}`
          };
          this.centerOnPole(coordinates[1], coordinates[0], 18);
          const powerLineId = feature.properties['power_line_id'];
          const poleId = feature.properties['id'];
          if (powerLineId != null && poleId != null) {
            this.mapService.requestSelectPoleInTree(
              powerLineId,
              poleId,
              feature.properties['segment_id'] ?? undefined
            );
          }
        });

        marker.addTo(this.map!);
        this.poleMarkers.push(marker);

        (marker as any).poleData = {
          coordinates: latlng,
          poleNumber: feature.properties['pole_number'] || 'N/A'
        };
        (marker as any).poleFeature = feature;
      }
    });
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
        tapPoleId: tapPoleId as number
      }
    });
    dialogRef.afterClosed().subscribe(() => {
      this.mapService.refreshData();
    });
  }

  /** То же из панели свойств опоры (selectedPole) */
  openCreatePoleFromTapPolePanel(): void {
    if (!this.selectedPole || this.selectedPole.is_tap_pole !== true || this.selectedPole.tap_branch_has_poles) return;
    const feature: GeoJSONFeature = {
      type: 'Feature',
      properties: this.selectedPole,
      geometry: { type: 'Point', coordinates: [this.selectedPole.longitude ?? 0, this.selectedPole.latitude ?? 0] }
    };
    this.openCreatePoleFromTapPole(feature);
  }

  renderPoleSequence(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    // Группируем опоры по линии и по ветке (магистраль vs отпайка), чтобы не смешивать в одну линию
    const key = (lineId: number, tapPoleId: number | null) => `${lineId}:${tapPoleId ?? 'main'}`;
    const polesByBranch: { [k: string]: any[] } = {};

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      const powerLineId = feature.properties['power_line_id'];
      const tapPoleId = feature.properties['tap_pole_id'] ?? null;
      if (powerLineId != null && feature.properties['sequence_number'] != null) {
        const k = key(powerLineId, tapPoleId);
        if (!polesByBranch[k]) polesByBranch[k] = [];
        polesByBranch[k].push(feature);
      }
    });

    Object.keys(polesByBranch).forEach(branchKey => {
      const poles = polesByBranch[branchKey];
      poles.sort((a, b) => (a.properties['sequence_number'] || 0) - (b.properties['sequence_number'] || 0));

      const coordinates: L.LatLngExpression[] = poles
        .filter((pole: any) => pole.geometry?.type === 'Point')
        .map((pole: any) => {
          const c = pole.geometry.coordinates as number[];
          return [c[1], c[0]] as L.LatLngExpression;
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
        const latlng: L.LatLngExpression = [coordinates[1], coordinates[0]];
        
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
        const latlng: L.LatLngExpression = [coordinates[1], coordinates[0]];
        
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'substation-marker',
            html: '<div style="background-color: #9C27B0; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white;"></div>',
            iconSize: [20, 20],
            iconAnchor: [10, 10]
          })
        }).bindPopup(`
          <strong>${feature.properties['name'] || 'Подстанция'}</strong><br>
          Код: ${feature.properties['code'] || 'N/A'}<br>
          Напряжение: ${feature.properties['voltage_level'] || 'N/A'} кВ<br>
          Адрес: ${feature.properties['address'] || 'N/A'}
        `);

        marker.addTo(this.map!);
        this.substationMarkers.push(marker);
      }
    });
  }

  clearLayers(): void {
    this.powerLineLayers.forEach(layer => this.map?.removeLayer(layer));
    this.poleMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.poleLabels.forEach(label => this.map?.removeLayer(label));
    this.tapMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.substationMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.poleSequenceLines.forEach(line => this.map?.removeLayer(line));
    this.clearSegmentHighlight();

    this.powerLineLayers = [];
    this.poleMarkers = [];
    this.poleLabels = [];
    this.tapMarkers = [];
    this.substationMarkers = [];
    this.poleSequenceLines = [];
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
        const coords = feature.geometry.coordinates as number[][];
        const latlngs = coords.map(c => [c[1], c[0]] as L.LatLngExpression);
        // Контур: сначала толстая чёрная обводка, поверх — линия того же цвета что и обычная ЛЭП
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
        const latlng: L.LatLngExpression = [c[1], c[0]];
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

    // Показываем подписи только при зуме от 15 до 20
    if (this.currentZoom >= 15 && this.currentZoom <= 20) {
      this.poleMarkers.forEach(marker => {
        const poleData = (marker as any).poleData;
        if (poleData) {
          const label = L.marker(poleData.coordinates, {
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
      width: '520px',
      maxWidth: '95vw',
      maxHeight: '90vh',
      disableClose: false,
      autoFocus: false,
      restoreFocus: false
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
    if (!this.selectedPole || !this.selectedPole.power_line_id) {
      this.snackBar.open('Выберите опору, принадлежащую линии', 'Закрыть', { duration: 2000 });
      return;
    }

    const dialogRef = this.dialog.open(PoleSequenceDialogComponent, {
      width: '600px',
      maxHeight: '80vh',
      data: { powerLineId: this.selectedPole.power_line_id },
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
    if (!this.selectedPole || !this.selectedPole.power_line_id) {
      this.snackBar.open('Выберите опору, принадлежащую линии', 'Закрыть', { duration: 2000 });
      return;
    }

    const dialogRef = this.dialog.open(CreateSpanDialogComponent, {
      width: '600px',
      maxHeight: '90vh',
      data: { 
        powerLineId: this.selectedPole.power_line_id,
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
    const lineId = powerLineId ?? this.selectedPole?.power_line_id;
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

