import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImageContours image      = new DataImageContours();
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
    image.CopyFrom(new DataImageContours());
    contour.CopyFrom(new DataContour());
    shading.CopyFrom(new DataShading());
    threshold.CopyFrom(new DataThreshold());
    shore.CopyFrom(new DataShore());
    style.CopyFrom(new Style());
  }
}
