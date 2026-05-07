import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Routes } from '@angular/router';
import { EquipmentListComponent } from './equipment-list/equipment-list.component';

const routes: Routes = [
  {
    path: '',
    component: EquipmentListComponent
  }
];

@NgModule({
  declarations: [
    EquipmentListComponent
  ],
  imports: [
    CommonModule,
    RouterModule.forChild(routes)
  ]
})
export class EquipmentModule { }

