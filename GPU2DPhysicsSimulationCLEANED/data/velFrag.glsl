#ifdef GL_ES
precision highp float;
precision highp vec4;
precision highp vec3;
precision highp vec2;
precision highp int;
#endif
#define PI 3.1415926535897932384626433832795
#define TWOPI (PI * 2.0)

const vec4 efactor = vec4(1.0, 255.0, 65025.0, 16581375.0);
const vec4 dfactor = vec4(1.0/1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0);
const float mask = 1.0/256.0;

uniform sampler2D texture;
uniform sampler2D posBuffer;
uniform sampler2D massBuffer;
uniform sampler2D maxVelBuffer;
uniform vec2 worldResolution;
uniform float minVel;
uniform float maxVel;
uniform float maxMass;
uniform float minMass;
uniform vec2 gravity = vec2(0.0, 0.1);
uniform vec2 wind = vec2(0.0, 0.0);
uniform vec2 normMouse;
uniform float time;

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

vec2 random2D(vec2 uv){
  uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float cubicCurve(float value){
  return value * value * (3.0 - 2.0 * value); // custom cubic curve
}

vec2 cubicCurve(vec2 value){
  return value * value * (3.0 - 2.0 * value); // custom cubic curve
}

vec3 cubicCurve(vec3 value){
  return value * value * (3.0 - 2.0 * value); // custom cubic curve
}

float noise(vec2 uv){
  vec2 iuv = floor(uv);
  vec2 fuv = fract(uv);
  vec2 suv = cubicCurve(fuv);

  float dotAA_ = dot(random2D(iuv + vec2(0.0)), fuv - vec2(0.0));
  float dotBB_ = dot(random2D(iuv + vec2(1.0, 0.0)), fuv - vec2(1.0, 0.0));
  float dotCC_ = dot(random2D(iuv + vec2(0.0, 1.0)), fuv - vec2(0.0, 1.0));
  float dotDD_ = dot(random2D(iuv + vec2(1.0, 1.0)), fuv - vec2(1.0, 1.0));

  return mix(
    mix(dotAA_, dotBB_, suv.x),
    mix(dotCC_, dotDD_, suv.x),
    suv.y);
}

//	Simplex 3D Noise 
//	by Ian McEwan, Ashima Arts
//
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C 
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0/7.0; // N=7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
}

vec3 snoiseVec3(vec3 x){

  float s  = snoise(vec3(x));
  float s1 = snoise(vec3( x.y - 19.1 , x.z + 33.4 , x.x + 47.2 ));
  float s2 = snoise(vec3( x.z + 74.2 , x.x - 124.5 , x.y + 99.4 ));
  vec3 c = vec3( s , s1 , s2 );
  return c;
}

vec3 curlNoise( vec3 p ){
  
  const float e = .1;
  vec3 dx = vec3( e   , 0.0 , 0.0 );
  vec3 dy = vec3( 0.0 , e   , 0.0 );
  vec3 dz = vec3( 0.0 , 0.0 , e   );

  vec3 p_x0 = snoiseVec3( p - dx );
  vec3 p_x1 = snoiseVec3( p + dx );
  vec3 p_y0 = snoiseVec3( p - dy );
  vec3 p_y1 = snoiseVec3( p + dy );
  vec3 p_z0 = snoiseVec3( p - dz );
  vec3 p_z1 = snoiseVec3( p + dz );

  float x = p_y1.z - p_y0.z - p_z1.y + p_z0.y;
  float y = p_z1.x - p_z0.x - p_x1.z + p_x0.z;
  float z = p_x1.y - p_x0.y - p_y1.x + p_y0.x;

  const float divisor = 1.0 / ( 2.0 * e );
  return normalize( vec3( x , y , z ) * divisor );

}

#define OCTAVE 6
void rotateNoiseIteration(inout vec2 noiseForce,inout float noiseAngle){
	for(int i=0; i<OCTAVE; i++){
		noiseAngle=snoise(vec3(noiseForce, time * 0.1))*PI;
		noiseForce=vec2(
			cos(noiseAngle),
			sin(noiseAngle)
		) * 0.5;
	}
}

float fbm(in vec3 pos) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.5;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVE; i++) {
        value += amplitude * snoise(pos);
        pos *= 2.;
        amplitude *= frequency;
    }
    return value;
}

vec2 fbmCurl(in vec3 pos) {
    // Initial values
    vec2 value = vec2(0.0);
    float amplitude = .5;
    float frequency = 0.5;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVE; i++) {
        value += amplitude * curlNoise(pos).xy;
        pos *= 2.;
        amplitude *= frequency;
    }
    return value;
}

void main() {
	vec4 velRGBA = texture(texture, vertTexCoord.xy);
	vec4 posRGBA = texture(posBuffer, vertTexCoord.xy);
	vec4 massRGBA = texture(massBuffer, vertTexCoord.xy);
	vec4 maxVelRGBA = texture(maxVelBuffer, vertTexCoord.xy);

	vec2 acc = vec2(0.0);
	float edgeVel = mix(minVel, maxVel, decodeRGBA32(maxVelRGBA));
	vec2 vel = (decodeRGBA16(velRGBA) * 2.0 - 1.0) * edgeVel; //we remap vel from  [0, 1] to [-1, 1] in order to have velocity in both side -x/+x -y/+y
	vec2 loc = decodeRGBA16(posRGBA) * worldResolution; //we remap the position from [0, 1] to [0, worldspace]	
	float mass = mix(minMass, maxMass, decodeRGBA32(massRGBA)); //we remap the mass from [0, 1] to [minMass, maxMass]

	//define friction
	float coeff = 0.015;//0.35;
	vec2 friction = normalize(vel * -1.0) * coeff;

/*	float noiseAngle = snoise(vec3(loc * 0.5 * 0.01, time * 0.1)) * PI;
	//float noiseAngle = snoise(vec3((loc/worldResolution) * (normMouse.x * 10.0), time * 0.1)) * PI;
	//float noiseAngle = fbm(vec3((loc/worldResolution) * (normMouse.x * 10.0), time * 0.1)) * TWOPI;
	vec2 noiseForce = vec2(
		cos(noiseAngle),
		sin(noiseAngle)
	);
	rotateNoiseIteration(noiseForce, noiseAngle);

	noiseForce *= edgeVel;*/
  float res = worldResolution.x / worldResolution.y;
  vec3 force3D = curlNoise(vec3(loc * vec2(1.0, res) + time, time) * 0.0015);
  // vec2 fbmcurl = fbmCurl(vec3(loc, time) *  vec3(vec2(0.001), 0.01));
  vec2 noiseForce = force3D.xy;

	//add forces
	acc += wind/mass;
	acc += (noiseForce / mass);
	acc += (friction / mass);
	// acc += gravity;

	//add acc to velocity
	vel += acc;
	vel = clamp(vel, -vec2(edgeVel), vec2(edgeVel)); //clamp velocity to max force


	//add vel to location
	loc += vel;

	vel /= edgeVel; //we normalize velocity
	vel = (vel * 0.5) + 0.5; //reset it from[-1, 1] to [0.0, 1.0]
	vel = clamp(vel, vec2(0), vec2(1.0)); //we clamp the velocity between [0, 1] (this is a security)

	//we encode the new velocuty as RGBA1616
	vec4 newPosEncoded = vec4(encodeRGBA16(vel.x), encodeRGBA16(vel.y));

  	fragColor = newPosEncoded;
}