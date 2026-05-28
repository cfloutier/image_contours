// ContourGenerator — wires data.image and data.contour to MarchingSquares.
//
// Prepares an ElevationGrid from the appropriate source (Classic or Terrarium),
// delegates contour extraction to MarchingSquares, and handles centered drawing.

class ContourGenerator
{
  PolylineGroup group          = new PolylineGroup();
  PolylineGroup filtered_group = new PolylineGroup();
  // Active group used for draw and export — updated by image_contours after each rebuild.
  // Reflects threshold filter + optional shore clip.
  PolylineGroup display_group  = null;

  // Elevation values for each level index (group_id → elevation).
  // Allows filtering polylines above/below a given threshold.
  float[] levels = new float[0];

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
    {
      levels = quantileLevels(grid, (int)data.contour.contour_levels);
      group  = ms.build(grid, levels);
    }
    else
    {
      int   n    = (int)data.contour.contour_levels;
      float step = (grid.vmax - grid.vmin) / (max(1, n) + 1);
      levels = new float[n];
      for (int i = 0; i < n; i++) levels[i] = grid.vmin + step * (i + 1);
      group  = ms.build(grid, (int)data.contour.contour_levels);
    }

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
  // Uses display_group if set (shore clip applied), falls back to filtered/raw.
  void drawFiltered()
  {
    PolylineGroup to_draw = (display_group != null) ? display_group
                          : (data.threshold.enabled ? filtered_group : group);
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

  // Returns a new PolylineGroup containing only polylines whose elevation level
  // is >= minLevel.  Uses group_id as index into the stored levels[] array.
  PolylineGroup groupAboveLevel(float minLevel)
  {
    PolylineGroup result = new PolylineGroup();
    for (Polyline pl : group.polylines)
    {
      if (pl.group_id >= 0 && pl.group_id < levels.length)
      {
        if (levels[pl.group_id] >= minLevel) result.add(pl);
      }
      else
      {
        result.add(pl);   // unknown level → keep
      }
    }
    return result;
  }

  // Same but applied to filtered_group (when threshold filter is active).
  PolylineGroup filteredGroupAboveLevel(float minLevel)
  {
    PolylineGroup result = new PolylineGroup();
    for (Polyline pl : filtered_group.polylines)
    {
      if (pl.group_id >= 0 && pl.group_id < levels.length)
      {
        if (levels[pl.group_id] >= minLevel) result.add(pl);
      }
      else
      {
        result.add(pl);
      }
    }
    return result;
  }

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

