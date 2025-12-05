import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { User, UserCreate, AuthResponse } from '../models/user.model';
import { PowerLine, PowerLineCreate } from '../models/power-line.model';
import { Pole, PoleCreate } from '../models/pole.model';
import { Equipment, EquipmentCreate } from '../models/equipment.model';
import { Substation, SubstationCreate } from '../models/substation.model';
import { GeoJSONCollection } from '../models/geojson.model';

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  // ========== Authentication ==========
  login(username: string, password: string): Observable<AuthResponse> {
    const formData = new URLSearchParams();
    formData.set('username', username);
    formData.set('password', password);

    return this.http.post<AuthResponse>(`${this.apiUrl}/auth/login`, formData.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
  }

  register(userData: UserCreate): Observable<User> {
    return this.http.post<User>(`${this.apiUrl}/auth/register`, userData);
  }

  getCurrentUser(): Observable<User> {
    return this.http.get<User>(`${this.apiUrl}/auth/me`);
  }

  // ========== Power Lines ==========
  getPowerLines(): Observable<PowerLine[]> {
    return this.http.get<PowerLine[]>(`${this.apiUrl}/power-lines`);
  }

  getPowerLine(id: number): Observable<PowerLine> {
    return this.http.get<PowerLine>(`${this.apiUrl}/power-lines/${id}`);
  }

  createPowerLine(powerLine: PowerLineCreate): Observable<PowerLine> {
    return this.http.post<PowerLine>(`${this.apiUrl}/power-lines`, powerLine);
  }

  updatePowerLine(id: number, powerLine: Partial<PowerLineCreate>): Observable<PowerLine> {
    return this.http.put<PowerLine>(`${this.apiUrl}/power-lines/${id}`, powerLine);
  }

  deletePowerLine(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/power-lines/${id}`);
  }

  // ========== Poles ==========
  getAllPoles(): Observable<Pole[]> {
    return this.http.get<Pole[]>(`${this.apiUrl}/poles`);
  }

  getPole(id: number): Observable<Pole> {
    return this.http.get<Pole>(`${this.apiUrl}/poles/${id}`);
  }

  getPolesByPowerLine(powerLineId: number): Observable<Pole[]> {
    return this.http.get<Pole[]>(`${this.apiUrl}/power-lines/${powerLineId}/poles`);
  }

  createPole(powerLineId: number, pole: PoleCreate): Observable<Pole> {
    return this.http.post<Pole>(`${this.apiUrl}/power-lines/${powerLineId}/poles`, pole);
  }

  // ========== Equipment ==========
  getAllEquipment(): Observable<Equipment[]> {
    return this.http.get<Equipment[]>(`${this.apiUrl}/equipment`);
  }

  getEquipment(id: number): Observable<Equipment> {
    return this.http.get<Equipment>(`${this.apiUrl}/equipment/${id}`);
  }

  getPoleEquipment(poleId: number): Observable<Equipment[]> {
    return this.http.get<Equipment[]>(`${this.apiUrl}/poles/${poleId}/equipment`);
  }

  createEquipment(poleId: number, equipment: EquipmentCreate): Observable<Equipment> {
    return this.http.post<Equipment>(`${this.apiUrl}/poles/${poleId}/equipment`, equipment);
  }

  // ========== Substations ==========
  getSubstations(): Observable<Substation[]> {
    return this.http.get<Substation[]>(`${this.apiUrl}/substations`);
  }

  getSubstation(id: number): Observable<Substation> {
    return this.http.get<Substation>(`${this.apiUrl}/substations/${id}`);
  }

  createSubstation(substation: SubstationCreate): Observable<Substation> {
    return this.http.post<Substation>(`${this.apiUrl}/substations`, substation);
  }

  // ========== Map ==========
  getPowerLinesGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/power-lines/geojson`);
  }

  getPolesGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/poles/geojson`);
  }

  getTapsGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/taps/geojson`);
  }

  getSubstationsGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/substations/geojson`);
  }

  getDataBounds(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/map/bounds`);
  }
}

