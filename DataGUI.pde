import controlP5.*;

class DataGUI extends MainPanel
{
  public DataGUI(ImgContourData data)
  {
    this.data = data;
    file_ui         = new FileGUI(data, true);
    images_ui       = new ImageContoursGUI(data.image);
    contour_ui      = new ContourGUI(data.contour);
    shading_ui      = new ShadingGUI(data.shading);
    threshold_ui    = new ThresholdGUI(data.threshold);
    shore_ui        = new ShoreGUI(data.shore);
    style_ui        = new StyleGUI(data.style);
  }

  ImgContourData    data;
  FileGUI           file_ui;
  ImageContoursGUI  images_ui;
  ContourGUI        contour_ui;
  ShadingGUI        shading_ui;
  ThresholdGUI      threshold_ui;
  ShoreGUI          shore_ui;
  StyleGUI          style_ui;

  void Init()
  {
    addTab(file_ui);
    addTab(images_ui);
    addTab(contour_ui);
    addTab(shading_ui);
    addTab(threshold_ui);
    addTab(shore_ui);
    addTab(style_ui);

    super.Init();

    cp5.getTab("Depth").bringToFront();
  }

  @Override
  void mouseDragged()
  {
    super.mouseDragged();

    // Perlin space pan: drag on canvas when no GUI panel is being moved
    if (dragging_panel == null && !cp5.isMouseOver() && data.image.use_perlin)
    {
      DataImageContours img = (DataImageContours) data.image;
      img.perlin_offset_x -= (mouseX - pmouseX);
      img.perlin_offset_y -= (mouseY - pmouseY);
      img.changed = true;
    }
  }
}
