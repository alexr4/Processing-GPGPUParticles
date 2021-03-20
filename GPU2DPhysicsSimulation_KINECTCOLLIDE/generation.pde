/**
 This tab show all the generation functions
 */
void drawTextureIntoPingPongBuffer(PingPongBuffer ppb, PImage tex) { 
  /**
   * IMPORTANT : pre-multiply alpha is not supported on processing 3.X (based on 3.4)
   * Here we use a trick in order to render our image properly into our pingpong buffer
   * find out more here : https://github.com/processing/processing/issues/3391
   */
  ppb.dst.beginDraw(); 
  ppb.dst.clear();
  ppb.dst.blendMode(REPLACE);
  ppb.dst.image(tex, 0, 0, ppb.dst.width, ppb.dst.height);
  ppb.dst.endDraw();
}


/*
Particles "Shapes" position
 **/
PVector[] getRandomData(int w, int h, int loopPI) {
  PVector[] data = new PVector[w*h];
  float midRadius = height * 0.35;
  float minRadius = height * 0.05;
  float margin = 0;
  float rectWidth = height * 0.15;
  float goldenRatio = (1.0 + sqrt(5.0)) / 2.0;
  for (int i=0; i<data.length; i++) {
    float x = i % w;
    float y = (i - x) / (float)h;

    float t = norm(i, 0, data.length) * TWO_PI;
    float eta = (TWO_PI / goldenRatio) * (i+1);
    float radius = sqrt(eta) * 1.0;
   // float noised = noise(x * 0.001, y * 0.001, i*0.001);
    //float noiseSwitch = noised * 2.0 - 1.0;
    //float r = midRadius + noised * minRadius + sin(t * loopPI) * (midRadius * noised) + random(-1, 1) * minRadius;
  //  r = random(midRadius);
    float nx = width/2 + cos(eta) * radius;
    float ny = height/2 + sin(eta) * radius;
    // nx = random(margin, width - margin);
    // ny = random(margin, height - margin);
    //nx = random(- width/2,  width/2) + width/2;
    //ny = random(-rectWidth, rectWidth) + height/2;

    // nx = map(x, 0, w, 10, w - 10);
    // ny = map(y, 0, h, 10, h - 10);
    data[i] = new PVector(nx / (float)width, ny/(float)height);
  }

  return data;
}


/**
 UTILITIES
 */
PVector[] getVelData(int w, int h) {
  PVector[] data = new PVector[w*h];
  for (int i=0; i<data.length; i++) {
    data[i] = new PVector(0.5, 0.5);//at first vel is |0|
  }

  return data;
}

float[] getMassData(int w, int h) {
  float[] data = new float[w*h];
  for (int i=0; i<data.length; i++) {
    float nm = random(1.0);
    data[i] = nm;
  }

  return data;
}

float[] getRandom1DData(int w, int h) {
  return getRandom1DData(w, h, 0.0, 1.0);
}

float[] getRandom1DData(int w, int h, float min, float max) {
  float[] data = new float[w*h];
  for (int i=0; i<data.length; i++) {
    float nm = random(min, max);
    data[i] = nm;
  }

  return data;
}
