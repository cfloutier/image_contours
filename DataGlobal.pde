import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImage image = new DataImage();
  Style style = new Style();

  ImgContourData()
  {
    addChapter(image);
    addChapter(style);
  }

  void reset()
  {
    image.CopyFrom(new DataImage());
    style.CopyFrom(new Style());
  }
}
