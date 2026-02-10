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
import {
  ConnectivityNode, ConnectivityNodeCreate,
  Terminal, TerminalCreate,
  LineSection, LineSectionCreate,
  AClineSegment, AClineSegmentCreate,
  Span, SpanCreate,
  PoleSequenceResponse
} from '../models/cim.model';

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
    // Убираем слэш в конце, чтобы избежать редиректа, который может сбросить CORS заголовки
    const url = `${this.apiUrl}/power-lines`.replace(/\/$/, '');
    console.log('ApiService.createPowerLine:', { url, data: powerLine });
    return this.http.post<PowerLine>(url, powerLine);
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

  getPoleByPowerLine(powerLineId: number, poleId: number): Observable<Pole> {
    return this.http.get<Pole>(`${this.apiUrl}/power-lines/${powerLineId}/poles/${poleId}`);
  }

  updatePole(powerLineId: number, poleId: number, pole: Partial<PoleCreate>): Observable<Pole> {
    return this.http.put<Pole>(`${this.apiUrl}/power-lines/${powerLineId}/poles/${poleId}`, pole);
  }

  deletePole(id: number): Observable<{message: string, details?: string}> {
    return this.http.delete<{message: string, details?: string}>(`${this.apiUrl}/poles/${id}`);
  }

  // ========== Spans ==========
  getSpansByPowerLine(powerLineId: number): Observable<Span[]> {
    return this.http.get<Span[]>(`${this.apiUrl}/power-lines/${powerLineId}/spans`);
  }

  getSpan(powerLineId: number, spanId: number): Observable<Span> {
    return this.http.get<Span>(`${this.apiUrl}/power-lines/${powerLineId}/spans/${spanId}`);
  }

  createSpan(powerLineId: number, span: any, segmentId?: number): Observable<Span> {
    let url = `${this.apiUrl}/power-lines/${powerLineId}/spans`;
    if (segmentId) {
      url += `?segment_id=${segmentId}`;
    }
    return this.http.post<Span>(url, span);
  }

  updateSpan(powerLineId: number, spanId: number, span: any): Observable<Span> {
    return this.http.put<Span>(`${this.apiUrl}/power-lines/${powerLineId}/spans/${spanId}`, span);
  }

  deleteSpan(powerLineId: number, spanId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/power-lines/${powerLineId}/spans/${spanId}`);
  }

  autoCreateSpans(powerLineId: number): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/power-lines/${powerLineId}/spans/auto-create`, {});
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

  deleteSubstation(id: number): Observable<{message: string}> {
    return this.http.delete<{message: string}>(`${this.apiUrl}/substations/${id}`);
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

  getSpansGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/spans/geojson`);
  }

  getDataBounds(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/map/bounds`);
  }

  // ========== Sync ==========
  uploadSyncBatch(batch: any): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/sync/upload`, batch);
  }

  downloadSyncData(lastSync: string): Observable<any> {
    const params = new HttpParams().set('last_sync', lastSync);
    return this.http.get<any>(`${this.apiUrl}/sync/download`, { params });
  }

  getAllSchemas(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/sync/schemas`);
  }

  getEntitySchema(entityType: string): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/sync/schema/${entityType}`);
  }

  // ========== CIM Structure ==========
  
  // ConnectivityNode
  createConnectivityNode(node: ConnectivityNodeCreate): Observable<ConnectivityNode> {
    return this.http.post<ConnectivityNode>(`${this.apiUrl}/cim/connectivity-nodes`, node);
  }

  getConnectivityNode(id: number): Observable<ConnectivityNode> {
    return this.http.get<ConnectivityNode>(`${this.apiUrl}/cim/connectivity-nodes/${id}`);
  }

  updateConnectivityNode(id: number, node: ConnectivityNodeCreate): Observable<ConnectivityNode> {
    return this.http.put<ConnectivityNode>(`${this.apiUrl}/cim/connectivity-nodes/${id}`, node);
  }

  deleteConnectivityNode(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/cim/connectivity-nodes/${id}`);
  }

  createConnectivityNodeForPole(poleId: number): Observable<ConnectivityNode> {
    return this.http.post<ConnectivityNode>(`${this.apiUrl}/cim/poles/${poleId}/connectivity-node`, {});
  }

  deleteConnectivityNodeFromPole(poleId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/cim/poles/${poleId}/connectivity-node`);
  }

  // AClineSegment
  createAClineSegment(segment: AClineSegmentCreate): Observable<AClineSegment> {
    return this.http.post<AClineSegment>(`${this.apiUrl}/cim/acline-segments`, segment);
  }

  getAClineSegment(id: number): Observable<AClineSegment> {
    return this.http.get<AClineSegment>(`${this.apiUrl}/cim/acline-segments/${id}`);
  }

  updateAClineSegment(id: number, segment: AClineSegmentCreate): Observable<AClineSegment> {
    return this.http.put<AClineSegment>(`${this.apiUrl}/cim/acline-segments/${id}`, segment);
  }

  // LineSection
  createLineSection(section: LineSectionCreate): Observable<LineSection> {
    return this.http.post<LineSection>(`${this.apiUrl}/cim/line-sections`, section);
  }

  getLineSection(id: number): Observable<LineSection> {
    return this.http.get<LineSection>(`${this.apiUrl}/cim/line-sections/${id}`);
  }

  // Span (CIM version)
  createSpanCIM(span: SpanCreate): Observable<Span> {
    return this.http.post<Span>(`${this.apiUrl}/cim/spans`, span);
  }

  // Pole Sequence
  autoSequencePoles(powerLineId: number, startPoleId?: number): Observable<PoleSequenceResponse> {
    const params = startPoleId ? new HttpParams().set('start_pole_id', startPoleId.toString()) : undefined;
    return this.http.post<PoleSequenceResponse>(
      `${this.apiUrl}/power-lines/${powerLineId}/poles/auto-sequence`,
      {},
      { params }
    );
  }

  updatePoleSequence(powerLineId: number, poleIds: number[]): Observable<PoleSequenceResponse> {
    return this.http.put<PoleSequenceResponse>(
      `${this.apiUrl}/power-lines/${powerLineId}/poles/sequence`,
      poleIds
    );
  }

  getPolesSequence(powerLineId: number): Observable<Pole[]> {
    return this.http.get<Pole[]>(`${this.apiUrl}/power-lines/${powerLineId}/poles/sequence`);
  }
}

