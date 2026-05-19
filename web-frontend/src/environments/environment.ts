// Конфигурация для разработки
export const environment = {
  production: false,
  // ============================================
  // НАСТРОЙКА ПРОТОКОЛА ПОДКЛЮЧЕНИЯ
  // ============================================
  // Измените эту переменную для переключения между HTTP и HTTPS
  // true = HTTPS, false = HTTP
  useHttps: false, // Для разработки используем HTTP
  // ============================================
  
  apiVersion: 'v1',
  
  get apiUrl(): string {
    // На проде — только относительный HTTPS-путь через nginx (см. environment.prod.ts).
    // В dev: тот же протокол, что у страницы (https-страница → https API, без mixed content).
    const protocol =
      typeof window !== 'undefined' && window.location.protocol === 'https:'
        ? 'https'
        : this.useHttps
          ? 'https'
          : 'http';
    const hostname =
      typeof window !== 'undefined' ? window.location.hostname : 'localhost';
    let backendHost: string;

    if (hostname === 'localhost' || hostname === '127.0.0.1') {
      backendHost = 'localhost:8000';
    } else {
      backendHost = `${hostname}:8000`;
    }

    return `${protocol}://${backendHost}/api/${this.apiVersion}`;
  },
  
  // Настройки карты (minZoom 3 — не отдалять до дублирования континентов; maxZoom 20 — точность ~0.00003°)
  map: {
    defaultZoom: 10,
    minZoom: 3,
    maxZoom: 20,
    /** Порог зума для отображения оборудования на линии: при зуме >= этого значения иконки скрыты. */
    minZoomToShowEquipment: 14,
    defaultCenter: {
      lat: 53.9045,
      lng: 27.5615
    }
  }
};

