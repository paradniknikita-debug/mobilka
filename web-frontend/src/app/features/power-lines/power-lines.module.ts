import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Routes } from '@angular/router';
import { PowerLinesListComponent } from './power-lines-list/power-lines-list.component';

const routes: Routes = [
  {
    path: '',
    component: PowerLinesListComponent
  }
];

@NgModule({
  declarations: [
    PowerLinesListComponent
  ],
  imports: [
    CommonModule,
    RouterModule.forChild(routes)
  ]
})
export class PowerLinesModule { }

