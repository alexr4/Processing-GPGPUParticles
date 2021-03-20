import fpstracker.core.*;
import gpuimage.core.*;
import gpuimage.utils.*;
import KinectPV2.*;


PerfTracker pt;
int nbParticles;

float res = 8.0;
int targetWidth = 1920;
int targetHeight = 1080;
int particlesTargetWidth,particlesTargetHeight;

PImage stencilImg;
PGraphics stencil;
Filter normalMap;
PShader normalShader;

PImage sprite;
PImage background;

//destination buffer
PGraphics fbuffer;

//post-process
Filter filter, sharpen, datamoshing;
Compositor compositor;
PImage ramp, lut;

//kinect
Filter fkinect;
KinectPV2 kinect;

//control
boolean pause;
boolean debug;
boolean init;

void settings() {
  //we use the P3D capabilities even if th particle system is 2D based
  // size(1280, 720, P3D);
  //size(1920, 1080, P3D);
  fullScreen(P3D, 1);
  smooth(8);
}

void setup() {
  //surface.setLocation(0, 0);
  pt = new PerfTracker(this, 120);

  stencilImg = loadImage("stencil.png");
  stencil = createGraphics(targetWidth, targetHeight, P2D);
  normalShader = loadShader("NormalMapping.glsl");
  normalMap = new Filter(this, stencil.width, stencil.height);
  
  ((PGraphicsOpenGL)stencil).textureSampling(3);
  stencil.hint(DISABLE_TEXTURE_MIPMAPS);

  normalMap.setFiltering(3);
  normalMap.enableTextureMipmaps(false);
  
  normalShader.set("Blur", 1.0);
  normalShader.set("sobel1Scale", 10.0);
  normalShader.set("sobel2Scale", 10.0);

  kinect = new KinectPV2(this);
  fkinect = new Filter(this, 512, 424);
  kinect.enableDepthImg(true);
  kinect.enableBodyTrackImg(true);

  kinect.init();

  particlesTargetWidth = floor(targetWidth/res);
  particlesTargetHeight = floor(targetHeight/res);

  fbuffer = createGraphics(targetWidth, targetHeight, P3D);
  filter = new Filter(this, targetWidth, targetHeight);
  sharpen = new Filter(this, targetWidth, targetHeight); 
  datamoshing = new Filter(this, targetWidth, targetHeight); 
  compositor = new Compositor(this, targetWidth, targetHeight);
  ramp = loadImage("ramp9.png");
  lut = loadImage("lut.png");

  ((PGraphicsOpenGL)fbuffer).textureSampling(3);
  fbuffer.hint(DISABLE_TEXTURE_MIPMAPS);

  sprite = loadImage("sprite-petal.png");
  background = loadImage("background-3.png");
  
  initFFMPEG(filter.getBuffer());
  background(0);

  println("Init particle system");
}

void draw() { 
  if(!init){
    loadShaders();
    initPackingSystem();
    PARTICLES.initWorld(targetWidth, targetHeight);
    initGPGPU(particlesTargetWidth, particlesTargetHeight);
    
    nbParticles = particlesTargetWidth * particlesTargetHeight;
    frameRate(60);
    println("Scene has: "+int(particlesTargetWidth * particlesTargetHeight)+" particles for: "+targetWidth+"*"+targetHeight);
    println("Buffer res: "+encodedPosBuffer.width+"*"+encodedPosBuffer.height);

    Time.setStartTime(this);
    init = true;
  }else{
    Time.update(this, pause);
    float inc = 0.05;
    float timeUpdate = Time.time * 0.01;//frameCount * inc;
    float maxTime = 100.0;//10.0 / inc;
    float nmx = (float)mouseX/width;
    float nmy = (float)mouseY/height;

    if(!pause){
      fkinect.getInvert(kinect.getBodyTrackImage());
      int loop = 5;
      for (int i=0; i<loop; i++) {
        fkinect.getDilation(fkinect.getBuffer());
      }
      fkinect.getInvert(fkinect.getBuffer());
      fkinect.getSignedDistanceField(fkinect.getBuffer(), 15);

      //create normal map
      stencil.beginDraw();
      stencil.background(0);
      stencil.imageMode(CENTER);
      stencil.image(fkinect.getBuffer(), stencil.width/2, stencil.height/2, stencil.height * (512.0/424.0), stencil.height);
      //stencil.image(stencilImg, 0, 0, stencil.width, stencil.height);
      // stencil.noStroke();
      // stencil.fill(255);
      // stencil.ellipse(nmx * stencil.width, nmy * stencil.height, 200, 200);
      // stencil.textSize(800);
      // stencil.textAlign(CENTER, CENTER);
      // stencil.text(round(millis()/1000.0), stencil.width/2, stencil.height/2);
      stencil.endDraw();
      normalMap.getCustomFilter(stencil, normalShader);

      //update the vel and pos buffers
      posBuffer.swap(); //we swap buffer first in order to get the value;
      velBuffer.swap(); //we swap buffer first in order to get the value;

      /**
      * IMPORTANT : pre-multiply alpha is not supported on processing 3.X (based on 3.4)
      * Here we use a trick in order to render our image properly into our pingpong buffer
      * find out more here : https://github.com/processing/processing/issues/3391
      */

      //bind variables & buffers to the vel buffer
      velFrag.set("normMouse", (float)mouseX/width, (float)mouseY/height);
      velFrag.set("time", timeUpdate);
      velFrag.set("wind", noise(timeUpdate * 0.01) * 15.0, (noise(timeUpdate * 0.01 + 1000.0) *2.0 - 1.0) * 15.0);
      // velFrag.set("gravity", 0.0, 10.0);
      velFrag.set("posBuffer", posBuffer.getSrcBuffer());
      velFrag.set("normalBuffer", normalMap.getBuffer());
      posFrag.set("maxLifeTime", (float)maxTime);

      //Update the vel buffer (using a ping pong buffer)
      velBuffer.dst.beginDraw(); 
      velBuffer.dst.clear();
      velBuffer.dst.blendMode(REPLACE);
      velBuffer.dst.shader(velFrag);
      velBuffer.dst.image(velBuffer.getSrcBuffer(), 0, 0);
      velBuffer.dst.endDraw();

      //bind variables & buffers to the position buffer
      posFrag.set("velBuffer", velBuffer.getSrcBuffer());
      posFrag.set("maxLifeTime", (float)maxTime);
      posFrag.set("time", (float)timeUpdate);
      posFrag.set("stencilBuffer", stencil);

      //Update the vel buffer (using a ping pong buffer)
      posBuffer.dst.beginDraw(); 
      posBuffer.dst.clear();
      posBuffer.dst.blendMode(REPLACE);
      posBuffer.dst.shader(posFrag);
      posBuffer.dst.image(posBuffer.getSrcBuffer(), 0, 0);
      posBuffer.dst.endDraw();
    }

    //Bind varibales & buffers to the particles system shader
    psh.set("posBuffer", posBuffer.dst);
    psh.set("velBuffer", velBuffer.getSrcBuffer());
    psh.set("maxLifeTime", (float)maxTime);
    psh.set("time", (float)timeUpdate);
    psh.set("stencilBuffer", stencil);
    psh.set("sprite", sprite);
    psh.set("maxSize", 30.0);

    //display the particles system
    fbuffer.beginDraw();
    fbuffer.background(0);
    fbuffer.image(background, 0, 0, fbuffer.width, fbuffer.height);
    fbuffer.shader(psh);
    fbuffer.shape(particles);
    fbuffer.resetShader();
    fbuffer.endDraw();

    //Post-Process
    postProcess();
    //tint(255, 1);
    //  image(fbuffer, 0, 0, width, height);

    image(filter.getBuffer(), 0, 0, width, height);


    if(debug){
      float uix = 120;
      float uiy = 0;
      float uiw = 400;
      float uih = 50;
      float uimargin = 4;
      String uiText = "pause: "+pause+"\n"+
                      "time: "+Time.time+"\n"+ 
                      "nb Particles: "+nbParticles;
      float uiBufferRes = 300;

      textAlign(LEFT, CENTER);
      fill(0);
      noStroke();
      rect(uix, uiy, uiw, uih);
      fill(255);
      text(uiText, uix + uimargin, uiy, uiw - uimargin, uih);

      drawDebugUI(uix, uih, width-uix, height-uih, uiBufferRes);
      image(normalMap.getBuffer(), 0, height - stencil.height * 0.25, stencil.width * 0.25, stencil.height * 0.25);
      image(fkinect.getBuffer(), stencil.width * 0.25, height - fkinect.getBuffer().height * 0.25, fkinect.getBuffer().width * 0.25, fkinect.getBuffer().height * 0.25);
      pt.display(0, 0);
    }else{
      pt.displayOnTopBar("nbParticles: "+nbParticles);
    }

    exportVideo();
  }
}

void keyPressed() {
  switch(key){
    case 'r':
      // Time.resetTimeForExport(this);
      drawTextureIntoPingPongBuffer(velBuffer, encodedVelBufferOrigin);
      drawTextureIntoPingPongBuffer(posBuffer, encodedPosBufferOrigin);
    break;
    case 'd' :
      debug = !debug;
    break;
    case 'p' :
      pause = !pause;
    break;
    case 'e' :
      Time.resetTimeForExport(this);
      drawTextureIntoPingPongBuffer(velBuffer, encodedVelBufferOrigin);
      drawTextureIntoPingPongBuffer(posBuffer, encodedPosBufferOrigin);
      startExport();
    break;
    case 's' :
      String name = year()+""+month()+""+day()+"--"+hour()+"-"+minute()+"-"+second()+"_GPGPUParticleSystem";
       filter.getBuffer().save(name+".tiff");
      //fbuffer.save(name+".tiff");
    break;
  }
}
