import java.awt.Image;
// trace contours of an image

import controlP5.*;
import processing.pdf.*;
import processing.dxf.*;
import processing.svg.*;

ImgContourData data;
DataGUI dataGui;

PGraphics current_graphics;
ControlP5 cp5;

void setup()
{
  size(1200, 800);
  pixelDensity(1);
  surface.setResizable(true);

  data = new ImgContourData();
  dataGui = new DataGUI(data);

  setupControls();

  data.LoadSettings("./Settings/default.json");

  dataGui.setGUIValues();
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

  end_draw();
}
