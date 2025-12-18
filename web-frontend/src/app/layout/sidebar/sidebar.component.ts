import { Component, OnInit, OnDestroy } from '@angular/core';
import { MapService } from '../../core/services/map.service';
import { MapData } from '../../core/services/map.service';
import { GeoJSONFeature } from '../../core/models/geojson.model';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { MatDialog } from '@angular/material/dialog';
import { DeleteObjectDialogComponent, DeleteObjectData } from '../../features/map/delete-object-dialog/delete-object-dialog.component';

// Структура данных для иерархичного дерева
interface PowerLineTreeItem {
  powerLine: GeoJSONFeature;
  segments: Array<{
    segmentId: number | null;
    segmentName: string | null;
    poles: GeoJSONFeature[];
  }>;
  polesWithoutSegment: GeoJSONFeature[];
}

@Component({
  selector: 'app-sidebar',
  templateUrl: './sidebar.component.html',
  styleUrls: ['./sidebar.component.scss']
})
export class SidebarComponent implements OnInit, OnDestroy {
  mapData: MapData | null = null;
  isLoading = true;
  private destroy$ = new Subject<void>();
  private powerLinesWithPolesCache: PowerLineTreeItem[] | null = null;

  constructor(
    private mapService: MapService,
    private dialog: MatDialog
  ) {}

  ngOnInit(): void {
    this.loadMapData();
    
    // Подписываемся на обновления данных
    this.mapService.dataRefresh
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        this.loadMapData();
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

  // Группировка опор по ЛЭП
  getPolesByPowerLine(powerLineId: number): GeoJSONFeature[] {
    return this.polesFeatures.filter(feature => 
      feature.properties['power_line_id'] === powerLineId
    );
  }

  // Получение всех уникальных ЛЭП с их сегментами и опорами (с кэшированием)
  getPowerLinesWithSegmentsAndPoles(): PowerLineTreeItem[] {
    // Проверяем наличие данных
    if (!this.mapData || !this.powerLinesFeatures.length) {
      return [];
    }
    
    // Используем кэш, если данные не изменились
    if (this.powerLinesWithPolesCache !== null) {
      return this.powerLinesWithPolesCache;
    }
    
    const result: PowerLineTreeItem[] = [];
    
    this.powerLinesFeatures.forEach(powerLine => {
      const powerLineId = powerLine.properties['id'];
      if (powerLineId) {
        const allPoles = this.getPolesByPowerLine(powerLineId);
        
        // Группируем опоры по сегментам
        const segmentsMap = new Map<number | string, GeoJSONFeature[]>();
        const polesWithoutSegment: GeoJSONFeature[] = [];
        
        allPoles.forEach(pole => {
          const segmentId = pole.properties['segment_id'];
          if (segmentId) {
            const key = segmentId;
            if (!segmentsMap.has(key)) {
              segmentsMap.set(key, []);
            }
            segmentsMap.get(key)!.push(pole);
          } else {
            polesWithoutSegment.push(pole);
          }
        });
        
        // Преобразуем Map в массив с информацией о сегментах
        const segments: Array<{
          segmentId: number | null;
          segmentName: string | null;
          poles: GeoJSONFeature[];
        }> = [];
        
        segmentsMap.forEach((poles, segmentId) => {
          // Берем имя сегмента из первой опоры
          const segmentName = poles[0]?.properties['segment_name'] || null;
          segments.push({
            segmentId: typeof segmentId === 'string' ? parseInt(segmentId) : segmentId,
            segmentName,
            poles
          });
        });
        
        // Сортируем сегменты по ID
        segments.sort((a, b) => {
          if (a.segmentId === null) return 1;
          if (b.segmentId === null) return -1;
          return a.segmentId - b.segmentId;
        });
        
        result.push({
          powerLine,
          segments,
          polesWithoutSegment
        });
      }
    });
    
    // Кэшируем результат
    this.powerLinesWithPolesCache = result;
    return result;
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

  togglePowerLine(powerLineId: number): void {
    if (this.expandedPowerLines.has(powerLineId)) {
      this.expandedPowerLines.delete(powerLineId);
    } else {
      this.expandedPowerLines.add(powerLineId);
    }
  }

  isPowerLineExpanded(powerLineId: number): boolean {
    return this.expandedPowerLines.has(powerLineId);
  }

  toggleSegment(powerLineId: number, segmentId: number | null): void {
    const key = `${powerLineId}-${segmentId}`;
    if (this.expandedSegments.has(key)) {
      this.expandedSegments.delete(key);
    } else {
      this.expandedSegments.add(key);
    }
  }

  isSegmentExpanded(powerLineId: number, segmentId: number | null): boolean {
    const key = `${powerLineId}-${segmentId}`;
    return this.expandedSegments.has(key);
  }

  togglePolesFolder(powerLineId: number, folderKey: string): void {
    const key = `${powerLineId}-${folderKey}`;
    if (this.expandedPolesFolders.has(key)) {
      this.expandedPolesFolders.delete(key);
    } else {
      this.expandedPolesFolders.add(key);
    }
  }

  isPolesFolderExpanded(powerLineId: number, folderKey: string): boolean {
    const key = `${powerLineId}-${folderKey}`;
    return this.expandedPolesFolders.has(key);
  }

  onFeatureClick(feature: GeoJSONFeature, event?: Event): void {
    if (event) {
      event.stopPropagation();
    }
    
    // Определяем тип объекта и координаты
    if (feature.geometry.type === 'Point') {
      const coordinates = feature.geometry.coordinates as number[];
      const lat = coordinates[1];
      const lng = coordinates[0];
      
      // Если это опора, применяем логику зума
      if (feature.properties['pole_number']) {
        // Получаем текущий зум из сервиса
        // Используем последнее значение из BehaviorSubject (синхронно)
        const currentZoom = this.mapService.getCurrentZoom();
        let targetZoom: number | null | undefined;
        
        // Логика зума:
        // - Если зум < 13: устанавливаем зум 10
        // - Если зум == 13: не меняем зум (null)
        // - Если зум >= 14: возвращаем к зуму 10
        if (currentZoom < 13) {
          targetZoom = 10;
        } else if (currentZoom === 13) {
          targetZoom = null; // Не меняем зум
        } else if (currentZoom >= 14) {
          targetZoom = 10;
        } else {
          // Для зума между 13 и 14 (не должно быть, но на всякий случай)
          targetZoom = 10;
        }
        
        // Центрируем карту на опоре с учетом логики зума
        this.mapService.requestCenterOnFeature('pole', [lat, lng], targetZoom, currentZoom);
      } else {
        // Для других объектов (отпайки, подстанции) используем текущий зум
        this.mapService.requestCenterOnFeature('pole', [lat, lng]);
      }
    } else if (feature.geometry.type === 'LineString') {
      // Для ЛЭП центрируем на середине линии
      const coordinates = feature.geometry.coordinates as number[][];
      if (coordinates.length > 0) {
        const midIndex = Math.floor(coordinates.length / 2);
        const midCoord = coordinates[midIndex];
        this.mapService.requestCenterOnFeature('powerLine', [midCoord[1], midCoord[0]], 12);
      }
    }
  }

  onFeatureRightClick(feature: GeoJSONFeature, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    // Определяем тип объекта
    let objectType: 'pole' | 'powerLine' | 'substation' | 'tap' = 'pole';
    let objectId: number | null = null;
    let objectName: string = '';
    
    if (feature.properties['pole_number']) {
      objectType = 'pole';
      objectId = feature.properties['id'];
      objectName = feature.properties['pole_number'] || 'N/A';
    } else if (feature.properties['name'] && feature.geometry.type === 'LineString') {
      objectType = 'powerLine';
      objectId = feature.properties['id'];
      objectName = feature.properties['name'] || 'N/A';
    } else if (feature.properties['name'] && feature.geometry.type === 'Point') {
      // Может быть подстанция или отпайка
      if (feature.properties['code']) {
        objectType = 'substation';
        objectId = feature.properties['id'];
        objectName = feature.properties['name'] || 'N/A';
      } else {
        objectType = 'tap';
        objectId = feature.properties['id'];
        objectName = feature.properties['tap_number'] || 'N/A';
      }
    }
    
    if (objectId === null || objectId === undefined) {
      return;
    }
    
    // Открываем диалог подтверждения удаления
    const dialogRef = this.dialog.open(DeleteObjectDialogComponent, {
      width: '400px',
      data: {
        objectType,
        objectId,
        objectName
      } as DeleteObjectData
    });
    
    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        // Обновляем данные после удаления
        this.mapService.refreshData();
        // Перезагружаем данные в sidebar
        this.loadMapData();
      }
    });
  }
}

