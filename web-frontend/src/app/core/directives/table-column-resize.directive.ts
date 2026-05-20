import {
  AfterViewInit,
  Directive,
  ElementRef,
  Input,
  OnDestroy,
} from '@angular/core';
import { MatTableColumnPrefs } from '../utils/mat-table-column-prefs';

/** Ручка на правой границе заголовка: курсор col-resize, перетаскивание как в Windows. */
@Directive({
  selector: '[appTableColumnResize]',
})
export class TableColumnResizeDirective implements AfterViewInit, OnDestroy {
  @Input('appTableColumnResize') columnId!: string;
  @Input() columnPrefs!: MatTableColumnPrefs;

  private handleEl?: HTMLElement;
  private dragging = false;
  private startX = 0;
  private startWidth = 0;

  private readonly onHandleMouseDown = (event: MouseEvent): void => {
    event.preventDefault();
    event.stopPropagation();
    const th = this.host.nativeElement;
    this.dragging = true;
    this.startX = event.clientX;
    this.startWidth = th.offsetWidth;
    th.classList.add('th-col-resizing');
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    document.addEventListener('mousemove', this.onDocumentMouseMove);
    document.addEventListener('mouseup', this.onDocumentMouseUp);
  };

  private readonly onDocumentMouseMove = (event: MouseEvent): void => {
    if (!this.dragging) {
      return;
    }
    const delta = event.clientX - this.startX;
    const w = Math.max(48, Math.min(520, this.startWidth + delta));
    const px = `${w}px`;
    const th = this.host.nativeElement;
    th.style.width = px;
    th.style.minWidth = px;
    th.style.maxWidth = px;
  };

  private readonly onDocumentMouseUp = (): void => {
    if (!this.dragging) {
      return;
    }
    this.dragging = false;
    this.host.nativeElement.classList.remove('th-col-resizing');
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
    this.detachDocumentListeners();
    const w = this.host.nativeElement.offsetWidth;
    if (this.columnPrefs && this.columnId) {
      this.columnPrefs.setColumnWidth(this.columnId, w);
    }
  };

  constructor(private readonly host: ElementRef<HTMLElement>) {}

  ngAfterViewInit(): void {
    const th = this.host.nativeElement;
    th.classList.add('th-col-resizable');
    const handle = document.createElement('span');
    handle.className = 'th-col-resize-handle';
    handle.setAttribute('role', 'separator');
    handle.setAttribute('aria-orientation', 'vertical');
    handle.setAttribute('aria-label', 'Изменить ширину столбца');
    handle.addEventListener('mousedown', this.onHandleMouseDown);
    th.appendChild(handle);
    this.handleEl = handle;
  }

  ngOnDestroy(): void {
    this.detachDocumentListeners();
    this.handleEl?.removeEventListener('mousedown', this.onHandleMouseDown);
  }

  private detachDocumentListeners(): void {
    document.removeEventListener('mousemove', this.onDocumentMouseMove);
    document.removeEventListener('mouseup', this.onDocumentMouseUp);
  }
}
