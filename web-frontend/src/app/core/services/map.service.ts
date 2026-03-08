import { Injectable } from '@angular/core';
import { Observable, forkJoin, Subject, BehaviorSubject } from 'rxjs';
import { ApiService } from './api.service';
import { GeoJSONCollection, GeoJSONFeature } from '../models/geojson.model';
import { PowerLine } from '../models/power-line.model';

export interface MapData {
  powerLines: GeoJSONCollection;
  powerLinesList: PowerLine[];
  poles: GeoJSONCollection;
  taps: GeoJSONCollection;
  substations: GeoJSONCollection;
  spans: GeoJSONCollection;
  equipment: GeoJSONCollection;
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
      spans: this.apiService.getSpansGeoJSON(),
      equipment: this.apiService.getEquipmentGeoJSON()
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
  // bounds: опционально [[southWest lat, southWest lng], [northEast lat, northEast lng]] — при задании выполняется fitBounds
  private centerOnFeatureSubject$ = new Subject<{
    type: string;
    coordinates: [number, number];
    zoom?: number | null;
    currentZoomForLogic?: number;
    bounds?: [[number, number], [number, number]];
  }>();
  
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
  // bounds: при задании карта выполняет fitBounds (координаты [lat, lng]: southWest, northEast)
  requestCenterOnFeature(
    type: string,
    coordinates: [number, number],
    zoom?: number | null,
    currentZoomForLogic?: number,
    bounds?: [[number, number], [number, number]]
  ): void {
    this.centerOnFeatureSubject$.next({ type, coordinates, zoom, currentZoomForLogic, bounds });
  }

  // Observable для подписки на центрирование
  get centerOnFeature$(): Observable<{
    type: string;
    coordinates: [number, number];
    zoom?: number | null;
    currentZoomForLogic?: number;
    bounds?: [[number, number], [number, number]];
  }> {
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

  /** Запрос показа панели свойств опоры при клике по дереву (то же, что при клике на карте) */
  private showPolePropertiesSubject$ = new Subject<GeoJSONFeature>();

  requestShowPoleProperties(feature: GeoJSONFeature): void {
    this.showPolePropertiesSubject$.next(feature);
  }

  get showPoleProperties$(): Observable<GeoJSONFeature> {
    return this.showPolePropertiesSubject$.asObservable();
  }

  /** Запрос пересборки топологии линии (пролёты/сегменты по порядку опор) */
  private requestRebuildTopologySubject$ = new Subject<number>();

  requestRebuildTopology(powerLineId: number): void {
    this.requestRebuildTopologySubject$.next(powerLineId);
  }

  get requestRebuildTopology$(): Observable<number> {
    return this.requestRebuildTopologySubject$.asObservable();
  }

  private requestSelectSegmentSubject$ = new Subject<{
    powerLineId: number;
    segmentId: number | null;
    bounds: [[number, number], [number, number]];
  }>();

  requestSelectSegment(powerLineId: number, segmentId: number | null, bounds: [[number, number], [number, number]]): void {
    this.requestSelectSegmentSubject$.next({ powerLineId, segmentId, bounds });
  }

  get requestSelectSegment$(): Observable<{ powerLineId: number; segmentId: number | null; bounds: [[number, number], [number, number]] }> {
    return this.requestSelectSegmentSubject$.asObservable();
  }

  private clearSegmentSelectionSubject$ = new Subject<void>();

  clearSegmentSelection(): void {
    this.clearSegmentSelectionSubject$.next();
  }

  get clearSegmentSelection$(): Observable<void> {
    return this.clearSegmentSelectionSubject$.asObservable();
  }

  // Выбор подстанции в дереве объектов (при клике на подстанцию на карте)
  private requestSelectSubstationInTreeSubject$ = new Subject<{ substationId: number }>();

  requestSelectSubstationInTree(substationId: number): void {
    this.requestSelectSubstationInTreeSubject$.next({ substationId });
  }

  get requestSelectSubstationInTree$(): Observable<{ substationId: number }> {
    return this.requestSelectSubstationInTreeSubject$.asObservable();
  }
}

