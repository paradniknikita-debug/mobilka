// Конфигурация для продакшена
export const environment = {
  production: true,
  useHttps: true, // В продакшене используем HTTPS
  apiVersion: 'v1',
  
  get apiUrl(): string {
    const protocol = this.useHttps ? 'https' : 'http';
    // В продакшене через nginx (порт 80/443), используем текущий хост
    const hostname = window.location.hostname;
    const port = window.location.port ? `:${window.location.port}` : '';
    return `${protocol}://${hostname}${port}/api/${this.apiVersion}`;
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

