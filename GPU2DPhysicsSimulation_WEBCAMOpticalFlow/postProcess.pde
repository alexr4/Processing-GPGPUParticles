void postProcess() {
  float nmx = (float)mouseX / (float)width; 
  float size = 0.025;

  //bloom image
  filter.getGaussianBlurUltraHigh(fbuffer, 5.0);
  //filter.getGaussianBlurUltraHigh(filter.getBuffer(), 5.0);
  compositor.getBlendAdd(filter.getBuffer(), fbuffer, 75.0);
  //add chroma warp
  filter.getChromaWarpHigh(compositor.getBuffer(), width/2, height/2, size * 0.1, (HALF_PI / 10.0) * size);
  //sharpen image
  sharpen.getHighPass(filter.getBuffer(), 4.0);
  sharpen.getDesaturate(sharpen.getBuffer(), 100.0);
  compositor.getBlendOverlay(sharpen.getBuffer(), filter.getBuffer(), 100.0);
  
  //LUT image
  filter.getLut1D(compositor.getBuffer(), lut);
}
