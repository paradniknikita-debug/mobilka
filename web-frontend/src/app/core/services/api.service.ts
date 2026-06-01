import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse, HttpParams, HttpResponse } from '@angular/common/http';
import { Observable, from, throwError } from 'rxjs';
import { map, catchError, switchMap } from 'rxjs/operators';
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
import { EquipmentCatalogCreate, EquipmentCatalogItem } from '../models/equipment-catalog.model';
import { LineConductorCatalogCreate, LineConductorCatalogItem } from '../models/line-conductor-catalog.model';
import { WireInfoCreate, WireInfoItem } from '../models/wire-info.model';
import { filenameFromContentDisposition } from '../utils/content-disposition';

/** Технические паспорта (паспортизация) */
export interface TechPassportListItem {
  id: number;
  mrid: string;
  title: string;
  object_type: string;
  object_mrid: string;
  object_id?: number | null;
  stp_reference?: string | null;
  created_at?: string | null;
}

export interface TechPassportListResponse {
  items: TechPassportListItem[];
  total: number;
}

export interface PassportSectionRow {
  label: string;
  value: unknown;
}

export interface PassportSectionTable {
  title: string;
  columns: string[];
  rows: Record<string, unknown>[];
}

export interface PassportSection {
  id: string;
  title: string;
  rows: PassportSectionRow[];
  tables: PassportSectionTable[];
}

export interface TechPassportDetail extends TechPassportListItem {
  snapshot_json: Record<string, unknown>;
  manual_sections?: Record<string, unknown> | null;
  sections?: PassportSection[];
}

export interface MapUidSearchHit {
  entity_type: string;
  entity_id: number;
  mrid: string;
  label: string;
  line_id?: number | null;
  pole_id?: number | null;
  substation_id?: number | null;
  latitude?: number | null;
  longitude?: number | null;
}

export interface AdminLoadMetrics {
  minutes: number;
  bucket_minutes?: number;
  from_ts: string | null;
  to_ts: string | null;
  redis_available: boolean;
  totals: { http_requests: number; db_writes: number };
  points: { ts: string; http_requests: number; db_writes: number }[];
}

/** Ответ POST /cim/apply/552-diff */
export interface CimApply552DiffResponse {
  created_substations?: number;
  created_locations?: number;
  created_position_points?: number;
  created_lines?: number;
  created_poles?: number;
  created_connectivity_nodes?: number;
  created_segments?: number;
  created_line_sections?: number;
  created_spans?: number;
  created_equipment?: number;
  parsed_total?: number;
  applied_total?: number;
  forward_total?: number;
  skipped_lepm_scaffolding?: number;
  reverse_total?: number;
  parsed_by_class?: Record<string, number>;
  hint?: string | null;
}

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

  getAdminStats(): Observable<Record<string, unknown>> {
    return this.http.get<Record<string, unknown>>(`${this.apiUrl}/admin/stats`);
  }

  getAdminLoadMetrics(
    minutes = 60,
    bucketMinutes?: number,
    maxPoints = 96,
  ): Observable<AdminLoadMetrics> {
    let params = new HttpParams()
      .set('minutes', String(minutes))
      .set('max_points', String(maxPoints));
    if (bucketMinutes != null && bucketMinutes > 0) {
      params = params.set('bucket_minutes', String(bucketMinutes));
    }
    return this.http.get<AdminLoadMetrics>(`${this.apiUrl}/admin/metrics/load`, { params });
  }

  getAdminInfrastructure(): Observable<{
    minio_console_url: string;
    swagger_url: string;
    redoc_url: string;
    api_home_url: string;
    openapi_url: string;
    docker_logs_available: boolean;
  }> {
    return this.http.get<{
      minio_console_url: string;
      swagger_url: string;
      redoc_url: string;
      api_home_url: string;
      openapi_url: string;
      docker_logs_available: boolean;
    }>(`${this.apiUrl}/admin/infrastructure`);
  }

  getAdminDockerLogs(
    service: string,
    tail = 300,
  ): Observable<{ service: string; container: string; tail: number; log: string }> {
    return this.http.get<{ service: string; container: string; tail: number; log: string }>(
      `${this.apiUrl}/admin/docker-logs/${encodeURIComponent(service)}`,
      { params: { tail: String(tail) } },
    );
  }

  getAdminUsers(): Observable<User[]> {
    return this.http.get<User[]>(`${this.apiUrl}/admin/users`);
  }

  createAdminUser(body: UserCreate): Observable<User> {
    return this.http.post<User>(`${this.apiUrl}/admin/users`, body);
  }

  patchAdminUser(
    id: number,
    body: Partial<{ full_name: string; email: string; role: string; is_active: boolean; password: string }>,
  ): Observable<User> {
    return this.http.patch<User>(`${this.apiUrl}/admin/users/${id}`, body);
  }

  deleteAdminUser(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/admin/users/${id}`);
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
    const raw = (relativeUrl || '').trim();
    if (!raw) return raw;
    const base = this.apiUrl.replace(/\/api\/v1\/?$/, '');
    if (/^https?:\/\//i.test(raw)) {
      try {
        const u = new URL(raw);
        const pathAndQuery = `${u.pathname || ''}${u.search || ''}${u.hash || ''}`;
        if (u.pathname.startsWith('/api/v1/')) {
          return `${base}${pathAndQuery}`;
        }
        if (u.pathname.startsWith('/attachments/')) {
          return `${base}/api/v1${pathAndQuery}`;
        }
      } catch {
        // Если URL некорректный — используем как есть.
      }
      return raw;
    }

    const normalized = raw.startsWith('/') ? raw : `/${raw}`;
    if (normalized.startsWith('/api/v1/')) {
      return `${base}${normalized}`;
    }
    if (normalized.startsWith('/attachments/')) {
      return `${base}/api/v1${normalized}`;
    }
    return `${base}${normalized}`;
  }

  /** Скачать вложение как Blob (для превью в img/audio). */
  getAttachmentBlob(relativeUrl: string): Observable<Blob> {
    return this.downloadAttachmentFile(relativeUrl, 'attachment').pipe(map((r) => r.blob));
  }

  /**
   * Скачать вложение: Blob + имя из Content-Disposition или fallback.
   */
  downloadAttachmentFile(
    relativeUrl: string,
    fallbackName: string
  ): Observable<{ blob: Blob; filename: string }> {
    const raw = (relativeUrl || '').trim();
    const candidates = this.buildAttachmentUrlCandidates(raw);
    if (!candidates.length) {
      candidates.push(this.getAttachmentUrl(raw));
    }

    const tryByIndex = (index: number): Observable<{ blob: Blob; filename: string }> => {
      const url = candidates[index];
      return this.http
        .get(url, { responseType: 'blob', observe: 'response' })
        .pipe(
          map((resp: HttpResponse<Blob>) => {
            const body = resp.body;
            if (!body) {
              throw new Error('Пустой ответ');
            }
            const fromHeader = filenameFromContentDisposition(
              resp.headers.get('Content-Disposition')
            );
            const filename =
              (fromHeader && fromHeader.trim()) ||
              (fallbackName && fallbackName.trim()) ||
              'attachment';
            return { blob: body, filename };
          }),
          catchError((err) => {
            if (index + 1 < candidates.length) {
              return tryByIndex(index + 1);
            }
            return throwError(() => err);
          })
        );
    };

    return tryByIndex(0);
  }

  /** Для legacy голосовых ссылок (.mp3/.ogg/.m4a...) пробуем соседние расширения. */
  private buildAttachmentUrlCandidates(relativeUrl: string): string[] {
    if (!relativeUrl) return [];
    if (/^https?:\/\//i.test(relativeUrl)) {
      // Полный URL уже готов к запросу, не нормализуем как относительный путь.
      const qIdx = relativeUrl.indexOf('?');
      const hashIdx = relativeUrl.indexOf('#');
      const cutAt = [qIdx, hashIdx].filter((x) => x >= 0).reduce((a, b) => Math.min(a, b), Number.MAX_SAFE_INTEGER);
      const basePart = cutAt === Number.MAX_SAFE_INTEGER ? relativeUrl : relativeUrl.slice(0, cutAt);
      const suffix = cutAt === Number.MAX_SAFE_INTEGER ? '' : relativeUrl.slice(cutAt);
      const dot = basePart.lastIndexOf('.');
      if (dot < 0) return [relativeUrl];
      const ext = basePart.slice(dot).toLowerCase();
      const voiceExt = ['.mp3', '.ogg', '.m4a', '.wav', '.webm'];
      if (!voiceExt.includes(ext)) return [relativeUrl];
      const stem = basePart.slice(0, dot);
      return [ext, ...voiceExt.filter((x) => x !== ext)].map((e) => `${stem}${e}${suffix}`);
    }

    const normalized = relativeUrl.startsWith('/') ? relativeUrl : `/${relativeUrl}`;
    const dot = normalized.lastIndexOf('.');
    if (dot < 0) {
      return [this.getAttachmentUrl(normalized)];
    }

    const ext = normalized.slice(dot).toLowerCase();
    const voiceExt = ['.mp3', '.ogg', '.m4a', '.wav', '.webm'];
    if (!voiceExt.includes(ext)) {
      return [this.getAttachmentUrl(normalized)];
    }

    const stem = normalized.slice(0, dot);
    const ordered = [ext, ...voiceExt.filter((x) => x !== ext)];
    const out: string[] = [];
    for (const e of ordered) {
      out.push(this.getAttachmentUrl(`${stem}${e}`));
    }
    return out;
  }

  /** Загрузить вложение к карточке опоры. Возвращает url для сохранения в card_comment_attachment. */
  uploadPoleAttachment(
    poleId: number,
    attachmentType: 'photo' | 'voice' | 'schema' | 'video' | 'file',
    file: File
  ): Observable<{
    url: string;
    type: string;
    filename: string;
    original_filename?: string | null;
    thumbnail_url?: string;
  }> {
    const formData = new FormData();
    formData.append('attachment_type', attachmentType);
    formData.append('file', file);
    return this.http.post<{
      url: string;
      type: string;
      filename: string;
      original_filename?: string | null;
      thumbnail_url?: string;
    }>(`${this.apiUrl}/attachments/poles/${poleId}/attachments`, formData);
  }

  uploadEquipmentAttachment(
    equipmentId: number,
    attachmentType: 'photo' | 'voice' | 'schema' | 'video' | 'file',
    file: File
  ): Observable<{
    url: string;
    type: string;
    filename: string;
    original_filename?: string | null;
    thumbnail_url?: string;
  }> {
    const formData = new FormData();
    formData.append('attachment_type', attachmentType);
    formData.append('file', file);
    return this.http.post<{
      url: string;
      type: string;
      filename: string;
      original_filename?: string | null;
      thumbnail_url?: string;
    }>(`${this.apiUrl}/attachments/equipment/${equipmentId}/attachments`, formData);
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

  // ========== Equipment Catalog ==========
  getEquipmentCatalog(params?: {
    type_code?: string;
    q?: string;
    is_active?: boolean;
    skip?: number;
    limit?: number;
  }): Observable<EquipmentCatalogItem[]> {
    let httpParams = new HttpParams();
    if (params?.type_code) httpParams = httpParams.set('type_code', params.type_code);
    if (params?.q) httpParams = httpParams.set('q', params.q);
    if (params?.is_active != null) httpParams = httpParams.set('is_active', String(params.is_active));
    if (params?.skip != null) httpParams = httpParams.set('skip', String(params.skip));
    if (params?.limit != null) httpParams = httpParams.set('limit', String(params.limit));
    return this.http.get<EquipmentCatalogItem[]>(`${this.apiUrl}/equipment-catalog`, { params: httpParams });
  }

  createEquipmentCatalogItem(payload: EquipmentCatalogCreate): Observable<EquipmentCatalogItem> {
    return this.http.post<EquipmentCatalogItem>(`${this.apiUrl}/equipment-catalog`, payload);
  }

  updateEquipmentCatalogItem(id: number, payload: Partial<EquipmentCatalogCreate>): Observable<EquipmentCatalogItem> {
    return this.http.put<EquipmentCatalogItem>(`${this.apiUrl}/equipment-catalog/${id}`, payload);
  }

  withdrawEquipmentCatalogItem(id: number): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.apiUrl}/equipment-catalog/${id}/withdraw`, {});
  }

  deleteEquipmentCatalogItem(id: number): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/equipment-catalog/${id}`);
  }

  importEquipmentCatalog(file: File, mode: 'upsert' | 'insert_only' = 'upsert'): Observable<{ inserted: number; updated: number; skipped: number; total: number }> {
    const formData = new FormData();
    formData.append('file', file);
    const params = new HttpParams().set('mode', mode);
    return this.http.post<{ inserted: number; updated: number; skipped: number; total: number }>(
      `${this.apiUrl}/equipment-catalog/import`,
      formData,
      { params }
    );
  }

  downloadEquipmentCatalogTemplate(): Observable<Blob> {
    return this.http.get(`${this.apiUrl}/equipment-catalog/template`, { responseType: 'blob' });
  }

  exportEquipmentCatalog(format: 'xlsx' | 'csv' = 'xlsx'): Observable<Blob> {
    const params = new HttpParams().set('fmt', format);
    return this.http.get(`${this.apiUrl}/equipment-catalog/export`, { params, responseType: 'blob' });
  }

  // ========== Line conductor marks (ЛЭП) ==========
  getLineConductorCatalog(params?: {
    q?: string;
    voltage_kv?: number;
    is_active?: boolean;
    skip?: number;
    limit?: number;
  }): Observable<LineConductorCatalogItem[]> {
    let httpParams = new HttpParams();
    if (params?.q) httpParams = httpParams.set('q', params.q);
    if (params?.voltage_kv != null) httpParams = httpParams.set('voltage_kv', String(params.voltage_kv));
    if (params?.is_active != null) httpParams = httpParams.set('is_active', String(params.is_active));
    if (params?.skip != null) httpParams = httpParams.set('skip', String(params.skip));
    if (params?.limit != null) httpParams = httpParams.set('limit', String(params.limit));
    return this.http.get<LineConductorCatalogItem[]>(`${this.apiUrl}/line-conductor-catalog`, { params: httpParams });
  }

  createLineConductorCatalogItem(payload: LineConductorCatalogCreate): Observable<LineConductorCatalogItem> {
    return this.http.post<LineConductorCatalogItem>(`${this.apiUrl}/line-conductor-catalog`, payload);
  }

  // ========== Wire catalog (WireInfo) ==========
  getWireInfoCatalog(params?: {
    q?: string;
    in_service?: boolean;
    skip?: number;
    limit?: number;
  }): Observable<WireInfoItem[]> {
    let httpParams = new HttpParams();
    if (params?.q) httpParams = httpParams.set('q', params.q);
    if (params?.in_service != null) httpParams = httpParams.set('in_service', String(params.in_service));
    if (params?.skip != null) httpParams = httpParams.set('skip', String(params.skip));
    if (params?.limit != null) httpParams = httpParams.set('limit', String(params.limit));
    return this.http.get<WireInfoItem[]>(`${this.apiUrl}/cim/wire-info`, { params: httpParams });
  }

  createWireInfo(payload: WireInfoCreate): Observable<WireInfoItem> {
    return this.http.post<WireInfoItem>(`${this.apiUrl}/cim/wire-info`, payload);
  }

  withdrawWireInfo(id: number): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.apiUrl}/cim/wire-info/${id}/withdraw`, {});
  }

  deleteWireInfo(id: number): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/cim/wire-info/${id}`);
  }

  downloadWireInfoTemplate(): Observable<Blob> {
    return this.http.get(`${this.apiUrl}/cim/wire-info/template`, { responseType: 'blob' });
  }

  exportWireInfoCatalog(format: 'xlsx' | 'csv' = 'xlsx'): Observable<Blob> {
    const params = new HttpParams().set('fmt', format);
    return this.http.get(`${this.apiUrl}/cim/wire-info/export`, { params, responseType: 'blob' });
  }

  importWireInfoCatalog(file: File, mode: 'upsert' | 'insert_only' = 'upsert'): Observable<{
    inserted: number;
    updated: number;
    skipped: number;
    total: number;
  }> {
    const formData = new FormData();
    formData.append('file', file);
    const params = new HttpParams().set('mode', mode);
    return this.http.post<{ inserted: number; updated: number; skipped: number; total: number }>(
      `${this.apiUrl}/cim/wire-info/import`,
      formData,
      { params },
    );
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

  /** Поиск на карте по mRID/UID (журнал изменений, CIM-узлы). */
  findMapUid(q: string): Observable<MapUidSearchHit | null> {
    const trimmed = (q || '').trim();
    return this.http
      .get<MapUidSearchHit>(`${this.apiUrl}/map/find-uid`, {
        params: new HttpParams().set('q', trimmed),
      })
      .pipe(
        catchError((err: HttpErrorResponse) => {
          if (err.status === 404) {
            return from([null]);
          }
          return throwError(() => err);
        }),
      );
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

  /** Экспорт CIM XML с метаданными ответа (например, деградация без оборудования). */
  exportCIMXmlResponse(
    includeSubstations: boolean = true,
    includePowerLines: boolean = true,
    useCimpy: boolean = true,
    includeGps: boolean = true,
    lineId: number | null = null,
    includeEquipment: boolean = true,
    includeElectricalModel: boolean = true,
    includeDefects: boolean = true,
    includeSubstationVoltageLevels: boolean = true
  ): Observable<{ body: Blob; degradedEquipmentOmitted: boolean }> {
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
    return this.http
      .get(`${this.apiUrl}/cim/export/xml`, {
        params,
        responseType: 'blob',
        observe: 'response',
      })
      .pipe(
        map((res) => ({
          body: res.body as Blob,
          degradedEquipmentOmitted:
            (res.headers.get('X-CIM-Export-Degraded') || '').includes('equipment'),
        }))
      );
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
    return this.exportCIM552DiffResponse(
      includeSubstations,
      includePowerLines,
      includeGps,
      lineId,
      includeEquipment,
      includeElectricalModel,
      includeDefects,
      includeSubstationVoltageLevels
    ).pipe(map((r) => r.body));
  }

  /**
   * Тот же запрос, что /cim/export/552-diff → внутри вызывает export_cim_xml.
   * Заголовок X-CIM-Export-Degraded: сервер мог выгрузить без оборудования (ретрай).
   */
  exportCIM552DiffResponse(
    includeSubstations: boolean = true,
    includePowerLines: boolean = true,
    includeGps: boolean = true,
    lineId: number | null = null,
    includeEquipment: boolean = true,
    includeElectricalModel: boolean = true,
    includeDefects: boolean = true,
    includeSubstationVoltageLevels: boolean = true
  ): Observable<{ body: Blob; degradedEquipmentOmitted: boolean }> {
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

    return this.http
      .get(`${this.apiUrl}/cim/export/552-diff`, {
        params,
        responseType: 'blob',
        observe: 'response',
      })
      .pipe(
        map((res) => ({
          body: res.body as Blob,
          degradedEquipmentOmitted:
            (res.headers.get('X-CIM-Export-Degraded') || '').includes('equipment'),
        }))
      );
  }

  importCIM552Diff(file: File): Observable<{ summary?: Record<string, number>; count?: number; objects?: any[] }> {
    const formData = new FormData();
    formData.append('file', file, file.name);
    return this.http.post<{ summary?: Record<string, number>; count?: number; objects?: any[] }>(
      `${this.apiUrl}/cim/import/552-diff`,
      formData
    );
  }

  applyCIM552Diff(file: File): Observable<CimApply552DiffResponse> {
    const formData = new FormData();
    formData.append('file', file, file.name);
    return this.http.post<CimApply552DiffResponse>(
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

  // ========== Tech passports ==========
  listTechPassports(skip = 0, limit = 50): Observable<TechPassportListResponse> {
    const params = new HttpParams().set('skip', String(skip)).set('limit', String(limit));
    return this.http.get<TechPassportListResponse>(`${this.apiUrl}/tech-passports`, { params });
  }

  createTechPassport(body: {
    object_type: string;
    object_id?: number | null;
    object_mrid?: string | null;
    title?: string | null;
    stp_reference?: string | null;
    manual_sections?: Record<string, unknown> | null;
  }): Observable<TechPassportDetail> {
    return this.http.post<TechPassportDetail>(`${this.apiUrl}/tech-passports`, body);
  }

  getTechPassport(id: number): Observable<TechPassportDetail> {
    return this.http.get<TechPassportDetail>(`${this.apiUrl}/tech-passports/${id}`);
  }

  deleteTechPassport(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/tech-passports/${id}`);
  }

  downloadTechPassportExport(
    id: number,
    format: 'pdf' | 'docx' | 'xlsx',
  ): Observable<{ blob: Blob; filename: string }> {
    const params = new HttpParams().set('format', format);
    return this.http
      .get(`${this.apiUrl}/tech-passports/${id}/export`, {
        params,
        observe: 'response',
        responseType: 'blob',
      })
      .pipe(
        switchMap((resp: HttpResponse<Blob>) => {
          if (!resp.body) {
            return throwError(() => new Error('Пустой ответ сервера'));
          }
          const ct = (resp.headers.get('Content-Type') || '').toLowerCase();
          if (ct.includes('json') || ct.includes('text/plain') || ct.includes('text/html')) {
            return from(resp.body.text()).pipe(
              switchMap((t) => throwError(() => new Error(this.parseExportErrorText(t, resp.status)))),
            );
          }
          if (resp.body.size < 48) {
            return from(resp.body.text()).pipe(
              switchMap((t) => {
                const trimmed = (t || '').trim();
                if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                  return throwError(() => new Error(this.parseExportErrorText(trimmed, resp.status)));
                }
                if (!resp.body || resp.body.size === 0) {
                  return throwError(() => new Error('Пустой файл от сервера'));
                }
                const filename =
                  filenameFromContentDisposition(resp.headers.get('Content-Disposition')) ||
                  `passport_${id}.${format === 'docx' ? 'docx' : format}`;
                return from(Promise.resolve({ blob: resp.body!, filename }));
              }),
            );
          }
          const filename =
            filenameFromContentDisposition(resp.headers.get('Content-Disposition')) ||
            `passport_${id}.${format === 'docx' ? 'docx' : format}`;
          return from(Promise.resolve({ blob: resp.body, filename }));
        }),
        catchError((err: HttpErrorResponse) => {
          const blob = err.error;
          if (blob instanceof Blob) {
            return from(blob.text()).pipe(
              switchMap((t) => {
                let msg = `Ошибка ${err.status}`;
                try {
                  const j = JSON.parse(t) as { detail?: unknown };
                  if (typeof j.detail === 'string') {
                    msg = j.detail;
                  }
                } catch {
                  if (t?.trim()) {
                    msg = t.trim();
                  }
                }
                return throwError(() => new Error(msg));
              }),
            );
          }
          const d = (err.error as { detail?: unknown } | null)?.detail;
          if (typeof d === 'string') {
            return throwError(() => new Error(d));
          }
          return throwError(() => new Error(err.message || `Ошибка ${err.status}`));
        }),
      );
  }

  private parseExportErrorText(text: string, status: number): string {
    const trimmed = (text || '').trim();
    if (!trimmed) {
      return `Ошибка ${status}`;
    }
    try {
      const j = JSON.parse(trimmed) as { detail?: unknown };
      if (typeof j.detail === 'string') {
        return j.detail;
      }
    } catch {
      // not JSON
    }
    return trimmed;
  }
}

