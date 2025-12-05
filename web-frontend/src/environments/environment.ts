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
    const protocol = this.useHttps ? 'https' : 'http';
    return `${protocol}://localhost/api/${this.apiVersion}`;
  },
  
  // Настройки карты
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

