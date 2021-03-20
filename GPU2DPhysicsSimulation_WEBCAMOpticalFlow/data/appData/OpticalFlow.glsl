#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif
#define PI 3.1415926535897932384626433832795

const vec4 efactor = vec4(1.0, 255.0, 65025.0, 16581375.0);
const vec4 dfactor = vec4(1.0/1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0);
const float mask = 1.0/256.0;

uniform sampler2D previousFrame;
uniform sampler2D texture;
uniform float threshold = 0.01; //framedifferencing Threshold
uniform float offsetInc = 0.1;
uniform vec2 offset = vec2(1.0, 1.0); //offset for sobel Operation
uniform float lambda = 0.1;
uniform vec2 scale = vec2(1.0, 1.0);
uniform vec2 resolution = vec2(1.0, 1.0);

in vec4 vertTexCoord;
in vec4 vertColor;
out vec4 fragColor;

vec4 packFlowAsColor(float fx ,float fy, vec2 scale){
	vec2 flowX = vec2(max(fx, 0.0), abs(min(fx, 0.0))) * scale.x;
	vec2 flowY = vec2(max(fy, 0.0), abs(min(fy, 0.0))) * scale.y;
	float dirY = 1.0;
	if(flowY.x > flowY.y){
		dirY = 0.9;
	}
	vec4 rgbaPacked = vec4(flowX.x, flowX.y, max(flowY.x, flowY.y), dirY);

	return rgbaPacked;
}

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

vec4 getGray(vec4 inputPix){
	float gray = dot(vec3(inputPix.x, inputPix.y, inputPix.z), vec3(0.3, 0.59, 0.11));
	return vec4(gray, gray, gray, 1.0);
}

vec4 getGrayTexture(sampler2D tex, vec2 texCoord){
	return getGray(texture2D(tex, texCoord));
}

vec4 getGradientAt(sampler2D current, sampler2D previous, vec2 texCoord, vec2 offset){
	vec4 gradient = getGrayTexture(previous, texCoord + offset) - getGrayTexture(previous, texCoord - offset);
	gradient += getGrayTexture(current, texCoord + offset) - getGrayTexture(current, texCoord - offset);
	return gradient;
}

void main()
{
	vec2 texel = vec2(1.0) / resolution.xy;
	vec4 current = texture(texture, vertTexCoord.st);
	vec4 previous = texture(previousFrame, vertTexCoord.st);
	
	vec2 offsetX = vec2(offset.x * texel.x, 0.0);//offsetInc
	vec2 offsetY = vec2(0.0, offset.y * texel.y);

	//Frame Differencing (dT)
	vec4 differencing = previous - current;
	float vel = (differencing.r + differencing.g + differencing.b)/3;
	float movement = smoothstep(threshold, 1.0, vel);
	vec4 newDifferencing = vec4(movement);
	//movement = pow(movement, 1.0);


	//Compute the gradient (movement Per Axis) (look alike sobel Operation)
	vec4 gradX = getGradientAt(texture, previousFrame, vertTexCoord.st, offsetX);
	vec4 gradY = getGradientAt(texture, previousFrame, vertTexCoord.st, offsetY);

	//Compute gradMagnitude
	vec4 gradMag = sqrt((gradX * gradX) + (gradY * gradY) + vec4(lambda));

	//compute Flow
	vec4 vx = newDifferencing * (gradX / gradMag);
	vec4 vy = newDifferencing * (gradY / gradMag);

	vec4 flowCoded = packFlowAsColor(vx.r, vy.r, scale);
	//flowCoded = encodeRGBA1616(vec2(vx.x, vy.x) * 0.5 + 0.5);

	fragColor = flowCoded;
}
