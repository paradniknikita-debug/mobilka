import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { AuthGuard } from './core/guards/auth.guard';

import { LoginComponent } from './features/auth/login/login.component';
import { MainLayoutComponent } from './layout/main-layout/main-layout.component';
import { MapComponent } from './features/map/map.component';

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

