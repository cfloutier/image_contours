// ElevationGrid — a 2D float array of elevation values decoded from an image source.
//
// Two constructors for the two supported formats:
//
//   ElevationGrid(PImage src)
//     Classic grayscale: brightness of each pixel → 0-255.
//     src is the already-processed image (resized + blurred by xLib).
//
//   ElevationGrid(PImage raw, int targetW, int targetH, int blurRadius)
//     Terrarium RGB encoding: elevation (m) = R*256 + G + B/256 - 32768.
//     Decodes to float FIRST, then resizes (bilinear on floats = correct).
//     Pass targetW/targetH = 0 to keep the original image dimensions.
//     Pass blurRadius = 0 to skip blurring.
//
// After construction, vmin and vmax hold the actual elevation range.

class ElevationGrid
{
  float[] values;
  int     width;
  int     height;
  float   vmin;
  float   vmax;

  // -- Classic: brightness 0-255 from a processed (pre-resized/blurred) image. --

  ElevationGrid(PImage src)
  {
    src.loadPixels();
    width  = src.width;
    height = src.height;
    values = new float[width * height];

    for (int i = 0; i < values.length; i++)
      values[i] = brightness(src.pixels[i]);

    computeRange();
  }

  // -- Terrarium: decode RGB to float FIRST, then resize, then blur. --

  ElevationGrid(PImage raw, int targetW, int targetH, int blurRadius)
  {
    raw.loadPixels();
    int sw = raw.width;
    int sh = raw.height;

    float[] decoded = new float[sw * sh];
    for (int i = 0; i < decoded.length; i++)
    {
      color c = raw.pixels[i];
      decoded[i] = red(c) * 256.0 + green(c) + blue(c) / 256.0 - 32768.0;
    }

    int dw = (targetW  > 0) ? targetW  : sw;
    int dh = (targetH  > 0) ? targetH  : sh;

    float[] vals = (dw != sw || dh != sh) ? resizeFloat(decoded, sw, sh, dw, dh) : decoded;
    if (blurRadius > 0) vals = blurFloat(vals, dw, dh, blurRadius);

    width  = dw;
    height = dh;
    values = vals;
    computeRange();
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  private void computeRange()
  {
    float mn =  Float.MAX_VALUE;
    float mx = -Float.MAX_VALUE;
    for (float v : values) { if (v < mn) mn = v; if (v > mx) mx = v; }
    vmin = mn;
    vmax = mx;
  }

  // Bilinear resize of a float array from (sw x sh) to (dw x dh).
  private float[] resizeFloat(float[] src, int sw, int sh, int dw, int dh)
  {
    float[] dst = new float[dw * dh];
    float   sx  = (float)(sw - 1) / max(1, dw - 1);
    float   sy  = (float)(sh - 1) / max(1, dh - 1);

    for (int y = 0; y < dh; y++)
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

    return dst;
  }

  // Separable box blur (radius r pixels).
  private float[] blurFloat(float[] src, int w, int h, int r)
  {
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
}
