import controlP5.*;

class ImgContourData extends DataGlobal
{
  DataImage       image        = new DataImage();
  DataContour     contour      = new DataContour();
  DataShading     shading      = new DataShading();
  DataShadeFilter shade_filter = new DataShadeFilter();
  Style           style        = new Style();

  ImgContourData()
  {
    addChapter(image);
    addChapter(contour);
    addChapter(shading);
    addChapter(shade_filter);
    addChapter(style);
  }

  void reset()
  {
    image.CopyFrom(new DataImage());
    contour.CopyFrom(new DataContour());
    shading.CopyFrom(new DataShading());
    shade_filter.CopyFrom(new DataShadeFilter());
    style.CopyFrom(new Style());
  }
}
