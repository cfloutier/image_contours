// MarchingSquares — pure contour extraction algorithm.
//
// Builds a PolylineGroup from an ElevationGrid by tracing contour lines
// at evenly-spaced levels using the Marching Squares algorithm.
//
// Usage:
//   MarchingSquares ms = new MarchingSquares();
//   PolylineGroup result = ms.build(grid, nLevels);
//
// Coordinates in the returned group are in pixel-space (0..grid.width, 0..grid.height).
//
// ------------------------------------------------------------------
// Corner bit encoding:
//   TL=8  TR=4
//   BL=1  BR=2
//
// Edges (0-3):
//   0 = top    (TL → TR)
//   1 = right  (TR → BR)
//   2 = bottom (BL → BR)
//   3 = left   (TL → BL)
// ------------------------------------------------------------------

class MarchingSquares
{
  // Builds contour lines at nLevels evenly distributed elevation levels.
  PolylineGroup build(ElevationGrid grid, int nLevels)
  {
    PolylineGroup result = new PolylineGroup();
    if (grid.width < 2 || grid.height < 2) return result;

    float n     = max(1, nLevels);
    float step  = (grid.vmax - grid.vmin) / (n + 1);
    float start = grid.vmin + step;

    for (float level = start; level < grid.vmax; level += step)
      chainSegments(result, marchLevel(grid, level));

    return result;
  }

  // Builds contour lines at the provided pre-computed elevation levels.
  PolylineGroup build(ElevationGrid grid, float[] levels)
  {
    PolylineGroup result = new PolylineGroup();
    if (grid.width < 2 || grid.height < 2) return result;

    for (float level : levels)
      chainSegments(result, marchLevel(grid, level));

    return result;
  }

  // ------------------------------------------------------------------
  // Marching Squares — one level
  // ------------------------------------------------------------------

  private ArrayList<float[]> marchLevel(ElevationGrid g, float level)
  {
    ArrayList<float[]> raw = new ArrayList<float[]>();
    int w = g.width, h = g.height;

    for (int cy = 0; cy < h - 1; cy++)
      for (int cx = 0; cx < w - 1; cx++)
      {
        float tl = g.values[ cx      +  cy      * w];
        float tr = g.values[(cx + 1) +  cy      * w];
        float br = g.values[(cx + 1) + (cy + 1) * w];
        float bl = g.values[ cx      + (cy + 1) * w];

        int idx = ((tl > level) ? 8 : 0)
                | ((tr > level) ? 4 : 0)
                | ((br > level) ? 2 : 0)
                | ((bl > level) ? 1 : 0);

        switch (idx)
        {
          case  0: case 15: break;  // all inside or all outside

          case  1: raw.add(seg(cx, cy, 2, 3, tl, tr, br, bl, level)); break; // BL
          case  2: raw.add(seg(cx, cy, 1, 2, tl, tr, br, bl, level)); break; // BR
          case  3: raw.add(seg(cx, cy, 1, 3, tl, tr, br, bl, level)); break; // BL+BR
          case  4: raw.add(seg(cx, cy, 0, 1, tl, tr, br, bl, level)); break; // TR

          case  5: // saddle TR+BL: two segments
            raw.add(seg(cx, cy, 0, 1, tl, tr, br, bl, level));
            raw.add(seg(cx, cy, 2, 3, tl, tr, br, bl, level));
            break;

          case  6: raw.add(seg(cx, cy, 0, 2, tl, tr, br, bl, level)); break; // TR+BR
          case  7: raw.add(seg(cx, cy, 0, 3, tl, tr, br, bl, level)); break; // TR+BR+BL
          case  8: raw.add(seg(cx, cy, 0, 3, tl, tr, br, bl, level)); break; // TL
          case  9: raw.add(seg(cx, cy, 0, 2, tl, tr, br, bl, level)); break; // TL+BL

          case 10: // saddle TL+BR: two segments
            raw.add(seg(cx, cy, 0, 3, tl, tr, br, bl, level));
            raw.add(seg(cx, cy, 1, 2, tl, tr, br, bl, level));
            break;

          case 11: raw.add(seg(cx, cy, 0, 1, tl, tr, br, bl, level)); break; // TL+BL+BR
          case 12: raw.add(seg(cx, cy, 1, 3, tl, tr, br, bl, level)); break; // TL+TR
          case 13: raw.add(seg(cx, cy, 1, 2, tl, tr, br, bl, level)); break; // TL+TR+BL
          case 14: raw.add(seg(cx, cy, 2, 3, tl, tr, br, bl, level)); break; // TL+TR+BR
        }
      }

    return raw;
  }

  // Returns [x1, y1, x2, y2] for the segment crossing edges e1 and e2 of cell (cx, cy).
  private float[] seg(int cx, int cy, int e1, int e2,
                      float tl, float tr, float br, float bl, float level)
  {
    float[] p1 = edgePt(e1, cx, cy, tl, tr, br, bl, level);
    float[] p2 = edgePt(e2, cx, cy, tl, tr, br, bl, level);
    return new float[] { p1[0], p1[1], p2[0], p2[1] };
  }

  // Interpolated crossing position on the given edge of cell (cx, cy).
  private float[] edgePt(int edge, int cx, int cy,
                          float tl, float tr, float br, float bl, float level)
  {
    float t;
    switch (edge)
    {
      case 0: t = safeT(tl, tr, level); return new float[] { cx + t, cy     }; // top
      case 1: t = safeT(tr, br, level); return new float[] { cx + 1, cy + t }; // right
      case 2: t = safeT(bl, br, level); return new float[] { cx + t, cy + 1 }; // bottom
      case 3: t = safeT(tl, bl, level); return new float[] { cx,     cy + t }; // left
    }
    return new float[] { cx, cy };
  }

  // Linear interpolation factor; returns 0.5 when the denominator is near zero.
  private float safeT(float a, float b, float level)
  {
    float d = b - a;
    if (abs(d) < 1e-10) return 0.5;
    return constrain((level - a) / d, 0, 1);
  }

  // ------------------------------------------------------------------
  // Segment chaining
  //
  // Shared edges between adjacent cells produce identical endpoint
  // coordinates by construction, so we chain segments via quantized
  // Long keys (0.001 px precision).
  // ------------------------------------------------------------------

  private void chainSegments(PolylineGroup result, ArrayList<float[]> rawSegs)
  {
    if (rawSegs.isEmpty()) return;

    HashMap<Long, ArrayList<int[]>> map = new HashMap<Long, ArrayList<int[]>>();
    for (int i = 0; i < rawSegs.size(); i++)
    {
      float[] s = rawSegs.get(i);
      mapPut(map, encode(s[0], s[1]), i, 0);
      mapPut(map, encode(s[2], s[3]), i, 1);
    }

    boolean[] used = new boolean[rawSegs.size()];

    for (int i = 0; i < rawSegs.size(); i++)
    {
      if (used[i]) continue;
      used[i] = true;

      float[] s = rawSegs.get(i);

      // Grow forward from endpoint B = (s[2], s[3])
      ArrayList<PVector> fwd = new ArrayList<PVector>();
      fwd.add(new PVector(s[2], s[3]));
      extendChain(fwd, map, rawSegs, used);

      // Grow backward from endpoint A = (s[0], s[1])
      ArrayList<PVector> bwd = new ArrayList<PVector>();
      bwd.add(new PVector(s[0], s[1]));
      extendChain(bwd, map, rawSegs, used);

      // Final polyline = reverse(bwd) + fwd → [..., A_prev, A, B, B_next, ...]
      Polyline line = new Polyline();
      for (int j = bwd.size() - 1; j >= 0; j--)
        line.addPoint(bwd.get(j));
      for (PVector p : fwd)
        line.addPoint(p);

      if (line.size() >= 2)
        result.add(line);
    }
  }

  private void extendChain(ArrayList<PVector> chain,
                            HashMap<Long, ArrayList<int[]>> map,
                            ArrayList<float[]> segs, boolean[] used)
  {
    while (true)
    {
      PVector tip = chain.get(chain.size() - 1);
      ArrayList<int[]> neighbors = map.get(encode(tip.x, tip.y));
      if (neighbors == null) break;

      boolean found = false;
      for (int[] nb : neighbors)
      {
        if (used[nb[0]]) continue;
        used[nb[0]] = true;
        float[] s = segs.get(nb[0]);
        // nb[1] is the end that matches tip → add the OTHER end
        chain.add(nb[1] == 0 ? new PVector(s[2], s[3]) : new PVector(s[0], s[1]));
        found = true;
        break;
      }
      if (!found) break;
    }
  }

  private void mapPut(HashMap<Long, ArrayList<int[]>> map, Long key, int seg, int end)
  {
    if (!map.containsKey(key)) map.put(key, new ArrayList<int[]>());
    map.get(key).add(new int[] { seg, end });
  }

  // Pack two float coordinates into a Long key (quantized to 0.001 px).
  private Long encode(float x, float y)
  {
    int ix = (int)(x * 1000 + 0.5);
    int iy = (int)(y * 1000 + 0.5);
    return ((long)ix << 32) | ((long)iy & 0xFFFFFFFFL);
  }
}
