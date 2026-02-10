import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class SidebarService {
  private sidebarVisible$ = new BehaviorSubject<boolean>(true);
  private sidebarWidth$ = new BehaviorSubject<number>(350);

  setSidebarVisible(visible: boolean): void {
    this.sidebarVisible$.next(visible);
  }

  getSidebarVisible(): Observable<boolean> {
    return this.sidebarVisible$.asObservable();
  }

  isSidebarOpen(): boolean {
    return this.sidebarVisible$.getValue();
  }

  setSidebarWidth(width: number): void {
    this.sidebarWidth$.next(width);
  }

  getSidebarWidth(): Observable<number> {
    return this.sidebarWidth$.asObservable();
  }

  getCurrentSidebarWidth(): number {
    return this.sidebarWidth$.getValue();
  }
}



