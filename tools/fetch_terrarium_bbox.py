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
    python tools/fetch_terrarium_bbox.py --geojson "{\"type\":\"FeatureCollection\",...}"
    python tools/fetch_terrarium_bbox.py --geojson-file my_box.geojson
"""

from __future__ import annotations

import argparse
import io
import json
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
MAX_ZOOM = 15
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


def terrarium_rgb_to_elevation(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return r * 256.0 + g + b / 256.0 - 32768.0


def elevation_to_terrarium_rgb(elev_m: float) -> tuple[int, int, int]:
    value = elev_m + 32768.0
    r = int(math.floor(value / 256.0))
    rem = value - r * 256.0
    g = int(math.floor(rem))
    b = int(round((rem - g) * 256.0))

    if b >= 256:
        b = 0
        g += 1
    if g >= 256:
        g = 0
        r += 1

    r = max(0, min(255, r))
    g = max(0, min(255, g))
    b = max(0, min(255, b))
    return r, g, b


def smooth_mosaic_tile_seams(mosaic: Image.Image, tiles_x: int, tiles_y: int) -> None:
    """Reduce visible contour seams caused by slight border mismatches between source tiles."""
    pixels = mosaic.load()
    width, height = mosaic.size

    for seam_ix in range(1, tiles_x):
        sx = seam_ix * TILE_SIZE
        for y in range(height):
            left_e = terrarium_rgb_to_elevation(pixels[sx - 1, y])
            right_e = terrarium_rgb_to_elevation(pixels[sx, y])
            avg_rgb = elevation_to_terrarium_rgb((left_e + right_e) * 0.5)
            pixels[sx - 1, y] = avg_rgb
            pixels[sx, y] = avg_rgb

    for seam_iy in range(1, tiles_y):
        sy = seam_iy * TILE_SIZE
        for x in range(width):
            top_e = terrarium_rgb_to_elevation(pixels[x, sy - 1])
            bottom_e = terrarium_rgb_to_elevation(pixels[x, sy])
            avg_rgb = elevation_to_terrarium_rgb((top_e + bottom_e) * 0.5)
            pixels[x, sy - 1] = avg_rgb
            pixels[x, sy] = avg_rgb


def bbox_from_lonlat_pairs(points: list[tuple[float, float]]) -> BBox:
    if not points:
        raise ValueError("Aucune coordonnee exploitable trouvee.")

    lons = [lon for lon, _lat in points]
    lats = [lat for _lon, lat in points]

    if any(abs(lat) > 90 for lat in lats) or any(abs(lon) > 180 for lon in lons):
        raise ValueError(
            "Valeurs hors bornes. Attendu: lat dans [-90,90], lon dans [-180,180]."
        )

    return BBox(
        north=max(lats),
        south=min(lats),
        west=min(lons),
        east=max(lons),
    )


def extract_lonlat_pairs(value: object) -> list[tuple[float, float]]:
    pairs: list[tuple[float, float]] = []

    if isinstance(value, dict):
        if isinstance(value.get("bbox"), list) and len(value["bbox"]) >= 4:
            bbox = value["bbox"]
            return [(float(bbox[0]), float(bbox[1])), (float(bbox[2]), float(bbox[3]))]

        value_type = value.get("type")
        if value_type == "FeatureCollection":
            for feature in value.get("features", []):
                pairs.extend(extract_lonlat_pairs(feature))
            return pairs

        if value_type == "Feature":
            return extract_lonlat_pairs(value.get("geometry"))

        if "coordinates" in value:
            return extract_lonlat_pairs(value["coordinates"])

        return pairs

    if isinstance(value, list):
        if len(value) >= 2 and all(isinstance(v, (int, float)) for v in value[:2]):
            lon = float(value[0])
            lat = float(value[1])
            pairs.append((lon, lat))
            return pairs

        for item in value:
            pairs.extend(extract_lonlat_pairs(item))

    return pairs


def parse_geojson_text(text: str) -> BBox | None:
    stripped = text.strip()
    if not stripped:
        return None

    if not stripped.startswith("{") and not stripped.startswith("["):
        return None

    try:
        payload = json.loads(stripped)
    except json.JSONDecodeError:
        return None

    points = extract_lonlat_pairs(payload)
    if not points:
        raise ValueError(
            "GeoJSON reconnu, mais aucune coordonnee exploitable n'a ete trouvee."
        )

    return bbox_from_lonlat_pairs(points)


def parse_coords_text(text: str) -> BBox:
    """
    Parse user text in one of these forms:
    - BBoxfinder style: lon,lat,lon,lat
    - raw GeoJSON/geojson.io selection (Polygon/Feature/FeatureCollection/bbox)
    """
    geojson_bbox = parse_geojson_text(text)
    if geojson_bbox is not None:
        return geojson_bbox

    nums = [float(v) for v in re.findall(r"[-+]?\d+(?:\.\d+)?", text)]
    if len(nums) < 4:
        raise ValueError(
            "Impossible de lire une bbox. Colle soit lon,lat,lon,lat, soit un GeoJSON depuis geojson.io."
        )

    lon1, lat1, lon2, lat2 = nums[0], nums[1], nums[2], nums[3]
    return bbox_from_lonlat_pairs([(lon1, lat1), (lon2, lat2)])


def load_text_argument(args: argparse.Namespace) -> str:
    provided = [
        args.coords is not None,
        args.geojson is not None,
        args.geojson_file is not None,
    ]
    if sum(provided) > 1:
        raise ValueError("Utilise un seul mode d'entree: --coords, --geojson ou --geojson-file.")

    if args.geojson_file is not None:
        path = Path(args.geojson_file)
        try:
            return path.read_text(encoding="utf-8")
        except OSError as e:
            raise ValueError(f"Impossible de lire le fichier GeoJSON: {path}") from e

    if args.geojson is not None:
        return args.geojson

    if args.coords is not None:
        return args.coords

    return prompt_coords()

def prompt_coords() -> str:
    print("Colle ici soit une bbox lon,lat,lon,lat, soit un GeoJSON geojson.io.")
    print("Tu peux coller sur une ou plusieurs lignes, puis valider par une ligne vide:")
    lines: list[str] = []
    while True:
        line = input("> ")
        if not line.strip():
            break
        lines.append(line)
    return " ".join(lines).strip()


def estimate_bbox_pixels(bbox: BBox, zoom: int) -> tuple[int, int]:
    """Approximate final crop size in pixels for a bbox at a given zoom."""
    x0, y0 = lonlat_to_pixel(bbox.west, bbox.north, zoom)
    x1, y1 = lonlat_to_pixel(bbox.east, bbox.south, zoom)

    w = max(1, int(math.ceil(x1 - x0)))
    h = max(1, int(math.ceil(y1 - y0)))
    return w, h


def pick_zoom_for_target_size(bbox: BBox, target_px: int, min_zoom: int = 0, max_zoom: int = MAX_ZOOM) -> tuple[int, int, int]:
    """
    Pick the zoom that best matches a target output size.
    Criterion: minimize |max(width, height) - target_px|.
    """
    best_zoom = min_zoom
    best_w, best_h = estimate_bbox_pixels(bbox, min_zoom)
    best_err = abs(max(best_w, best_h) - target_px)

    for z in range(min_zoom + 1, max_zoom + 1):
        w, h = estimate_bbox_pixels(bbox, z)
        err = abs(max(w, h) - target_px)

        # Tie-breaker: prefer lower zoom to avoid unnecessary download volume.
        if err < best_err or (err == best_err and z < best_zoom):
            best_zoom = z
            best_w, best_h = w, h
            best_err = err

    return best_zoom, best_w, best_h


def prompt_target_size() -> int:
    print("Choisis une taille cible (approx.) pour l'image finale:")
    print(f"  (limitee par la disponibilite reelle des tuiles Terrarium, zoom max {MAX_ZOOM})")
    print("  1) Petite  ~256 px")
    print("  2) Moyenne ~512 px")
    print("  3) Grande  ~1024 px")
    print("  4) Tres grande ~2048 px")
    print("  5) Ultra ~4096 px")
    print("  6) Personnalisee")

    while True:
        choice = input("Selection [2]: ").strip() or "2"
        if choice == "1":
            return 256
        if choice == "2":
            return 512
        if choice == "3":
            return 1024
        if choice == "4":
            return 2048
        if choice == "5":
            return 4096
        if choice == "6":
            while True:
                raw = input("Taille cible (px): ").strip()
                if not raw:
                    continue
                try:
                    px = int(raw)
                except ValueError:
                    print("Valeur invalide, entre un entier > 0.")
                    continue
                if px > 0:
                    return px
                print("Valeur invalide, entre un entier > 0.")
        else:
            print("Choix invalide. Entre 1, 2, 3, 4, 5 ou 6.")


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


def estimate_tile_range(bbox: BBox, zoom: int) -> tuple[int, int, int, int, int]:
    """Return tile bounds and total tile count for the bbox at zoom."""
    x0, y0 = lonlat_to_pixel(bbox.west, bbox.north, zoom)  # top-left
    x1, y1 = lonlat_to_pixel(bbox.east, bbox.south, zoom)  # bottom-right

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
    return tx0, ty0, tx1, ty1, total


def prompt_confirm_large_download(total_tiles: int, warn_tiles: int) -> bool:
    print("ATTENTION: volume important.")
    print(f"  {total_tiles} tuiles a telecharger (seuil warning: {warn_tiles}).")
    print("Continuer ? [o/N]")
    ans = input("> ").strip().lower()
    return ans in ("o", "oui", "y", "yes")


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

    if tiles_x > 1 or tiles_y > 1:
        print("[3/4] Lissage des jointures internes entre tuiles...", flush=True)
        smooth_mosaic_tile_seams(mosaic, tiles_x, tiles_y)

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
                        help="Text containing either lon,lat,lon,lat or a raw GeoJSON selection")
    parser.add_argument("--geojson", type=str, default=None,
                        help="Raw GeoJSON text (FeatureCollection, Feature, Polygon, bbox, etc.)")
    parser.add_argument("--geojson-file", type=str, default=None,
                        help="Path to a .geojson/.json file to read and use as the bbox source")
    parser.add_argument("--zoom", type=int, default=None,
                        help=f"Terrarium zoom level (0-{MAX_ZOOM}). If provided, overrides automatic zoom selection")
    parser.add_argument("--target-size", type=int, default=None,
                        help="Approximate target size in pixels (long side). Used only when --zoom is omitted")
    parser.add_argument("--warn-tiles", type=int, default=100,
                        help="Warn and ask confirmation when estimated tile count exceeds this threshold (default: 100)")
    parser.add_argument("--yes", action="store_true",
                        help="Auto-confirm large downloads (skip interactive warning prompt)")
    parser.add_argument("-o", "--output", type=str, default=None,
                        help="Output Terrarium PNG path. If omitted, asks interactively and appends _z<zoom>")

    args = parser.parse_args()

    try:
        text = load_text_argument(args)
        print("Analyse des coordonnees...", flush=True)
        bbox = parse_coords_text(text)
        print(
            "BBox: "
            f"north={bbox.north:.6f}, south={bbox.south:.6f}, west={bbox.west:.6f}, east={bbox.east:.6f}"
        )

        if args.zoom is not None:
            zoom = args.zoom
            if not (0 <= zoom <= MAX_ZOOM):
                print(f"Erreur: zoom doit etre entre 0 et {MAX_ZOOM} pour ce workflow.", file=sys.stderr)
                return 2
            est_w, est_h = estimate_bbox_pixels(bbox, zoom)
            print(f"Mode zoom force: {zoom} (taille estimee: {est_w}x{est_h})", flush=True)
        else:
            target_px = args.target_size if args.target_size is not None else prompt_target_size()
            if target_px <= 0:
                print("Erreur: target-size doit etre un entier > 0.", file=sys.stderr)
                return 2

            print(f"Taille cible: ~{target_px}px (cote le plus long)", flush=True)
            zoom, est_w, est_h = pick_zoom_for_target_size(bbox, target_px)
            print(f"Zoom auto choisi: {zoom} (taille estimee: {est_w}x{est_h})", flush=True)
            if zoom == MAX_ZOOM and max(est_w, est_h) < target_px:
                print(
                    f"Note: taille cible non atteinte: les tuiles Terrarium semblent s'arreter au zoom {MAX_ZOOM} "
                    f"(estimation max pour cette bbox: {est_w}x{est_h}).",
                    flush=True,
                )

        tx0, ty0, tx1, ty1, total_tiles = estimate_tile_range(bbox, zoom)
        print(f"Pre-check tuiles: {total_tiles} (x:{tx0}->{tx1}, y:{ty0}->{ty1})", flush=True)

        if args.warn_tiles >= 0 and total_tiles > args.warn_tiles:
            if args.yes:
                print("Warning accepte via --yes, continuation.", flush=True)
            else:
                if not prompt_confirm_large_download(total_tiles, args.warn_tiles):
                    print("Operation annulee par l'utilisateur.", flush=True)
                    return 0

        out = Path(args.output) if args.output else prompt_output_path(zoom)

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
