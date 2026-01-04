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
      .subscribe(({ coordinates, zoom, currentZoomForLogic }: {type: string, coordinates: [number, number], zoom?: number | null, currentZoomForLogic?: number}) => {
        // Получаем актуальный зум из карты (самый надежный способ)
        if (this.map) {
          const actualZoom = this.map.getZoom();
          // Обновляем зум в сервисе для следующего использования
          this.mapService.setCurrentZoom(actualZoom);
        }
        this.centerOnPole(coordinates[0], coordinates[1], zoom);
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
  }

  renderPowerLines(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    geoJson.features.forEach((feature: GeoJSONFeature) => {
      if (feature.geometry.type === 'LineString') {
        const coordinates = feature.geometry.coordinates as number[][];
        const latlngs = coordinates.map(coord => [coord[1], coord[0]] as L.LatLngExpression);
        
        const polyline = L.polyline(latlngs, {
          color: '#f44336',
          weight: 3,
          opacity: 0.8
        }).bindPopup(`
          <strong>${feature.properties['name'] || 'ЛЭП'}</strong><br>
          Напряжение: ${feature.properties['voltage_level']} кВ<br>
          Опор: ${feature.properties['pole_count'] || 0}
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
        
        // Определяем цвет маркера в зависимости от наличия узла соединения
        const hasConnectivityNode = feature.properties['connectivity_node_id'];
        const sequenceNumber = feature.properties['sequence_number'];
        const markerColor = hasConnectivityNode ? '#2196F3' : '#FF9800';
        
        // Создаём HTML для маркера с номером последовательности
        let markerHtml = `<div style="background-color: ${markerColor}; width: 8px; height: 8px; border-radius: 50%; border: 2px solid white; cursor: pointer; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`;
        
        if (sequenceNumber) {
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
        
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'pole-marker',
            html: markerHtml,
            iconSize: sequenceNumber ? [20, 30] : [8, 8],
            iconAnchor: sequenceNumber ? [10, 30] : [4, 4]
          })
        }).bindPopup(`
          <strong>Опора ${feature.properties['pole_number'] || 'N/A'}</strong><br>
          ${sequenceNumber ? `Порядок: ${sequenceNumber}<br>` : ''}
          Тип: ${feature.properties['pole_type'] || 'N/A'}<br>
          Высота: ${feature.properties['height'] || 'N/A'} м<br>
          Состояние: ${feature.properties['condition'] || 'N/A'}<br>
          ${hasConnectivityNode ? '<span style="color: green;">✓ Узел соединения</span>' : '<span style="color: orange;">⚠ Нет узла соединения</span>'}
        `);

        // Обработчик клика для показа свойств и центрирования
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
          // Центрируем карту на опоре без изменения зума
          this.centerOnPole(coordinates[1], coordinates[0]);
        });

        marker.addTo(this.map!);
        this.poleMarkers.push(marker);

        // Сохраняем информацию о маркере для подписей
        (marker as any).poleData = {
          coordinates: latlng,
          poleNumber: feature.properties['pole_number'] || 'N/A'
        };
      }
    });
  }

  renderPoleSequence(geoJson: any): void {
    if (!this.map || !geoJson.features) return;

    // Группируем опоры по линиям
    const polesByLine: { [key: number]: any[] } = {};
    
    geoJson.features.forEach((feature: GeoJSONFeature) => {
      const powerLineId = feature.properties['power_line_id'];
      if (powerLineId && feature.properties['sequence_number']) {
        if (!polesByLine[powerLineId]) {
          polesByLine[powerLineId] = [];
        }
        polesByLine[powerLineId].push(feature);
      }
    });

    // Для каждой линии рисуем линию последовательности
    Object.keys(polesByLine).forEach(lineId => {
      const poles = polesByLine[parseInt(lineId)];
      
      // Сортируем опоры по sequence_number
      poles.sort((a, b) => {
        const seqA = a.properties['sequence_number'] || 0;
        const seqB = b.properties['sequence_number'] || 0;
        return seqA - seqB;
      });

      // Создаём массив координат
      const coordinates: L.LatLngExpression[] = poles
        .filter(pole => pole.geometry.type === 'Point')
        .map(pole => {
          const coords = pole.geometry.coordinates as number[];
          return [coords[1], coords[0]] as L.LatLngExpression;
        });

      if (coordinates.length > 1) {
        if (!this.map) return;
        
        // Рисуем пунктирную линию последовательности
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
    
    this.powerLineLayers = [];
    this.poleMarkers = [];
    this.poleLabels = [];
    this.tapMarkers = [];
    this.substationMarkers = [];
    this.poleSequenceLines = [];
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
      width: '700px',
      maxWidth: '90vw',
      maxHeight: '90vh',
      disableClose: false,
      autoFocus: false,
      restoreFocus: false
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        // Обновляем данные карты после создания объекта
        // Используем setTimeout для небольшой задержки, чтобы сервер успел обработать запрос
        setTimeout(() => {
          this.loadMapData();
          // Уведомляем сервис об обновлении для sidebar
          this.mapService.refreshData();
        }, 500);
      }
    });
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

  autoCreateSpans(): void {
    if (!this.selectedPole || !this.selectedPole.power_line_id) {
      this.snackBar.open('Выберите опору, принадлежащую линии', 'Закрыть', { duration: 2000 });
      return;
    }

    if (!confirm('Создать пролёты автоматически между всеми опорами в порядке их последовательности?')) {
      return;
    }

    this.apiService.autoCreateSpans(this.selectedPole.power_line_id).subscribe({
      next: (response) => {
        this.snackBar.open(
          `Создано пролётов: ${response.created_count || response.spans?.length || 0}`,
          'Закрыть',
          { duration: 3000 }
        );
        this.loadMapData();
      },
      error: (error) => {
        console.error('Ошибка автоматического создания пролётов:', error);
        let errorMessage = 'Ошибка создания пролётов';
        
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

