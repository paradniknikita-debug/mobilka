import { Component, OnInit, OnDestroy } from '@angular/core';
import { MapService } from '../../core/services/map.service';
import { MapData } from '../../core/services/map.service';
import { GeoJSONFeature } from '../../core/models/geojson.model';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';

@Component({
  selector: 'app-sidebar',
  templateUrl: './sidebar.component.html',
  styleUrls: ['./sidebar.component.scss']
})
export class SidebarComponent implements OnInit, OnDestroy {
  mapData: MapData | null = null;
  isLoading = true;
  private destroy$ = new Subject<void>();

  constructor(private mapService: MapService) {}

  ngOnInit(): void {
    this.loadMapData();
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
          this.isLoading = false;
        },
        error: (error) => {
          console.error('Ошибка загрузки данных для sidebar:', error);
          this.isLoading = false;
        }
      });
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

  onFeatureClick(feature: GeoJSONFeature): void {
    // Эмитим событие для Map компонента через сервис или EventEmitter
    // Пока просто логируем
    console.log('Клик по объекту:', feature.properties);
  }
}

