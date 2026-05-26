// Contour line generator using Marching Squares algorithm.
//
// Modes:
//   Classic   — reads brightness (red channel, 0-255) from data.image.transformed_image
//   Terrarium — reads raw RGB from data.image.image and decodes elevation:
//               elevation (m) = R*256 + G + B/256 - 32768
//
// Produces a PolylineGroup with segments chained into continuous polylines.

class ContourGenerator
{
  PolylineGroup group = new PolylineGroup();

  float elev_min = 0;
  float elev_max = 0;

  private float[] elevation;
  private int     img_w;
  private int     img_h;
  private float   img_cx;   // half-width  (centering offset)
  private float   img_cy;   // half-height (centering offset)

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  void build()
  {
    group.clear();

    // ------------------------------------------------------------------
    // 1. Decode elevation to a float array from the appropriate source.
    //
    //    Classic   → transformed_image (already resized + blurred + levels)
    //    Terrarium → raw source image decoded FIRST to floats, THEN resized.
    //                Resizing encoded RGB values is wrong: at each R-channel
    //                boundary (every 256m), bilinear interpolation mixes
    //                e.g. (R=124,G=255) with (R=125,G=0), producing a false
    //                ~255m elevation dip that creates spurious contour lines.
    // ------------------------------------------------------------------

    float[] raw_elev;
    int     raw_w, raw_h;

    if (data.contour.terrarium_mode)
    {
      PImage src = data.image.image;
      if (src == null) { println("ContourGenerator: no source image"); return; }

      src.loadPixels();
      raw_w = src.width;
      raw_h = src.height;
      raw_elev = new float[raw_w * raw_h];

      for (int i = 0; i < raw_elev.length; i++)
      {
        color c = src.pixels[i];
        raw_elev[i] = red(c) * 256.0 + green(c) + blue(c) / 256.0 - 32768.0;
      }

      // Resize the float array to display dimensions (bilinear on floats = correct).
      if (data.image.transformed_image != null)
      {
        int dw = data.image.transformed_image.width;
        int dh = data.image.transformed_image.height;
        if (dw != raw_w || dh != raw_h)
          raw_elev = resizeElevation(raw_elev, raw_w, raw_h, dw, dh);
        img_w = dw;
        img_h = dh;
      }
      else
      {
        img_w = raw_w;
        img_h = raw_h;
      }

      // Apply blur on floats (equivalent to data.image.Blur for classic mode).
      int blur_r = (int) data.image.Blur;
      if (blur_r > 0)
        raw_elev = blurElevation(raw_elev, img_w, img_h, blur_r);
    }
    else
    {
      PImage src = data.image.transformed_image;
      if (src == null) { println("ContourGenerator: no source image"); return; }

      src.loadPixels();
      img_w = src.width;
      img_h = src.height;
      raw_elev = new float[img_w * img_h];

      for (int i = 0; i < raw_elev.length; i++)
        raw_elev[i] = brightness(src.pixels[i]);   // 0–255
    }

    if (img_w < 2 || img_h < 2) return;

    img_cx = img_w / 2.0;
    img_cy = img_h / 2.0;

    // ------------------------------------------------------------------
    // 2. Compute elevation range and build contour levels.
    // ------------------------------------------------------------------

    elevation = raw_elev;
    elev_min  =  Float.MAX_VALUE;
    elev_max  = -Float.MAX_VALUE;

    for (int i = 0; i < elevation.length; i++)
    {
      if (elevation[i] < elev_min) elev_min = elevation[i];
      if (elevation[i] > elev_max) elev_max = elevation[i];
    }

    // contour_levels = nombre de niveaux → step réel = plage / (n+1)
    float n_levels    = max(1, data.contour.contour_levels);
    float step        = (elev_max - elev_min) / (n_levels + 1);
    float level_start = elev_min + step;
    int   level_count = 0;

    for (float level = level_start; level < elev_max; level += step)
    {
      marchingSquaresLevel(level);
      level_count++;
    }

    println("Contours: " + level_count + " niveaux, " + group.size() + " polylines"
          + "  elevation [" + nf(elev_min, 1, 1) + " ; " + nf(elev_max, 1, 1) + "]");
  }

  // Bilinear resize of a float elevation array.
  private float[] resizeElevation(float[] src, int sw, int sh, int dw, int dh)
  {
    float[] dst = new float[dw * dh];
    float   sx  = (float)(sw - 1) / max(1, dw - 1);
    float   sy  = (float)(sh - 1) / max(1, dh - 1);

    for (int y = 0; y < dh; y++)
    {
      for (int x = 0; x < dw; x++)
      {
        float fx = x * sx,  fy = y * sy;
        int   x0 = (int) fx, y0 = (int) fy;
        int   x1 = min(x0 + 1, sw - 1), y1 = min(y0 + 1, sh - 1);
        float tx = fx - x0,  ty = fy - y0;

        dst[x + y * dw] =
            src[x0 + y0 * sw] * (1-tx) * (1-ty)
          + src[x1 + y0 * sw] *    tx  * (1-ty)
          + src[x0 + y1 * sw] * (1-tx) *    ty
          + src[x1 + y1 * sw] *    tx  *    ty;
      }
    }
    return dst;
  }

  // Separable box blur on a float elevation array (radius in pixels).
  private float[] blurElevation(float[] src, int w, int h, int r)
  {
    if (r <= 0) return src;
    float[] tmp = new float[w * h];
    float[] dst = new float[w * h];

    // Horizontal pass
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
      {
        float sum = 0;
        for (int dx = -r; dx <= r; dx++)
          sum += src[constrain(x + dx, 0, w - 1) + y * w];
        tmp[x + y * w] = sum / (2 * r + 1);
      }

    // Vertical pass
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
      {
        float sum = 0;
        for (int dy = -r; dy <= r; dy++)
          sum += tmp[x + constrain(y + dy, 0, h - 1) * w];
        dst[x + y * w] = sum / (2 * r + 1);
      }

    return dst;
  }

  void draw()
  {
    // Contour coordinates are in pixel-space (0..img_w, 0..img_h).
    // The image is drawn centered on the origin, so we apply the same offset.
    current_graphics.pushMatrix();
    current_graphics.translate(-img_cx, -img_cy);
    group.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);
    current_graphics.popMatrix();
  }

  // ------------------------------------------------------------------
  // Marching Squares
  // ------------------------------------------------------------------
  //
  // Corner encoding (bit weights):
  //   TL=8  TR=4
  //   BL=1  BR=2
  //
  // Edges (0-3):
  //   0 = top    (TL → TR)
  //   1 = right  (TR → BR)
  //   2 = bottom (BL → BR)
  //   3 = left   (TL → BL)

  private void marchingSquaresLevel(float level)
  {
    ArrayList<float[]> rawSegs = new ArrayList<float[]>();

    for (int cy = 0; cy < img_h - 1; cy++)
    {
      for (int cx = 0; cx < img_w - 1; cx++)
      {
        float tl = elevation[ cx      +  cy      * img_w];
        float tr = elevation[(cx + 1) +  cy      * img_w];
        float br = elevation[(cx + 1) + (cy + 1) * img_w];
        float bl = elevation[ cx      + (cy + 1) * img_w];

        int idx = ((tl > level) ? 8 : 0)
                | ((tr > level) ? 4 : 0)
                | ((br > level) ? 2 : 0)
                | ((bl > level) ? 1 : 0);

        switch (idx)
        {
          // 0 and 15: all corners on same side → no crossing
          case  0: case 15: break;

          case  1: rawSegs.add(seg(cx, cy, 2, 3, tl, tr, br, bl, level)); break; // BL
          case  2: rawSegs.add(seg(cx, cy, 1, 2, tl, tr, br, bl, level)); break; // BR
          case  3: rawSegs.add(seg(cx, cy, 1, 3, tl, tr, br, bl, level)); break; // BL+BR
          case  4: rawSegs.add(seg(cx, cy, 0, 1, tl, tr, br, bl, level)); break; // TR

          case  5: // TR+BL saddle: two separate segments
            rawSegs.add(seg(cx, cy, 0, 1, tl, tr, br, bl, level));
            rawSegs.add(seg(cx, cy, 2, 3, tl, tr, br, bl, level));
            break;

          case  6: rawSegs.add(seg(cx, cy, 0, 2, tl, tr, br, bl, level)); break; // TR+BR
          case  7: rawSegs.add(seg(cx, cy, 0, 3, tl, tr, br, bl, level)); break; // TR+BR+BL
          case  8: rawSegs.add(seg(cx, cy, 0, 3, tl, tr, br, bl, level)); break; // TL
          case  9: rawSegs.add(seg(cx, cy, 0, 2, tl, tr, br, bl, level)); break; // TL+BL

          case 10: // TL+BR saddle: two separate segments
            rawSegs.add(seg(cx, cy, 0, 3, tl, tr, br, bl, level));
            rawSegs.add(seg(cx, cy, 1, 2, tl, tr, br, bl, level));
            break;

          case 11: rawSegs.add(seg(cx, cy, 0, 1, tl, tr, br, bl, level)); break; // TL+BL+BR
          case 12: rawSegs.add(seg(cx, cy, 1, 3, tl, tr, br, bl, level)); break; // TL+TR
          case 13: rawSegs.add(seg(cx, cy, 1, 2, tl, tr, br, bl, level)); break; // TL+TR+BL
          case 14: rawSegs.add(seg(cx, cy, 2, 3, tl, tr, br, bl, level)); break; // TL+TR+BR
        }
      }
    }

    chainSegments(rawSegs);
  }

  // Returns [x1, y1, x2, y2] segment between two cell edges.
  private float[] seg(int cx, int cy, int e1, int e2,
                      float tl, float tr, float br, float bl, float level)
  {
    float[] p1 = edgePt(e1, cx, cy, tl, tr, br, bl, level);
    float[] p2 = edgePt(e2, cx, cy, tl, tr, br, bl, level);
    return new float[] { p1[0], p1[1], p2[0], p2[1] };
  }

  // Interpolated crossing position on the given edge.
  private float[] edgePt(int edge, int cx, int cy,
                          float tl, float tr, float br, float bl, float level)
  {
    float t;
    switch (edge)
    {
      case 0: t = safeT(tl, tr, level); return new float[] { cx + t, cy       }; // top
      case 1: t = safeT(tr, br, level); return new float[] { cx + 1, cy + t   }; // right
      case 2: t = safeT(bl, br, level); return new float[] { cx + t, cy + 1   }; // bottom
      case 3: t = safeT(tl, bl, level); return new float[] { cx,     cy + t   }; // left
    }
    return new float[] { cx, cy };
  }

  // Linear interpolation parameter; returns 0.5 when denominator is near zero.
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
  // coordinates by construction, so we can chain segments using exact
  // quantized integer keys (0.001 px precision).
  // ------------------------------------------------------------------

  private void chainSegments(ArrayList<float[]> rawSegs)
  {
    if (rawSegs.isEmpty()) return;

    // Map endpoint → list of {segmentIndex, endIndex (0=start, 1=end)}
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

      // Grow forward from B = (s[2], s[3])
      ArrayList<PVector> fwd = new ArrayList<PVector>();
      fwd.add(new PVector(s[2], s[3]));
      extendChain(fwd, map, rawSegs, used);

      // Grow backward from A = (s[0], s[1])
      ArrayList<PVector> bwd = new ArrayList<PVector>();
      bwd.add(new PVector(s[0], s[1]));
      extendChain(bwd, map, rawSegs, used);

      // Final polyline = reverse(bwd) + fwd
      // = [..., A_prev, A, B, B_next, ...]
      Polyline line = new Polyline();
      for (int j = bwd.size() - 1; j >= 0; j--)
        line.addPoint(bwd.get(j));
      for (PVector p : fwd)
        line.addPoint(p);

      if (line.size() >= 2)
        group.add(line);
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
        // nb[1] is the end that connects to tip → add the OTHER end
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

  // Pack two coordinates into a Long key (quantized to 0.001 px).
  private Long encode(float x, float y)
  {
    int ix = (int)(x * 1000 + 0.5);
    int iy = (int)(y * 1000 + 0.5);
    return ((long)ix << 32) | ((long)iy & 0xFFFFFFFFL);
  }
}
