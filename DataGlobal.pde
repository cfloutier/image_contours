import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImage image = new DataImage();
  DataContour contour = new DataContour();
  DataShading shading = new DataShading();
  Style style = new Style();

  ImgContourData()
  {
    addChapter(image);
    addChapter(contour);
    addChapter(shading);
    addChapter(style);
  }

  void reset()
  {
    image.CopyFrom(new DataImage());
    contour.CopyFrom(new DataContour());
    shading.CopyFrom(new DataShading());
    style.CopyFrom(new Style());
  }
}
