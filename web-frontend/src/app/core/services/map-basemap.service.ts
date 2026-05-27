import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';
import * as L from 'leaflet';
import {
  BASEMAP_CHAIN,
  BASEMAP_STORAGE_KEY,
  DEFAULT_BASEMAP_ID,
  BasemapDefinition,
  basemapById,
  nextBasemapInChain,
  normalizeBasemapId,
} from '../map/basemap.config';

export interface BasemapSwitchEvent {
  from: BasemapDefinition;
  to: BasemapDefinition;
  automatic: boolean;
}

const TILE_LAYER_OPTS: L.TileLayerOptions = {
  attribution: '',
  maxZoom: 19,
  tileSize: 256,
  keepBuffer: 2,
  detectRetina: false,
  errorTileUrl:
    'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==',
};

/** Сколько ошибок тайлов за окно времени — переключить на следующий источник */
const AUTO_FALLBACK_ERROR_THRESHOLD = 4;
const AUTO_FALLBACK_WINDOW_MS = 4000;

@Injectable({ providedIn: 'root' })
export class MapBasemapService {
  private map: L.Map | null = null;
  private tileLayer: L.TileLayer | null = null;
  private activeId = BASEMAP_CHAIN[0].id;
  private tileErrors: number[] = [];
  private autoFallbackEnabled = true;

  readonly switched$ = new Subject<BasemapSwitchEvent>();

  get basemaps(): BasemapDefinition[] {
    return BASEMAP_CHAIN;
  }

  get activeBasemapId(): string {
    return this.activeId;
  }

  get activeBasemap(): BasemapDefinition {
    return basemapById(this.activeId);
  }

  attach(map: L.Map, preferredId?: string): L.TileLayer {
    this.map = map;
    const saved = preferredId ?? this.readSavedId() ?? DEFAULT_BASEMAP_ID;
    this.activeId = normalizeBasemapId(saved);
    this.tileLayer = this.createLayer(this.activeBasemap);
    this.tileLayer.on('tileerror', () => this.onTileError());
    this.tileLayer.addTo(map);
    return this.tileLayer;
  }

  setBasemap(id: string, automatic = false): void {
    if (!this.map) {
      return;
    }
    const next = basemapById(id);
    if (next.id === this.activeId) {
      return;
    }
    const prev = this.activeBasemap;
    this.replaceLayer(next);
    this.persist(next.id);
    this.switched$.next({ from: prev, to: next, automatic });
  }

  setAutoFallbackEnabled(enabled: boolean): void {
    this.autoFallbackEnabled = enabled;
  }

  detach(): void {
    if (this.tileLayer && this.map) {
      this.map.removeLayer(this.tileLayer);
    }
    this.map = null;
    this.tileLayer = null;
    this.tileErrors = [];
  }

  private createLayer(def: BasemapDefinition): L.TileLayer {
    const opts: L.TileLayerOptions = { ...TILE_LAYER_OPTS };
    if (def.subdomains) {
      opts.subdomains = def.subdomains;
    }
    return L.tileLayer(def.urlTemplate, opts);
  }

  private replaceLayer(def: BasemapDefinition): void {
    if (!this.map || !this.tileLayer) {
      return;
    }
    this.map.removeLayer(this.tileLayer);
    this.activeId = def.id;
    this.tileErrors = [];
    this.tileLayer = this.createLayer(def);
    this.tileLayer.on('tileerror', () => this.onTileError());
    this.tileLayer.addTo(this.map);
  }

  private onTileError(): void {
    if (!this.autoFallbackEnabled) {
      return;
    }
    const now = Date.now();
    this.tileErrors.push(now);
    this.tileErrors = this.tileErrors.filter((t) => now - t <= AUTO_FALLBACK_WINDOW_MS);
    if (this.tileErrors.length < AUTO_FALLBACK_ERROR_THRESHOLD) {
      return;
    }
    const next = nextBasemapInChain(this.activeId);
    if (!next) {
      return;
    }
    this.tileErrors = [];
    const prev = this.activeBasemap;
    this.replaceLayer(next);
    this.persist(next.id);
    this.switched$.next({ from: prev, to: next, automatic: true });
  }

  private readSavedId(): string | null {
    try {
      return localStorage.getItem(BASEMAP_STORAGE_KEY);
    } catch {
      return null;
    }
  }

  private persist(id: string): void {
    try {
      localStorage.setItem(BASEMAP_STORAGE_KEY, id);
    } catch {
      /* ignore quota / private mode */
    }
  }
}
