import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImage image = new DataImage();
  DataContour contour = new DataContour();
  Style style = new Style();

  ImgContourData()
  {
    addChapter(image);
    addChapter(contour);
    addChapter(style);
  }

  void reset()
  {
    image.CopyFrom(new DataImage());
    contour.CopyFrom(new DataContour());
    style.CopyFrom(new Style());
  }
}
