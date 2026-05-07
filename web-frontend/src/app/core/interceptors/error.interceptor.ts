import { Injectable, Injector } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  constructor(
    private injector: Injector,
    private router: Router
  ) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {
        if (error.status === 401) {
          const url = error.url || '';
          // Неверный пароль на /auth/login — не сбрасывать сессию и не уводить с экрана входа
          if (url.includes('/auth/login') || url.includes('/auth/token')) {
            return throwError(() => error);
          }
          console.log('🔓 Токен истек, требуется повторная авторизация');
          const authService = this.injector.get(AuthService);
          authService.logout();
        } else if (error.status === 403) {
          // Доступ запрещен
          console.log('🚫 Доступ запрещен (403)');
        }

        return throwError(() => error);
      })
    );
  }
}

