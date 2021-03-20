#ifdef GL_ES
precision highp float;
precision highp vec4;
precision highp vec3;
precision highp vec2;
precision highp int;
#endif

const vec4 efactor = vec4(1.0, 255.0, 65025.0, 16581375.0);
const vec4 dfactor = vec4(1.0/1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0);
const float mask = 1.0/256.0;

uniform sampler2D texture;
uniform sampler2D velBuffer;
uniform sampler2D lifeBuffer;
uniform sampler2D offsetTimeBuffer;
uniform sampler2D originBuffer;
uniform float maxLifeTime;
uniform float time;
uniform vec2 worldResolution;
uniform sampler2D maxVelBuffer;
uniform float minVel;
uniform float maxVel;

in vec4 vertColor;
in vec4 vertTexCoord;

out vec4 fragColor;

vec2 encodeRGBA16(float v){
	vec2 rg = v * efactor.rg;
	rg.g = fract(rg.g);
	rg.r -= rg.g * mask;
	return vec2(rg);
}

vec4 encodeRGBA1616(vec2 xy){
	vec4 encodedData = vec4(encodeRGBA16(xy.x), encodeRGBA16(xy.y));
	encodedData.a = 1.0;
	return encodedData;
}

vec2 decodeRGBA16(vec4 rgba){
	return vec2(dot(rgba.rg, dfactor.rg), dot(rgba.ba, dfactor.rg));
}

float decodeRGBA32(vec4 rgba){
	return dot(rgba, dfactor.rgba);
}

void main() {
	vec4 prevPosRGBA = texture(texture, vertTexCoord.xy);
	vec4 velRGBA = texture(velBuffer, vertTexCoord.xy);
	vec4 maxVelRGBA = texture(maxVelBuffer, vertTexCoord.xy);
	vec4 maxLifeRGBA = texture(lifeBuffer, vertTexCoord.xy);
	vec4 offsetTimeRGBA = texture(offsetTimeBuffer, vertTexCoord.xy);
	vec4 originRGBA = texture(originBuffer, vertTexCoord.xy);

	vec2 loc = decodeRGBA16(prevPosRGBA) * worldResolution;
	vec2 origin = decodeRGBA16(originRGBA) * worldResolution;
	float edgeVel = mix(minVel, maxVel, decodeRGBA32(maxVelRGBA));
	//we remap vel from  [0, 1] to [-1, 1] in order to have -1.0 * velocity
	vec2 vel = (decodeRGBA16(velRGBA) * 2.0 - 1.0) * edgeVel;
	float maxLife = decodeRGBA32(maxLifeRGBA) * maxLifeTime;
	float offsetTime = decodeRGBA32(offsetTimeRGBA) * maxLifeTime;
	
	float life = (mod(time + offsetTime, maxLife) / maxLife);

	loc += vel;

	if(life <= 0.01){
		loc = origin;
	}

	// vec2 LtoM = loc - mouse;
	// float d = length(LtoM);
	// float edgeObstacle = 1.0 - step(mouseSize * 0.5, d);
	// vec2 edgePos = mouse + normalize(LtoM) * (mouseSize * 0.5);
	// loc = edgePos * edgeObstacle + loc * (1.0 - edgeObstacle);

	//edge
	//loc = mod(loc, worldResolution);
	loc /= worldResolution;// - vec2(0.0, 0.1); //we reduce the world position of 0.1 in order to avoid infinite bounce on the ground
	//loc = clamp(loc, 0.0, 1.0);

	vec4 newPosEncoded = vec4(encodeRGBA16(loc.x), encodeRGBA16(loc.y));

  	fragColor = newPosEncoded;
}