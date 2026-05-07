import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Routes } from '@angular/router';
import { PolesListComponent } from './poles-list/poles-list.component';

const routes: Routes = [
  {
    path: '',
    component: PolesListComponent
  }
];

@NgModule({
  declarations: [
    PolesListComponent
  ],
  imports: [
    CommonModule,
    RouterModule.forChild(routes)
  ]
})
export class PolesModule { }

