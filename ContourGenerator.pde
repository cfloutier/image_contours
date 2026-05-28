// ContourGenerator — wires data.image and data.contour to MarchingSquares.
//
// Prepares an ElevationGrid from the appropriate source (Classic or Terrarium),
// delegates contour extraction to MarchingSquares, and handles centered drawing.

class ContourGenerator
{
  PolylineGroup group          = new PolylineGroup();
  PolylineGroup filtered_group = new PolylineGroup();

  float elev_min = 0;
  float elev_max = 0;

  private float           img_cx;
  private float           img_cy;
  private MarchingSquares ms            = new MarchingSquares();
  private ContourShadeFilter shade_filter = new ContourShadeFilter();

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  void build()
  {
    group.clear();

    ElevationGrid grid;

    if (data.contour.terrarium_mode)
    {
      PImage raw = data.image.image;
      if (raw == null) { println("ContourGenerator: no source image"); return; }
      int tw = (data.image.transformed_image != null) ? data.image.transformed_image.width  : 0;
      int th = (data.image.transformed_image != null) ? data.image.transformed_image.height : 0;
      grid = new ElevationGrid(raw, tw, th, (int)data.image.Blur);
    }
    else
    {
      PImage src = data.image.transformed_image;
      if (src == null) { println("ContourGenerator: no source image"); return; }
      grid = new ElevationGrid(src);
    }

    elev_min = grid.vmin;
    elev_max = grid.vmax;
    img_cx   = grid.width  / 2.0;
    img_cy   = grid.height / 2.0;

    if (data.contour.quantile_mode)
      group = ms.build(grid, quantileLevels(grid, (int)data.contour.contour_levels));
    else
      group = ms.build(grid, (int)data.contour.contour_levels);

    println("Contours: " + group.size() + " polylines"
          + "  elevation [" + nf(elev_min, 1, 1) + " ; " + nf(elev_max, 1, 1) + "]");
  }

  void draw()
  {
    // Contour coordinates are in pixel-space (0..grid.width, 0..grid.height).
    // The image is drawn centered on the origin, so we apply the same offset.
    current_graphics.pushMatrix();
    current_graphics.translate(-img_cx, -img_cy);
    group.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);
    current_graphics.popMatrix();
  }

  // Applies the shade filter and stores the result in filtered_group.
  void buildFilter(PImage shade_image)
  {
    shade_filter.build(group, shade_image);
    filtered_group = shade_filter.filtered_group;
    println("ThresholdFilter: " + filtered_group.size() + " polylines after filter");
  }

  // Draws the shade-filtered contours (or the raw group when filter is disabled).
  void drawFiltered()
  {
    PolylineGroup to_draw = data.threshold.enabled ? filtered_group : group;
    current_graphics.pushMatrix();
    current_graphics.translate(-img_cx, -img_cy);
    to_draw.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);
    current_graphics.popMatrix();
  }

  // ------------------------------------------------------------------
  // Quantile level computation
  //
  // Sorts all elevation values and places nLevels thresholds at equal
  // quantile positions so that each band between consecutive levels
  // contains approximately the same number of pixels.
  // ------------------------------------------------------------------

  private float[] quantileLevels(ElevationGrid grid, int nLevels)
  {
    int n = max(1, nLevels);

    float[] sorted = new float[grid.values.length];
    System.arraycopy(grid.values, 0, sorted, 0, grid.values.length);
    java.util.Arrays.sort(sorted);

    float[] levels = new float[n];
    for (int i = 0; i < n; i++)
    {
      float q   = (float)(i + 1) / (n + 1);
      int   idx = constrain((int)(q * sorted.length), 0, sorted.length - 1);
      levels[i] = sorted[idx];
    }
    return levels;
  }
}

