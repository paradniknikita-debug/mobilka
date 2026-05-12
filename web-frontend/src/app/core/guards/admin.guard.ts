import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { isAdminUser } from '../utils/role-utils';

@Injectable({ providedIn: 'root' })
export class AdminGuard implements CanActivate {
  constructor(
    private readonly auth: AuthService,
    private readonly router: Router,
  ) {}

  canActivate(): boolean {
    const u = this.auth.getCurrentUser();
    if (isAdminUser(u)) {
      return true;
    }
    void this.router.navigate(['/map']);
    return false;
  }
}
