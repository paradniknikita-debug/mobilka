import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { HttpClientModule, HTTP_INTERCEPTORS } from '@angular/common/http';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';

// Angular Material
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatExpansionModule } from '@angular/material/expansion';
import { MatSnackBarModule } from '@angular/material/snack-bar';
import { MatDialogModule, MAT_DIALOG_DEFAULT_OPTIONS } from '@angular/material/dialog';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule } from '@angular/material/paginator';
import { MatSortModule } from '@angular/material/sort';
import { MatMenuModule } from '@angular/material/menu';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatSelectModule } from '@angular/material/select';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatAutocompleteModule } from '@angular/material/autocomplete';
import { MatDividerModule } from '@angular/material/divider';

// CDK Drag & Drop
import { DragDropModule } from '@angular/cdk/drag-drop';

// Leaflet
import { LeafletModule } from '@asymmetrik/ngx-leaflet';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';

// Core
import { AuthInterceptor } from './core/interceptors/auth.interceptor';
import { ErrorInterceptor } from './core/interceptors/error.interceptor';

// Layout
import { MainLayoutComponent } from './layout/main-layout/main-layout.component';
import { SidebarComponent } from './layout/sidebar/sidebar.component';

// Features
import { LoginComponent } from './features/auth/login/login.component';
import { MapComponent } from './features/map/map.component';
import { CreateObjectDialogComponent } from './features/map/create-object-dialog/create-object-dialog.component';
import { DeleteObjectDialogComponent } from './features/map/delete-object-dialog/delete-object-dialog.component';
import { PoleConnectivityDialogComponent } from './features/map/pole-connectivity-dialog/pole-connectivity-dialog.component';
import { PoleSequenceDialogComponent } from './features/map/pole-sequence-dialog/pole-sequence-dialog.component';
import { CreateSpanDialogComponent } from './features/map/create-span-dialog/create-span-dialog.component';
import { CreateSegmentDialogComponent } from './features/map/create-segment-dialog/create-segment-dialog.component';
import { EditPowerLineDialogComponent } from './features/map/edit-power-line-dialog/edit-power-line-dialog.component';

@NgModule({
  declarations: [
    AppComponent,
    MainLayoutComponent,
    SidebarComponent,
    LoginComponent,
    MapComponent,
    CreateObjectDialogComponent,
    DeleteObjectDialogComponent,
    PoleConnectivityDialogComponent,
    PoleSequenceDialogComponent,
    CreateSpanDialogComponent,
    CreateSegmentDialogComponent,
    EditPowerLineDialogComponent
  ],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule,
    AppRoutingModule,

    // Material
    MatToolbarModule,
    MatButtonModule,
    MatIconModule,
    MatSidenavModule,
    MatListModule,
    MatFormFieldModule,
    MatInputModule,
    MatCardModule,
    MatProgressSpinnerModule,
    MatExpansionModule,
    MatSnackBarModule,
    MatDialogModule,
    MatTableModule,
    MatPaginatorModule,
    MatSortModule,
    MatMenuModule,
    MatTooltipModule,
    MatSelectModule,
    MatCheckboxModule,
    MatAutocompleteModule,
    MatDividerModule,

    // CDK
    DragDropModule,

    // Leaflet
    LeafletModule
  ],
  providers: [
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: ErrorInterceptor,
      multi: true
    },
    // Глобальная конфигурация для MatDialog
    {
      provide: MAT_DIALOG_DEFAULT_OPTIONS,
      useValue: {
        autoFocus: false,
        restoreFocus: false,
        hasBackdrop: true,
        disableClose: false
      }
    }
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }

