#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif
uniform sampler2D ramp;
uniform float time;

in vec4 vertColor;
in vec4 vertTexCoord;
in vec2 texCoord;
in float angle;
in float speed;

out vec4 fragColor;

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

mat2 rotate2d(float angle){
  return mat2(cos(angle), -sin(angle),
              sin(angle),  cos(angle));
}

float rectangleSDF(vec2 st, vec2 thickness){
  //remap st coordinate from 0.0 to 1.0 to -1.0, 1.0
  st = st * 2.0 - 1.0;
  float edgeX = abs(st.x / thickness.x);
  float edgeY = abs(st.y / thickness.y);
  return max(edgeX, edgeY);
}

float stroke(float x, float s, float w){
  float d = step(s, x + w * 0.5) - step(s, x - w * 0.5);
  return clamp(d, 0.0, 1.0);
}

float fill(float x, float size, float smoothness){
  return 1.0 - smoothstep(size - smoothness * 0.5, size + smoothness * 0.5, x);
}

void main() {
  vec3 rgb = texture2D(ramp, vec2(vertColor.r, 0.5)).rgb;

  float noised = noise(vertColor.xy * 100.0 + time * 0.1);
  float minThickness = 0.05;
  float maxThickness = 0.5;
  float thickness = mix(minThickness, maxThickness, noised);

  vec2 uv = texCoord * 2.0 - 1.0;
  uv = rotate2d(angle) * uv;
  uv = uv * 0.5 + 0.5;

  float rectSDF = rectangleSDF(uv, vec2(1.0, thickness));
  float circSDF = length(vec2(0.5) - uv);
  float filled = fill(rectSDF, 0.45, 0.75);

  vec4 color = vec4(vec3(1.0), filled * vertColor.a);// * (1.0 - uv.x) );
  color.rgb *= rgb;

  fragColor = color;
}