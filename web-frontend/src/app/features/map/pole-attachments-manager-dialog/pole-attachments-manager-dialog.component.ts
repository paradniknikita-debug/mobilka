import { Component, Inject, OnInit, ViewChild, ElementRef } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatTableDataSource } from '@angular/material/table';
import { ApiService } from '../../../core/services/api.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { PoleCardAttachmentItem } from '../../../core/models/pole-card-attachment.model';

export type CardAttachmentsEntity = 'pole' | 'equipment';

export interface PoleAttachmentsManagerDialogData {
  entity: CardAttachmentsEntity;
  entityId: number;
  items: PoleCardAttachmentItem[];
  /** @deprecated используйте entity + entityId */
  poleId?: number;
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
  pendingType: 'photo' | 'voice' | 'schema' | 'video' | 'file' = 'file';
  uploading = false;

  private _entity: CardAttachmentsEntity = 'pole';
  private _entityId = 0;

  constructor(
    public dialogRef: MatDialogRef<PoleAttachmentsManagerDialogComponent, PoleCardAttachmentItem[]>,
    @Inject(MAT_DIALOG_DATA) public data: PoleAttachmentsManagerDialogData,
    private apiService: ApiService,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    const d = this.data as PoleAttachmentsManagerDialogData;
    if (d.entity && d.entityId != null) {
      this._entity = d.entity;
      this._entityId = Number(d.entityId);
    } else if (d.poleId != null) {
      this._entity = 'pole';
      this._entityId = Number(d.poleId);
    }
    this.localItems = JSON.parse(JSON.stringify(this.data.items || []));
    this.dataSource.data = this.localItems;
  }

  get dialogTitle(): string {
    return this._entity === 'equipment' ? 'Вложения карточки оборудования' : 'Вложения карточки опоры';
  }

  get hintText(): string {
    const save =
      this._entity === 'equipment'
        ? 'После добавления или удаления нажмите «Готово» и сохраните оборудование.'
        : 'После добавления или удаления нажмите «Готово» и сохраните опору.';
    return `Двойной клик по строке или кнопка со значком загрузки — скачать файл. ${save}`;
  }

  typeLabel(t: string): string {
    switch ((t || '').toLowerCase()) {
      case 'photo':
        return 'Фото';
      case 'schema':
        return 'Схема';
      case 'voice':
        return 'Голос';
      case 'video':
        return 'Видео';
      case 'file':
        return 'Файл';
      default:
        return 'Вложение';
    }
  }

  displayName(row: PoleCardAttachmentItem): string {
    const orig = row.original_filename?.trim();
    if (orig) return orig;
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
    this.pendingType = 'file';
    setTimeout(() => this.fileInput?.nativeElement?.click(), 0);
  }

  get fileAccept(): string {
    return '*/*';
  }

  private inferAttachmentType(filename: string): 'photo' | 'voice' | 'schema' | 'video' | 'file' {
    const lower = (filename || '').toLowerCase();
    if (/\.(jpe?g|png|gif|webp|bmp|heic|tif|tiff)$/.test(lower)) return 'photo';
    if (/\.(svg|pdf)$/.test(lower)) return 'schema';
    if (/\.(mp4|mov)$/.test(lower)) return 'video';
    if (/\.(m4a|mp3|wav|ogg|aac|webm)$/.test(lower)) return 'voice';
    return 'file';
  }

  onFileSelected(ev: Event): void {
    const input = ev.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    if (!this._entityId) {
      this.snackBar.open('Не задан идентификатор объекта для загрузки', 'Закрыть', { duration: 3000 });
      return;
    }
    this.pendingType = this.inferAttachmentType(file.name);
    this.uploading = true;
    const upload$ =
      this._entity === 'equipment'
        ? this.apiService.uploadEquipmentAttachment(this._entityId, this.pendingType, file)
        : this.apiService.uploadPoleAttachment(this._entityId, this.pendingType, file);
    upload$.subscribe({
      next: (res) => {
        const att: PoleCardAttachmentItem = {
          t: res.type || this.pendingType,
          url: res.url,
          filename: res.filename,
          original_filename: (res as any).original_filename ?? undefined,
          thumbnail: (res as any).thumbnail_url,
          thumbnail_url: (res as any).thumbnail_url,
          added_at: (res as any).added_at,
          added_by_id: (res as any).added_by_id,
          added_by_name: (res as any).added_by_name
        };
        this.localItems = [...this.localItems, att];
        this.dataSource.data = this.localItems;
        this.uploading = false;
        const hint =
          this._entity === 'equipment'
            ? 'Файл загружен. Сохраните оборудование, чтобы закрепить вложения в карточке.'
            : 'Файл загружен. Сохраните опору, чтобы закрепить вложения в карточке.';
        this.snackBar.open(hint, 'Закрыть', { duration: 4000 });
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
    const fallback = this.displayName(row);
    this.apiService.downloadAttachmentFile(row.url, fallback !== '—' ? fallback : 'attachment').subscribe({
      next: ({ blob, filename }) => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);
        this.snackBar.open('Файл сохранён', 'Закрыть', { duration: 2000 });
      },
      error: (e: HttpErrorResponse) => {
        const detail =
          (typeof e?.error === 'string' && e.error.trim()) ||
          e?.error?.detail ||
          e?.message ||
          'Ошибка скачивания';
        this.snackBar.open(detail, 'Закрыть', { duration: 4000 });
      }
    });
  }

  cancel(): void {
    this.dialogRef.close();
  }

  done(): void {
    this.dialogRef.close(this.localItems);
  }
}
