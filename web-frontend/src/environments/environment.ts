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
    // Определяем IP адрес сервера динамически
    // Если запущено на localhost (компьютер), используем localhost
    // Если доступно с других устройств, используем IP адрес компьютера
    const hostname = window.location.hostname;
    let backendHost: string;
    
    if (hostname === 'localhost' || hostname === '127.0.0.1') {
      // Запущено локально на компьютере
      backendHost = 'localhost:8000';
    } else {
      // Доступно с других устройств - используем тот же хост, но порт 8000
      backendHost = `${hostname}:8000`;
    }
    
    return `${protocol}://${backendHost}/api/${this.apiVersion}`;
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

