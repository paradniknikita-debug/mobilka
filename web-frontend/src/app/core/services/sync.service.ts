import { Injectable } from '@angular/core';
import { Observable, interval, Subject, BehaviorSubject, from, of } from 'rxjs';
import { switchMap, catchError, tap, map } from 'rxjs/operators';
import { ApiService } from './api.service';
import { MapService } from './map.service';
import { HttpClient } from '@angular/common/http';

export interface SyncRecord {
  id: string;
  entity_type: string;
  action: 'create' | 'update' | 'delete';
  data: any;
  timestamp: string;
  status?: 'pending' | 'synced' | 'failed';
  error_message?: string;
}

export interface SyncBatch {
  batch_id: string;
  timestamp: string;
  records: SyncRecord[];
}

export interface SyncState {
  isSyncing: boolean;
  lastSyncTime: Date | null;
  pendingRecords: number;
  error: string | null;
}

@Injectable({
  providedIn: 'root'
})
export class SyncService {
  private syncState$ = new BehaviorSubject<SyncState>({
    isSyncing: false,
    lastSyncTime: null,
    pendingRecords: 0,
    error: null
  });

  private pendingChanges: SyncRecord[] = [];
  private syncInterval$: Observable<number> | null = null;
  private autoSyncEnabled = false;
  private syncIntervalMs = 30000; // 30 секунд по умолчанию

  constructor(
    private apiService: ApiService,
    private mapService: MapService,
    private http: HttpClient
  ) {
    this.loadPendingChanges();
    // Загружаем время последней синхронизации
    const lastSync = this.getLastSyncTime();
    if (lastSync) {
      this.updateSyncState({ lastSyncTime: lastSync });
    }
  }

  /**
   * Получить текущее состояние синхронизации
   */
  getSyncState(): Observable<SyncState> {
    return this.syncState$.asObservable();
  }

  /**
   * Включить автоматическую синхронизацию
   */
  enableAutoSync(intervalMs: number = 30000): void {
    this.autoSyncEnabled = true;
    this.syncIntervalMs = intervalMs;
    
    // Останавливаем предыдущий интервал если был
    if (this.syncInterval$) {
      // В RxJS interval автоматически останавливается при unsubscribe
    }

    // Запускаем периодическую синхронизацию
    this.syncInterval$ = interval(this.syncIntervalMs);
    this.syncInterval$.pipe(
      switchMap(() => this.sync())
    ).subscribe({
      next: () => {
        console.log('Автоматическая синхронизация выполнена');
      },
      error: (error) => {
        console.error('Ошибка автоматической синхронизации:', error);
      }
    });
  }

  /**
   * Выключить автоматическую синхронизацию
   */
  disableAutoSync(): void {
    this.autoSyncEnabled = false;
    this.syncInterval$ = null;
  }

  /**
   * Добавить изменение в очередь синхронизации
   */
  addChange(entityType: string, action: 'create' | 'update' | 'delete', data: any): void {
    const record: SyncRecord = {
      id: this.generateId(),
      entity_type: entityType,
      action: action,
      data: data,
      timestamp: new Date().toISOString(),
      status: 'pending'
    };

    this.pendingChanges.push(record);
    this.savePendingChanges();
    this.updateSyncState();
  }

  /**
   * Выполнить синхронизацию
   */
  sync(): Observable<any> {
    const state = this.syncState$.value;
    if (state.isSyncing) {
      return of(null); // Уже синхронизируется
    }

    this.updateSyncState({ isSyncing: true, error: null });

    // Сначала отправляем локальные изменения
    return this.uploadChanges().pipe(
      switchMap(() => {
        // Затем загружаем изменения с сервера
        return this.downloadChanges();
      }),
      tap(() => {
        // Обновляем состояние после успешной синхронизации
        const syncTime = new Date();
        this.updateSyncState({
          isSyncing: false,
          lastSyncTime: syncTime,
          error: null
        });
        this.setLastSyncTime(syncTime);
        // Обновляем данные на карте
        this.mapService.refreshData();
      }),
      catchError((error) => {
        this.updateSyncState({
          isSyncing: false,
          error: error.message || 'Ошибка синхронизации'
        });
        return of(null);
      })
    );
  }

  /**
   * Отправить локальные изменения на сервер
   */
  private uploadChanges(): Observable<any> {
    if (this.pendingChanges.length === 0) {
      return of(null);
    }

    const batch: SyncBatch = {
      batch_id: this.generateId(),
      timestamp: new Date().toISOString(),
      records: this.pendingChanges
    };

    return this.apiService.uploadSyncBatch(batch).pipe(
      tap((response: any) => {
        if (response.success) {
          // Удаляем успешно синхронизированные записи
          this.pendingChanges = this.pendingChanges.filter(
            record => !batch.records.some(r => r.id === record.id)
          );
          this.savePendingChanges();
          this.updateSyncState();
        } else {
          // Помечаем неудачные записи
          if (response.errors) {
            response.errors.forEach((error: any) => {
              const record = this.pendingChanges.find(r => r.id === error.record_id);
              if (record) {
                record.status = 'failed';
                record.error_message = error.error;
              }
            });
            this.savePendingChanges();
          }
        }
      })
    );
  }

  /**
   * Загрузить изменения с сервера
   */
  private downloadChanges(): Observable<any> {
    const lastSync = this.syncState$.value.lastSyncTime;
    const lastSyncParam = lastSync 
      ? lastSync.toISOString() 
      : new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(); // 24 часа назад

    return from(
      fetch(`${this.apiService['apiUrl']}/sync/download?last_sync=${encodeURIComponent(lastSyncParam)}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
        }
      }).then(response => response.json())
    ).pipe(
      tap((response: any) => {
        if (response.records && response.records.length > 0) {
          // Обрабатываем полученные записи
          this.processServerRecords(response.records);
        }
      })
    );
  }

  /**
   * Обработать записи, полученные с сервера
   */
  private processServerRecords(records: any[]): void {
    // Здесь должна быть логика обработки записей с сервера
    // Например, обновление локальных данных, если они есть
    // Пока просто обновляем данные на карте
    console.log(`Получено ${records.length} записей с сервера`);
  }

  /**
   * Обновить состояние синхронизации
   */
  private updateSyncState(partial?: Partial<SyncState>): void {
    const current = this.syncState$.value;
    const updated: SyncState = {
      ...current,
      ...partial,
      pendingRecords: this.pendingChanges.filter(r => r.status === 'pending').length
    };
    this.syncState$.next(updated);
  }

  /**
   * Сохранить ожидающие изменения в localStorage
   */
  private savePendingChanges(): void {
    try {
      localStorage.setItem('sync_pending_changes', JSON.stringify(this.pendingChanges));
    } catch (error) {
      console.error('Ошибка сохранения ожидающих изменений:', error);
    }
  }

  /**
   * Загрузить ожидающие изменения из localStorage
   */
  private loadPendingChanges(): void {
    try {
      const stored = localStorage.getItem('sync_pending_changes');
      if (stored) {
        this.pendingChanges = JSON.parse(stored);
        this.updateSyncState();
      }
    } catch (error) {
      console.error('Ошибка загрузки ожидающих изменений:', error);
    }
  }

  /**
   * Получить время последней синхронизации
   */
  getLastSyncTime(): Date | null {
    try {
      const stored = localStorage.getItem('sync_last_sync_time');
      return stored ? new Date(stored) : null;
    } catch {
      return null;
    }
  }

  /**
   * Сохранить время последней синхронизации
   */
  private setLastSyncTime(time: Date): void {
    try {
      localStorage.setItem('sync_last_sync_time', time.toISOString());
    } catch (error) {
      console.error('Ошибка сохранения времени синхронизации:', error);
    }
  }

  /**
   * Генерация уникального ID
   */
  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Очистить все ожидающие изменения
   */
  clearPendingChanges(): void {
    this.pendingChanges = [];
    this.savePendingChanges();
    this.updateSyncState();
  }
}
