import {
  Directive,
  ElementRef,
  AfterViewInit,
  OnDestroy,
  Optional,
} from '@angular/core';
import { MatDialogRef } from '@angular/material/dialog';

/**
 * Директива для растягивания диалогового окна: ручка в углу, кнопки закрыть/на весь экран.
 * При ресайзе меняет размер и контейнера, и overlay-pane, чтобы можно было растягивать вширь.
 */
@Directive({
  selector: '[appResizableDialog]'
})
export class ResizableDialogDirective implements AfterViewInit, OnDestroy {
  private handle: HTMLElement | null = null;
  private toolbar: HTMLElement | null = null;
  private resizing = false;
  private startX = 0;
  private startY = 0;
  private startW = 0;
  private startH = 0;
  private boundDoResize = (e: MouseEvent) => this.doResize(e);
  private boundStopResize = () => this.stopResize();

  constructor(
    private el: ElementRef<HTMLElement>,
    @Optional() private dialogRef: MatDialogRef<unknown> | null
  ) {}

  ngAfterViewInit(): void {
    const container = this.getContainer();
    if (!container) return;

    container.style.position = 'relative';

    const pane = this.getPane(container);
    if (pane) {
      pane.style.maxWidth = '95vw';
      pane.style.maxHeight = '90vh';
    }

    if (!this.hasCustomHeaderControls(container)) {
      this.toolbar = document.createElement('div');
      this.toolbar.className = 'app-dialog-toolbar';
      const maxBtn = document.createElement('button');
      maxBtn.type = 'button';
      maxBtn.className = 'app-dialog-btn app-dialog-btn-maximize';
      maxBtn.title = 'На весь экран';
      maxBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/></svg>';
      maxBtn.setAttribute('aria-label', 'На весь экран');
      maxBtn.addEventListener('click', () => this.maximize());
      this.toolbar.appendChild(maxBtn);
      container.appendChild(this.toolbar);
    }

    this.handle = document.createElement('div');
    this.handle.className = 'app-dialog-resize-handle';
    this.handle.title = 'Тяните для изменения размера';
    this.handle.addEventListener('mousedown', (e: MouseEvent) => this.startResize(e));
    container.appendChild(this.handle);
  }

  ngOnDestroy(): void {
    this.stopResize();
    [this.handle, this.toolbar].forEach(node => {
      if (node?.parentNode) node.parentNode.removeChild(node);
    });
  }

  private getContainer(): HTMLElement | null {
    return this.el.nativeElement.closest('.mat-mdc-dialog-container') as HTMLElement
      || this.el.nativeElement.closest('.mat-dialog-container') as HTMLElement;
  }

  private getPane(container: HTMLElement): HTMLElement | null {
    let p: HTMLElement | null = container.parentElement;
    while (p && !p.classList.contains('cdk-overlay-pane')) p = p.parentElement;
    return p;
  }

  private hasCustomHeaderControls(container: HTMLElement): boolean {
    const titleSelectors = '.mat-mdc-dialog-title, .mat-dialog-title';
    const title = container.querySelector(titleSelectors);
    if (!title) return false;

    const hasCloseInTitle = !!title.querySelector('button[mat-dialog-close], [mat-dialog-close]');
    const iconNodes = Array.from(title.querySelectorAll('mat-icon'));
    const hasFullscreenInTitle = iconNodes.some((i) => {
      const t = (i.textContent || '').trim();
      return t === 'fullscreen' || t === 'fullscreen_exit';
    });
    return hasCloseInTitle || hasFullscreenInTitle;
  }

  private maximize(): void {
    const container = this.getContainer();
    const pane = container ? this.getPane(container) : null;
    const w = '95vw';
    const h = '90vh';
    if (container) {
      container.style.width = w;
      container.style.height = h;
      container.style.maxWidth = w;
      container.style.maxHeight = h;
    }
    if (pane) {
      pane.style.width = w;
      pane.style.height = h;
      pane.style.maxWidth = w;
      pane.style.maxHeight = h;
    }
  }

  private startResize(e: MouseEvent): void {
    e.preventDefault();
    e.stopPropagation();
    const container = this.getContainer();
    if (!container) return;
    this.resizing = true;
    this.startX = e.clientX;
    this.startY = e.clientY;
    this.startW = container.offsetWidth;
    this.startH = container.offsetHeight;
    document.addEventListener('mousemove', this.boundDoResize);
    document.addEventListener('mouseup', this.boundStopResize);
  }

  private doResize(e: MouseEvent): void {
    if (!this.resizing) return;
    const container = this.getContainer();
    const pane = container ? this.getPane(container) : null;
    if (!container) return;
    const dw = e.clientX - this.startX;
    const dh = e.clientY - this.startY;
    const w = Math.max(320, Math.min(this.startW + dw, 95 * window.innerWidth / 100));
    const h = Math.max(200, Math.min(this.startH + dh, 90 * window.innerHeight / 100));
    const wPx = w + 'px';
    const hPx = h + 'px';
    container.style.width = wPx;
    container.style.height = hPx;
    container.style.maxWidth = '95vw';
    container.style.maxHeight = '90vh';
    if (pane) {
      pane.style.width = wPx;
      pane.style.height = hPx;
      pane.style.maxWidth = '95vw';
      pane.style.maxHeight = '90vh';
    }
  }

  private stopResize(): void {
    this.resizing = false;
    document.removeEventListener('mousemove', this.boundDoResize);
    document.removeEventListener('mouseup', this.boundStopResize);
  }
}
