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
    // Если используется Docker с nginx, используем порт 80 (без указания порта)
    // Если бэкенд запущен локально, используем порт 8000
    // Для Docker: http://localhost/api/v1 (nginx проксирует на порт 80)
    // Для локального запуска: http://localhost:8000/api/v1
    // По умолчанию используем порт 8000 для локального запуска
    // Если используете Docker, измените на: return `${protocol}://localhost/api/${this.apiVersion}`;
    return `${protocol}://localhost:8000/api/${this.apiVersion}`;
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

