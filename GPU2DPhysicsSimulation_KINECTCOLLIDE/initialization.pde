//load shaders for GPGPU simulation
void loadShaders(){
    posFrag = loadShader("posFrag.glsl");
    velFrag = loadShader("velFrag.glsl");
    psh = loadShader("pfrag.glsl", "pvert.glsl");
}

void initPackingSystem(){
    vp = new Vec2Packing(this);
    fp = new FloatPacking(this);
}

void initGPGPU(int w, int h) {
    //create a array of random value between 0 and 1
    PVector[] firstPosData = getRandomData(w, h, (int)random(4, 12));
    PVector[] firstVelData = getVelData(w, h);
    float[] massData = getMassData(w, h);
    float[] maxVelData = getMassData(w, h);
    float[] lifeData = getRandom1DData(w, h, 0.25, 1.0);
    float[] offsetTimeData = getRandom1DData(w, h, 0.0, 1.0);

    //creates buffers and feed with data
    encodedPosBuffer = vp.encodeARGB(firstPosData);
    encodedVelBuffer = vp.encodeARGB(firstVelData);
    encodedMassBuffer = fp.encodeARGB32Float(massData);
    encodedMaxVelBuffer = fp.encodeARGB32Float(maxVelData);
    encodedLifeBuffer = fp.encodeARGB32Float(lifeData);
    encodedOffsetTimeBuffer = fp.encodeARGB32Float(offsetTimeData);

    //Create two ping pong buffer (one for each pos and vel buffer)
    posBuffer = new PingPongBuffer(this, encodedPosBuffer.width, encodedPosBuffer.height, P2D);
    velBuffer = new PingPongBuffer(this, encodedVelBuffer.width, encodedVelBuffer.height, P2D);

    //set the filtering
    posBuffer.setFiltering(3);
    posBuffer.enableTextureMipmaps(false);
    velBuffer.setFiltering(3);
    velBuffer.enableTextureMipmaps(false);

    drawTextureIntoPingPongBuffer(velBuffer, encodedVelBuffer);
    drawTextureIntoPingPongBuffer(posBuffer, encodedPosBuffer);

    //copy the vel and pos origin for reset
    encodedPosBufferOrigin = encodedPosBuffer.copy();
    encodedVelBufferOrigin = encodedVelBuffer.copy();

    createBasedParticlesShape(firstPosData);

    //bind data to shaders
    bindBasedDataToVelShader();
    bindBasedDataToPosShader();
    bindBasedDataToParticlesShader();
}

public void createBasedParticlesShape(PVector[] firstPosData){
 //create grid of particles
  particles = createShape();
  particles.beginShape(POINTS);
  particles.strokeWeight(1); 
  particles.strokeCap(SQUARE); //define cap as SQUARE to have a Squared billboard
  for (int i=0; i<firstPosData.length; i++) {
    float x = i % encodedPosBuffer.width;
    float y = (i - x) / encodedPosBuffer.width;
    //decomment this lines if you want to see the color of each particle as its index
    double normi =(double)i / (double)firstPosData.length;
    int indexColor = vp.doubleToARGB32(normi);
    particles.stroke(indexColor);
    particles.vertex(x, y);
  }
  particles.endShape();
}

public void bindBasedDataToVelShader(){
    velFrag.set("massBuffer", encodedMassBuffer);
    velFrag.set("maxVelBuffer", encodedMaxVelBuffer);
    velFrag.set("worldResolution", (float) PARTICLES.worldResolution.x, (float) PARTICLES.worldResolution.y);
    velFrag.set("maxMass", PARTICLES.maxMass);
    velFrag.set("minMass", PARTICLES.minMass);
    velFrag.set("minVel", PARTICLES.minVel);
    velFrag.set("maxVel", PARTICLES.maxVel);
    velFrag.set("lifeBuffer", encodedLifeBuffer);
    velFrag.set("offsetTimeBuffer", encodedOffsetTimeBuffer);
}

public void bindBasedDataToPosShader(){
    posFrag.set("maxVelBuffer", encodedMaxVelBuffer);
    posFrag.set("lifeBuffer", encodedLifeBuffer);
    velFrag.set("offsetTimeBuffer", encodedOffsetTimeBuffer);
    posFrag.set("originBuffer", encodedPosBufferOrigin);
    posFrag.set("worldResolution", (float) PARTICLES.worldResolution.x, (float) PARTICLES.worldResolution.y);
    posFrag.set("minVel", PARTICLES.minVel);
    posFrag.set("maxVel", PARTICLES.maxVel);
}

public void bindBasedDataToParticlesShader(){
    //set the variable to the particles vert/frag shader
    psh.set("worldResolution", (float) PARTICLES.worldResolution.x, (float) PARTICLES.worldResolution.y);
    psh.set("resolution", (float) width, (float) height);
    psh.set("bufferResolution", (float)encodedPosBuffer.width, (float)encodedPosBuffer.height);
    psh.set("ramp", ramp);
    psh.set("maxVelBuffer", encodedMaxVelBuffer);
    psh.set("minVel", PARTICLES.minVel);
    psh.set("maxVel", PARTICLES.maxVel);
    psh.set("maxMass", PARTICLES.maxMass);
    psh.set("minMass", PARTICLES.minMass);
    psh.set("massBuffer", encodedMassBuffer);
    psh.set("lifeBuffer", encodedLifeBuffer);
    psh.set("offsetTimeBuffer", encodedOffsetTimeBuffer);
}
