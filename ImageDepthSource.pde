// Project-specific depth source extension for image_contours.
// Keeps xLib_Image generic while adding a Perlin-generated source mode.

class DataImageContours extends DataImage
{
  // Source mode for depth map:
  // false = load image file from data/
  // true  = generate procedural map using custom PerlinNoise (xLib_MyPerlin.pde)
  boolean use_perlin = false;

  int   perlin_seed          = 1;
  float perlin_scale         = 0.02;
  int   perlin_octaves       = 4;
  float perlin_falloff       = 0.5;
  int   perlin_source_width  = 1024;
  int   perlin_source_height = 1024;
  float perlin_z             = 0.0;

  private PerlinNoise perlin_gen = null;
  private boolean last_use_perlin = false;

  @Override
  void buildTransformedImage()
  {
    // Handle source mode switch (file <-> perlin) explicitly.
    if (use_perlin != last_use_perlin)
    {
      image = null;
      transformed_image = null;
      reset_image = true;
      last_use_perlin = use_perlin;
    }

    if (use_perlin)
    {
      if (image == null || changed || reset_image)
        buildPerlinImage();

      if (image == null)
        return;

      if (changed || transformed_image == null || reset_image)
      {
        println("----------------- Rebuild transformed image ----------------");

        transformed_image = image.copy();
        if (transformed_image == null)
        {
          println("Error building transformed image from perlin source");
          return;
        }

        transformed_image.resize((int)Width, (int)Height());
        if (blackAndWhite)
          transformed_image.filter(GRAY);
        transformed_image.filter(BLUR, Blur);
        transformed_image.loadPixels();
        applyLevels(transformed_image);
        transformed_image.updatePixels();

        changed = true;
        reset_image = false;
      }
      return;
    }

    // File mode uses base implementation.
    super.buildTransformedImage();
  }

  void buildPerlinImage()
  {
    int w = max(8, perlin_source_width);
    int h = max(8, perlin_source_height);

    if (perlin_gen == null)
      perlin_gen = new PerlinNoise();

    perlin_gen.noiseSeed(perlin_seed);
    perlin_gen.noiseDetail(max(1, perlin_octaves), constrain(perlin_falloff, 0.01, 1.5));

    float s = max(1e-6, perlin_scale);

    float[] vals = new float[w * h];
    float mn =  Float.MAX_VALUE;
    float mx = -Float.MAX_VALUE;

    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
      {
        float v = perlin_gen.noise(x * s, y * s, perlin_z);
        vals[x + y * w] = v;
        if (v < mn) mn = v;
        if (v > mx) mx = v;
      }

    float range = max(1e-9, mx - mn);

    image = createImage(w, h, RGB);
    image.loadPixels();
    for (int i = 0; i < image.pixels.length; i++)
    {
      float n = (vals[i] - mn) / range;
      int g = (int)(constrain(n, 0, 1) * 255 + 0.5);
      image.pixels[i] = color(g);
    }
    image.updatePixels();

    // println("Perlin source generated: " + w + "x" + h
    //   + " seed=" + perlin_seed
    //   + " scale=" + nf(perlin_scale, 1, 4)
    //   + " oct=" + perlin_octaves
    //   + " falloff=" + nf(perlin_falloff, 1, 3));
  }
}

class ImageContoursGUI extends ImageGUI
{
  DataImageContours contoursImage;

  ControlsGroup file_source_group;
  ControlsGroup file_processing_group;
  ControlsGroup perlin_group;

  Textlabel source_title;
  Textlabel blur_title;
  Textlabel levels_title;
  Textlabel perlin_title;

  Slider perlin_seed;
  Slider perlin_scale;
  Slider perlin_octaves;
  Slider perlin_falloff;
  Slider perlin_source_width;
  Slider perlin_source_height;
  Slider perlin_z;
  Toggle use_perlin;

  ImageContoursGUI(DataImageContours data)
  {
    super(data);
    contoursImage = data;
    pageName = "Depth";
  }

  @Override
  void SelectSourceImage()
  {
    if (contoursImage.use_perlin)
    {
      println("Perlin mode active: disable 'Use Perlin' to select a file.");
      return;
    }
    super.SelectSourceImage();
  }

  @Override
  void update_ui()
  {
    if (contoursImage.use_perlin)
    {
      if (file_source_group != null) file_source_group.hide();
      if (file_processing_group != null) file_processing_group.show();
      if (blur_title != null) blur_title.show();
      if (levels_title != null) levels_title.show();
      if (perlin_group != null) perlin_group.show();
      if (perlin_title != null) perlin_title.show();
      file_Label.setText("Perlin " + contoursImage.perlin_source_width + "x" + contoursImage.perlin_source_height);
    }
    else
    {
      if (file_source_group != null) file_source_group.show();
      if (file_processing_group != null) file_processing_group.show();
      if (blur_title != null) blur_title.show();
      if (levels_title != null) levels_title.show();
      if (perlin_group != null) perlin_group.hide();
      if (perlin_title != null) perlin_title.hide();

      super.update_ui();
    }
  }

  @Override
  void setupControls()
  {
    super.Init();

    file_source_group = new ControlsGroup(contoursImage);
    file_processing_group = new ControlsGroup(contoursImage);
    perlin_group = new ControlsGroup(contoursImage);

    // Source choice first (requested order).
    source_title = addLabel("Depth Source");
    use_perlin = addToggle("use_perlin", "Use Perlin");
    nextLine();

    select_bt = addButton("Select Source Image");
    select_bt.plugTo(this, "SelectSourceImage");
    file_source_group.add(select_bt);

    file_Label = inlineLabel("File Label", 200);
    nextLine();

    draw = addToggle("draw", "Draw");
    blackAndWhite = addToggle("blackAndWhite", "Black & White");
    nextLine();
    Width = addSlider("Width", "Width", 200, 2000);
    ImageAlpha = addSlider("ImageAlpha", "Image Alpha", this, 0, 255);
    nextLine();

    blur_title = addLabel("add Blur ");
    Blur = addIntSlider("Blur", "Blur", 1, 20);
    file_processing_group.add(Blur);
    nextLine();

    perlin_title = addLabel("Perlin Source");
    perlin_seed = addIntSlider("perlin_seed", "Perlin Seed", 0, 1000000);
    perlin_group.add(perlin_seed);
    perlin_octaves = addIntSlider("perlin_octaves", "Perlin Octaves", 1, 8);
    perlin_group.add(perlin_octaves);
    nextLine();

    perlin_scale = addSlider("perlin_scale", "Perlin Scale", 0.001, 0.2);
    perlin_group.add(perlin_scale);
    perlin_falloff = addSlider("perlin_falloff", "Perlin Falloff", 0.1, 1.2);
    perlin_group.add(perlin_falloff);
    nextLine();

    perlin_source_width = addIntSlider("perlin_source_width", "Perlin W", 128, 4096);
    perlin_group.add(perlin_source_width);
    perlin_source_height = addIntSlider("perlin_source_height", "Perlin H", 128, 4096);
    perlin_group.add(perlin_source_height);
    nextLine();

    perlin_z = addSlider("perlin_z", "Perlin Z", 0, 32);
    perlin_group.add(perlin_z);
    nextLine();

    nextLine();
    levels_title = inlineLabel("Gamma Correction", 200);
    resetLevels_bt = addButton("Reset Levels");
    resetLevels_bt.plugTo(this, "ResetLevels");
    file_processing_group.add(resetLevels_bt);
    nextLine();
    levelsMin   = addSlider("levelsMin",   "Levels Min",   0, 254);
    file_processing_group.add(levelsMin);
    levelsGamma = addSlider("levelsGamma", "Levels Gamma", -1.0, 1.0);
    file_processing_group.add(levelsGamma);
    levelsMax   = addSlider("levelsMax",   "Levels Max",   1, 255);
    file_processing_group.add(levelsMax);

    // Initialize visibility according to current mode.
    update_ui();
  }

  @Override
  void setGUIValues()
  {
    super.setGUIValues();
    use_perlin.setValue(contoursImage.use_perlin ? 1 : 0);
    perlin_seed.setValue(contoursImage.perlin_seed);
    perlin_scale.setValue(contoursImage.perlin_scale);
    perlin_octaves.setValue(contoursImage.perlin_octaves);
    perlin_falloff.setValue(contoursImage.perlin_falloff);
    perlin_source_width.setValue(contoursImage.perlin_source_width);
    perlin_source_height.setValue(contoursImage.perlin_source_height);
    perlin_z.setValue(contoursImage.perlin_z);
  }

  @Override
  public void controlEvent(ControlEvent theEvent)
  {
    if (!theEvent.isController())
    {
      super.controlEvent(theEvent);
      return;
    }

    Controller c = theEvent.getController();

    if (c == use_perlin)
    {
      contoursImage.use_perlin = use_perlin.getValue() > 0.5;
      update_ui();
      onUIChanged();
      return;
    }

    if (c == blackAndWhite)
    {
      contoursImage.blackAndWhite = blackAndWhite.getValue() > 0.5;
      onUIChanged();
      return;
    }

    if (c == Width)
    {
      contoursImage.Width = Width.getValue();
      onUIChanged();
      return;
    }

    if (c == Blur)
    {
      contoursImage.Blur = (int)Blur.getValue();
      onUIChanged();
      return;
    }

    if (c == levelsMin)
    {
      contoursImage.levelsMin = levelsMin.getValue();
      onUIChanged();
      return;
    }

    if (c == levelsGamma)
    {
      contoursImage.levelsGamma = levelsGamma.getValue();
      onUIChanged();
      return;
    }

    if (c == levelsMax)
    {
      contoursImage.levelsMax = levelsMax.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_seed)
    {
      contoursImage.perlin_seed = (int)perlin_seed.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_octaves)
    {
      contoursImage.perlin_octaves = (int)perlin_octaves.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_source_width)
    {
      contoursImage.perlin_source_width = (int)perlin_source_width.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_source_height)
    {
      contoursImage.perlin_source_height = (int)perlin_source_height.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_scale)
    {
      contoursImage.perlin_scale = perlin_scale.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_falloff)
    {
      contoursImage.perlin_falloff = perlin_falloff.getValue();
      onUIChanged();
      return;
    }

    if (c == perlin_z)
    {
      contoursImage.perlin_z = perlin_z.getValue();
      onUIChanged();
      return;
    }

    super.controlEvent(theEvent);
  }
}
