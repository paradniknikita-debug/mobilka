import { Component, Input, OnInit, OnDestroy } from '@angular/core';
import { ApiService } from '../../../core/services/api.service';

/** Загружает аудио/видео через API (с авторизацией) и отображает через blob URL. */
@Component({
  selector: 'app-attachment-media-view',
  templateUrl: './attachment-media-view.component.html',
  styleUrls: ['./attachment-media-view.component.scss']
})
export class AttachmentMediaViewComponent implements OnInit, OnDestroy {
  @Input() url!: string;
  @Input() type!: 'voice' | 'video';

  blobUrl: string | null = null;
  loading = true;
  error = false;

  constructor(private api: ApiService) {}

  ngOnInit(): void {
    if (!this.url?.trim()) {
      this.loading = false;
      this.error = true;
      return;
    }
    this.api.getAttachmentBlob(this.url).subscribe({
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

  ngOnDestroy(): void {
    if (this.blobUrl) {
      URL.revokeObjectURL(this.blobUrl);
    }
  }
}
