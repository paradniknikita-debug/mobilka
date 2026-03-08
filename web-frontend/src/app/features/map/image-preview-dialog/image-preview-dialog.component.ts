import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';

export interface ImagePreviewDialogData {
  url: string;
}

@Component({
  selector: 'app-image-preview-dialog',
  templateUrl: './image-preview-dialog.component.html',
  styleUrls: ['./image-preview-dialog.component.scss']
})
export class ImagePreviewDialogComponent {
  blobUrl: string | null = null;
  loading = true;
  error = false;

  constructor(
    private dialogRef: MatDialogRef<ImagePreviewDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: ImagePreviewDialogData,
    private api: ApiService
  ) {
    this.api.getAttachmentBlob(data.url).subscribe({
      next: (blob) => {
        this.blobUrl = URL.createObjectURL(blob);
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.error = true;
      }
    });
  }

  onClose(): void {
    if (this.blobUrl) {
      URL.revokeObjectURL(this.blobUrl);
    }
    this.dialogRef.close();
  }
}
