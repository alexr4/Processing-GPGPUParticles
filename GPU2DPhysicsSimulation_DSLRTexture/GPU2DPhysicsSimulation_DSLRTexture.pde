import fpstracker.core.*;
import gpuimage.core.*;
import gpuimage.utils.*;

import edsdk.bindings.*; 
import edsdk.api.*; 
import edsdk.processing.*; 
import edsdk.utils.CanonConstants.*; 
ProcessingCanonCamera cam; 
PGraphics dslrTexture;
boolean isLive = true;

PerfTracker pt;
int nbParticles;

float res = 1.0;
int targetWidth = 1920;
int targetHeight = 1080;
int particlesTargetWidth, particlesTargetHeight;

//destination buffer
PGraphics fbuffer;

//post-process
Filter filter, sharpen;
Compositor compositor;
PImage ramp, lut;

//control
boolean pause;
boolean debug;
boolean init;

void settings() {
  //we use the P3D capabilities even if th particle system is 2D based
  size(1280, 720, P3D);
  //fullScreen(P3D, 2);
  smooth(8);
}

void setup() {
  surface.setLocation(1920, 0);
  pt = new PerfTracker(this, 120);

  particlesTargetWidth = floor(targetWidth/res);
  particlesTargetHeight = floor(targetHeight/res);

  fbuffer = createGraphics(targetWidth, targetHeight, P3D);
  filter = new Filter(this, targetWidth, targetHeight);
  sharpen = new Filter(this, targetWidth, targetHeight); 
  compositor = new Compositor(this, targetWidth, targetHeight);
  ramp = loadImage("ramp9.png");
  lut = loadImage("lut.png");

  ((PGraphicsOpenGL)fbuffer).textureSampling(3);
  fbuffer.hint(DISABLE_TEXTURE_MIPMAPS);


  cam = new ProcessingCanonCamera( this );
  cam.setAutoUpdateLiveView( true ); 
  cam.beginLiveView();
  dslrTexture = createGraphics(targetWidth, targetHeight, P2D);


  initFFMPEG(filter.getBuffer());
  background(0);

  println("Init particle system");
}

void draw() { 
  if (!init) {
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
  } else {
    Time.update(this, pause);
    float inc = 0.05;
    float timeUpdate = Time.time * 0.01;//frameCount * inc;
    float maxTime = 100.0;//10.0 / inc;

    //getCamera
    if (cam.isLiveViewOn() && isLive) { 
      PImage live = cam.liveViewImage(); 
      float aspectRatio = 1056.0 / 704.0;
      dslrTexture.beginDraw();
      dslrTexture.imageMode(CENTER);
      dslrTexture.image(live, dslrTexture.width/2, dslrTexture.height/2, dslrTexture.width, dslrTexture.width / aspectRatio);
      dslrTexture.endDraw();
      psh.set("dslrTexture", dslrTexture);
    }

    if (!pause) {

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
      velFrag.set("time", (float)timeUpdate);
      velFrag.set("wind", 0.1, 0.0);
      velFrag.set("posBuffer", posBuffer.getSrcBuffer());

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

    //display the particles system
    fbuffer.beginDraw();
    fbuffer.background(#000415);
    fbuffer.shader(psh);
    fbuffer.shape(particles);
    fbuffer.endDraw();

    //Post-Process
    postProcess();
    //tint(255, 1);
    image(filter.getBuffer(), 0, 0, width, height);
     //image(fbuffer, 0, 0, width, height);


    if (debug) {
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
      pt.display(0, 0);
    } else {
      pt.displayOnTopBar("nbParticles: "+nbParticles);
    }

    exportVideo();
  }
}

void keyPressed() {
  switch(key) {
  case 'r':
    drawTextureIntoPingPongBuffer(velBuffer, encodedVelBuffer);
    drawTextureIntoPingPongBuffer(posBuffer, encodedPosBuffer);
    break;
  case 'd' :
    debug = !debug;
    break;
  case 'p' :
    pause = !pause;
    break;
  case 'e' :
    startExport();
    break;
  case 's' :
    String name = year()+""+month()+""+day()+"--"+hour()+"-"+minute()+"-"+second()+"_GPGPUParticleSystem";
    filter.getBuffer().save(name+".tiff");
    break;
  case 'l' : 
    isLive = !isLive;
    break;
  }
}
