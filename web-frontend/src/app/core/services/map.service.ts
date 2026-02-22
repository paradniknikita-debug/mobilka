import { Injectable } from '@angular/core';
import { Observable, forkJoin, Subject, BehaviorSubject } from 'rxjs';
import { ApiService } from './api.service';
import { GeoJSONCollection } from '../models/geojson.model';
import { PowerLine } from '../models/power-line.model';

export interface MapData {
  powerLines: GeoJSONCollection;
  powerLinesList: PowerLine[];
  poles: GeoJSONCollection;
  taps: GeoJSONCollection;
  substations: GeoJSONCollection;
  spans: GeoJSONCollection;
}

@Injectable({
  providedIn: 'root'
})
export class MapService {
  private dataRefresh$ = new Subject<void>();
  
  constructor(private apiService: ApiService) {}

  loadAllMapData(): Observable<MapData> {
    return forkJoin({
      powerLines: this.apiService.getPowerLinesGeoJSON(),
      powerLinesList: this.apiService.getPowerLines(),
      poles: this.apiService.getPolesGeoJSON(),
      taps: this.apiService.getTapsGeoJSON(),
      substations: this.apiService.getSubstationsGeoJSON(),
      spans: this.apiService.getSpansGeoJSON()
    });
  }

  // Метод для уведомления об обновлении данных
  refreshData(): void {
    this.dataRefresh$.next();
  }

  // Observable для подписки на обновления
  get dataRefresh(): Observable<void> {
    return this.dataRefresh$.asObservable();
  }

  // Subject для центрирования на объекте
  // zoom: number - конкретный зум, null - не менять зум, undefined - использовать значение по умолчанию
  // currentZoomForLogic: текущий зум для применения логики (если нужен)
  private centerOnFeatureSubject$ = new Subject<{type: string, coordinates: [number, number], zoom?: number | null, currentZoomForLogic?: number}>();
  
  // Текущий зум карты (используем BehaviorSubject для синхронизации)
  private currentZoom$ = new BehaviorSubject<number>(10);
  
  // Метод для обновления текущего зума
  setCurrentZoom(zoom: number): void {
    this.currentZoom$.next(zoom);
  }
  
  // Метод для получения текущего зума (синхронно)
  getCurrentZoom(): number {
    return this.currentZoom$.getValue();
  }
  
  // Observable для подписки на изменения зума
  get currentZoomObservable$(): Observable<number> {
    return this.currentZoom$.asObservable();
  }
  
  // Метод для центрирования на объекте
  // zoom: number - конкретный зум, null - не менять зум, undefined - использовать значение по умолчанию
  // currentZoomForLogic: текущий зум для применения логики (опционально)
  requestCenterOnFeature(type: string, coordinates: [number, number], zoom?: number | null, currentZoomForLogic?: number): void {
    this.centerOnFeatureSubject$.next({ type, coordinates, zoom, currentZoomForLogic });
  }

  // Observable для подписки на центрирование
  get centerOnFeature$(): Observable<{type: string, coordinates: [number, number], zoom?: number | null, currentZoomForLogic?: number}> {
    return this.centerOnFeatureSubject$.asObservable();
  }

  // Запрос выделения опоры в дереве объектов (при клике на опору на карте)
  private requestSelectPoleInTreeSubject$ = new Subject<{
    powerLineId: number;
    segmentId?: number | null;
    poleId: number;
  }>();

  requestSelectPoleInTree(powerLineId: number, poleId: number, segmentId?: number | null): void {
    this.requestSelectPoleInTreeSubject$.next({ powerLineId, segmentId, poleId });
  }

  get requestSelectPoleInTree$(): Observable<{
    powerLineId: number;
    segmentId?: number | null;
    poleId: number;
  }> {
    return this.requestSelectPoleInTreeSubject$.asObservable();
  }
}

