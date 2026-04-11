import { Component, Inject, OnInit, ViewChild, ElementRef } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatTableDataSource } from '@angular/material/table';
import { ApiService } from '../../../core/services/api.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { PoleCardAttachmentItem } from '../../../core/models/pole-card-attachment.model';

export interface PoleAttachmentsManagerDialogData {
  poleId: number;
  items: PoleCardAttachmentItem[];
}

@Component({
  selector: 'app-pole-attachments-manager-dialog',
  templateUrl: './pole-attachments-manager-dialog.component.html',
  styleUrls: ['./pole-attachments-manager-dialog.component.scss']
})
export class PoleAttachmentsManagerDialogComponent implements OnInit {
  @ViewChild('fileInput') fileInput?: ElementRef<HTMLInputElement>;

  displayedColumns: string[] = ['typeLabel', 'filename', 'extension', 'addedAt', 'addedBy', 'actions'];
  dataSource = new MatTableDataSource<PoleCardAttachmentItem>([]);
  localItems: PoleCardAttachmentItem[] = [];
  pendingType: 'photo' | 'voice' | 'schema' | 'video' = 'schema';
  uploading = false;

  constructor(
    public dialogRef: MatDialogRef<PoleAttachmentsManagerDialogComponent, PoleCardAttachmentItem[]>,
    @Inject(MAT_DIALOG_DATA) public data: PoleAttachmentsManagerDialogData,
    private apiService: ApiService,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.localItems = JSON.parse(JSON.stringify(this.data.items || []));
    this.dataSource.data = this.localItems;
  }

  typeLabel(t: string): string {
    switch (t) {
      case 'file': return 'Файл';
      case 'voice': return 'Аудио';
      case 'video': return 'Видео';
      case 'schema': return 'Схема';
      case 'photo': return 'Фото';
      default: return t || 'Файл';
    }
  }

  displayName(row: PoleCardAttachmentItem): string {
    const fn = row.filename?.trim();
    if (fn) return fn;
    return this.basename(row.url);
  }

  extensionOf(row: PoleCardAttachmentItem): string {
    const name = this.displayName(row);
    const i = name.lastIndexOf('.');
    if (i <= 0 || i >= name.length - 1) return '—';
    return name.slice(i).toLowerCase();
  }

  formatWhen(row: PoleCardAttachmentItem): string {
    const s = row.added_at?.trim();
    if (!s) return '—';
    const d = Date.parse(s);
    if (Number.isNaN(d)) return s;
    try {
      return (
        new Date(d).toLocaleString('ru-RU', { timeZone: 'Europe/Moscow' }) + ' МСК'
      );
    } catch {
      return s;
    }
  }

  who(row: PoleCardAttachmentItem): string {
    return row.added_by_name?.trim() || (row.added_by_id != null ? `id ${row.added_by_id}` : '—');
  }

  private basename(url: string): string {
    if (!url?.trim()) return '—';
    const seg = url.replace(/\/+$/, '').split('/').pop();
    return seg || '—';
  }

  triggerPickFile(): void {
    this.pendingType = 'schema';
    setTimeout(() => this.fileInput?.nativeElement?.click(), 0);
  }

  get fileAccept(): string {
    return '*/*';
  }

  onFileSelected(ev: Event): void {
    const input = ev.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    this.uploading = true;
    this.apiService.uploadPoleAttachment(this.data.poleId, this.pendingType, file).subscribe({
      next: (res) => {
        const att: PoleCardAttachmentItem = {
          t: res.type || this.pendingType,
          url: res.url,
          filename: res.filename,
          thumbnail: (res as any).thumbnail_url,
          thumbnail_url: (res as any).thumbnail_url,
          added_at: (res as any).added_at,
          added_by_id: (res as any).added_by_id,
          added_by_name: (res as any).added_by_name
        };
        this.localItems = [...this.localItems, att];
        this.dataSource.data = this.localItems;
        this.uploading = false;
        this.snackBar.open('Файл загружен. Сохраните опору, чтобы закрепить вложения в карточке.', 'Закрыть', { duration: 4000 });
      },
      error: () => {
        this.uploading = false;
        this.snackBar.open('Ошибка загрузки файла', 'Закрыть', { duration: 3000 });
      }
    });
  }

  remove(i: number): void {
    this.localItems = this.localItems.filter((_, j) => j !== i);
    this.dataSource.data = this.localItems;
  }

  download(row: PoleCardAttachmentItem): void {
    const name = this.displayName(row);
    this.apiService.getAttachmentBlob(row.url).subscribe({
      next: (blob) => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = name !== '—' ? name : 'attachment';
        a.click();
        URL.revokeObjectURL(url);
        this.snackBar.open('Файл сохранён', 'Закрыть', { duration: 2000 });
      },
      error: () => this.snackBar.open('Ошибка скачивания', 'Закрыть', { duration: 3000 })
    });
  }

  cancel(): void {
    this.dialogRef.close();
  }

  done(): void {
    this.dialogRef.close(this.localItems);
  }
}
