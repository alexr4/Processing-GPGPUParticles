# Simple GPGPU 2D Simulation

This repository presents various experiments on GPGPU particles simulation made at the studio Bonjour lab.
All simulation is done in GPU side using texture to encode/decode position and physics simulation.
It contains the following elements : 

* GPU2DPhysicsSimulationCLEANED : simple template for GPGPU simulation using [GPUImage library](https://github.com/Bonjour-Interactive-Lab/Processing-GPUImage) and [FPSTracker library](https://github.com/Bonjour-Interactive-Lab/Processing-FPSTracker)
* GPU2DPhysicsSimulation_COLLISION : collision with background using screen-space collision
* GPU2DPhysicsSimulation_DSLRTexture : using canon DSLR as source image input
* GPU2DPhysicsSimulation_KINECTCOLLIDE : using kinect as source image for collision
* GPU2DPhysicsSimulation_KINECTCOLLIDERAIN : Water fall experiment
* GPU2DPhysicsSimulation_WEBCAM : using webcam as source image
* GPU2DPhysicsSimulation_WEBCAMOpticalFlow : using webcam as source image + optical flow to update particles movement according to webcam
