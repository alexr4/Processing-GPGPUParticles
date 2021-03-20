
//GPGPU objects
Vec2Packing vp;
FloatPacking fp;
PingPongBuffer posBuffer, velBuffer;
PImage encodedPosBuffer, encodedVelBuffer, encodedMassBuffer, encodedMaxVelBuffer;
PShader posFrag, velFrag;
PImage encodedPosBufferOrigin, encodedVelBufferOrigin, encodedLifeBuffer, encodedOffsetTimeBuffer;

//Particles variables
PShape particles;
PShader psh;

public static class PARTICLES{
    public static float minVel = 2.5;
    public static float maxVel = 5.0;
    
    public static float minMass = 1.0;
    public static float maxMass = 1.0;
    
    public static PVector worldResolution;
    public static float worldMultiplicator = 1.15;

    public static void initWorld(float w, float h){
        worldResolution = new PVector(w, h);
        worldResolution.mult(worldMultiplicator);
    }
}