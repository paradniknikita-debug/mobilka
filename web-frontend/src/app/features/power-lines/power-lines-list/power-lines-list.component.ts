import { Component } from '@angular/core';

@Component({
  selector: 'app-power-lines-list',
  template: `
    <div class="container">
      <h1>ЛЭП</h1>
      <p>Список линий электропередач будет здесь</p>
    </div>
  `,
  styles: [`
    .container {
      padding: 16px;
    }
  `]
})
export class PowerLinesListComponent {
}

