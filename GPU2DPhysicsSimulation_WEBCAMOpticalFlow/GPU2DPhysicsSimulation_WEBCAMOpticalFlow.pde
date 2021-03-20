/*
 - corriger Optical flow avec encodage de l'angle uniquement → Pas la bonne solution : Quid de reprendre tel quel la base déjà produite ?
 X - friction ++ pour ralentir les particules
 X - améliorer curl noise plus en courbe → Pas necessaire
 X - Corriger la taille des particles
 */

import fpstracker.core.*;
import gpuimage.core.*;
import gpuimage.utils.*;
import spout.*;

import KinectPV2.*;
import org.json.JSONObject;
import org.json.JSONArray;


public JSONObject config;
String subPath = "appData/";
KinectPV2 kinect;
Spout spout;

PGraphics camTexture;
boolean isLive = true;

PingPongBuffer ppb;
Filter ofFilters;
PGraphics ofToBind;
PShader normalmap;
PShader of;

PerfTracker pt;
int nbParticles;

float res = 1.5;
int targetWidth = 1920;
int targetHeight = 1080;
int particlesTargetWidth, particlesTargetHeight;

//destination buffer
PGraphics fbuffer;
PGraphics rotatedCam;

//post-process
Filter filter, sharpen;
Compositor compositor;
PImage ramp, lut;

//control
boolean pause;
boolean debug;
boolean init;

int windowX       = 0;
int windowY       = 0;
int windowWidth   = 1080;
int windowHeight  = 1920;
int displayRes    = 1;
int fps           = 30;
String appName;
String debugTxt;
boolean errorOnLaunch;

void settings() {
  //we use the P3D capabilities even if th particle system is 2D based
  if (args != null) {
    //appName       = args[0];
    windowWidth   = Integer.parseInt(args[0]);
    windowHeight  = Integer.parseInt(args[1]);
    windowX       = Integer.parseInt(args[2]);
    windowY       = Integer.parseInt(args[3]);
    fps           = Integer.parseInt(args[4]);
  } else {
    println("args == null");
    debugTxt = "args == null.\nPlease send argument before cmd";
    errorOnLaunch = true;
    fps = 30;
    windowX = 0;
    windowY = 0;
  }
  fullScreen(P3D);
  PJOGL.setIcon("ico.png");
  smooth(8);
}


void setup() {
  try {
    config = new JSONObject(loadJSONObject("config.json").toString());

    appName = config.getString("title");
    displayRes    = config.getJSONObject("window").getInt("displayRes");
    windowWidth   = config.getJSONObject("window").getInt("width");
    windowHeight  = config.getJSONObject("window").getInt("height");
    windowX       = config.getJSONObject("window").getInt("x");
    windowY       = config.getJSONObject("window").getInt("y");
    fps           = config.getJSONObject("window").getInt("fps");
    
    surface.setSize(windowWidth / displayRes, windowHeight / displayRes);
    surface.setLocation(windowX, windowY);
    surface.setTitle(appName);
    frameRate(fps);

    //app params
    res = (float) config.getJSONObject("app").getDouble("resolution");
  } 
  catch (Exception e) {
    e.printStackTrace();
  }
  pt = new PerfTracker(this, 120);

  particlesTargetWidth = floor(targetWidth/res);
  particlesTargetHeight = floor(targetHeight/res);

  fbuffer = createGraphics(targetWidth, targetHeight, P3D);
  filter = new Filter(this, targetWidth, targetHeight);
  sharpen = new Filter(this, targetWidth, targetHeight); 
  compositor = new Compositor(this, targetWidth, targetHeight);
  ramp = loadImage(subPath+"ramp9.png");
  lut = loadImage(subPath+"lut.png");

  ((PGraphicsOpenGL)fbuffer).textureSampling(3);
  fbuffer.hint(DISABLE_TEXTURE_MIPMAPS);

  kinect = new KinectPV2(this);
  kinect.enableColorImg(true);
  kinect.init();

  rotatedCam = createGraphics(1920, 1080, P3D);
  camTexture = createGraphics(targetWidth, targetHeight, P2D);

  int div = 5;
  ppb = new PingPongBuffer(this, targetWidth/div, targetHeight/div, 8, P2D);
  ppb.enableTextureMipmaps(false);
  ppb.setFiltering(3);
  ofFilters = new Filter(this, targetWidth/div, targetHeight/div);
  ofToBind = createGraphics(targetWidth, targetHeight, P2D);
  ((PGraphicsOpenGL)ofToBind).textureSampling(3);
  ofToBind.hint(DISABLE_TEXTURE_MIPMAPS);
  ofToBind.beginDraw();
  ofToBind.background(0);
  ofToBind.endDraw();

  of = loadShader(subPath+"OpticalFlow.glsl");
  of.set("resolution", (float)(targetWidth/4), (float)(targetHeight/4));//0.01);
  of.set("offsetInc", 0.01);//0.01);
  of.set("lambda", 0.01);//0.001
  of.set("scale", 1., 1.);
  of.set("threshold", 0.1);

  normalmap = loadShader(subPath+"NormalMapping.glsl");
  normalmap.set("Blur", 1.75);
  normalmap.set("sobel1Scale", 0.5);
  normalmap.set("sobel2Scale", 0.5);
  
  spout = new Spout(this);
  spout.createSender(appName);


  initFFMPEG(filter.getBuffer());
  background(0);

  //frameRate(30); 
  println("Init particle system");
}

void draw() { 
  noCursor();
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
    float timeUpdate = (!FFMPEGParams.export) ? Time.time * 0.01 : frameCount * inc;
    float maxTime =  (!FFMPEGParams.export) ? 100.0 : 10.0 / inc;


    //getCamera
    if (isLive) {  
      rotatedCam.beginDraw();
      rotatedCam.translate(rotatedCam.width/2, rotatedCam.height/2);
      //rotatedCam.rotateY(PI);
      rotatedCam.imageMode(CENTER);
      rotatedCam.image(kinect.getColorImage(), 0, 0, rotatedCam.width, rotatedCam.height);
      rotatedCam.endDraw();

      computeOpticalFlow();

      camTexture.beginDraw();
      camTexture.image(rotatedCam, 0, 0);
      camTexture.endDraw();
      psh.set("dslrTexture", camTexture);
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
      velFrag.set("opticalFlow", ofToBind);
      velFrag.set("maxLifeTime", (float)maxTime);
      velFrag.set("time", (float)timeUpdate);

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
    spout.sendTexture(filter.getBuffer());

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

      drawDebugUI(uix, uih, width-uix, height-uih, uiBufferRes / displayRes);
      image(ofToBind, 0, height - targetHeight/8 / displayRes, targetWidth/8 / displayRes, targetHeight/8 / displayRes);
      pt.display(0, 0);
    } else {
      pt.displayOnTopBar("nbParticles: "+nbParticles);
    }

    exportVideo();
  }
}

void computeOpticalFlow() {

  ppb.dst.beginDraw();  
  ppb.dst.clear();
  ppb.dst.blendMode(REPLACE);
  ppb.dst.shader(normalmap);
  ppb.dst.image(rotatedCam, 0, 0, ppb.dst.width, ppb.dst.height);
  ppb.dst.endDraw();

  of.set("previousFrame", ppb.getSrcBuffer());
  ofFilters.getCustomFilter(ppb.getDstBuffer(), of);
  ofFilters.getGaussianBlurUltraHigh(ofFilters.getBuffer(), 2.0);

  ofToBind.beginDraw();
  //ofToBind.tint(255, 100);
  ofToBind.clear();
  ofToBind.blendMode(REPLACE);
  ofToBind.image(ofFilters.getBuffer(), 0, 0, ofToBind.width, ofToBind.height);
  ofToBind.endDraw();
  ppb.swap();//Swap the buffer for the next loop
}

void keyPressed() {
  switch(key) {
  case 'r':
  case 'R':
    drawTextureIntoPingPongBuffer(velBuffer, encodedVelBuffer);
    drawTextureIntoPingPongBuffer(posBuffer, encodedPosBuffer);
    break;
  case 'd' :
  case 'D' :
    debug = !debug;
    break;
  case 'p' :
  case 'P' :
    pause = !pause;
    break;
  case 'e' :
  case 'E' :
    startExport();
    break;
  case 's' :
  case 'S' :
    String name = year()+""+month()+""+day()+"--"+hour()+"-"+minute()+"-"+second()+"_GPGPUParticleSystem";
    filter.getBuffer().save(name+".tiff");
    break;
  case 'l' : 
  case 'L' : 
    isLive = !isLive;
    break;
  }
}
