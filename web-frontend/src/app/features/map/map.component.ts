import { Component, OnInit, OnDestroy } from '@angular/core';
import { MapService, MapData } from '../../core/services/map.service';
import { GeoJSONFeature } from '../../core/models/geojson.model';
import { environment } from '../../../environments/environment';
import * as L from 'leaflet';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { MatSnackBar } from '@angular/material/snack-bar';

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
  
  private destroy$ = new Subject<void>();
  private layers: L.Layer[] = [];

  // Маркеры для разных типов объектов
  private powerLineLayers: L.Layer[] = [];
  private poleMarkers: L.Marker[] = [];
  private tapMarkers: L.Marker[] = [];
  private substationMarkers: L.Marker[] = [];

  constructor(
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.initMap();
    this.loadMapData();
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

    // Очищаем предыдущие слои
    this.clearLayers();

    // Рендерим ЛЭП (линии)
    this.renderPowerLines(data.powerLines);
    
    // Рендерим опоры (точки)
    this.renderPoles(data.poles);
    
    // Рендерим отпайки (точки)
    this.renderTaps(data.taps);
    
    // Рендерим подстанции (точки)
    this.renderSubstations(data.substations);

    // Центрируем карту на объектах
    this.centerOnObjects();
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
        
        const marker = L.marker(latlng, {
          icon: L.divIcon({
            className: 'pole-marker',
            html: '<div style="background-color: #2196F3; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white;"></div>',
            iconSize: [20, 20],
            iconAnchor: [10, 10]
          })
        }).bindPopup(`
          <strong>Опора ${feature.properties['pole_number'] || 'N/A'}</strong><br>
          Тип: ${feature.properties['pole_type'] || 'N/A'}<br>
          Высота: ${feature.properties['height'] || 'N/A'} м<br>
          Состояние: ${feature.properties['condition'] || 'N/A'}
        `);

        marker.addTo(this.map!);
        this.poleMarkers.push(marker);
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
    this.tapMarkers.forEach(marker => this.map?.removeLayer(marker));
    this.substationMarkers.forEach(marker => this.map?.removeLayer(marker));
    
    this.powerLineLayers = [];
    this.poleMarkers = [];
    this.tapMarkers = [];
    this.substationMarkers = [];
  }

  centerOnObjects(): void {
    if (!this.map || !this.mapData) return;

    const bounds = L.latLngBounds([]);
    let hasBounds = false;

    // Добавляем все маркеры в bounds
    [...this.poleMarkers, ...this.tapMarkers, ...this.substationMarkers].forEach(marker => {
      bounds.extend(marker.getLatLng());
      hasBounds = true;
    });

    // Добавляем точки из полилиний
    this.powerLineLayers.forEach(layer => {
      if (layer instanceof L.Polyline) {
        layer.getLatLngs().forEach((latlng: any) => {
          if (Array.isArray(latlng)) {
            latlng.forEach((ll: L.LatLng) => bounds.extend(ll));
          } else {
            bounds.extend(latlng);
          }
          hasBounds = true;
        });
      }
    });

    if (hasBounds) {
      this.map.fitBounds(bounds, { padding: [50, 50] });
    }
  }

  refreshData(): void {
    this.loadMapData();
  }
}

