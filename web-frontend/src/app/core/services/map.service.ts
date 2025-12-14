import { Injectable } from '@angular/core';
import { Observable, forkJoin } from 'rxjs';
import { ApiService } from './api.service';
import { GeoJSONCollection } from '../models/geojson.model';

export interface MapData {
  powerLines: GeoJSONCollection;
  poles: GeoJSONCollection;
  taps: GeoJSONCollection;
  substations: GeoJSONCollection;
}

@Injectable({
  providedIn: 'root'
})
export class MapService {
  constructor(private apiService: ApiService) {}

  loadAllMapData(): Observable<MapData> {
    return forkJoin({
      powerLines: this.apiService.getPowerLinesGeoJSON(),
      poles: this.apiService.getPolesGeoJSON(),
      taps: this.apiService.getTapsGeoJSON(),
      substations: this.apiService.getSubstationsGeoJSON()
    });
  }
}

