// Конфигурация для продакшена
export const environment = {
  production: true,
  useHttps: true, // В продакшене используем HTTPS
  apiVersion: 'v1',
  
  get apiUrl(): string {
    const protocol = this.useHttps ? 'https' : 'http';
    // В продакшене через nginx (порт 80/443), в разработке напрямую к бэкенду (порт 8000)
    return `${protocol}://localhost/api/${this.apiVersion}`;
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

