import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { AuthGuard } from './core/guards/auth.guard';

import { LoginComponent } from './features/auth/login/login.component';
import { MainLayoutComponent } from './layout/main-layout/main-layout.component';
import { MapComponent } from './features/map/map.component';
import { ChangeLogComponent } from './features/change-log/change-log.component';
import { ReportsComponent } from './features/reports/reports.component';
import { CimImportComponent } from './features/cim-import/cim-import.component';

const routes: Routes = [
  {
    path: 'login',
    component: LoginComponent
  },
  {
    path: '',
    component: MainLayoutComponent,
    canActivate: [AuthGuard],
    children: [
      {
        path: '',
        redirectTo: '/map',
        pathMatch: 'full'
      },
      {
        path: 'map',
        component: MapComponent
      },
      {
        path: 'change-log',
        component: ChangeLogComponent
      },
      {
        path: 'reports',
        component: ReportsComponent
      },
      {
        path: 'cim-import',
        component: CimImportComponent
      },
      {
        path: 'power-lines',
        loadChildren: () => import('./features/power-lines/power-lines.module').then(m => m.PowerLinesModule)
      },
      {
        path: 'poles',
        loadChildren: () => import('./features/poles/poles.module').then(m => m.PolesModule)
      },
      {
        path: 'equipment',
        loadChildren: () => import('./features/equipment/equipment.module').then(m => m.EquipmentModule)
      },
      {
        path: 'substations',
        loadChildren: () => import('./features/substations/substations.module').then(m => m.SubstationsModule)
      }
    ]
  },
  {
    path: '**',
    redirectTo: '/map'
  }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }

