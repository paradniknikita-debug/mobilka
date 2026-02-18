// Конфигурация для продакшена
export const environment = {
  production: true,
  useHttps: true, // В продакшене используем HTTPS
  apiVersion: 'v1',
  
  get apiUrl(): string {
    // В продакшене используем относительный путь через nginx (без порта 8000)
    // Это избегает проблем с Mixed Content и работает с HTTPS
    return `/api/${this.apiVersion}`;
  },
  
  map: {
    defaultZoom: 10,
    minZoom: 1,
    maxZoom: 18,
    defaultCenter: {
      lat: 53.9045,
      lng: 27.5615
    }
  }
};

