import { Component, Input, Output, EventEmitter, OnInit, OnDestroy } from '@angular/core';
import { ApiService } from '../../../core/services/api.service';

/**
 * Загружает изображение вложения через API (с авторизацией) и отображает как blob.
 * Клик по изображению эмитит openPreview(url) — родитель открывает диалог предпросмотра.
 */
@Component({
  selector: 'app-attachment-image-view',
  templateUrl: './attachment-image-view.component.html',
  styleUrls: ['./attachment-image-view.component.scss']
})
export class AttachmentImageViewComponent implements OnInit, OnDestroy {
  @Input() url!: string;
  @Input() thumbnailUrl?: string | null;
  @Input() alt = 'Изображение';
  @Input() cssClass = '';
  @Input() clickable = true;
  @Output() openPreview = new EventEmitter<string>();

  blobUrl: string | null = null;
  loading = true;
  error = false;

  constructor(private api: ApiService) {}

  ngOnInit(): void {
    const thumb = (this.thumbnailUrl && this.thumbnailUrl.trim()) ? this.thumbnailUrl.trim() : null;
    const loadUrl = thumb || this.url;
    if (!loadUrl) {
      this.loading = false;
      this.error = true;
      return;
    }
    this.api.getAttachmentBlob(loadUrl).subscribe({
      next: (blob) => {
        this.blobUrl = URL.createObjectURL(blob);
        this.loading = false;
      },
      error: () => {
        if (thumb && this.url && thumb !== this.url) {
          this.loadFallbackFromUrl();
        } else {
          this.loading = false;
          this.error = true;
        }
      }
    });
  }

  private loadFallbackFromUrl(): void {
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

  onClick(): void {
    if (this.clickable && this.url && !this.loading && !this.error) {
      this.openPreview.emit(this.url);
    }
  }
}
