// ContourShadeFilter cuts contour lines by sampling the shade image.
//
// DataThreshold + ThresholdGUI are in xLib_ThresholdData.pde (shared with image_lines).
// group_id on each ContourPolyline (= level_index set by MarchingSquares) is used
// to cycle thresholds per contour level, the same way image_lines cycles per line group.

// ------------------------------------------------------------------
// Filter
// ------------------------------------------------------------------

class ContourShadeFilter
{
  PolylineGroup filtered_group = new PolylineGroup();

  private Polyline current_line     = null;
  private int      current_group_id = -1;

  // Filters source contour group using shade pixel brightness.
  // If shade_image is null the source group is kept as-is.
  void build(PolylineGroup source, PImage shade_image)
  {
    filtered_group.clear();
    current_line = null;

    if (shade_image == null || !data.threshold.enabled)
    {
      for (Polyline l : source.polylines)
        filtered_group.add(l);
      return;
    }

    shade_image.loadPixels();

    int   level_counter   = 0;
    int   direction_index = 1;
    current_group_id = -1;
    float threshold  = 0;

    for (int i_line = 0; i_line < source.size(); i_line++)
    {
      Polyline source_line = source.polylines.get(i_line);

      // group_id is set to level_index by MarchingSquares advance threshold on each new level.
      if (source_line.group_id != current_group_id)
      {
        current_group_id = source_line.group_id;

        int distributed_index = data.threshold.get_distributed_threshold_index(level_counter);
        threshold = data.threshold.get_threshold_by_index(distributed_index);

        if (data.threshold.distribution_mode == DataThreshold.DISTRIBUTION_MIRROR)
        {
          level_counter += direction_index;
          if (level_counter >= data.threshold.nb_values || level_counter < 0)
          {
            direction_index  = -direction_index;
            level_counter   += direction_index * 2;
          }
        }
        else
        {
          level_counter++;
          if (level_counter >= data.threshold.nb_values)
            level_counter = 0;
        }
      }

      for (int i_pt = 0; i_pt < source_line.size(); i_pt++)
      {
        PVector pt = source_line.get(i_pt);

        int   ix        = constrain(round(pt.x), 0, shade_image.width  - 1);
        int   iy        = constrain(round(pt.y), 0, shade_image.height - 1);
        float shade_val = red(shade_image.pixels[ix + iy * shade_image.width]);

        boolean keep = data.threshold.black
          ? (shade_val < threshold)
          : (shade_val > threshold);

        if (keep) addPoint(pt);
        else      closeLine();
      }

      closeLine();
    }
  }

  // ------------------------------------------------------------------
  // Internal helpers
  // ------------------------------------------------------------------

  private void addPoint(PVector p)
  {
    if (current_line == null)
    {
      current_line = new Polyline();
      current_line.group_id = current_group_id;   // preserve level for shore clipping
    }
    current_line.addPoint(p);
  }

  private void closeLine()
  {
    if (current_line != null)
    {
      if (current_line.size() >= 2)
        filtered_group.add(current_line);
      current_line = null;
    }
  }
}

