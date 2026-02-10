import { Component, Inject, OnInit } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Pole } from '../../../core/models/pole.model';
import { CdkDragDrop, moveItemInArray } from '@angular/cdk/drag-drop';

@Component({
  selector: 'app-pole-sequence-dialog',
  templateUrl: './pole-sequence-dialog.component.html',
  styleUrls: ['./pole-sequence-dialog.component.scss']
})
export class PoleSequenceDialogComponent implements OnInit {
  powerLineId: number;
  poles: Pole[] = [];
  originalSequence: number[] = [];
  isLoading = false;
  isSaving = false;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { powerLineId: number },
    private dialogRef: MatDialogRef<PoleSequenceDialogComponent>,
    private apiService: ApiService,
    private snackBar: MatSnackBar
  ) {
    this.powerLineId = data.powerLineId;
  }

  ngOnInit(): void {
    this.loadPoles();
  }

  loadPoles(): void {
    this.isLoading = true;
    this.apiService.getPolesSequence(this.powerLineId).subscribe({
      next: (poles) => {
        this.poles = poles;
        this.originalSequence = poles.map(p => p.id);
        this.isLoading = false;
      },
      error: (error) => {
        console.error('Ошибка загрузки опор:', error);
        this.snackBar.open('Ошибка загрузки опор', 'Закрыть', { duration: 3000 });
        this.isLoading = false;
      }
    });
  }

  drop(event: CdkDragDrop<Pole[]>): void {
    moveItemInArray(this.poles, event.previousIndex, event.currentIndex);
    // Обновляем sequence_number для визуализации
    this.poles.forEach((pole, index) => {
      pole.sequence_number = index + 1;
    });
  }

  autoSequence(): void {
    if (this.poles.length === 0) {
      return;
    }

    this.isLoading = true;
    const startPoleId = this.poles[0].id;
    
    this.apiService.autoSequencePoles(this.powerLineId, startPoleId).subscribe({
      next: (response) => {
        this.snackBar.open(response.message, 'Закрыть', { duration: 3000 });
        this.loadPoles(); // Перезагружаем опоры с новой последовательностью
      },
      error: (error) => {
        console.error('Ошибка автоматического определения последовательности:', error);
        this.snackBar.open(
          error.error?.detail || 'Ошибка определения последовательности',
          'Закрыть',
          { duration: 5000 }
        );
        this.isLoading = false;
      }
    });
  }

  saveSequence(): void {
    const poleIds = this.poles.map(p => p.id);
    
    // Проверяем, изменилась ли последовательность
    const hasChanged = poleIds.some((id, index) => id !== this.originalSequence[index]);
    
    if (!hasChanged) {
      this.snackBar.open('Последовательность не изменилась', 'Закрыть', { duration: 2000 });
      return;
    }

    this.isSaving = true;
    this.apiService.updatePoleSequence(this.powerLineId, poleIds).subscribe({
      next: (response) => {
        this.snackBar.open(response.message, 'Закрыть', { duration: 3000 });
        this.originalSequence = [...poleIds];
        this.isSaving = false;
        this.dialogRef.close({ success: true, sequence: poleIds });
      },
      error: (error) => {
        console.error('Ошибка сохранения последовательности:', error);
        this.snackBar.open(
          error.error?.detail || 'Ошибка сохранения последовательности',
          'Закрыть',
          { duration: 5000 }
        );
        this.isSaving = false;
      }
    });
  }

  resetSequence(): void {
    this.loadPoles();
  }

  close(): void {
    this.dialogRef.close();
  }

  getSequenceChanged(): boolean {
    return this.poles.some((pole, index) => pole.id !== this.originalSequence[index]);
  }
}

