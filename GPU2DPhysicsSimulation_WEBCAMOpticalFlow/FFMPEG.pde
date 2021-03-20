import com.hamoid.*;

VideoExport videoExport;
ControlledTime videoTime;

static class FFMPEGParams {
  static boolean export = false;
  static String filename = "export";
  static int exportTime = 30000;
  static int videoQuality = 100;
  static int audioQuality = 64;
  static int FPS = 60;
  static boolean debugOutput = false;
}

void initFFMPEG(PGraphics target) {
  videoTime = new ControlledTime();
  videoExport = new VideoExport(this, FFMPEGParams.filename+".mp4", target); 
  videoExport.setQuality(FFMPEGParams.videoQuality, FFMPEGParams.audioQuality);
  videoExport.setFrameRate(FFMPEGParams.FPS);
  videoExport.setDebugging(FFMPEGParams.debugOutput);
}

void startExport(){
  if (!FFMPEGParams.export) {
      FFMPEGParams.export = true;
      Time.resetTimeForExport(this);
      videoTime.resetTimeForExport();

      videoExport.startMovie();
    }
}

void exportVideo() {
  if (FFMPEGParams.export) {
    videoTime.update(false);
    videoTime.computeTimeAnimation(FFMPEGParams.exportTime);
    if (videoTime.timeLoop == 0) {
      videoExport.saveFrame();
    } else {
      videoExport.endMovie();
      FFMPEGParams.export = false;
    }

    String uiExportProgress = "FFMPEG export: "+round(videoTime.normTime * 100)+"%";
    float headerWidth = width;
    float headerHeight = height/10;
    float progressWidth = width * 0.95;
    float pogressHeight = headerHeight * 0.15;
    float yOffset = 10;
    color headerColor = color(255, 200, 0);
    color progressColor = color(255, 127, 0);

    pushStyle();
    fill(headerColor);
    noStroke();
    rectMode(CENTER);
    rect(width/2, height/2, headerWidth, headerHeight);
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(14);
    text(uiExportProgress, width/2, height/2 - yOffset);
    stroke(progressColor);
    noFill();
    rect(width/2, height/2 + yOffset, progressWidth, pogressHeight);
    fill(progressColor);
    noStroke();
    rect(width/2, height/2 + yOffset, progressWidth * videoTime.normTime, pogressHeight);
    popStyle();
  }
}
