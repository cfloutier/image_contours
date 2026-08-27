import java.awt.Image;
// trace contours of an image

import controlP5.*;
import processing.pdf.*;
import processing.dxf.*;
import processing.svg.*;

ImgContourData data;
DataGUI dataGui;

ContourGenerator generator;
ReliefShadingGenerator shading_generator;
ShoreGenerator shore_generator;

PGraphics current_graphics;
ControlP5 cp5;

int lastContourCalcMillis = -1;
int lastShoreCalcMillis   = -1;
int lastDrawMillis        = -1;

void setup()
{
  size(1200, 800);
  pixelDensity(1);
  surface.setResizable(true);

  data = new ImgContourData();
  dataGui = new DataGUI(data);

  generator = new ContourGenerator();
  shading_generator = new ReliefShadingGenerator();
  shore_generator = new ShoreGenerator();

  setupControls();

  data.LoadSettings("./Settings/default.json");

  dataGui.setGUIValues();

  file_ui.export_group = generator.group;
}

void setupControls()
{
  cp5 = new ControlP5(this);
  cp5.getTab("default").setLabel("Hide GUI");

  dataGui.Init();
}

void rebuildIfNeeded()
{
  // Decoupled recompute policy:
  // - Image changes affect both contour + shading
  // - Contour chapter changes affect contour only
  // - Shading chapter changes affect shading only
  // - Page/global changes can require export-scale refresh
  boolean image_changed   = data.image.changed;
  boolean contour_changed = data.contour.changed;
  boolean shading_changed = data.shading.changed;
  boolean filter_changed  = data.threshold.changed;
  boolean shore_changed   = data.shore.changed;
  boolean page_changed    = data.page.changed;
  boolean global_changed  = data.changed;

  boolean contour_compute  = data.contour.compute;
  boolean shading_compute  = data.shading.compute;

  boolean rebuild_contours = contour_compute && (image_changed || contour_changed || global_changed);
  boolean rebuild_shading  = shading_compute && (image_changed || shading_changed || global_changed);
  boolean rebuild_filter   = rebuild_contours || rebuild_shading || filter_changed || contour_changed || shading_changed;
  boolean rebuild_shore    = image_changed || shore_changed || global_changed;

  if (rebuild_contours)
  {
    long t0 = System.currentTimeMillis();
    generator.build();
    lastContourCalcMillis = (int)(System.currentTimeMillis() - t0);
  }
  else if (!contour_compute && (contour_changed || global_changed))
  {
    generator.group.clear();
    generator.filtered_group.clear();
    generator.display_group = new PolylineGroup();
    generator.levels = new float[0];
    lastContourCalcMillis = -1;
  }

  if (rebuild_shading)
    shading_generator.build();
  else if (!shading_compute && (shading_changed || global_changed))
    shading_generator.shaded_image = null;

  if (rebuild_shore)
  {
    long t0 = System.currentTimeMillis();
    shore_generator.build();
    lastShoreCalcMillis = (int)(System.currentTimeMillis() - t0);
  }

  if (rebuild_filter)
    generator.buildFilter(shading_generator.shaded_image);

  // Rebuild display_group and export_group whenever contours, filter, or shore change.
  // display_group = what ContourGenerator.drawFiltered() uses.
  // export_group  = merged contours + shore lines (draw AND export are identical).
  if (rebuild_filter || rebuild_shore || shore_changed)
  {
    // Choose base contour group (threshold-filtered or raw)
    PolylineGroup base = data.threshold.enabled ? generator.filtered_group : generator.group;

    // Apply shore clip if requested (independent of shore wave display)
    boolean doClip = data.shore.clip_contours && generator.levels.length > 0;
    if (doClip)
      base = data.threshold.enabled
        ? generator.filteredGroupAboveLevel(data.shore.shore_level)
        : generator.groupAboveLevel(data.shore.shore_level);

    generator.display_group = base;

    // Build merged export group: filtered contours + shore baseline + waves
    PolylineGroup merged = new PolylineGroup();
    for (Polyline p : base.polylines)               merged.add(p);
    if (data.shore.enabled)
    {
      for (Polyline p : shore_generator.group.polylines)       merged.add(p);
      for (Polyline p : shore_generator.waves_group.polylines) merged.add(p);
    }
    file_ui.export_group = merged;
  }

  // Export scale depends on contour geometry and page clipping settings.
  if (rebuild_contours || contour_changed || page_changed || global_changed)
  {
    file_ui.updateExportScale(generator.group.getBoundingBox(
      data.page.clipping, data.page.clip_width, data.page.clip_height));
  }

  if (data.any_change())
    data.reset_all_changes();
}

void drawHUD()
{
  int hud_x = 20;
  int hud_y = height - 10;

  color bg = data.style.backgroundColor;
  color fg = color(255 - red(bg), 255 - green(bg), 255 - blue(bg));

  fill(fg);
  textSize(12);

  int line_count = (generator != null && generator.group != null) ? generator.group.size() : 0;
  String line_text = "lines: " + StringUtils.formatInt(line_count);

  String calc_text  = (lastContourCalcMillis >= 0)
    ? "calc contour: " + StringUtils.formatDuration(lastContourCalcMillis)
    : "calc contour: n/a";

  String shore_text = "  calc shore: " + (lastShoreCalcMillis >= 0 ? StringUtils.formatDuration(lastShoreCalcMillis) : "n/a");
  String draw_text  = "  draw: " + (lastDrawMillis >= 0 ? StringUtils.formatDuration(lastDrawMillis) : "n/a");

  text(line_text + "   " + calc_text + shore_text + draw_text, hud_x, hud_y);
}

void draw()
{
  long t0_draw = System.currentTimeMillis();
  start_draw();

  data.image.buildTransformedImage();

  rebuildIfNeeded();

  if (data.image.draw)
    data.image.draw(data.image.imageAlpha);

  if (data.shading.draw)
    shading_generator.draw();

  strokeWeight(data.style.lineWidth);
  stroke(data.style.lineColor);
  noFill();

  if (data.contour.draw)
    generator.drawFiltered();

  shore_generator.draw();

  end_draw();
  lastDrawMillis = (int)(System.currentTimeMillis() - t0_draw);

  drawHUD();
}
