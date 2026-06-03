// Relief shading built from elevation data (classic brightness or Terrarium decode).
// Produces a grayscale image using a configurable sun direction.

class DataShading extends GenericData
{
  DataShading() {
    super("Shading");
  }

  boolean compute = true;
  boolean draw = true;
  float imageAlpha = 180;

  // Sun azimuth in degrees, clockwise from North (0=N, 90=E, 180=S, 270=W).
  float sun_azimuth_deg = 315;
  // Sun altitude above the horizon in degrees.
  float sun_altitude_deg = 45;

  // Vertical exaggeration applied to elevation gradients.
  float z_factor = 1.2;
  // Base light level kept in shadows [0..1].
  float ambient = 0.2;

  // Post-lighting tone controls.
  float contrast = 1.0;
  float gamma = 1.0;

  boolean invert = false;
}

class ShadingGUI extends GUIPanel
{
  DataShading shading;

  ShadingGUI(DataShading shading)
  {
    super("Shading", shading);
    this.shading = shading;
  }

  Toggle compute;
  Toggle draw;
  Slider imageAlpha;
  Slider sun_azimuth_deg;
  Slider sun_altitude_deg;
  Slider z_factor;
  Slider ambient;
  Slider contrast;
  Slider gamma;
  Toggle invert;

  void setupControls()
  {
    super.Init();

    compute = addToggle("compute", "Compute");
    draw = addToggle("draw", "Draw");
    imageAlpha = addSlider("imageAlpha", "Image Alpha", 0, 255);
    nextLine();

    sun_azimuth_deg = addSlider("sun_azimuth_deg", "Sun Azimuth", 0, 360);
    sun_altitude_deg = addSlider("sun_altitude_deg", "Sun Altitude", 1, 89);
    nextLine();

    z_factor = addSlider("z_factor", "Z Factor", 0.1, 10.0);
    ambient = addSlider("ambient", "Ambient", 0.0, 1.0);
    nextLine();

    contrast = addSlider("contrast", "Contrast", 0.2, 3.0);
    gamma = addSlider("gamma", "Gamma", 0.3, 3.0);
    nextLine();

    invert = addToggle("invert", "Invert");
  }

  void setGUIValues()
  {
    compute.setValue(shading.compute);
    draw.setValue(shading.draw);
    imageAlpha.setValue(shading.imageAlpha);
    sun_azimuth_deg.setValue(shading.sun_azimuth_deg);
    sun_altitude_deg.setValue(shading.sun_altitude_deg);
    z_factor.setValue(shading.z_factor);
    ambient.setValue(shading.ambient);
    contrast.setValue(shading.contrast);
    gamma.setValue(shading.gamma);
    invert.setValue(shading.invert);
  }
}

class ReliefShadingGenerator
{
  PImage shaded_image = null;

  private float img_cx = 0;
  private float img_cy = 0;

  void build()
  {
    ElevationGrid grid = buildGrid();
    if (grid == null)
    {
      shaded_image = null;
      return;
    }

    img_cx = grid.width / 2.0;
    img_cy = grid.height / 2.0;

    shaded_image = createImage(grid.width, grid.height, RGB);
    shaded_image.loadPixels();

    int w = grid.width;
    int h = grid.height;

    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
      {
        float shade = computeShade(grid, x, y);
        shade = applyTone(shade);
        if (data.shading.invert) shade = 1.0 - shade;
        int g = int(constrain(shade, 0, 1) * 255 + 0.5);
        shaded_image.pixels[x + y * w] = color(g);
      }

    shaded_image.updatePixels();

    println("ReliefShading: " + w + "x" + h
      + "  sun(az=" + nf(data.shading.sun_azimuth_deg, 1, 1)
        + ", alt=" + nf(data.shading.sun_altitude_deg, 1, 1) + ")"
        + "  tone(c=" + nf(data.shading.contrast, 1, 2)
        + ", g=" + nf(data.shading.gamma, 1, 2) + ")");
  }

  void draw()
  {
    if (shaded_image == null || data.shading.imageAlpha <= 0)
      return;

    current_graphics.pushMatrix();
    current_graphics.tint(255, data.shading.imageAlpha);
    current_graphics.image(shaded_image, -img_cx, -img_cy, shaded_image.width, shaded_image.height);
    current_graphics.noTint();
    current_graphics.popMatrix();
  }

  private ElevationGrid buildGrid()
  {
    if (data.contour.terrarium_mode)
    {
      PImage raw = data.image.image;
      if (raw == null) return null;

      int tw = (data.image.transformed_image != null) ? data.image.transformed_image.width : 0;
      int th = (data.image.transformed_image != null) ? data.image.transformed_image.height : 0;
      return new ElevationGrid(raw, tw, th, (int)data.image.Blur);
    }

    PImage src = data.image.transformed_image;
    if (src == null) return null;
    return new ElevationGrid(src);
  }

  private float computeShade(ElevationGrid grid, int x, int y)
  {
    int w = grid.width;
    int h = grid.height;

    int xm = max(0, x - 1);
    int xp = min(w - 1, x + 1);
    int ym = max(0, y - 1);
    int yp = min(h - 1, y + 1);

    float zL = grid.values[xm + y * w];
    float zR = grid.values[xp + y * w];
    float zU = grid.values[x + ym * w];
    float zD = grid.values[x + yp * w];

    float zf = data.shading.z_factor;

    float dzdx = 0.5 * (zR - zL) * zf;
    float dzdy_img = 0.5 * (zD - zU) * zf;
    float dzdy = -dzdy_img;

    float slope = atan(sqrt(dzdx * dzdx + dzdy * dzdy));

    float aspect = atan2(dzdy, -dzdx);
    if (aspect < 0) aspect += TWO_PI;

    float azimuth = radians(90.0 - data.shading.sun_azimuth_deg);
    float zenith = radians(90.0 - data.shading.sun_altitude_deg);

    float direct = cos(zenith) * cos(slope)
      + sin(zenith) * sin(slope) * cos(azimuth - aspect);
    direct = max(0, direct);

    float ambient = constrain(data.shading.ambient, 0, 1);
    return ambient + (1.0 - ambient) * direct;
  }

  // Post-lighting tone mapping to control visual separation globally.
  private float applyTone(float shade)
  {
    float s = constrain(shade, 0, 1);

    float c = max(0.01, data.shading.contrast);
    s = (s - 0.5) * c + 0.5;
    s = constrain(s, 0, 1);

    float g = max(0.01, data.shading.gamma);
    s = pow(s, g);

    return constrain(s, 0, 1);
  }
}
