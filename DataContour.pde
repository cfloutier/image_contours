class DataContour extends GenericData
{
  DataContour() {
    super("Contour");
  }

  boolean draw          = true;
  boolean terrarium_mode = false;
  float   contour_levels = 20;   // nombre de niveaux souhaités (mode-agnostique)
}


class ContourGUI extends GUIPanel
{
  DataContour contour;

  ContourGUI(DataContour contour)
  {
    super("Contour", contour);
    this.contour = contour;
  }

  Toggle draw;
  Toggle terrarium_mode;
  Slider contour_levels;
  Textlabel mode_label;

  void setGUIValues()
  {
    draw.setValue(contour.draw);
    terrarium_mode.setValue(contour.terrarium_mode);
    contour_levels.setValue(contour.contour_levels);
  }

  void setupControls()
  {
    super.Init();

    draw           = addToggle("draw",           "Draw");
    nextLine();
    terrarium_mode = addToggle("terrarium_mode", "Mode Terrarium");
    nextLine();
    mode_label = addLabel("Classic : luminosite (canal rouge, 0-255)");
    nextLine();
    contour_levels = addSlider("contour_levels", "Nombre de niveaux", 2, 400);
  }

  void update_ui()
  {
    if (contour.terrarium_mode)
      mode_label.setText("Terrarium : elevation = R x 256 + G + B/256 - 32768 m");
    else
      mode_label.setText("Classic : luminosite (canal rouge, 0-255)");
  }
}
