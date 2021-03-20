import java.util.Map;

void drawDebugUI(float x, float y, float w, float h, float res){
    int cols = floor(w/res);
    int rows = floor(h/res);
    HashMap<String, PImage> list = getBuffers();

    int i = 0;
    int iw = 0;
    float uihs = 0.1;
    noStroke();
    textAlign(CENTER, CENTER);
    for (Map.Entry me : list.entrySet()) {
        float ix = i % cols;
        float iy = (i - ix) / cols;
        String name = (String) me.getKey();
        PImage img = (PImage)me.getValue();


        fill(0);
        rect(ix * res + x, iy * res + y, res, res);
        image(img, ix * res + x, iy * res + y, res, res);
        fill(0, 100);
        rect(ix * res + x, iy * res + y, res, res * uihs);
        fill(255);
        text(name, ix * res + x + 4, iy * res + y, res, res * uihs);

        i++;
    }

}

HashMap<String, PImage> getBuffers(){
    HashMap<String, PImage> list = new HashMap<String, PImage>();

    list.put("PosBuffer", posBuffer.getDstBuffer());
    list.put("VelBuffer", velBuffer.getDstBuffer());
    list.put("MassBuffer",encodedMassBuffer);
    list.put("MaxVelBuffer",encodedMaxVelBuffer);
    list.put("LifeBuffer",encodedLifeBuffer);
    list.put("OffsetLifeBuffer",encodedOffsetTimeBuffer);

    return list;
}
