#!/usr/bin/env python3
"""
gen_terrarium.py — Generate PNG images encoded in the Terrarium RGB elevation format.

Terrarium encoding:  elevation (m) = R*256 + G + B/256 - 32768
Valid range        : -32768 m  to  +32512 m  (sea floor to beyond Everest)

Usage examples:
    python gen_terrarium.py concentric
    python gen_terrarium.py concentric --size 512 --center 2000 --edge -500 -o data/test.png
    python gen_terrarium.py from_gray input.png --min_elev -500 --max_elev 3000 -o out.png
"""

import argparse
import math
import sys
import numpy as np
from PIL import Image


# ---------------------------------------------------------------------------
# Core encode / decode
# ---------------------------------------------------------------------------

def encode_terrarium(elevation: np.ndarray) -> Image.Image:
    """
    Encode a float32/float64 elevation array (metres, shape HxW) as a
    Terrarium RGB PNG image.
    """
    raw = elevation.astype(np.float64) + 32768.0
    raw = np.clip(raw, 0.0, 65535.0 + 255.0 / 256.0)

    R = (raw / 256.0).astype(np.int32).astype(np.uint8)
    G = (raw.astype(np.int32) % 256).astype(np.uint8)
    B = ((raw - raw.astype(np.int32)) * 256.0).astype(np.uint8)

    return Image.fromarray(np.stack([R, G, B], axis=2), mode='RGB')


def decode_terrarium(img: Image.Image) -> np.ndarray:
    """
    Decode a Terrarium RGB image to a float64 elevation array (metres).
    """
    arr = np.array(img.convert('RGB'), dtype=np.float64)
    return arr[:, :, 0] * 256.0 + arr[:, :, 1] + arr[:, :, 2] / 256.0 - 32768.0


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------

def gen_concentric(size: int = 256,
                   elev_center: float = 1000.0,
                   elev_edge: float = -1000.0) -> np.ndarray:
    """
    Radial (concentric) gradient.
    elev_center at the exact center, elev_edge at the farthest corner.
    """
    cx = cy = (size - 1) / 2.0
    max_dist = math.sqrt(cx * cx + cy * cy)

    ys, xs = np.mgrid[0:size, 0:size]
    t = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max_dist   # 0=centre, 1=coin
    t = np.clip(t, 0.0, 1.0)

    return elev_center + (elev_edge - elev_center) * t


def gen_from_gray(src_path: str,
                  min_elev: float = -1000.0,
                  max_elev: float = 1000.0) -> np.ndarray:
    """
    Convert a grayscale image (0=black → min_elev, 255=white → max_elev)
    to an elevation array.
    """
    img  = Image.open(src_path).convert('L')
    gray = np.array(img, dtype=np.float64) / 255.0
    return min_elev + (max_elev - min_elev) * gray


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate Terrarium-encoded PNG elevation images",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)

    sub = parser.add_subparsers(dest="cmd", required=True)

    # --- concentric ---
    p = sub.add_parser("concentric", help="Radial gradient test image")
    p.add_argument("--size",    type=int,   default=256,    help="Image size in pixels (square)")
    p.add_argument("--center",  type=float, default=1000.0, help="Elevation at center (m)")
    p.add_argument("--edge",    type=float, default=-1000.0,help="Elevation at corners (m)")
    p.add_argument("-o", "--output", default="terrarium_concentric.png")

    # --- from_gray ---
    p = sub.add_parser("from_gray", help="Convert a grayscale heightmap to Terrarium")
    p.add_argument("input",                                  help="Source grayscale PNG")
    p.add_argument("--min_elev", type=float, default=-1000.0)
    p.add_argument("--max_elev", type=float, default=1000.0)
    p.add_argument("-o", "--output", default="terrarium_from_gray.png")

    args = parser.parse_args()

    if args.cmd == "concentric":
        elev = gen_concentric(args.size, args.center, args.edge)
        out  = args.output
    elif args.cmd == "from_gray":
        elev = gen_from_gray(args.input, args.min_elev, args.max_elev)
        out  = args.output

    img = encode_terrarium(elev)
    img.save(out)
    print(f"Saved  : {out}  ({img.width}x{img.height} px)")
    print(f"Range  : {elev.min():.1f} m  to  {elev.max():.1f} m")

    # Verify round-trip
    decoded = decode_terrarium(img)
    err = np.abs(decoded - elev).max()
    print(f"Max encoding error : {err:.4f} m")


if __name__ == "__main__":
    main()
