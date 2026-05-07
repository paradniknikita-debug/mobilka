import { Component, Inject, AfterViewInit, OnDestroy } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import * as L from 'leaflet';

export interface CimPreviewMapDialogData {
  points: { lat: number; lng: number; label?: string }[];
  polylines?: { from: [number, number]; to: [number, number]; label?: string }[];
}

@Component({
  selector: 'app-cim-preview-map-dialog',
  templateUrl: './cim-preview-map-dialog.component.html',
  styleUrls: ['./cim-preview-map-dialog.component.scss']
})
export class CimPreviewMapDialogComponent implements AfterViewInit, OnDestroy {
  private map: L.Map | null = null;
  points: { lat: number; lng: number; label?: string }[] = [];
  polylines: { from: [number, number]; to: [number, number]; label?: string }[] = [];

  constructor(
    @Inject(MAT_DIALOG_DATA) public data: CimPreviewMapDialogData,
    private dialogRef: MatDialogRef<CimPreviewMapDialogComponent>
  ) {
    this.points = data?.points ?? [];
    this.polylines = data?.polylines ?? [];
  }

  ngAfterViewInit(): void {
    setTimeout(() => this.initMap(), 100);
  }

  ngOnDestroy(): void {
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }

  private initMap(): void {
    const container = document.getElementById('cim-preview-map');
    if (!container || (this.points.length === 0 && this.polylines.length === 0)) {
      return;
    }
    const allCoords: [number, number][] = [
      ...this.points.map((p) => [p.lat, p.lng] as [number, number]),
      ...this.polylines.flatMap((l) => [l.from, l.to]),
    ];
    const center: L.LatLngExpression = allCoords.length ? allCoords[0] : [55.75, 37.62];
    const map = L.map('cim-preview-map', {
      center,
      zoom: 12,
      zoomControl: true
    });
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(map);

    const bounds: L.LatLngBoundsLiteral = allCoords.length
      ? [[Math.min(...allCoords.map(p => p[0])), Math.min(...allCoords.map(p => p[1]))],
         [Math.max(...allCoords.map(p => p[0])), Math.max(...allCoords.map(p => p[1]))]]
      : [center as [number, number], center as [number, number]];
    map.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });

    const icon = L.icon({
      iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
      iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
      shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
      iconSize: [25, 41],
      iconAnchor: [12, 41]
    });

    this.polylines.forEach((line) => {
      const poly = L.polyline([line.from, line.to], {
        color: '#1976d2',
        weight: 3,
        opacity: 0.75,
      }).addTo(map);
      if (line.label) {
        poly.bindTooltip(line.label, { permanent: false });
      }
    });

    this.points.forEach(p => {
      const marker = L.marker([p.lat, p.lng], { icon }).addTo(map);
      if (p.label) {
        marker.bindTooltip(p.label, { permanent: false });
      }
    });

    this.map = map;
    setTimeout(() => map.invalidateSize(), 200);
  }

  close(): void {
    this.dialogRef.close();
  }
}
