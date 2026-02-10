import { Component, Inject } from '@angular/core';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MapService } from '../../../core/services/map.service';
import { MatSnackBar } from '@angular/material/snack-bar';

export interface DeleteObjectData {
  objectType: 'pole' | 'powerLine' | 'substation' | 'tap' | 'span';
  objectId: number;
  objectName: string;
  powerLineId?: number; // Для пролётов нужен powerLineId
}

@Component({
  selector: 'app-delete-object-dialog',
  templateUrl: './delete-object-dialog.component.html',
  styleUrls: ['./delete-object-dialog.component.scss']
})
export class DeleteObjectDialogComponent {
  isDeleting = false;

  constructor(
    public dialogRef: MatDialogRef<DeleteObjectDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: DeleteObjectData,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {}

  getObjectTypeLabel(): string {
    switch (this.data.objectType) {
      case 'pole':
        return 'опору';
      case 'powerLine':
        return 'ЛЭП';
      case 'substation':
        return 'подстанцию';
      case 'tap':
        return 'отпайку';
      case 'span':
        return 'пролёт';
      default:
        return 'объект';
    }
  }

  getObjectTypeLabelNominative(): string {
    switch (this.data.objectType) {
      case 'pole':
        return 'опора';
      case 'powerLine':
        return 'ЛЭП';
      case 'substation':
        return 'подстанция';
      case 'tap':
        return 'отпайка';
      case 'span':
        return 'пролёт';
      default:
        return 'объект';
    }
  }

  onConfirm(): void {
    this.isDeleting = true;

    // В зависимости от типа объекта вызываем соответствующий метод API
    let deleteObservable: any;
    
    switch (this.data.objectType) {
      case 'powerLine':
        deleteObservable = this.apiService.deletePowerLine(this.data.objectId);
        break;
      case 'pole':
        deleteObservable = this.apiService.deletePole(this.data.objectId);
        break;
      case 'span':
        if (this.data.powerLineId) {
          deleteObservable = this.apiService.deleteSpan(this.data.powerLineId, this.data.objectId);
        } else {
          this.snackBar.open('Ошибка: не указана ЛЭП для удаления пролёта', 'Закрыть', {
            duration: 3000
          });
          this.isDeleting = false;
          return;
        }
        break;
      case 'substation':
        deleteObservable = this.apiService.deleteSubstation(this.data.objectId);
        break;
      case 'tap':
        // TODO: Добавить методы удаления для отпаек
        this.snackBar.open('Удаление этого типа объектов пока не реализовано', 'Закрыть', {
          duration: 3000
        });
        this.isDeleting = false;
        this.dialogRef.close(false);
        return;
      default:
        this.isDeleting = false;
        return;
    }

    if (deleteObservable) {
      deleteObservable.subscribe({
        next: (response?: {message?: string, details?: string}) => {
          const label = this.getObjectTypeLabelNominative();
          const capitalizedLabel = label.charAt(0).toUpperCase() + label.slice(1);
          let message: string;
          
          if (this.data.objectType === 'substation') {
            message = `${capitalizedLabel} успешно удалена.`;
          } else if (this.data.objectType === 'pole') {
            message = response?.details 
              ? `${capitalizedLabel} успешно удалена. ${response.details}`
              : `${capitalizedLabel} успешно удалена. Пролёты, напрямую связанные с этой опорой, также удалены. Остальная структура линии сохранена.`;
          } else {
            message = response?.details 
              ? `${capitalizedLabel} успешно удалена. ${response.details}`
              : `${capitalizedLabel} успешно удалена.`;
          }
          
          this.snackBar.open(message, 'Закрыть', {
            duration: 4000
          });
          // Уведомляем сервис карты об обновлении данных
          this.mapService.refreshData();
          this.dialogRef.close(true);
        },
        error: (error: any) => {
          console.error('Ошибка удаления объекта:', error);
          console.error('Полная информация об ошибке:', {
            status: error.status,
            statusText: error.statusText,
            message: error.message,
            error: error.error,
            url: error.url,
            name: error.name
          });
          
          let errorMessage = 'Ошибка удаления объекта';
          
          // Обработка различных типов ошибок
          if (error.status === 0) {
            // Ошибка сети или CORS
            errorMessage = 'Ошибка соединения с сервером. Проверьте подключение к интернету и настройки CORS.';
            console.error('Ошибка сети (status 0). Возможные причины:');
            console.error('  - Сервер недоступен');
            console.error('  - Проблема с CORS');
            console.error('  - Блокировка запроса браузером');
          } else if (error.status === 404) {
            errorMessage = 'Объект не найден';
          } else if (error.status === 403) {
            errorMessage = 'Доступ запрещен. Проверьте права доступа.';
          } else if (error.status === 401) {
            errorMessage = 'Требуется авторизация. Войдите в систему заново.';
          } else if (error.status === 409) {
            // 409 больше не должно возникать, так как связанные объекты удаляются автоматически
            errorMessage = error.error?.detail || 'Не удалось удалить объект: существуют связанные данные';
          } else if (error.error?.detail) {
            if (typeof error.error.detail === 'string') {
              errorMessage = error.error.detail;
            } else {
              errorMessage = JSON.stringify(error.error.detail);
            }
          } else if (error.error?.message) {
            errorMessage = error.error.message;
          } else if (error.message) {
            errorMessage = error.message;
          }
          
          this.snackBar.open(errorMessage, 'Закрыть', {
            duration: 5000,
            panelClass: ['error-snackbar']
          });
          this.isDeleting = false;
        }
      });
    }
  }

  onCancel(): void {
    this.dialogRef.close(false);
  }
}
