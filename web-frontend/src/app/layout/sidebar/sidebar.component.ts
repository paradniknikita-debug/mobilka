import { Component, OnInit, OnDestroy, ViewChild, ChangeDetectorRef } from '@angular/core';
import { MapService } from '../../core/services/map.service';
import { MapData } from '../../core/services/map.service';
import { GeoJSONFeature } from '../../core/models/geojson.model';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { MatDialog } from '@angular/material/dialog';
import { MatMenuTrigger, MatMenu } from '@angular/material/menu';
import { Overlay } from '@angular/cdk/overlay';
import { DeleteObjectDialogComponent, DeleteObjectData } from '../../features/map/delete-object-dialog/delete-object-dialog.component';
import { CreateObjectDialogComponent } from '../../features/map/create-object-dialog/create-object-dialog.component';
import { CreateSpanDialogComponent } from '../../features/map/create-span-dialog/create-span-dialog.component';
import { CreateSegmentDialogComponent } from '../../features/map/create-segment-dialog/create-segment-dialog.component';
import { EditPowerLineDialogComponent } from '../../features/map/edit-power-line-dialog/edit-power-line-dialog.component';
import { ApiService } from '../../core/services/api.service';

// Структура данных для иерархичного дерева
interface PowerLineTreeItem {
  powerLine: GeoJSONFeature;
  segments: Array<{
    segmentId: number | null;
    segmentName: string | null;
    poles: GeoJSONFeature[];
    spans: GeoJSONFeature[];
  }>;
  polesWithoutSegment: GeoJSONFeature[];
  spansWithoutSegment: GeoJSONFeature[];
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
    private cdr: ChangeDetectorRef
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

  get spansFeatures(): GeoJSONFeature[] {
    return this.mapData?.spans?.features || [];
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
        const allSpans = this.spansFeatures.filter(feature => 
          feature.properties['power_line_id'] === powerLineId
        );
        
        // Группируем опоры и пролёты по сегментам
        const segmentsMap = new Map<number | string, {poles: GeoJSONFeature[], spans: GeoJSONFeature[]}>();
        const polesWithoutSegment: GeoJSONFeature[] = [];
        const spansWithoutSegment: GeoJSONFeature[] = [];
        
        allPoles.forEach(pole => {
          const segmentId = pole.properties['segment_id'];
          if (segmentId) {
            const key = segmentId;
            if (!segmentsMap.has(key)) {
              segmentsMap.set(key, {poles: [], spans: []});
            }
            segmentsMap.get(key)!.poles.push(pole);
          } else {
            polesWithoutSegment.push(pole);
          }
        });
        
        // Группируем пролёты по сегментам
        allSpans.forEach((span: GeoJSONFeature) => {
          const segmentId = span.properties['segment_id'] || span.properties['acline_segment_id'];
          if (segmentId) {
            const key = segmentId;
            if (!segmentsMap.has(key)) {
              segmentsMap.set(key, {poles: [], spans: []});
            }
            segmentsMap.get(key)!.spans.push(span);
          } else {
            spansWithoutSegment.push(span);
          }
        });
        
        // Преобразуем Map в массив с информацией о сегментах
        const segments: Array<{
          segmentId: number | null;
          segmentName: string | null;
          poles: GeoJSONFeature[];
          spans: GeoJSONFeature[];
        }> = [];
        
        segmentsMap.forEach((data, segmentId) => {
          // Берем имя сегмента из первой опоры или пролёта
          const segmentName = data.poles[0]?.properties['segment_name'] || 
                            data.spans[0]?.properties['segment_name'] || null;
          segments.push({
            segmentId: typeof segmentId === 'string' ? parseInt(segmentId) : segmentId,
            segmentName,
            poles: data.poles,
            spans: data.spans
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
          polesWithoutSegment,
          spansWithoutSegment
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

  contextMenuPosition = { x: '0px', y: '0px' };
  contextMenuFeature: GeoJSONFeature | null = null;
  contextMenuType: 'powerLine' | 'segment' | 'span' | 'pole' | 'folder' | 'root' | null = null;
  contextMenuPowerLineId: number | null = null;
  contextMenuSegmentId: number | null = null;

  onFeatureRightClick(feature: GeoJSONFeature, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuFeature = feature;
    
    // Определяем тип объекта и контекст
    if (feature.properties['span_number']) {
      // Пролёт
      this.contextMenuType = 'span';
      this.contextMenuPowerLineId = feature.properties['power_line_id'];
      this.contextMenuSegmentId = feature.properties['acline_segment_id'] || feature.properties['segment_id'];
    } else if (feature.properties['pole_number']) {
      // Опора
      this.contextMenuType = 'pole';
      this.contextMenuPowerLineId = feature.properties['power_line_id'];
    } else if (feature.properties['name'] && feature.properties['code'] && !feature.properties['pole_number'] && !feature.properties['tap_number']) {
      // ЛЭП
      this.contextMenuType = 'powerLine';
      this.contextMenuPowerLineId = feature.properties['id'];
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

  onSegmentRightClick(segmentId: number | null, powerLineId: number, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'segment';
    this.contextMenuSegmentId = segmentId;
    this.contextMenuPowerLineId = powerLineId;
    this.contextMenuFeature = null;
    
    // Используем setTimeout для того, чтобы ViewChild успел инициализироваться
    setTimeout(() => {
      if (this.menuTrigger) {
        try {
          // Проверяем, что trigger инициализирован
          if (this.menuTrigger.menu) {
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
    }, 0);
  }

  onFolderRightClick(folderType: 'poles' | 'spans', powerLineId: number, segmentId: number | null, event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'folder';
    this.contextMenuPowerLineId = powerLineId;
    this.contextMenuSegmentId = segmentId;
    this.contextMenuFeature = null;
    
    // Используем setTimeout для того, чтобы ViewChild успел инициализироваться
    setTimeout(() => {
      if (this.menuTrigger) {
        try {
          // Проверяем, что trigger инициализирован
          if (this.menuTrigger.menu) {
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
    }, 0);
  }

  onRootRightClick(event: MouseEvent): void {
    event.preventDefault();
    event.stopPropagation();
    
    this.contextMenuPosition.x = event.clientX + 'px';
    this.contextMenuPosition.y = event.clientY + 'px';
    this.contextMenuType = 'root';
    this.contextMenuFeature = null;
    this.contextMenuPowerLineId = null;
    this.contextMenuSegmentId = null;
    
    // Используем setTimeout для того, чтобы ViewChild успел инициализироваться
    setTimeout(() => {
      if (this.menuTrigger) {
        try {
          // Проверяем, что trigger инициализирован
          if (this.menuTrigger.menu) {
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
    }, 0);
  }

  onCreateObject(): void {
    if (this.contextMenuType === 'root') {
      // В корне - создаём только линию
      const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
        width: '600px',
        data: { defaultObjectType: 'powerline' }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'powerLine' && this.contextMenuPowerLineId) {
      // В линии - создаём опору
      const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
        width: '600px',
        data: { 
          defaultObjectType: 'pole',
          powerLineId: this.contextMenuPowerLineId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'segment' && this.contextMenuPowerLineId) {
      // В участке - создаём пролёт
      const dialogRef = this.dialog.open(CreateSpanDialogComponent, {
        width: '600px',
        data: { 
          powerLineId: this.contextMenuPowerLineId,
          segmentId: this.contextMenuSegmentId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'folder' && this.contextMenuPowerLineId) {
      // В папке опор - создаём опору
      const dialogRef = this.dialog.open(CreateObjectDialogComponent, {
        width: '600px',
        data: { 
          defaultObjectType: 'pole',
          powerLineId: this.contextMenuPowerLineId
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
    if (this.contextMenuType === 'powerLine' && this.contextMenuPowerLineId) {
      // Создаём участок (AClineSegment) в линии
      const dialogRef = this.dialog.open(CreateSegmentDialogComponent, {
        width: '600px',
        data: { 
          powerLineId: this.contextMenuPowerLineId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    }
  }

  onEditObject(): void {
    if (!this.contextMenuFeature) return;
    
    if (this.contextMenuType === 'powerLine' && this.contextMenuPowerLineId) {
      // Редактирование ЛЭП
      const dialogRef = this.dialog.open(EditPowerLineDialogComponent, {
        width: '600px',
        data: { 
          powerLineId: this.contextMenuPowerLineId
        }
      });
      
      dialogRef.afterClosed().subscribe(result => {
        if (result && result.success) {
          this.mapService.refreshData();
        }
      });
    } else if (this.contextMenuType === 'pole') {
      // Редактирование опоры - пока не реализовано
      console.log('Редактирование опоры пока не реализовано');
    } else if (this.contextMenuType === 'span' && this.contextMenuFeature) {
      // Редактирование пролёта
      const spanId = this.contextMenuFeature.properties['id'];
      const powerLineId = this.contextMenuFeature.properties['power_line_id'];
      const segmentId = this.contextMenuFeature.properties['acline_segment_id'] || this.contextMenuFeature.properties['segment_id'];
      
      if (spanId && powerLineId) {
        const dialogRef = this.dialog.open(CreateSpanDialogComponent, {
          width: '600px',
          data: { 
            powerLineId: powerLineId,
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
    }
  }

  onDeleteObject(): void {
    if (!this.contextMenuFeature) return;
    
    // Определяем тип объекта
    let objectType: 'pole' | 'powerLine' | 'substation' | 'tap' | 'span' = 'pole';
    let objectId: number | null = null;
    let objectName: string = '';
    
    if (this.contextMenuFeature.properties['span_number']) {
      objectType = 'span';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['span_number'] || 'N/A';
    } else if (this.contextMenuFeature.properties['pole_number']) {
      objectType = 'pole';
      objectId = this.contextMenuFeature.properties['id'];
      objectName = this.contextMenuFeature.properties['pole_number'] || 'N/A';
    } else if (this.contextMenuFeature.properties['name'] && this.contextMenuFeature.properties['code']) {
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
    
    // Для пролётов добавляем powerLineId
    if (objectType === 'span' && this.contextMenuPowerLineId) {
      deleteData.powerLineId = this.contextMenuPowerLineId;
    }
    
    const dialogRef = this.dialog.open(DeleteObjectDialogComponent, {
      width: '400px',
      data: deleteData,
      autoFocus: false,
      restoreFocus: false
    });
    
    dialogRef.afterClosed().subscribe(result => {
      if (result && result.deleted) {
        this.mapService.refreshData();
      }
    });
  }
}

