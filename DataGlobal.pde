import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImage       image        = new DataImage();
  DataContour     contour      = new DataContour();
  DataShading     shading      = new DataShading();
  DataThreshold     threshold    = new DataThreshold();
  Style             style        = new Style();

  ImgContourData()
  {
    addChapter(image);
    addChapter(contour);
    addChapter(shading);
    addChapter(threshold);
    addChapter(style);
  }

  void reset()
  {
    image.CopyFrom(new DataImage());
    contour.CopyFrom(new DataContour());
    shading.CopyFrom(new DataShading());
    threshold.CopyFrom(new DataThreshold());
    style.CopyFrom(new Style());
  }
}
