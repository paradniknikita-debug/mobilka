import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss']
})
export class LoginComponent implements OnInit {
  loginForm: FormGroup;
  isLoading = false;
  returnUrl: string = '/map';

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router,
    private route: ActivatedRoute,
    private snackBar: MatSnackBar
  ) {
    this.loginForm = this.fb.group({
      username: ['', [Validators.required]],
      password: ['', [Validators.required]]
    });
  }

  ngOnInit(): void {
    // Получаем returnUrl из query параметров
    this.returnUrl = this.route.snapshot.queryParams['returnUrl'] || '/map';
    
    // Если уже авторизован, перенаправляем
    if (this.authService.isAuthenticated()) {
      this.router.navigate([this.returnUrl]);
    }
  }

  onSubmit(): void {
    if (this.loginForm.invalid) {
      return;
    }

    this.isLoading = true;
    const { username, password } = this.loginForm.value;

    this.authService.login(username, password).subscribe({
      next: () => {
        console.log('✅ Успешный вход');
        this.router.navigate([this.returnUrl]);
      },
      error: (error) => {
        console.error('❌ Ошибка входа:', error);
        this.isLoading = false;
        
        let errorMessage = 'Ошибка авторизации';
        if (error.error?.detail) {
          errorMessage = error.error.detail;
        } else if (error.status === 401) {
          errorMessage = 'Неверный логин или пароль';
        } else if (error.status === 0) {
          errorMessage = 'Ошибка соединения с сервером';
        }

        this.snackBar.open(errorMessage, 'Закрыть', {
          duration: 4000,
          horizontalPosition: 'center',
          verticalPosition: 'top',
          panelClass: ['error-snackbar']
        });
      }
    });
  }
}

