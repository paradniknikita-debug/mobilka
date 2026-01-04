import { Component, Inject, OnInit } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ApiService } from '../../../core/services/api.service';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Pole } from '../../../core/models/pole.model';
import { ConnectivityNode, ConnectivityNodeCreate } from '../../../core/models/cim.model';

@Component({
  selector: 'app-pole-connectivity-dialog',
  templateUrl: './pole-connectivity-dialog.component.html',
  styleUrls: ['./pole-connectivity-dialog.component.scss']
})
export class PoleConnectivityDialogComponent implements OnInit {
  pole: Pole;
  connectivityNode: ConnectivityNode | null = null;
  isLoading = false;

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: { pole: Pole },
    private dialogRef: MatDialogRef<PoleConnectivityDialogComponent>,
    private apiService: ApiService,
    private snackBar: MatSnackBar
  ) {
    this.pole = data.pole;
  }

  ngOnInit(): void {
    this.loadConnectivityNode();
  }

  loadConnectivityNode(): void {
    if (this.pole.connectivity_node_id) {
      this.isLoading = true;
      this.apiService.getConnectivityNode(this.pole.connectivity_node_id).subscribe({
        next: (node) => {
          this.connectivityNode = node;
          this.isLoading = false;
        },
        error: (error) => {
          console.error('Ошибка загрузки узла соединения:', error);
          this.isLoading = false;
        }
      });
    }
  }

  createConnectivityNode(): void {
    this.isLoading = true;
    this.apiService.createConnectivityNodeForPole(this.pole.id).subscribe({
      next: (node) => {
        this.connectivityNode = node;
        this.pole.connectivity_node_id = node.id;
        this.snackBar.open('Узел соединения создан', 'Закрыть', { duration: 3000 });
        this.isLoading = false;
        this.dialogRef.close({ success: true, connectivityNode: node });
      },
      error: (error) => {
        console.error('Ошибка создания узла соединения:', error);
        this.snackBar.open(
          error.error?.detail || 'Ошибка создания узла соединения',
          'Закрыть',
          { duration: 5000 }
        );
        this.isLoading = false;
      }
    });
  }

  deleteConnectivityNode(): void {
    if (!this.pole.connectivity_node_id) {
      return;
    }

    if (!confirm('Вы уверены, что хотите удалить узел соединения? Это может повлиять на сегменты линии.')) {
      return;
    }

    this.isLoading = true;
    this.apiService.deleteConnectivityNodeFromPole(this.pole.id).subscribe({
      next: () => {
        this.connectivityNode = null;
        this.pole.connectivity_node_id = undefined;
        this.snackBar.open('Узел соединения удалён', 'Закрыть', { duration: 3000 });
        this.isLoading = false;
        this.dialogRef.close({ success: true, connectivityNode: null });
      },
      error: (error) => {
        console.error('Ошибка удаления узла соединения:', error);
        this.snackBar.open(
          error.error?.detail || 'Ошибка удаления узла соединения',
          'Закрыть',
          { duration: 5000 }
        );
        this.isLoading = false;
      }
    });
  }

  close(): void {
    this.dialogRef.close();
  }
}

