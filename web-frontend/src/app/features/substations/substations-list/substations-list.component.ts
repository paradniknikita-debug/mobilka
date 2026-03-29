import { Component } from '@angular/core';

@Component({
  selector: 'app-substations-list',
  template: `
    <div class="container">
      <h1>Подстанции</h1>
      <p>Список подстанций будет здесь</p>
    </div>
  `,
  styles: [`
    .container {
      padding: 16px;
    }
  `]
})
export class SubstationsListComponent {
}

