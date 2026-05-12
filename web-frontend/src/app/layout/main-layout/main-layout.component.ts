import { Component, HostListener, OnDestroy, OnInit } from '@angular/core';
import { Observable, Subject } from 'rxjs';
import { filter, map, takeUntil } from 'rxjs/operators';
import { AuthService } from '../../core/services/auth.service';
import { Router, NavigationEnd } from '@angular/router';
import { SidebarService } from '../../core/services/sidebar.service';
import { User } from '../../core/models/user.model';
import { canAccessPassportization, canUseExports, isAdminUser } from '../../core/utils/role-utils';

@Component({
  selector: 'app-main-layout',
  templateUrl: './main-layout.component.html',
  styleUrls: ['./main-layout.component.scss']
})
export class MainLayoutComponent implements OnInit, OnDestroy {
  sidebarWidth = 350;
  sidebarVisible = true;
  /** Текущий пользователь для условий в шаблоне (роли). */
  readonly user$: Observable<User | null>;
  readonly canUseExports$: Observable<boolean>;
  readonly canAccessPassportization$: Observable<boolean>;
  readonly isAdmin$: Observable<boolean>;
  /** Показывать кнопку раскрытия дерева только на карте (скрыта на Журнал и CIM/552) */
  showSidebarToggle = true;
  private destroy$ = new Subject<void>();
  private isResizing = false;
  private startX = 0;
  private startWidth = 0;

  constructor(
    private authService: AuthService,
    readonly router: Router,
    private sidebarService: SidebarService
  ) {
    this.user$ = this.authService.currentUser$;
    this.canUseExports$ = this.user$.pipe(map((u) => canUseExports(u ?? undefined)));
    this.canAccessPassportization$ = this.user$.pipe(map((u) => canAccessPassportization(u ?? undefined)));
    this.isAdmin$ = this.user$.pipe(map((u) => isAdminUser(u ?? undefined)));
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
    const hideOn = [
      '/change-log',
      '/cim-import',
      '/passportization',
      '/reports',
      '/equipment-catalog',
      '/equipment-catalog-bulk',
      '/admin',
    ];
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

  /** Подсветка «Паспортизация» для /passportization и устаревших /reports, /equipment-catalog. */
  isPassportizationRouteActive(): boolean {
    const path = this.router.url.split('?')[0];
    return (
      path === '/passportization' ||
      path === '/reports' ||
      path === '/tech-passports' ||
      path === '/equipment-catalog' ||
      path === '/equipment-catalog-bulk'
    );
  }
}

