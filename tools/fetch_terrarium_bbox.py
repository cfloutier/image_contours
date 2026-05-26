#!/usr/bin/env python3
"""
fetch_terrarium_bbox.py — Build a Terrarium PNG from a lat/lon rectangle.

Workflow (clipboard-friendly):
1) Draw a rectangle on any web map and copy two corners (or a bbox).
2) Run this script.
3) Paste (Ctrl+V) the copied text when prompted.
4) The script downloads Terrarium tiles, crops the exact area, saves PNG.

Output is Terrarium-encoded RGB:
  elevation (m) = R*256 + G + B/256 - 32768

Examples:
  python tools/fetch_terrarium_bbox.py
  python tools/fetch_terrarium_bbox.py --zoom 12 -o data/alps_terrarium.png
  python tools/fetch_terrarium_bbox.py --coords "45.98,6.85 45.82,7.10"
"""

from __future__ import annotations

import argparse
import io
import math
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

TILE_SIZE = 256
MAX_LAT = 85.05112878
TERRARIUM_URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"


@dataclass
class BBox:
    north: float
    south: float
    west: float
    east: float


def clamp_lat(lat: float) -> float:
    return max(-MAX_LAT, min(MAX_LAT, lat))


def lonlat_to_pixel(lon: float, lat: float, zoom: int) -> tuple[float, float]:
    """Web Mercator lon/lat -> global pixel coordinates at zoom."""
    lat = clamp_lat(lat)
    scale = (2**zoom) * TILE_SIZE
    x = (lon + 180.0) / 360.0 * scale
    lat_rad = math.radians(lat)
    y = (1.0 - math.log(math.tan(lat_rad) + (1.0 / math.cos(lat_rad))) / math.pi) / 2.0 * scale
    return x, y


def parse_coords_text(text: str) -> BBox:
    """
    Parse user text in a single accepted format (BBoxfinder style):
    west, south, east, north

    We accept noisy input (labels, brackets, etc.) by extracting the first 4 floats
    in that exact order.
    """
    nums = [float(v) for v in re.findall(r"[-+]?\d+(?:\.\d+)?", text)]
    if len(nums) < 4:
        raise ValueError(
            "Impossible de lire 4 nombres. Colle une bbox BBoxfinder au format north,west,south,east."
        )

    west, south, east, north = nums[0], nums[1], nums[2], nums[3]

    if abs(north) > 90 or abs(south) > 90 or abs(west) > 180 or abs(east) > 180:
        raise ValueError(
            "Valeurs hors bornes. Attendu: south/north dans [-90,90], west/east dans [-180,180]."
        )

    # Normalize in case corners are swapped.
    north, south = max(north, south), min(north, south)
    west, east = min(west, east), max(west, east)

    return BBox(north=north, south=south, west=west, east=east)

def prompt_coords() -> str:
    print("Colle ici une bbox BBoxfinder: west,south,east,north (W,S,E,N).")
    print("Tu peux coller sur une ou plusieurs lignes, puis valider par une ligne vide:")
    lines: list[str] = []
    while True:
        line = input("> ")
        if not line.strip():
            break
        lines.append(line)
    return " ".join(lines).strip()


def prompt_zoom() -> int:
    print("Choisis la definition (niveau de detail):")
    print("  1) Basse   (zoom 8)  - grande zone (iles, regions entieres)")
    print("  2) Moyenne (zoom 10) - departement / massif")
    print("  3) Haute   (zoom 12) - ville / petite zone")
    print("  4) Personnalisee (0-15)")

    while True:
        choice = input("Selection [2]: ").strip() or "2"
        if choice == "1":
            return 8
        if choice == "2":
            return 10
        if choice == "3":
            return 12
        if choice == "4":
            while True:
                raw = input("Zoom (0-15): ").strip()
                if not raw:
                    continue
                try:
                    z = int(raw)
                except ValueError:
                    print("Valeur invalide, entre un entier de 0 a 15.")
                    continue
                if 0 <= z <= 15:
                    return z
                print("Valeur invalide, entre un entier de 0 a 15.")
        else:
            print("Choix invalide. Entre 1, 2, 3 ou 4.")


def prompt_output_path(zoom: int) -> Path:
    print("Nom du fichier de sortie (sans extension).")
    print("Le suffixe du niveau sera ajoute automatiquement: _z<zoom>.png")
    raw = input("Nom [terrarium_bbox]: ").strip() or "terrarium_bbox"

    # Keep only the file name part to avoid accidental path pastes.
    base = os.path.basename(raw)
    base = re.sub(r"\.png$", "", base, flags=re.IGNORECASE)
    base = re.sub(r"[^A-Za-z0-9._-]+", "_", base).strip("._-")
    if not base:
        base = "terrarium_bbox"

    return Path("data") / f"{base}_z{zoom}.png"


def download_tile(z: int, x: int, y: int, timeout: float = 20.0) -> Image.Image:
    url = TERRARIUM_URL.format(z=z, x=x, y=y)
    req = urllib.request.Request(url, headers={"User-Agent": "image-contours/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            blob = resp.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Tuile indisponible (HTTP {e.code}) pour z/x/y={z}/{x}/{y}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Erreur reseau pour z/x/y={z}/{x}/{y}: {e}") from e

    return Image.open(io.BytesIO(blob)).convert("RGB")


def build_terrarium_crop(bbox: BBox, zoom: int) -> Image.Image:
    if bbox.west >= bbox.east:
        raise ValueError("BBox invalide: west doit etre < east (antimeridien non gere).")
    if bbox.south >= bbox.north:
        raise ValueError("BBox invalide: south doit etre < north.")

    print("[1/4] Projection lat/lon -> pixels...", flush=True)

    # Pixel bbox in global mercator pixel space
    x0, y0 = lonlat_to_pixel(bbox.west, bbox.north, zoom)  # top-left
    x1, y1 = lonlat_to_pixel(bbox.east, bbox.south, zoom)  # bottom-right

    print("[1/4] Projection terminee.", flush=True)
    print("[2/4] Calcul des tuiles necessaires...", flush=True)

    tx0 = int(math.floor(x0 / TILE_SIZE))
    ty0 = int(math.floor(y0 / TILE_SIZE))
    tx1 = int(math.floor((x1 - 1e-9) / TILE_SIZE))
    ty1 = int(math.floor((y1 - 1e-9) / TILE_SIZE))

    tiles_x = tx1 - tx0 + 1
    tiles_y = ty1 - ty0 + 1
    if tiles_x <= 0 or tiles_y <= 0:
        raise ValueError("Selection vide apres projection.")

    max_tile = 2**zoom
    if tx0 < 0 or ty0 < 0 or tx1 >= max_tile or ty1 >= max_tile:
        raise ValueError("Selection hors bornes de zoom.")

    total = tiles_x * tiles_y
    print(
        "[2/4] "
        f"{total} tuiles a telecharger (x:{tx0}->{tx1}, y:{ty0}->{ty1}, zoom {zoom}).",
        flush=True,
    )

    print("[3/4] Download des tuiles...", flush=True)
    mosaic = Image.new("RGB", (tiles_x * TILE_SIZE, tiles_y * TILE_SIZE))

    done = 0
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            print(f"  - tuile {done + 1}/{total}: z/x/y={zoom}/{tx}/{ty}", flush=True)
            tile = download_tile(zoom, tx, ty)
            mosaic.paste(tile, ((tx - tx0) * TILE_SIZE, (ty - ty0) * TILE_SIZE))
            done += 1
            print(f"    telecharge ({int(done * 100 / total)}%)", flush=True)

    print("[3/4] Download termine.", flush=True)
    print("[4/4] Recadrage final...", flush=True)

    # Crop exact pixel bbox inside mosaic
    crop_left = int(math.floor(x0 - tx0 * TILE_SIZE))
    crop_top = int(math.floor(y0 - ty0 * TILE_SIZE))
    crop_right = int(math.ceil(x1 - tx0 * TILE_SIZE))
    crop_bottom = int(math.ceil(y1 - ty0 * TILE_SIZE))

    if crop_right <= crop_left or crop_bottom <= crop_top:
        raise ValueError("Crop invalide (largeur/hauteur <= 0).")

    cropped = mosaic.crop((crop_left, crop_top, crop_right, crop_bottom))
    print("[4/4] Recadrage termine.", flush=True)
    return cropped


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch and crop Terrarium elevation PNG from lat/lon rectangle")
    parser.add_argument("--coords", type=str, default=None,
                        help="Text containing a BBoxfinder bbox in west,south,east,north order")
    parser.add_argument("--zoom", type=int, default=None,
                        help="Terrarium zoom level (0-15). If omitted, an interactive definition menu is shown")
    parser.add_argument("-o", "--output", type=str, default=None,
                        help="Output Terrarium PNG path. If omitted, asks interactively and appends _z<zoom>")

    args = parser.parse_args()

    zoom = args.zoom if args.zoom is not None else prompt_zoom()

    if not (0 <= zoom <= 15):
        print("Erreur: zoom doit etre entre 0 et 15 pour ce workflow.", file=sys.stderr)
        return 2

    text = args.coords if args.coords else prompt_coords()
    out = Path(args.output) if args.output else prompt_output_path(zoom)

    try:
        print("Analyse des coordonnees...", flush=True)
        bbox = parse_coords_text(text)
        print(
            "BBox: "
            f"north={bbox.north:.6f}, south={bbox.south:.6f}, west={bbox.west:.6f}, east={bbox.east:.6f}"
        )

        print(f"Definition choisie: zoom {zoom}", flush=True)
        img = build_terrarium_crop(bbox, zoom)

        out.parent.mkdir(parents=True, exist_ok=True)
        print("Sauvegarde du PNG...", flush=True)
        img.save(out)

        print(f"Saved: {out}")
        print(f"Size : {img.width}x{img.height} px (zoom {zoom})")
        print("Format: Terrarium RGB")
        return 0
    except Exception as e:
        print(f"Erreur: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
