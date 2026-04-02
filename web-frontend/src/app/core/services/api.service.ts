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
import { ChangeLogEntry, ChangeLogFilters, ModelIssue } from '../models/change-log.model';

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  /** Параметр для обхода кэша браузера при загрузке данных карты. */
  private cacheBustParams(): HttpParams {
    return new HttpParams().set('_', String(Date.now()));
  }

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
    return this.http.get<PowerLine[]>(`${this.apiUrl}/power-lines`, { params: this.cacheBustParams() });
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

  deletePowerLine(id: number, cascade: boolean = true): Observable<void> {
    const params = new HttpParams().set('cascade', String(cascade));
    return this.http.delete<void>(`${this.apiUrl}/power-lines/${id}`, { params });
  }

  // ========== Poles ==========
  getAllPoles(): Observable<Pole[]> {
    return this.http.get<Pole[]>(`${this.apiUrl}/poles`);
  }

  getPole(id: number): Observable<Pole> {
    return this.http.get<Pole>(`${this.apiUrl}/poles/${id}`);
  }

  getPolesByPowerLine(lineId: number): Observable<Pole[]> {
    return this.http.get<Pole[]>(`${this.apiUrl}/power-lines/${lineId}/poles`);
  }

  createPole(lineId: number, pole: PoleCreate): Observable<Pole> {
    return this.http.post<Pole>(`${this.apiUrl}/power-lines/${lineId}/poles`, pole);
  }

  linkLineToSubstation(lineId: number, firstPoleId: number, substationId: number): Observable<{ acline_segment_id: number; name: string }> {
    return this.http.post<{ acline_segment_id: number; name: string }>(
      `${this.apiUrl}/power-lines/${lineId}/link-substation`,
      { first_pole_id: firstPoleId, substation_id: substationId }
    );
  }

  /** Назначить или снять ТП в конце участка (отпайки) */
  setSegmentEndSubstation(lineId: number, segmentId: number, body: { to_substation_id: number | null }): Observable<{ segment_id: number; to_substation_id: number | null }> {
    return this.http.patch<{ segment_id: number; to_substation_id: number | null }>(
      `${this.apiUrl}/power-lines/${lineId}/segments/${segmentId}/substation`,
      body
    );
  }

  getPoleByPowerLine(lineId: number, poleId: number): Observable<Pole> {
    return this.http.get<Pole>(`${this.apiUrl}/power-lines/${lineId}/poles/${poleId}`);
  }

  updatePole(lineId: number, poleId: number, pole: Partial<PoleCreate>): Observable<Pole> {
    return this.http.put<Pole>(`${this.apiUrl}/power-lines/${lineId}/poles/${poleId}`, pole);
  }

  deletePole(id: number): Observable<{message: string, details?: string}> {
    return this.http.delete<{message: string, details?: string}>(`${this.apiUrl}/poles/${id}`);
  }

  /** Полный URL вложения карточки опоры (для img/audio src). relativeUrl — путь от бэкенда, например /api/v1/attachments/poles/1/file.jpg */
  getAttachmentUrl(relativeUrl: string): string {
    const path = relativeUrl.startsWith('/') ? relativeUrl : `/${relativeUrl}`;
    const base = this.apiUrl.replace(/\/api\/v1\/?$/, '');
    return `${base}${path}`;
  }

  /** Скачать вложение как Blob (для сохранения на диск с правильным именем). */
  getAttachmentBlob(relativeUrl: string): Observable<Blob> {
    const url = this.getAttachmentUrl(relativeUrl);
    return this.http.get(url, { responseType: 'blob' });
  }

  /** Загрузить вложение к карточке опоры (фото, голос, схема, видео). Возвращает url для сохранения в card_comment_attachment. */
  uploadPoleAttachment(poleId: number, attachmentType: 'photo' | 'voice' | 'schema' | 'video', file: File): Observable<{ url: string; type: string; filename: string }> {
    const formData = new FormData();
    formData.append('attachment_type', attachmentType);
    formData.append('file', file);
    return this.http.post<{ url: string; type: string; filename: string }>(
      `${this.apiUrl}/attachments/poles/${poleId}/attachments`,
      formData
    );
  }

  // ========== Spans ==========
  getSpansByPowerLine(lineId: number): Observable<Span[]> {
    return this.http.get<Span[]>(`${this.apiUrl}/power-lines/${lineId}/spans`);
  }

  getSpan(lineId: number, spanId: number): Observable<Span> {
    return this.http.get<Span>(`${this.apiUrl}/power-lines/${lineId}/spans/${spanId}`);
  }

  createSpan(lineId: number, span: any, segmentId?: number): Observable<Span> {
    let url = `${this.apiUrl}/power-lines/${lineId}/spans`;
    if (segmentId) {
      url += `?segment_id=${segmentId}`;
    }
    return this.http.post<Span>(url, span);
  }

  updateSpan(lineId: number, spanId: number, span: any): Observable<Span> {
    return this.http.put<Span>(`${this.apiUrl}/power-lines/${lineId}/spans/${spanId}`, span);
  }

  deleteSpan(lineId: number, spanId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/power-lines/${lineId}/spans/${spanId}`);
  }

  autoCreateSpans(lineId: number, mode: 'full' | 'preserve' = 'full'): Observable<any> {
    const params = new HttpParams().set('mode', mode);
    return this.http.post<any>(`${this.apiUrl}/power-lines/${lineId}/spans/auto-create`, {}, { params });
  }

  // ========== Equipment ==========
  getAllEquipment(): Observable<Equipment[]> {
    return this.http.get<Equipment[]>(`${this.apiUrl}/equipment`, { params: this.cacheBustParams() });
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

  updateEquipment(id: number, equipment: Partial<EquipmentCreate>): Observable<Equipment> {
    return this.http.put<Equipment>(`${this.apiUrl}/equipment/${id}`, equipment);
  }

  deleteEquipment(id: number): Observable<{message: string}> {
    return this.http.delete<{message: string}>(`${this.apiUrl}/equipment/${id}`);
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

  updateSubstation(id: number, substation: SubstationCreate): Observable<Substation> {
    return this.http.put<Substation>(`${this.apiUrl}/substations/${id}`, substation);
  }

  deleteSubstation(id: number): Observable<{message: string}> {
    return this.http.delete<{message: string}>(`${this.apiUrl}/substations/${id}`);
  }

  // ========== Map ==========
  getPowerLinesGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/power-lines/geojson`, { params: this.cacheBustParams() });
  }

  getPolesGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/poles/geojson`, { params: this.cacheBustParams() });
  }

  getTapsGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/taps/geojson`, { params: this.cacheBustParams() });
  }

  getSubstationsGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/substations/geojson`, { params: this.cacheBustParams() });
  }

  getSpansGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/spans/geojson`, { params: this.cacheBustParams() });
  }

  /** Оборудование на карте: точки между опорами с иконкой и углом (как во Flutter). */
  getEquipmentGeoJSON(): Observable<GeoJSONCollection> {
    return this.http.get<GeoJSONCollection>(`${this.apiUrl}/map/equipment/geojson`, { params: this.cacheBustParams() });
  }

  getDataBounds(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/map/bounds`);
  }

  getAclineSegment(segmentId: number): Observable<AClineSegment> {
    return this.http.get<AClineSegment>(`${this.apiUrl}/cim/acline-segments/${segmentId}`);
  }

  getPoleTerminals(poleId: number): Observable<Terminal[]> {
    return this.http.get<Terminal[]>(`${this.apiUrl}/cim/poles/${poleId}/terminals`);
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

  // ========== CIM Export / Import (FullModel, 552) ==========
  exportCIMXml(
    includeSubstations: boolean = true,
    includePowerLines: boolean = true,
    useCimpy: boolean = true,
    includeGps: boolean = true,
    lineId: number | null = null,
    includeEquipment: boolean = true,
    includeElectricalModel: boolean = true,
    includeDefects: boolean = true,
    includeSubstationVoltageLevels: boolean = true
  ): Observable<Blob> {
    let params = new HttpParams()
      .set('include_substations', String(includeSubstations))
      .set('include_power_lines', String(includePowerLines))
      .set('use_cimpy', String(useCimpy))
      .set('include_gps', String(includeGps))
      .set('include_equipment', String(includeEquipment))
      .set('include_electrical_model', String(includeElectricalModel))
      .set('include_defects', String(includeDefects))
      .set('include_substation_voltage_levels', String(includeSubstationVoltageLevels));

    if (lineId != null) {
      params = params.set('line_id', String(lineId));
    }
    return this.http.get(`${this.apiUrl}/cim/export/xml`, {
      params,
      responseType: 'blob'
    });
  }

  importCIMXml(file: File): Observable<{ summary?: Record<string, number>; count?: number; objects?: any[] }> {
    const formData = new FormData();
    formData.append('file', file, file.name);
    return this.http.post<{ summary?: Record<string, number>; count?: number; objects?: any[] }>(
      `${this.apiUrl}/cim/import/xml`,
      formData
    );
  }

  exportCIM552Diff(
    includeSubstations: boolean = true,
    includePowerLines: boolean = true,
    includeGps: boolean = true,
    lineId: number | null = null,
    includeEquipment: boolean = true,
    includeElectricalModel: boolean = true,
    includeDefects: boolean = true,
    includeSubstationVoltageLevels: boolean = true
  ): Observable<Blob> {
    let params = new HttpParams()
      .set('include_substations', String(includeSubstations))
      .set('include_power_lines', String(includePowerLines))
      .set('include_gps', String(includeGps))
      .set('include_equipment', String(includeEquipment))
      .set('include_electrical_model', String(includeElectricalModel))
      .set('include_defects', String(includeDefects))
      .set('include_substation_voltage_levels', String(includeSubstationVoltageLevels));

    if (lineId != null) {
      params = params.set('line_id', String(lineId));
    }

    return this.http.get(`${this.apiUrl}/cim/export/552-diff`, {
      params,
      responseType: 'blob'
    });
  }

  importCIM552Diff(file: File): Observable<{ summary?: Record<string, number>; count?: number; objects?: any[] }> {
    const formData = new FormData();
    formData.append('file', file, file.name);
    return this.http.post<{ summary?: Record<string, number>; count?: number; objects?: any[] }>(
      `${this.apiUrl}/cim/import/552-diff`,
      formData
    );
  }

  applyCIM552Diff(file: File): Observable<{ created_substations?: number; created_locations?: number; created_position_points?: number }> {
    const formData = new FormData();
    formData.append('file', file, file.name);
    return this.http.post<{ created_substations?: number; created_locations?: number; created_position_points?: number }>(
      `${this.apiUrl}/cim/apply/552-diff`,
      formData
    );
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

  deleteAClineSegment(id: number): Observable<{message?: string; details?: string}> {
    return this.http.delete<{message?: string; details?: string}>(`${this.apiUrl}/cim/acline-segments/${id}`);
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
  autoSequencePoles(lineId: number, startPoleId?: number): Observable<PoleSequenceResponse> {
    const params = startPoleId ? new HttpParams().set('start_pole_id', startPoleId.toString()) : undefined;
    return this.http.post<PoleSequenceResponse>(
      `${this.apiUrl}/power-lines/${lineId}/poles/auto-sequence`,
      {},
      { params }
    );
  }

  updatePoleSequence(lineId: number, poleIds: number[]): Observable<PoleSequenceResponse> {
    return this.http.put<PoleSequenceResponse>(
      `${this.apiUrl}/power-lines/${lineId}/poles/sequence`,
      poleIds
    );
  }

  getPolesSequence(lineId: number): Observable<Pole[]> {
    return this.http.get<Pole[]>(`${this.apiUrl}/power-lines/${lineId}/poles/sequence`);
  }

  // ========== Журнал (изменения + несоответствия) ==========
  getChangeLog(params?: ChangeLogFilters): Observable<ChangeLogEntry[]> {
    let httpParams = new HttpParams();
    if (params?.source) httpParams = httpParams.set('source', params.source);
    if (params?.action) httpParams = httpParams.set('action', params.action);
    if (params?.entity_type) httpParams = httpParams.set('entity_type', params.entity_type);
    if (params?.entity_id != null) httpParams = httpParams.set('entity_id', String(params.entity_id));
    if (params?.from_dt) httpParams = httpParams.set('from_dt', String(params.from_dt));
    if (params?.to_dt) httpParams = httpParams.set('to_dt', String(params.to_dt));
    if (params?.limit != null) httpParams = httpParams.set('limit', params.limit.toString());
    if (params?.offset != null) httpParams = httpParams.set('offset', params.offset.toString());
    return this.http.get<ChangeLogEntry[]>(`${this.apiUrl}/change-log`, { params: httpParams });
  }

  getChangeLogErrors(): Observable<ModelIssue[]> {
    return this.http.get<ModelIssue[]>(`${this.apiUrl}/change-log/errors`);
  }

  createChangeLogEntry(data: {
    source: string;
    action: string;
    entity_type: string;
    entity_id?: number | null;
    payload?: Record<string, unknown> | null;
    session_id?: string | null;
  }): Observable<ChangeLogEntry> {
    return this.http.post<ChangeLogEntry>(`${this.apiUrl}/change-log`, data);
  }

  // ========== Reports (defects / patrol / by line) ==========
  getDefectsReport(params: {
    line_id?: number | null;
    pole_id?: number | null;
    criticality?: string | null;
    defect_contains?: string | null;
    from_dt?: string | null;
    to_dt?: string | null;
    limit?: number | null;
    offset?: number | null;
    format?: 'json' | 'csv';
  }): Observable<any> {
    let httpParams = new HttpParams();
    if (params?.line_id != null) httpParams = httpParams.set('line_id', String(params.line_id));
    if (params?.pole_id != null) httpParams = httpParams.set('pole_id', String(params.pole_id));
    if (params?.criticality != null) httpParams = httpParams.set('criticality', String(params.criticality));
    if (params?.defect_contains != null) httpParams = httpParams.set('defect_contains', String(params.defect_contains));
    if (params?.from_dt != null) httpParams = httpParams.set('from_dt', String(params.from_dt));
    if (params?.to_dt != null) httpParams = httpParams.set('to_dt', String(params.to_dt));
    if (params?.limit != null) httpParams = httpParams.set('limit', String(params.limit));
    if (params?.offset != null) httpParams = httpParams.set('offset', String(params.offset));
    httpParams = httpParams.set('format', params?.format ?? 'json');
    return this.http.get<any>(`${this.apiUrl}/reports/defects`, { params: httpParams });
  }

  downloadDefectsReportCsv(params: {
    line_id?: number | null;
    pole_id?: number | null;
    criticality?: string | null;
    defect_contains?: string | null;
    from_dt?: string | null;
    to_dt?: string | null;
    limit?: number | null;
    offset?: number | null;
  }): Observable<Blob> {
    let httpParams = new HttpParams();
    if (params?.line_id != null) httpParams = httpParams.set('line_id', String(params.line_id));
    if (params?.pole_id != null) httpParams = httpParams.set('pole_id', String(params.pole_id));
    if (params?.criticality != null) httpParams = httpParams.set('criticality', String(params.criticality));
    if (params?.defect_contains != null) httpParams = httpParams.set('defect_contains', String(params.defect_contains));
    if (params?.from_dt != null) httpParams = httpParams.set('from_dt', String(params.from_dt));
    if (params?.to_dt != null) httpParams = httpParams.set('to_dt', String(params.to_dt));
    if (params?.limit != null) httpParams = httpParams.set('limit', String(params.limit));
    if (params?.offset != null) httpParams = httpParams.set('offset', String(params.offset));
    httpParams = httpParams.set('format', 'csv');
    return this.http.get(`${this.apiUrl}/reports/defects`, { params: httpParams, responseType: 'blob' });
  }

  getByLineReport(lineId: number): Observable<any> {
    const httpParams = new HttpParams().set('line_id', String(lineId));
    return this.http.get<any>(`${this.apiUrl}/reports/by-line`, { params: httpParams });
  }

  getPatrolReport(params: {
    line_id?: number | null;
    from_dt?: string | null;
    to_dt?: string | null;
    limit?: number | null;
    offset?: number | null;
  }): Observable<any> {
    let httpParams = new HttpParams();
    if (params?.line_id != null) httpParams = httpParams.set('line_id', String(params.line_id));
    if (params?.from_dt != null) httpParams = httpParams.set('from_dt', String(params.from_dt));
    if (params?.to_dt != null) httpParams = httpParams.set('to_dt', String(params.to_dt));
    if (params?.limit != null) httpParams = httpParams.set('limit', String(params.limit));
    if (params?.offset != null) httpParams = httpParams.set('offset', String(params.offset));
    return this.http.get<any>(`${this.apiUrl}/reports/patrol`, { params: httpParams });
  }
}

