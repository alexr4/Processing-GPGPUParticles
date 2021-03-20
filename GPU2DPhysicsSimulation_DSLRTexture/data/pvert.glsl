#ifdef GL_ES
precision highp float;
precision highp vec2;
precision highp vec3;
precision highp vec4;
precision highp int;
#endif
#define PI 3.14159265359

const vec4 efactor = vec4(1.0, 255.0, 65025.0, 16581375.0);
const vec4 dfactor = vec4(1.0/1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0);
const float mask = 1.0/256.0;

uniform mat4 projection;
uniform mat4 modelview;

uniform sampler2D originBuffer;
uniform sampler2D posBuffer;
uniform sampler2D massBuffer;
uniform sampler2D lifeBuffer;
uniform sampler2D offsetTimeBuffer;
uniform sampler2D velBuffer;
uniform sampler2D maxVelBuffer;
uniform vec2 worldResolution = vec2(1280, 720);
uniform vec2 bufferResolution;
uniform vec2 resolution;
uniform float maxMass;
uniform float minMass;
uniform float maxVel;
uniform float minVel;
uniform float maxLifeTime;
uniform float time;

in vec4 position;
in vec4 color;
in vec2 offset;

out vec4 vertColor;
out vec4 vertTexCoord;
out vec2 texCoord;
out float angle;
out float speed;
out vec2 normPosition;

float random (vec2 st) {
    return fract(sin(dot(st.xy, vec2(10.9898,78.233)))*43758.5453123);
}


float decodeRGBA16(vec2 rg){
  return dot(rg, dfactor.rg);
}

vec2 decodeRGBA16(vec4 rgba){
  return vec2(decodeRGBA16(rgba.rg), decodeRGBA16(rgba.ba));
}

float decodeRGBA32(vec4 rgba){
	return dot(rgba, dfactor.rgba);
}

vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

void main(){
	/*
	//Old method using RGBA color to retrive index
	float index = decodeRGBA32(color) * (bufferResolution.x * bufferResolution.y);
	float x = mod(index, bufferResolution.x);
	float y = (index - x) / bufferResolution.x;
	vec2 uv = vec2(x, y) / bufferResolution;
	vertTexCoord = vec4(uv, 0.0, 1.0);
	*/

	vertTexCoord.xy = position.xy / bufferResolution.xy;

	vertTexCoord.zw = vec2(0.0, 1.0);

   	//get the data into texture
   	vec4 posRGBA = texture(posBuffer, vertTexCoord.xy);
	vec4 oposRGBA = texture(originBuffer, vertTexCoord.xy);
	vec4 velRGBA = texture(velBuffer, vertTexCoord.xy);
	vec4 maxVelRGBA = texture(maxVelBuffer, vertTexCoord.xy);
   	vec4 massRGBA = texture(massBuffer, vertTexCoord.xy);
	vec4 maxLifeRGBA = texture(lifeBuffer, vertTexCoord.xy);
	vec4 offsetTimeRGBA = texture(offsetTimeBuffer, vertTexCoord.xy);

  	//decode the data 
  	vec2 pos = decodeRGBA16(posRGBA) * worldResolution - (worldResolution - resolution) * 0.5;
	float edgeVel = mix(minVel, maxVel, decodeRGBA32(maxVelRGBA));
	vec2 vel = (decodeRGBA16(velRGBA) * 2.0 - 1.0) * edgeVel;
	vec2 nextPos = pos + vel;
	float nmass = decodeRGBA32(massRGBA);
	float maxLife = decodeRGBA32(maxLifeRGBA) * maxLifeTime;
	float offsetTime = decodeRGBA32(offsetTimeRGBA) * maxLifeTime;
	speed = length(vel) / edgeVel;

  	vec2 opos = decodeRGBA16(oposRGBA) * worldResolution;// - (worldResolution - resolution) * 0.5;
	normPosition = opos / worldResolution;
	normPosition = clamp(normPosition, vec2(0), vec2(1.0));

	//angle
	vec2 toNext   	= nextPos - pos;//normalize(nextPos) - normalize(pos);
  	float radius    = length(toNext);
  	angle     		= atan(toNext.y, toNext.x) + PI;
	
	float life = (mod(time + offsetTime, maxLife) / maxLife);
  	float mass = minMass + nmass * (maxMass - minMass);
	float alpha = abs(life * 2.0 - 1.0);

	vec4 clip = projection * modelview * vec4(pos, 0, 1); //we scale the pos to avoid sketch edges
	vec2 weight = vec2(alpha * 10.0);
	gl_Position = clip + projection * vec4(offset.xy * weight, 0, 0);

	
	texCoord = vec2(0.5) + offset.xy;

	// vec3 col = pal( life, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20) );
	//vec3 col = mix(vec3(0.0, 1.0, 0.6157), vec3(0.9098, 0.9255, 1.0), life);
	float index = random(position.xy);
	vec3 col = vec3(index);
	vertColor = vec4(col, alpha);
}