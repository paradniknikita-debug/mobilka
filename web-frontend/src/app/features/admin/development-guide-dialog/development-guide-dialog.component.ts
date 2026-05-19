import { Component, Inject, OnInit } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-development-guide-dialog',
  templateUrl: './development-guide-dialog.component.html',
  styleUrls: ['./development-guide-dialog.component.scss'],
})
export class DevelopmentGuideDialogComponent implements OnInit {
  text = '';
  loading = true;

  constructor(
    public dialogRef: MatDialogRef<DevelopmentGuideDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: Record<string, never>,
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
  ) {}

  ngOnInit(): void {
    this.api.getAdminDevelopmentGuide().subscribe({
      next: (body) => {
        this.text = body;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.text = 'Не удалось загрузить DEVELOPMENT_GUIDE.md';
        this.snackBar.open('Ошибка загрузки руководства', 'Закрыть', { duration: 4000 });
      },
    });
  }

  close(): void {
    this.dialogRef.close();
  }
}
