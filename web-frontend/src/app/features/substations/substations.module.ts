import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Routes } from '@angular/router';
import { SubstationsListComponent } from './substations-list/substations-list.component';

const routes: Routes = [
  {
    path: '',
    component: SubstationsListComponent
  }
];

@NgModule({
  declarations: [
    SubstationsListComponent
  ],
  imports: [
    CommonModule,
    RouterModule.forChild(routes)
  ]
})
export class SubstationsModule { }

