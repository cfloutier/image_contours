import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImage       image        = new DataImage();
  DataContour     contour      = new DataContour();
  DataShading     shading      = new DataShading();
  DataThreshold   threshold    = new DataThreshold();
  DataShore       shore        = new DataShore();
  Style           style        = new Style();

  ImgContourData()
  {
    addChapter(image);
    addChapter(contour);
    addChapter(shading);
    addChapter(threshold);
    addChapter(shore);
    addChapter(style);
  }

  void reset()
  {
    image.CopyFrom(new DataImage());
    contour.CopyFrom(new DataContour());
    shading.CopyFrom(new DataShading());
    threshold.CopyFrom(new DataThreshold());
    shore.CopyFrom(new DataShore());
    style.CopyFrom(new Style());
  }
}
