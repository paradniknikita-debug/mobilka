import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { canAccessPassportization } from '../utils/role-utils';

/** Паспортизация: все роли; инженер-обходчик — только просмотр (редактирование — паспортист/админ). */
@Injectable({ providedIn: 'root' })
export class PassportizationGuard implements CanActivate {
  constructor(
    private readonly auth: AuthService,
    private readonly router: Router,
  ) {}

  canActivate(): boolean {
    const u = this.auth.getCurrentUser();
    if (canAccessPassportization(u)) {
      return true;
    }
    void this.router.navigate(['/map']);
    return false;
  }
}
