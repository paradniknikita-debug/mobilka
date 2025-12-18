import { Component, HostListener, OnDestroy } from '@angular/core';
import { AuthService } from '../../core/services/auth.service';
import { Router } from '@angular/router';
import { Subject } from 'rxjs';
import { SidebarService } from '../../core/services/sidebar.service';

@Component({
  selector: 'app-main-layout',
  templateUrl: './main-layout.component.html',
  styleUrls: ['./main-layout.component.scss']
})
export class MainLayoutComponent implements OnDestroy {
  sidebarWidth = 350;
  sidebarVisible = true;
  private destroy$ = new Subject<void>();
  private isResizing = false;
  private startX = 0;
  private startWidth = 0;

  constructor(
    private authService: AuthService,
    private router: Router,
    private sidebarService: SidebarService
  ) {
    // Инициализируем состояние sidebar в сервисе
    this.sidebarService.setSidebarVisible(this.sidebarVisible);
    this.sidebarService.setSidebarWidth(this.sidebarWidth);
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

