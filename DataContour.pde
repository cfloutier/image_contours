class DataContour extends GenericData
{
  DataContour() {
    super("Contour");
  }

  // Si true : tile Terrarium (AWS terrain) — élévation = R×256 + G + B/256 − 32768
  // Si false : mode classique — luminosité du canal rouge (0–255)
  boolean terrarium_mode = false;
}


class ContourGUI extends GUIPanel
{
  DataContour contour;

  ContourGUI(DataContour contour)
  {
    super("Contour", contour);
    this.contour = contour;
  }

  Toggle terrarium_mode;

  void setGUIValues()
  {
    terrarium_mode.setValue(contour.terrarium_mode);
  }

  void setupControls()
  {
    super.Init();

    terrarium_mode = addToggle("terrarium_mode", "Terrarium RGB (AWS terrain tiles)");
    nextLine();
    addLabel("Terrarium : R×256 + G + B/256 − 32768 m");
    nextLine();
    addLabel("Classic   : luminosite canal rouge (0-255)");
  }

  void update_ui() {}
}
