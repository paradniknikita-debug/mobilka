import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MapService } from '../../../core/services/map.service';
import { MatSnackBar } from '@angular/material/snack-bar';

export interface RebuildTopologyDialogData {
  powerLineId: number;
}

@Component({
  selector: 'app-rebuild-topology-dialog',
  templateUrl: './rebuild-topology-dialog.component.html',
  styleUrls: ['./rebuild-topology-dialog.component.scss']
})
export class RebuildTopologyDialogComponent {
  loading = false;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: RebuildTopologyDialogData,
    private dialogRef: MatDialogRef<RebuildTopologyDialogComponent>,
    private apiService: ApiService,
    private mapService: MapService,
    private snackBar: MatSnackBar
  ) {}

  onMode(mode: 'full' | 'preserve'): void {
    this.loading = true;
    this.apiService.autoCreateSpans(this.data.powerLineId, mode).subscribe({
      next: () => {
        this.snackBar.open(
          mode === 'full' ? 'Топология пересобрана с нуля.' : 'Недостающие пролёты добавлены.',
          'Закрыть',
          { duration: 3000 }
        );
        this.mapService.refreshData();
        this.dialogRef.close(true);
      },
      error: (err) => {
        this.loading = false;
        this.snackBar.open(
          err.error?.detail || err.message || 'Ошибка пересборки топологии',
          'Закрыть',
          { duration: 5000, panelClass: ['error-snackbar'] }
        );
      }
    });
  }
}
