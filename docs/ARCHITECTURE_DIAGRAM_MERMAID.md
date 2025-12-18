# Диаграмма архитектуры системы (Mermaid)

## Общая архитектура системы

```mermaid
graph TB
    subgraph "Клиентские приложения"
        WEB[Web Frontend<br/>Angular 17<br/>Leaflet Maps]
        MOBILE[Mobile Frontend<br/>Flutter<br/>Drift SQLite]
    end
    
    subgraph "Инфраструктура"
        NGINX[Nginx<br/>Reverse Proxy<br/>SSL/TLS]
    end
    
    subgraph "Backend сервер"
        API[FastAPI Backend<br/>Python 3.11+<br/>REST API]
        AUTH[Auth Module<br/>JWT Tokens]
        MAP[Map Module<br/>GeoJSON]
        SYNC[Sync Module<br/>Data Sync]
    end
    
    subgraph "База данных"
        PG[(PostgreSQL 15<br/>PostGIS<br/>Spatial Data)]
        REDIS[(Redis<br/>Cache<br/>Optional)]
    end
    
    WEB -->|HTTPS| NGINX
    MOBILE -->|HTTPS| NGINX
    NGINX -->|Proxy| API
    API --> AUTH
    API --> MAP
    API --> SYNC
    API -->|SQLAlchemy| PG
    API -.->|Optional| REDIS
    
    style WEB fill:#42b883
    style MOBILE fill:#42b883
    style NGINX fill:#009639
    style API fill:#009688
    style PG fill:#336791
    style REDIS fill:#dc382d
```

## Детальная архитектура Backend

```mermaid
graph LR
    subgraph "API Layer"
        ROUTES[API Routes<br/>/api/v1/*]
    end
    
    subgraph "Business Logic"
        VALID[Validation<br/>Pydantic Schemas]
        PROCESS[Processing<br/>Business Rules]
    end
    
    subgraph "Data Access"
        ORM[SQLAlchemy ORM<br/>Models]
        QUERY[Database Queries<br/>Async]
    end
    
    subgraph "Database"
        DB[(PostgreSQL<br/>Tables & Indexes)]
    end
    
    ROUTES --> VALID
    VALID --> PROCESS
    PROCESS --> ORM
    ORM --> QUERY
    QUERY --> DB
    
    style ROUTES fill:#009688
    style VALID fill:#ff9800
    style PROCESS fill:#ff9800
    style ORM fill:#795548
    style DB fill:#336791
```

## Поток аутентификации

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant N as Nginx
    participant B as Backend
    participant DB as PostgreSQL
    
    U->>F: Login (username, password)
    F->>N: POST /api/v1/auth/login
    N->>B: Forward request
    B->>DB: Verify credentials
    DB-->>B: User data
    B->>B: Generate JWT token
    B-->>N: JWT token
    N-->>F: JWT token
    F->>F: Store token
    F-->>U: Authenticated
```

## Поток синхронизации данных (Mobile)

```mermaid
sequenceDiagram
    participant M as Mobile App
    participant L as Local DB<br/>SQLite
    participant S as Backend Server
    participant P as PostgreSQL
    
    Note over M,L: Offline Mode
    M->>L: Save data locally
    L-->>M: Data saved
    
    Note over M,S: Online Mode
    M->>S: POST /api/v1/sync
    S->>P: Save data
    P-->>S: Confirmation
    S->>P: Get updates
    P-->>S: Updated data
    S-->>M: Sync response
    M->>L: Update local DB
```

## Архитектура компонентов Frontend (Angular)

```mermaid
graph TB
    subgraph "Angular Application"
        COMP[Components<br/>Map, Sidebar, etc.]
        SERV[Services<br/>MapService, ApiService]
        HTTP[HTTP Client<br/>Interceptors]
    end
    
    subgraph "External"
        API[Backend API<br/>HTTPS]
    end
    
    COMP --> SERV
    SERV --> HTTP
    HTTP --> API
    
    style COMP fill:#dd0031
    style SERV fill:#c3002f
    style HTTP fill:#b52e31
    style API fill:#009688
```

## Docker Compose архитектура

```mermaid
graph TB
    subgraph "Docker Network: lepm_network"
        subgraph "Services"
            NGINX_C[Nginx Container<br/>Ports: 80, 443]
            BACKEND_C[Backend Container<br/>Port: 8000]
            PG_C[PostgreSQL Container<br/>Port: 5432]
            REDIS_C[Redis Container<br/>Port: 6379]
        end
    end
    
    CLIENT[Client Browser/App] -->|HTTPS:443| NGINX_C
    CLIENT -->|HTTP:80| NGINX_C
    NGINX_C -->|Proxy| BACKEND_C
    BACKEND_C -->|SQL| PG_C
    BACKEND_C -.->|Cache| REDIS_C
    
    style NGINX_C fill:#009639
    style BACKEND_C fill:#009688
    style PG_C fill:#336791
    style REDIS_C fill:#dc382d
```

## Модель данных (ER диаграмма)

```mermaid
erDiagram
    USER ||--o{ POWER_LINE : creates
    POWER_LINE ||--o{ POLE : contains
    POWER_LINE ||--o{ ACLINE_SEGMENT : has
    ACLINE_SEGMENT ||--o{ POLE : includes
    POLE ||--o{ EQUIPMENT : has
    POWER_LINE ||--o{ TAP : has
    SUBSTATION ||--o{ POWER_LINE : connects
    BRANCH ||--o{ POWER_LINE : manages
    GEOGRAPHIC_REGION ||--o{ POWER_LINE : contains
    
    USER {
        int id PK
        string username
        string email
        string password_hash
        string role
    }
    
    POWER_LINE {
        int id PK
        string name
        geometry line_geometry
        int branch_id FK
    }
    
    POLE {
        int id PK
        string pole_number
        geometry location
        int power_line_id FK
    }
    
    EQUIPMENT {
        int id PK
        string type
        int pole_id FK
    }
```

## Поток создания объекта на карте

```mermaid
flowchart TD
    START[User clicks on map] --> CHECK{Object type?}
    CHECK -->|Pole| POLE[Create Pole Dialog]
    CHECK -->|Line| LINE[Create Line Dialog]
    CHECK -->|Substation| SUB[Create Substation Dialog]
    
    POLE --> VALID[Validate Input]
    LINE --> VALID
    SUB --> VALID
    
    VALID --> SEND[POST to Backend API]
    SEND --> SAVE[Save to PostgreSQL]
    SAVE --> RESPONSE[Return Created Object]
    RESPONSE --> UPDATE[Update Map Display]
    UPDATE --> END[Object visible on map]
    
    style START fill:#4caf50
    style END fill:#4caf50
    style VALID fill:#ff9800
    style SAVE fill:#2196f3
```
