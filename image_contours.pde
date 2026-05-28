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

PGraphics current_graphics;
ControlP5 cp5;

int lastContourCalcMillis = -1;

void setup()
{
  size(1200, 800);
  pixelDensity(1);
  surface.setResizable(true);

  data = new ImgContourData();
  dataGui = new DataGUI(data);

  generator = new ContourGenerator();
  shading_generator = new ReliefShadingGenerator();

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
  boolean filter_changed  = data.shade_filter.changed;
  boolean page_changed    = data.page.changed;
  boolean global_changed  = data.changed;

  boolean rebuild_contours = image_changed || contour_changed || global_changed;
  boolean rebuild_shading  = image_changed || shading_changed || global_changed;
  boolean rebuild_filter   = rebuild_contours || rebuild_shading || filter_changed;

  if (rebuild_contours)
  {
    long t0 = System.currentTimeMillis();
    generator.build();
    lastContourCalcMillis = (int)(System.currentTimeMillis() - t0);
  }

  if (rebuild_shading)
    shading_generator.build();

  if (rebuild_filter)
  {
    generator.buildFilter(shading_generator.shaded_image);
    // Update export target to always use the active (possibly filtered) group
    file_ui.export_group = data.shade_filter.enabled
      ? generator.filtered_group
      : generator.group;
  }

  // Export scale depends on contour geometry and page clipping settings.
  if (rebuild_contours || page_changed || global_changed)
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

  color bg = data.style.backgroundColor.col;
  color fg = color(255 - red(bg), 255 - green(bg), 255 - blue(bg));

  fill(fg);
  textSize(12);

  int line_count = (generator != null && generator.group != null) ? generator.group.size() : 0;
  String line_text = "lines: " + StringUtils.formatInt(line_count);

  String calc_text = (lastContourCalcMillis >= 0)
    ? "calc contour: " + StringUtils.formatDuration(lastContourCalcMillis)
    : "calc contour: n/a";

  text(line_text + "   " + calc_text, hud_x, hud_y);
}

void draw()
{
  start_draw();

  data.image.buildTransformedImage();

  rebuildIfNeeded();

  if (data.image.draw)
    data.image.draw(data.image.imageAlpha);

  if (data.shading.draw)
    shading_generator.draw();

  strokeWeight(data.style.lineWidth);
  stroke(data.style.lineColor.col);
  noFill();

  if (data.contour.draw)
    generator.drawFiltered();

  end_draw();

  drawHUD();
}
