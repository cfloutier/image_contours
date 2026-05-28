// DataShore — optional shore line generation at a manually selected elevation.
//
// The shore line is a contour extracted at a single elevation level (shore_level),
// intended as a baseline representing the sea/land boundary.
//
// Wave lines are geometric offsets of the shore polyline (no elevation map):
// each point is displaced along the averaged vertex normal by i * wave_step pixels.

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class DataShore extends GenericData
{
  DataShore() {
    super("Shore");
  }

  boolean enabled      = false;
  float   shore_level  = 0;    // elevation value: 0-255 in classic mode, metres in Terrarium mode

  int     wave_count   = 5;
  float   wave_step    = 4.0;
  float   simplify_eps = 1.5;

  boolean clip_contours = false;   // hide contours below shore_level

  boolean dash_waves    = false;   // gradient dash effect on wave lines
  float   dash_len      = 10.0;   // dash length (px)
  float   dash_gap_step = 3.0;    // gap increment per wave (0 = solid, step*i for wave i)
}

// ---------------------------------------------------------------------------
// GUI
// ---------------------------------------------------------------------------

class ShoreGUI extends GUIPanel
{
  DataShore shore;

  ShoreGUI(DataShore shore)
  {
    super("Shore", shore);
    this.shore = shore;
  }

  Toggle enabled;
  Slider shore_level;
  Slider wave_count;
  Slider wave_step;
  Slider simplify_eps;
  Toggle clip_contours;
  Toggle dash_waves;
  Slider dash_len;
  Slider dash_gap_step;

  void setGUIValues()
  {
    enabled.setValue(shore.enabled);
    shore_level.setValue(shore.shore_level);
    wave_count.setValue(shore.wave_count);
    wave_step.setValue(shore.wave_step);
    simplify_eps.setValue(shore.simplify_eps);
    clip_contours.setValue(shore.clip_contours);
    dash_waves.setValue(shore.dash_waves);
    dash_len.setValue(shore.dash_len);
    dash_gap_step.setValue(shore.dash_gap_step);
  }

  void setupControls()
  {
    super.Init();

    enabled     = addToggle("enabled",     "Activer le rivage");
    nextLine();
    shore_level = addSlider("shore_level", "Hauteur du rivage (0-255 / metres terrarium)", -10, 10);
    nextLine();
    wave_count   = addSlider("wave_count",   "Nombre de lignes",    0, 30);
    wave_step    = addSlider("wave_step",    "Espacement (px)",   -30, 30);
    nextLine();
    simplify_eps = addSlider("simplify_eps", "Simplification", 0, 2);
    nextLine();
    clip_contours = addToggle("clip_contours", "Masquer les courbes sous le rivage");
    nextLine();
    dash_waves    = addToggle("dash_waves",    "Dégradé de tirets");
    nextLine();
    dash_len      = addSlider("dash_len",      "Longueur des tirets (px)",   2, 40);
    dash_gap_step = addSlider("dash_gap_step", "Incrément d'espace par vague (px)", 0, 20);
  }
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

class ShoreGenerator
{
  PolylineGroup group       = new PolylineGroup();   // shore baseline
  PolylineGroup waves_group = new PolylineGroup();   // geometric offset lines

  private float           img_cx;
  private float           img_cy;
  private MarchingSquares ms = new MarchingSquares();

  void build()
  {
    group.clear();
    waves_group.clear();
    if (!data.shore.enabled) return;

    ElevationGrid grid;

    if (data.contour.terrarium_mode)
    {
      PImage raw = data.image.image;
      if (raw == null) { println("[Shore] no source image"); return; }
      int tw = (data.image.transformed_image != null) ? data.image.transformed_image.width  : 0;
      int th = (data.image.transformed_image != null) ? data.image.transformed_image.height : 0;
      grid = new ElevationGrid(raw, tw, th, (int)data.image.Blur);
    }
    else
    {
      PImage src = data.image.transformed_image;
      if (src == null) { println("[Shore] no source image"); return; }
      grid = new ElevationGrid(src);
    }

    img_cx = grid.width  / 2.0;
    img_cy = grid.height / 2.0;

    group = ms.build(grid, new float[]{ data.shore.shore_level });

    float bw = grid.width, bh = grid.height;
    float eps    = data.shore.simplify_eps;
    float margin = 1.5;
    float minLen = abs(data.shore.wave_step) * 2;
    PolylineGroup filtered = new PolylineGroup();
    for (Polyline src : group.polylines)
    {
      // Discard open polylines whose endpoints touch the image boundary (coast leaving frame)
      if (!src.isClosed())
      {
        PVector a = src.points.get(0);
        PVector b = src.points.get(src.points.size() - 1);
        boolean aOnBorder = a.x < margin || a.y < margin || a.x > bw - margin || a.y > bh - margin;
        boolean bOnBorder = b.x < margin || b.y < margin || b.x > bw - margin || b.y > bh - margin;
        if (aOnBorder || bOnBorder) continue;
      }

      Polyline s = (eps > 0) ? src.simplify(eps) : src;
      int uv = s.isClosed() ? s.points.size() - 1 : s.points.size();
      if (uv < 5) continue;
      if (s.isClosed() && s.area() < 4) continue;
      if (s.length() < minLen) continue;
      filtered.add(s);
    }
    group = filtered;
    println("[Shore] " + group.size() + " polylines");

    // Build geometric offset lines from the simplified shore baseline
    int   n    = (int) data.shore.wave_count;
    float step = data.shore.wave_step;

    for (int i = 1; i <= n; i++)
    {
      float dist = i * step;
      float gap  = data.shore.dash_waves ? (i - 1) * data.shore.dash_gap_step : 0;

      for (Polyline src : group.polylines)
      {
        Polyline off = src.offset(dist);
        if (off == null) continue;
        Polyline cleaned = off.dedupe(5.0).removeSpikes().removeHairpins(120).simplify(eps);
        if (data.shore.dash_waves && gap > 0)
        {
          for (Polyline dash : cleaned.splitToDashes(data.shore.dash_len, gap))
            waves_group.add(dash);
        }
        else
        {
          waves_group.add(cleaned);
        }
      }
    }
    println("[Shore] " + waves_group.size() + " wave polylines");
  }

  void draw()
  {
    if (!data.shore.enabled) return;

    current_graphics.pushMatrix();
    current_graphics.translate(-img_cx, -img_cy);

    if (group.size() > 0)
      group.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

    if (waves_group.size() > 0)
      waves_group.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

    current_graphics.popMatrix();
  }
}
