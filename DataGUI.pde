import controlP5.*;

class DataGUI extends MainPanel
{
  public DataGUI(ImgContourData data)
  {
    this.data = data;
    file_ui         = new FileGUI(data, true);
    images_ui       = new ImageGUI(data.image);
    contour_ui      = new ContourGUI(data.contour);
    shading_ui      = new ShadingGUI(data.shading);
    threshold_ui    = new ThresholdGUI(data.threshold);
    shore_ui        = new ShoreGUI(data.shore);
    style_ui        = new StyleGUI(data.style);
  }

  ImgContourData    data;
  FileGUI           file_ui;
  ImageGUI          images_ui;
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

    cp5.getTab("Image").bringToFront();
  }
}
