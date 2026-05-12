import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, NavigationEnd, Router } from '@angular/router';
import { Subscription, merge } from 'rxjs';
import { filter } from 'rxjs/operators';
import { AuthService } from '../../core/services/auth.service';
import { canUseExports } from '../../core/utils/role-utils';

const TAB_KEYS = ['reports', 'passports', 'equipment', 'conductors'] as const;
type TabKey = (typeof TAB_KEYS)[number];

@Component({
  selector: 'app-passportization',
  templateUrl: './passportization.component.html',
  styleUrls: ['./passportization.component.scss'],
})
export class PassportizationComponent implements OnInit, OnDestroy {
  tabIndex = 0;
  private sub?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
    private readonly auth: AuthService,
  ) {}

  canManagePassportization(): boolean {
    return canUseExports(this.auth.getCurrentUser());
  }

  ngOnInit(): void {
    this.syncTabFromRoute();

    this.sub = merge(
      this.route.queryParamMap,
      this.router.events.pipe(filter((e): e is NavigationEnd => e instanceof NavigationEnd)),
    ).subscribe(() => this.syncTabFromRoute());
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  private syncTabFromRoute(): void {
    const qTab = this.route.snapshot.queryParamMap.get('tab') as TabKey | null;
    if (qTab && TAB_KEYS.includes(qTab)) {
      this.tabIndex = TAB_KEYS.indexOf(qTab);
      return;
    }

    const path = this.route.snapshot.routeConfig?.path;
    if (path === 'reports') {
      this.tabIndex = 0;
      return;
    }
    if (path === 'equipment-catalog' || path === 'equipment-catalog-bulk') {
      this.tabIndex = 2;
      return;
    }

    const dataTab = this.route.snapshot.data['passportTab'] as TabKey | undefined;
    if (dataTab && TAB_KEYS.includes(dataTab)) {
      this.tabIndex = TAB_KEYS.indexOf(dataTab);
      return;
    }

    if (path === 'passportization') {
      this.tabIndex = 0;
    }
  }

  onTabChange(index: number): void {
    this.tabIndex = index;
    const key = TAB_KEYS[index] ?? TAB_KEYS[0];
    void this.router.navigate(['/passportization'], {
      queryParams: { tab: key },
      replaceUrl: true,
    });
  }
}
