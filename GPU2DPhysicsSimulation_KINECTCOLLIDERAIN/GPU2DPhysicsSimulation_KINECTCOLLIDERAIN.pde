import fpstracker.core.*;
import gpuimage.core.*;
import gpuimage.utils.*;
import KinectPV2.*;
import spout.*;
import org.json.JSONObject;
import org.json.JSONArray;

public JSONObject config;
String subPath = "appData/";
Spout spout;


PerfTracker pt;
int nbParticles;

float res = 4.0;
int targetWidth = 1920;
int targetHeight = 1080;
int particlesTargetWidth, particlesTargetHeight;

PImage stencilImg;


PGraphics stencil;
Filter normalMap;
PShader normalShader;

//destination buffer
PGraphics fbuffer;

//post-process
int HISTORY_SIZE = 10;
PGraphics rainBuffer;
PShader FXAA;
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

int windowX       = 0;
int windowY       = 0;
int windowWidth   = 1080;
int windowHeight  = 1920;
int displayRes    = 4;
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
    res = (float) config.getJSONObject("app").getInt("resolution");
  } 
  catch (Exception e) {
    e.printStackTrace();
  }

  pt = new PerfTracker(this, 120);

  stencilImg = loadImage(subPath+"stencil.png");
  stencil = createGraphics(targetWidth, targetHeight, P2D);
  normalShader = loadShader(subPath+"NormalMapping.glsl");
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
  lut = loadImage(subPath+"lut-4.png");
  ramp = loadImage(subPath+"ramp-12.png");


  FXAA = loadShader(subPath+"fxaa.glsl");

  ((PGraphicsOpenGL)fbuffer).textureSampling(3);
  fbuffer.hint(DISABLE_TEXTURE_MIPMAPS);

  fbuffer.smooth(8);

  fbuffer.beginDraw();
  fbuffer.background(0);
  fbuffer.endDraw();

  rainBuffer = createGraphics(targetWidth, targetHeight, P2D);
  
  spout = new Spout(this);
  spout.createSender(appName);

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
    float nmx = (float)mouseX/width;
    float nmy = (float)mouseY/height;

    if (!pause) {
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
      velFrag.set("wind", (noise(timeUpdate * 0.01) * 2.0 - 1.0) * 0.05, 0.0);
      velFrag.set("gravity", 0.0, 1.0);
      velFrag.set("posBuffer", posBuffer.getSrcBuffer());
      velFrag.set("normalBuffer", normalMap.getBuffer());
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
    psh.set("maxSize", 50.0);

    //display the particles system
    fbuffer.beginDraw();
    fbuffer.background(0);
    //fbuffer.image(background, 0, 0, fbuffer.width, fbuffer.height);
    fbuffer.shader(psh);
    fbuffer.shape(particles);
    fbuffer.resetShader();
    fbuffer.endDraw();

    rainBuffer.beginDraw();
    rainBuffer.tint(255, 255.0/HISTORY_SIZE);
    rainBuffer.image(fbuffer, 0, 0, rainBuffer.width, rainBuffer.height);
    rainBuffer.endDraw();


    ////Post-Process
    postProcess();
    //// tint(255, 10);
    // //image(rainBuffer, 0, 0, width, height);
    image(filter.getBuffer(), 0, 0, width, height);
    spout.sendTexture(filter.getBuffer());
    //image(kinect.getBodyTrackImage(), 0, 0);


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
      image(normalMap.getBuffer(), 0, height - stencil.height * 0.25 / displayRes, stencil.width * 0.25 / displayRes, stencil.height * 0.25 / displayRes);
      image(fkinect.getBuffer(), stencil.width * 0.25 / displayRes, height - fkinect.getBuffer().height * 0.25 / displayRes, fkinect.getBuffer().width * 0.25 / displayRes, fkinect.getBuffer().height * 0.25 / displayRes);

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
    rainBuffer.save(name+"_Based.tiff");
    break;
  }
}
