#!/usr/bin/env python3
"""Скачивает растровые тайлы OSM DE для Беларуси и собирает MBTiles (офлайн-подложка в APK).

Пример:
  python scripts/build_belarus_basemap_mbtiles.py --max-zoom 11
  python scripts/build_belarus_basemap_mbtiles.py --max-zoom 10 --output frontend/assets/maps/belarus_basemap.mbtiles
"""
from __future__ import annotations

import argparse
import math
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Границы РБ — как в frontend/lib/core/config/app_config.dart
SOUTH, WEST, NORTH, EAST = 51.26, 23.18, 56.17, 32.78
TILE_URL = "https://tile.openstreetmap.de/{z}/{x}/{y}.png"
USER_AGENT = "LEPM-Mobile/1.1 basemap-builder (diplom project; contact admin)"


def lon_to_tile_x(lon: float, zoom: int) -> int:
    return int(math.floor((lon + 180.0) / 360.0 * (1 << zoom)))


def lat_to_tile_y(lat: float, zoom: int) -> int:
    lat_rad = math.radians(lat)
    n = 1 << zoom
    return int(
        math.floor((1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n)
    )


def tile_range(zoom: int) -> list[tuple[int, int, int]]:
    x_min = lon_to_tile_x(WEST, zoom)
    x_max = lon_to_tile_x(EAST, zoom)
    y_min = lat_to_tile_y(NORTH, zoom)
    y_max = lat_to_tile_y(SOUTH, zoom)
    out: list[tuple[int, int, int]] = []
    for x in range(x_min, x_max + 1):
        for y in range(y_min, y_max + 1):
            out.append((zoom, x, y))
    return out


def create_mbtiles(path: Path, min_zoom: int, max_zoom: int) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE tiles (
          zoom_level INTEGER,
          tile_column INTEGER,
          tile_row INTEGER,
          tile_data BLOB
        );
        CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);
        CREATE TABLE metadata (name text, value text);
        """
    )
    conn.execute(
        "INSERT INTO metadata VALUES (?, ?)",
        ("name", "Belarus OSM DE basemap"),
    )
    conn.execute(
        "INSERT INTO metadata VALUES (?, ?)",
        ("type", "baselayer"),
    )
    conn.execute(
        "INSERT INTO metadata VALUES (?, ?)",
        ("format", "png"),
    )
    conn.execute(
        "INSERT INTO metadata VALUES (?, ?)",
        ("minzoom", str(min_zoom)),
    )
    conn.execute(
        "INSERT INTO metadata VALUES (?, ?)",
        ("maxzoom", str(max_zoom)),
    )
    conn.execute(
        "INSERT INTO metadata VALUES (?, ?)",
        ("bounds", f"{WEST},{SOUTH},{EAST},{NORTH}"),
    )
    conn.commit()
    return conn


def fetch_tile(z: int, x: int, y: int, retries: int = 3) -> bytes | None:
    url = TILE_URL.format(z=z, x=x, y=y)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(1.5 * (attempt + 1))
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-zoom", type=int, default=4)
    parser.add_argument("--max-zoom", type=int, default=11)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("frontend/assets/maps/belarus_basemap.mbtiles"),
    )
    parser.add_argument("--delay", type=float, default=0.05, help="Пауза между запросами, сек")
    args = parser.parse_args()

    tiles: list[tuple[int, int, int]] = []
    for z in range(args.min_zoom, args.max_zoom + 1):
        tiles.extend(tile_range(z))
    print(f"Tiles to fetch: {len(tiles)} (z{args.min_zoom}–z{args.max_zoom})")

    conn = create_mbtiles(args.output, args.min_zoom, args.max_zoom)
    ok = 0
    for i, (z, x, y) in enumerate(tiles, start=1):
        # MBTiles TMS: tile_row flipped
        tms_y = (1 << z) - 1 - y
        data = fetch_tile(z, x, y)
        if data:
            conn.execute(
                "INSERT OR REPLACE INTO tiles VALUES (?, ?, ?, ?)",
                (z, x, tms_y, sqlite3.Binary(data)),
            )
            ok += 1
        if i % 25 == 0:
            conn.commit()
            print(f"  {i}/{len(tiles)} downloaded ({ok} ok)")
        time.sleep(args.delay)

    conn.commit()
    conn.close()
    size_mb = args.output.stat().st_size / (1024 * 1024)
    print(f"Done: {args.output} ({size_mb:.1f} MB, {ok}/{len(tiles)} tiles)")
    return 0 if ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
