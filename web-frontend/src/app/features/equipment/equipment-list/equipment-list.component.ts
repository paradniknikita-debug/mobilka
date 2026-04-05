import { Component } from '@angular/core';

@Component({
  selector: 'app-equipment-list',
  template: `
    <div class="container">
      <h1>Оборудование</h1>
      <p>Список оборудования будет здесь</p>
    </div>
  `,
  styles: [`
    .container {
      padding: 16px;
    }
  `]
})
export class EquipmentListComponent {
}

