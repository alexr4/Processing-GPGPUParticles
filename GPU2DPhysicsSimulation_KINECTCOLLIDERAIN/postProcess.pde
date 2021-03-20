void postProcess() {
  float nmx = (float)mouseX / (float)width; 
  float cwsize = 0.025;

  //bloom image
  filter.getGaussianBlurUltraHigh(rainBuffer, 15.0);
  compositor.getBlendScreen(filter.getBuffer(), rainBuffer, 25.0);
  // //add chroma warp
  filter.getChromaWarpHigh(compositor.getBuffer(), width/2, height/2, cwsize * 0.1, (HALF_PI / 10.0) * cwsize);
  //sharpen image
  sharpen.getHighPass(compositor.getBuffer(), 4.0);
  sharpen.getDesaturate(sharpen.getBuffer(), 100.0);
  compositor.getBlendOverlay(sharpen.getBuffer(), filter.getBuffer(), 100.0);
  // //LUT image
  for (int i=0; i<4; i++) {
    filter.getCustomFilter(compositor.getBuffer(), FXAA);
  } 
  filter.getLut1D(filter.getBuffer(), lut);
  filter.getAnimatedGrain(filter.getBuffer(), 0.1);
}
