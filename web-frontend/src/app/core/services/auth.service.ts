import { Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable, throwError } from 'rxjs';
import { catchError, switchMap, tap } from 'rxjs/operators';
import { ApiService } from './api.service';
import { User, AuthResponse } from '../models/user.model';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly TOKEN_KEY = 'auth_token';
  private readonly USER_KEY = 'current_user';
  
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  constructor(
    private apiService: ApiService,
    private router: Router
  ) {
    // Откладываем загрузку пользователя до следующего тика event loop,
    // чтобы избежать циклической зависимости при инициализации
    setTimeout(() => {
      this.loadUserFromStorage();
    }, 0);
  }

  login(username: string, password: string): Observable<User> {
    return this.apiService.login(username, password).pipe(
      switchMap((response: AuthResponse) => {
        // Сохраняем токен
        localStorage.setItem(this.TOKEN_KEY, response.access_token);
        console.log('✅ Токен сохранен');
        
        // Загружаем информацию о пользователе и возвращаем её
        return this.apiService.getCurrentUser().pipe(
          tap((user: User) => {
            console.log('✅ Пользователь загружен:', user.username);
            this.currentUserSubject.next(user);
            localStorage.setItem(this.USER_KEY, JSON.stringify(user));
          })
        );
      }),
      catchError(error => {
        console.error('❌ Ошибка при логине:', error);
        return throwError(() => error);
      })
    );
  }

  private loadCurrentUser(): void {
    this.apiService.getCurrentUser().subscribe({
      next: (user: User) => {
        console.log('✅ Пользователь загружен:', user.username);
        this.currentUserSubject.next(user);
        localStorage.setItem(this.USER_KEY, JSON.stringify(user));
      },
      error: (error) => {
        console.error('❌ Ошибка загрузки пользователя:', error);
        this.logout();
      }
    });
  }

  private loadUserFromStorage(): void {
    const token = localStorage.getItem(this.TOKEN_KEY);
    const userStr = localStorage.getItem(this.USER_KEY);
    
    if (token && userStr) {
      try {
        const user = JSON.parse(userStr);
        this.currentUserSubject.next(user);
        // Проверяем валидность токена, загружая пользователя
        this.loadCurrentUser();
      } catch (e) {
        console.error('Ошибка парсинга пользователя из storage:', e);
        this.logout();
      }
    }
  }

  logout(): void {
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem(this.USER_KEY);
    this.currentUserSubject.next(null);
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  isAuthenticated(): boolean {
    return this.getToken() !== null && this.currentUserSubject.value !== null;
  }

  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }
}

