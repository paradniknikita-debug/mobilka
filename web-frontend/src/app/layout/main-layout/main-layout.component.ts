import { Component, HostListener, OnDestroy, OnInit } from '@angular/core';
import { Subject } from 'rxjs';
import { filter, takeUntil } from 'rxjs/operators';
import { AuthService } from '../../core/services/auth.service';
import { Router, NavigationEnd } from '@angular/router';
import { SidebarService } from '../../core/services/sidebar.service';

@Component({
  selector: 'app-main-layout',
  templateUrl: './main-layout.component.html',
  styleUrls: ['./main-layout.component.scss']
})
export class MainLayoutComponent implements OnInit, OnDestroy {
  sidebarWidth = 350;
  sidebarVisible = true;
  /** Показывать кнопку раскрытия дерева только на карте (скрыта на Журнал и CIM/552) */
  showSidebarToggle = true;
  private destroy$ = new Subject<void>();
  private isResizing = false;
  private startX = 0;
  private startWidth = 0;

  constructor(
    private authService: AuthService,
    private router: Router,
    private sidebarService: SidebarService
  ) {
    this.sidebarService.setSidebarVisible(this.sidebarVisible);
    this.sidebarService.setSidebarWidth(this.sidebarWidth);
  }

  ngOnInit(): void {
    this.updateShowSidebarToggle(this.router.url);
    this.router.events.pipe(
      filter((e): e is NavigationEnd => e instanceof NavigationEnd),
      takeUntil(this.destroy$)
    ).subscribe(e => this.updateShowSidebarToggle(e.urlAfterRedirects || e.url));
  }

  private updateShowSidebarToggle(url: string): void {
    const hideOn = ['/change-log', '/cim-import', '/equipment-catalog', '/reports'];
    const hide = hideOn.some(path => url.startsWith(path) || url.includes(path));
    this.showSidebarToggle = !hide;
    if (hide) {
      this.sidebarVisible = false;
      this.sidebarService.setSidebarVisible(false);
    }
  }

  startResize(event: MouseEvent): void {
    this.isResizing = true;
    this.startX = event.clientX;
    this.startWidth = this.sidebarWidth;
    event.preventDefault();
    event.stopPropagation();
  }

  @HostListener('document:mousemove', ['$event'])
  onMouseMove(event: MouseEvent): void {
    if (!this.isResizing) return;
    
    // Так как sidebar слева, при движении мыши вправо ширина увеличивается
    const diff = event.clientX - this.startX;
    const newWidth = this.startWidth + diff;
    
    // Ограничиваем минимальную и максимальную ширину
    if (newWidth >= 200 && newWidth <= 800) {
      this.sidebarWidth = newWidth;
      this.sidebarService.setSidebarWidth(newWidth);
    }
  }

  @HostListener('document:mouseup')
  onMouseUp(): void {
    this.isResizing = false;
  }

  toggleSidebar(): void {
    this.sidebarVisible = !this.sidebarVisible;
    this.sidebarService.setSidebarVisible(this.sidebarVisible);
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}

