import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

export type AppTheme = 'dark' | 'light';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly storageKey = 'app_theme';
  private readonly theme$ = new BehaviorSubject<AppTheme>(this.readInitialTheme());

  constructor() {
    this.applyTheme(this.theme$.value);
  }

  get currentTheme(): AppTheme {
    return this.theme$.value;
  }

  get isDark(): boolean {
    return this.theme$.value === 'dark';
  }

  toggleTheme(): void {
    this.setTheme(this.isDark ? 'light' : 'dark');
  }

  setTheme(theme: AppTheme): void {
    this.theme$.next(theme);
    this.applyTheme(theme);
    localStorage.setItem(this.storageKey, theme);
  }

  private readInitialTheme(): AppTheme {
    const raw = localStorage.getItem(this.storageKey);
    if (raw === 'light' || raw === 'dark') return raw;
    return 'dark';
    }

  private applyTheme(theme: AppTheme): void {
    const body = document.body;
    body.classList.remove('app-theme-dark', 'app-theme-light');
    body.classList.add(theme === 'dark' ? 'app-theme-dark' : 'app-theme-light');
  }
}
