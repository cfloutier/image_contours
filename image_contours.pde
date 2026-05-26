import java.awt.Image;
// trace contours of an image

import controlP5.*;
import processing.pdf.*;
import processing.dxf.*;
import processing.svg.*;

ImgContourData data;
DataGUI dataGui;

ContourGenerator generator;

PGraphics current_graphics;
ControlP5 cp5;

void setup()
{
  size(1200, 800);
  pixelDensity(1);
  surface.setResizable(true);

  data = new ImgContourData();
  dataGui = new DataGUI(data);

  generator = new ContourGenerator();

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

void draw()
{
  start_draw();

  data.image.buildTransformedImage();

  if (data.image.draw)
    data.image.draw(data.image.imageAlpha);

  if (data.any_change())
  {
    generator.build();
    file_ui.updateExportScale(generator.group.getBoundingBox(
      data.page.clipping, data.page.clip_width, data.page.clip_height));
    data.reset_all_changes();
  }

  strokeWeight(data.style.lineWidth);
  stroke(data.style.lineColor.col);
  noFill();

  if (data.contour.draw)
    generator.draw();

  end_draw();
}
