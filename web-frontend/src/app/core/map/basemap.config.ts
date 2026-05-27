import { environment } from '../../../environments/environment';

export interface BasemapDefinition {
  id: string;
  label: string;
  /** Шаблон Leaflet: {z}/{x}/{y} и опционально {s} для subdomains */
  urlTemplate: string;
  subdomains?: string;
}

export const DEFAULT_BASEMAP_ID = 'osm';

/**
 * Порядок = цепочка автопереключения при ошибках загрузки тайлов.
 * По умолчанию OpenStreetMap; при недоступности — зеркала и прокси сервера.
 */
export const BASEMAP_CHAIN: BasemapDefinition[] = [
  {
    id: 'osm',
    label: 'OpenStreetMap',
    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: 'abc',
  },
  {
    id: 'proxy',
    label: 'Кэш сервера',
    urlTemplate: `${environment.apiUrl}/map/tiles/{z}/{x}/{y}.png`,
  },
  {
    id: 'osm-de',
    label: 'OpenStreetMap (DE)',
    urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
  },
  {
    id: 'osm-hot',
    label: 'OSM Humanitarian',
    urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    subdomains: 'abc',
  },
  {
    id: 'arcgis',
    label: 'ArcGIS World',
    urlTemplate:
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
  },
  {
    id: 'carto',
    label: 'Carto Voyager',
    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    subdomains: 'abcd',
  },
];

export const BASEMAP_STORAGE_KEY = 'map_basemap_id';

export function normalizeBasemapId(id: string | null | undefined): string {
  if (!id) {
    return DEFAULT_BASEMAP_ID;
  }
  return basemapById(id).id;
}

export function basemapById(id: string): BasemapDefinition {
  return BASEMAP_CHAIN.find((b) => b.id === id) ?? BASEMAP_CHAIN[0];
}

export function nextBasemapInChain(currentId: string): BasemapDefinition | null {
  const idx = BASEMAP_CHAIN.findIndex((b) => b.id === currentId);
  if (idx < 0 || idx >= BASEMAP_CHAIN.length - 1) {
    return null;
  }
  return BASEMAP_CHAIN[idx + 1];
}
