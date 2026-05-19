import { Component, Inject, OnInit } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MatSnackBar } from '@angular/material/snack-bar';

export interface DockerLogsDialogData {
  services: { id: string; label: string }[];
}

@Component({
  selector: 'app-docker-logs-dialog',
  templateUrl: './docker-logs-dialog.component.html',
  styleUrls: ['./docker-logs-dialog.component.scss'],
})
export class DockerLogsDialogComponent implements OnInit {
  service = 'backend';
  tail = 300;
  logText = '';
  loading = false;

  constructor(
    public dialogRef: MatDialogRef<DockerLogsDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: DockerLogsDialogData,
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
  ) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.api.getAdminDockerLogs(this.service, this.tail).subscribe({
      next: (res) => {
        this.logText = res.log || '';
        this.loading = false;
      },
      error: (e) => {
        this.loading = false;
        const detail =
          (typeof e?.error === 'object' && e?.error?.detail) ||
          (typeof e?.error === 'string' ? e.error : null) ||
          e?.message ||
          'Не удалось загрузить логи';
        this.logText = String(detail);
        this.snackBar.open(String(detail), 'Закрыть', { duration: 5000 });
      },
    });
  }

  copy(): void {
    if (!this.logText) return;
    navigator.clipboard?.writeText(this.logText).then(
      () => this.snackBar.open('Скопировано в буфер', 'Закрыть', { duration: 2000 }),
      () => this.snackBar.open('Не удалось скопировать', 'Закрыть', { duration: 3000 }),
    );
  }

  close(): void {
    this.dialogRef.close();
  }
}
