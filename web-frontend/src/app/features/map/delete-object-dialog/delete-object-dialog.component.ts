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
    let deleteObservable;
    
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
      case 'tap':
        // TODO: Добавить методы удаления для этих типов
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
        next: () => {
          const label = this.getObjectTypeLabelNominative();
          const capitalizedLabel = label.charAt(0).toUpperCase() + label.slice(1);
          this.snackBar.open(`${capitalizedLabel} успешно удалена`, 'Закрыть', {
            duration: 3000
          });
          // Уведомляем сервис карты об обновлении данных
          this.mapService.refreshData();
          this.dialogRef.close(true);
        },
        error: (error) => {
          console.error('Ошибка удаления объекта:', error);
          let errorMessage = 'Ошибка удаления объекта';
          
          if (error.error?.detail) {
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
