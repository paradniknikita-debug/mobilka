import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { User, UserCreate } from '../../core/models/user.model';
import {
  ROLE_ADMIN,
  ROLE_FIELD_ENGINEER,
  ROLE_LABELS,
  ROLE_PASSPORT_CLERK,
  normalizeRole,
} from '../../core/utils/role-utils';

@Component({
  selector: 'app-admin',
  templateUrl: './admin.component.html',
  styleUrls: ['./admin.component.scss'],
})
export class AdminComponent implements OnInit {
  readonly normalizeRole = normalizeRole;

  readonly displayedColumns = [
    'id',
    'username',
    'password_plain',
    'full_name',
    'role',
    'active',
    'actions',
  ];

  stats: Record<string, unknown> | null = null;
  users: User[] = [];
  loading = false;
  currentUserId: number | null = null;

  readonly roleOptions = [
    { value: ROLE_ADMIN, label: ROLE_LABELS[ROLE_ADMIN] },
    { value: ROLE_PASSPORT_CLERK, label: ROLE_LABELS[ROLE_PASSPORT_CLERK] },
    { value: ROLE_FIELD_ENGINEER, label: ROLE_LABELS[ROLE_FIELD_ENGINEER] },
  ];

  createForm: UserCreate = {
    username: '',
    email: '',
    full_name: '',
    password: '',
    role: ROLE_FIELD_ENGINEER,
  };

  constructor(
    private readonly api: ApiService,
    private readonly snackBar: MatSnackBar,
    private readonly auth: AuthService,
  ) {}

  ngOnInit(): void {
    this.currentUserId = this.auth.getCurrentUser()?.id ?? null;
    this.reload();
  }

  reload(): void {
    this.loading = true;
    this.api.getAdminStats().subscribe({
      next: (s) => {
        this.stats = s;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.snackBar.open('Не удалось загрузить метрики', 'Закрыть', { duration: 4000 });
      },
    });
    this.api.getAdminUsers().subscribe({
      next: (rows) => {
        this.users = rows ?? [];
      },
      error: () => {
        this.snackBar.open('Не удалось загрузить пользователей', 'Закрыть', { duration: 4000 });
      },
    });
  }

  displayRole(role: string): string {
    const n = normalizeRole(role);
    return ROLE_LABELS[n] || n;
  }

  createUser(): void {
    const c = this.createForm;
    if (!c.username?.trim() || !c.email?.trim() || !c.full_name?.trim() || !c.password?.trim()) {
      this.snackBar.open('Заполните логин, email, ФИО и пароль', 'Закрыть', { duration: 4000 });
      return;
    }
    this.api.createAdminUser(c).subscribe({
      next: () => {
        this.snackBar.open('Пользователь создан', 'Закрыть', { duration: 3000 });
        this.createForm = {
          username: '',
          email: '',
          full_name: '',
          password: '',
          role: ROLE_FIELD_ENGINEER,
        };
        this.reload();
      },
      error: (e) => {
        const msg = e?.error?.detail || 'Ошибка создания пользователя';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка создания', 'Закрыть', { duration: 5000 });
      },
    });
  }

  updateUser(u: User, patch: { role?: string; is_active?: boolean }): void {
    this.api.patchAdminUser(u.id, patch).subscribe({
      next: () => {
        this.snackBar.open('Сохранено', 'Закрыть', { duration: 2000 });
        this.reload();
      },
      error: (e) => {
        const msg = e?.error?.detail || 'Ошибка сохранения';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка', 'Закрыть', { duration: 5000 });
      },
    });
  }

  onRoleChange(u: User, value: string): void {
    this.updateUser(u, { role: value });
  }

  onActiveChange(u: User, checked: boolean): void {
    this.updateUser(u, { is_active: checked });
  }

  changePassword(u: User): void {
    const v = window.prompt(
      `Новый пароль для «${u.username}» (не короче 6 символов). Отмена — без изменений.`,
      '',
    );
    if (v === null) {
      return;
    }
    const pwd = (v || '').trim();
    if (pwd.length < 6) {
      this.snackBar.open('Пароль должен быть не короче 6 символов', 'Закрыть', { duration: 4000 });
      return;
    }
    this.api.patchAdminUser(u.id, { password: pwd }).subscribe({
      next: () => {
        this.snackBar.open('Пароль обновлён', 'Закрыть', { duration: 3000 });
        this.reload();
      },
      error: (e) => {
        const msg = e?.error?.detail || 'Ошибка смены пароля';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка', 'Закрыть', { duration: 5000 });
      },
    });
  }

  deleteUser(u: User): void {
    if (
      !confirm(
        `Удалить пользователя «${u.username}» безвозвратно?\n` +
          'Все ссылки «создал» на объектах будут переназначены на вашу учётную запись.',
      )
    ) {
      return;
    }
    this.api.deleteAdminUser(u.id).subscribe({
      next: () => {
        this.snackBar.open('Пользователь удалён', 'Закрыть', { duration: 3000 });
        this.reload();
      },
      error: (e) => {
        const msg = e?.error?.detail || e?.message || 'Не удалось удалить';
        this.snackBar.open(typeof msg === 'string' ? msg : 'Ошибка удаления', 'Закрыть', { duration: 6000 });
      },
    });
  }
}
