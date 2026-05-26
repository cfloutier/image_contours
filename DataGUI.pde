import controlP5.*;

class DataGUI extends MainPanel
{
  public DataGUI(ImgContourData data)
  {
    this.data = data;
    file_ui = new FileGUI(data, true);
    images_ui = new ImageGUI(data.image);
    contour_ui = new ContourGUI(data.contour);
    style_ui = new StyleGUI(data.style);
  }

  ImgContourData data;
  FileGUI file_ui;
  ImageGUI images_ui;
  ContourGUI contour_ui;
  StyleGUI style_ui;

  void Init()
  {
    addTab(file_ui);
    addTab(images_ui);
    addTab(contour_ui);
    addTab(style_ui);

    super.Init();

    cp5.getTab("Image").bringToFront();
  }
}
