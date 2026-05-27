// ContourShadeFilter — cuts contour lines by sampling the shade image.
//
// For each contour polyline the threshold cycles through a configurable list
// (same logic as ThresholdFilter / DataThreshold in image_lines).
// At every point the shade pixel brightness is compared to the current threshold;
// segments that fail the test are cut, producing a new filtered PolylineGroup.

// ------------------------------------------------------------------
// Data
// ------------------------------------------------------------------

class DataShadeFilter extends GenericData
{
  DataShadeFilter() {
    super("ShadeFilter");
  }

  boolean enabled   = false;  // apply the filter
  boolean black     = true;   // true = keep dark zones (shade < threshold)
  boolean mirror    = false;  // bounce threshold index instead of cycling

  int     nb_values  = 1;

  boolean use_power  = false;
  float   power      = 0;
  float   min_value  = 0;
  float   max_value  = 255;

  float threshold_1  = 128;
  float threshold_2  = 128;
  float threshold_3  = 128;
  float threshold_4  = 128;
  float threshold_5  = 128;
  float threshold_6  = 128;
  float threshold_7  = 128;
  float threshold_8  = 128;
  float threshold_9  = 128;
  float threshold_10 = 128;
  float threshold_11 = 128;
  float threshold_12 = 128;

  float lerp_threshold(float v0, float v1, float t) {
    return lerp(v0, v1, t);
  }

  float get_threshold_by_index(int index)
  {
    if (use_power)
    {
      float ratio = 0.5;
      if (nb_values > 1)
        ratio = (float)index / (nb_values - 1);

      float factor = (power >= 0) ? (1 + power) : (1.0 / (1 - power));
      float value  = pow(ratio, factor);
      return lerp(min_value, max_value, value);
    }

    switch (index)
    {
      case  0: return threshold_1;
      case  1: return threshold_2;
      case  2: return threshold_3;
      case  3: return threshold_4;
      case  4: return threshold_5;
      case  5: return threshold_6;
      case  6: return threshold_7;
      case  7: return threshold_8;
      case  8: return threshold_9;
      case  9: return threshold_10;
      case 10: return threshold_11;
      case 11: return threshold_12;
      default: return 0;
    }
  }
}

// ------------------------------------------------------------------
// GUI
// ------------------------------------------------------------------

class ShadeFilterGUI extends GUIPanel
{
  DataShadeFilter sf;

  ShadeFilterGUI(DataShadeFilter sf)
  {
    super("ShadeFilter", sf);
    this.sf = sf;
  }

  Toggle  enabled;
  Toggle  black;
  Toggle  mirror;
  Toggle  use_power;
  Slider  nb_values;

  Slider threshold_1;
  Slider threshold_2;
  Slider threshold_3;
  Slider threshold_4;
  Slider threshold_5;
  Slider threshold_6;
  Slider threshold_7;
  Slider threshold_8;
  Slider threshold_9;
  Slider threshold_10;
  Slider threshold_11;
  Slider threshold_12;

  Slider power;
  Slider min_value;
  Slider max_value;

  void setupControls()
  {
    super.Init();

    enabled   = addToggle("enabled",   "Activer le filtre");
    nextLine();
    black     = addToggle("black",     "Garder zones sombres");
    mirror    = addToggle("mirror",    "Mirror");
    nextLine();
    use_power = addToggle("use_power", "Courbe puissance");
    nb_values = addIntSlider("nb_values", "Nb seuils", 1, 12);
    nextLine();
    nextLine();

    float savedY = yPos;

    threshold_1  = addSlider("threshold_1",  "Seuil 1",  0, 255); nextLine();
    threshold_2  = addSlider("threshold_2",  "Seuil 2",  0, 255); nextLine();
    threshold_3  = addSlider("threshold_3",  "Seuil 3",  0, 255); nextLine();
    threshold_4  = addSlider("threshold_4",  "Seuil 4",  0, 255); nextLine();
    threshold_5  = addSlider("threshold_5",  "Seuil 5",  0, 255); nextLine();
    threshold_6  = addSlider("threshold_6",  "Seuil 6",  0, 255); nextLine();
    threshold_7  = addSlider("threshold_7",  "Seuil 7",  0, 255); nextLine();
    threshold_8  = addSlider("threshold_8",  "Seuil 8",  0, 255); nextLine();
    threshold_9  = addSlider("threshold_9",  "Seuil 9",  0, 255); nextLine();
    threshold_10 = addSlider("threshold_10", "Seuil 10", 0, 255); nextLine();
    threshold_11 = addSlider("threshold_11", "Seuil 11", 0, 255); nextLine();
    threshold_12 = addSlider("threshold_12", "Seuil 12", 0, 255); nextLine();

    yPos = savedY;

    power     = addSlider("power",     "Puissance",  -10, 10); nextLine();
    min_value = addSlider("min_value", "Min",          0, 255);
    max_value = addSlider("max_value", "Max",          0, 255); nextLine();
  }

  void setGUIValues()
  {
    enabled.setValue(sf.enabled);
    black.setValue(sf.black);
    mirror.setValue(sf.mirror);
    use_power.setValue(sf.use_power);
    nb_values.setValue(sf.nb_values);

    threshold_1.setValue(sf.threshold_1);
    threshold_2.setValue(sf.threshold_2);
    threshold_3.setValue(sf.threshold_3);
    threshold_4.setValue(sf.threshold_4);
    threshold_5.setValue(sf.threshold_5);
    threshold_6.setValue(sf.threshold_6);
    threshold_7.setValue(sf.threshold_7);
    threshold_8.setValue(sf.threshold_8);
    threshold_9.setValue(sf.threshold_9);
    threshold_10.setValue(sf.threshold_10);
    threshold_11.setValue(sf.threshold_11);
    threshold_12.setValue(sf.threshold_12);

    power.setValue(sf.power);
    min_value.setValue(sf.min_value);
    max_value.setValue(sf.max_value);
  }

  void update_ui()
  {
    if (sf.use_power)
    {
      threshold_1.hide();  threshold_2.hide();  threshold_3.hide();
      threshold_4.hide();  threshold_5.hide();  threshold_6.hide();
      threshold_7.hide();  threshold_8.hide();  threshold_9.hide();
      threshold_10.hide(); threshold_11.hide(); threshold_12.hide();

      power.show(); min_value.show(); max_value.show();

      // Sync displayed slider values from the power curve
      threshold_1.setValue(sf.get_threshold_by_index(0));
      threshold_2.setValue(sf.get_threshold_by_index(1));
      threshold_3.setValue(sf.get_threshold_by_index(2));
      threshold_4.setValue(sf.get_threshold_by_index(3));
      threshold_5.setValue(sf.get_threshold_by_index(4));
      threshold_6.setValue(sf.get_threshold_by_index(5));
      threshold_7.setValue(sf.get_threshold_by_index(6));
      threshold_8.setValue(sf.get_threshold_by_index(7));
      threshold_9.setValue(sf.get_threshold_by_index(8));
      threshold_10.setValue(sf.get_threshold_by_index(9));
      threshold_11.setValue(sf.get_threshold_by_index(10));
      threshold_12.setValue(sf.get_threshold_by_index(11));
    }
    else
    {
      if (sf.nb_values >= 1)  threshold_1.show();  else threshold_1.hide();
      if (sf.nb_values >= 2)  threshold_2.show();  else threshold_2.hide();
      if (sf.nb_values >= 3)  threshold_3.show();  else threshold_3.hide();
      if (sf.nb_values >= 4)  threshold_4.show();  else threshold_4.hide();
      if (sf.nb_values >= 5)  threshold_5.show();  else threshold_5.hide();
      if (sf.nb_values >= 6)  threshold_6.show();  else threshold_6.hide();
      if (sf.nb_values >= 7)  threshold_7.show();  else threshold_7.hide();
      if (sf.nb_values >= 8)  threshold_8.show();  else threshold_8.hide();
      if (sf.nb_values >= 9)  threshold_9.show();  else threshold_9.hide();
      if (sf.nb_values >= 10) threshold_10.show(); else threshold_10.hide();
      if (sf.nb_values >= 11) threshold_11.show(); else threshold_11.hide();
      if (sf.nb_values >= 12) threshold_12.show(); else threshold_12.hide();

      power.hide(); min_value.hide(); max_value.hide();
    }
  }
}

// ------------------------------------------------------------------
// Filter
// ------------------------------------------------------------------

class ContourShadeFilter
{
  PolylineGroup filtered_group = new PolylineGroup();

  private Polyline current_line = null;

  // Filters source contour group using shade pixel brightness.
  // contour_offset is the (cx, cy) offset applied when drawing contours
  // (same as img_cx / img_cy in ContourGenerator), so we can convert
  // centered drawing coords back to pixel-space for shade sampling.
  // If shade_image is null the source group is kept as-is.
  void build(PolylineGroup source, PImage shade_image)
  {
    filtered_group.clear();
    current_line = null;

    if (shade_image == null || !data.shade_filter.enabled)
    {
      // Copy source references unchanged
      for (Polyline l : source.polylines)
        filtered_group.add(l);
      return;
    }

    shade_image.loadPixels();

    int   threshold_index  = 0;
    int   direction_index  = 1;
    int   current_level    = -1;
    float threshold        = 0;

    for (int i_line = 0; i_line < source.size(); i_line++)
    {
      Polyline source_line = source.polylines.get(i_line);

      // Determine the level_index of this polyline (0 if not tagged).
      int line_level = (source_line instanceof ContourPolyline)
        ? ((ContourPolyline)source_line).level_index
        : 0;

      // Advance threshold only when entering a new contour level.
      if (line_level != current_level)
      {
        current_level = line_level;
        threshold = data.shade_filter.get_threshold_by_index(threshold_index);
        threshold_index += direction_index;

        if (data.shade_filter.mirror)
        {
          if (threshold_index >= data.shade_filter.nb_values || threshold_index < 0)
          {
            direction_index  = -direction_index;
            threshold_index += direction_index * 2;
          }
        }
        else
        {
          if (threshold_index >= data.shade_filter.nb_values)
            threshold_index = 0;
        }
      }

      for (int i_pt = 0; i_pt < source_line.size(); i_pt++)
      {
        PVector pt = source_line.get(i_pt);

        // Contour points are in pixel-space (0..grid.width, 0..grid.height).
        // Shade image has the same dimensions — sample directly.
        int ix = constrain(round(pt.x), 0, shade_image.width  - 1);
        int iy = constrain(round(pt.y), 0, shade_image.height - 1);
        float shade_val = red(shade_image.pixels[ix + iy * shade_image.width]);

        boolean keep = data.shade_filter.black
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
      current_line = new Polyline();
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
