import { Component } from '@angular/core';

@Component({
  selector: 'app-poles-list',
  template: `
    <div class="container">
      <h1>Опоры</h1>
      <p>Список опор будет здесь</p>
    </div>
  `,
  styles: [`
    .container {
      padding: 16px;
    }
  `]
})
export class PolesListComponent {
}

