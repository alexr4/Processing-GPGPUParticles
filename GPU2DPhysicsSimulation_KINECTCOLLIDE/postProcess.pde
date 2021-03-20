void postProcess(){
    float nmx = (float)mouseX / (float)width; 
    float cwsize = 0.025;


    //bloom image
    filter.getGaussianBlurUltraHigh(fbuffer, 5.0);
    //filter.getGaussianBlurUltraHigh(filter.getBuffer(), 5.0);
    compositor.getBlendAdd(filter.getBuffer(), fbuffer, 25.0);
    //add chroma warp
    filter.getChromaWarpHigh(compositor.getBuffer(), width/2, height/2, cwsize * 0.1, (HALF_PI / 10.0) * cwsize);
    //sharpen image
    sharpen.getHighPass(filter.getBuffer(), 4.0);
    sharpen.getDesaturate(sharpen.getBuffer(), 100.0);
    compositor.getBlendOverlay(sharpen.getBuffer(), filter.getBuffer(), 100.0);
    //LUT image
    filter.getLut1D(compositor.getBuffer(), lut);
    // filter.getGlitchStitch(filter.getBuffer(), noise(Time.time * 0.01) * 0.25, Time.time);
    float threshold = noise(millis() * 0.0001, frameCount * 0.01) * 0.15;
    float offsetRGB = noise(frameCount * 0.0125, millis() * 0.005) * 0.005;
    float size = 2.5;
    float minVelocity = 0.0;
    float maxVelocity = 0.35;
    float offsetSobel = 0.05;
    float lambda = 1.0;
    datamoshing.getDatamoshing5x5(filter.getBuffer(), minVelocity, maxVelocity, offsetSobel, lambda, threshold, size, offsetRGB);

    
    filter.getAnimatedGrainRGB(datamoshing.getBuffer(), 0.05);

}
