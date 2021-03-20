#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D ramp;
uniform sampler2D dslrTexture;

in vec4 vertColor;
in vec4 vertTexCoord;
in vec2 texCoord;
in float angle;
in float speed;
in float life;
in vec2 normPosition;

out vec4 fragColor;

float random (vec2 st) {
    return fract(sin(dot(st.xy, vec2(10.9898,78.233)))*43758.5453123);
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
  vec3 rgb = texture2D(ramp, vec2(vertColor.x, 0.5)).rgb;
  vec3 dslrRGB = texture2D(dslrTexture, vec2(normPosition.x, 1.0 - normPosition.y)).rgb;

  vec2 uv = texCoord * 2.0 - 1.0;
  uv = rotate2d(angle) * uv;
  uv = uv * 0.5 + 0.5;

  // float rndSize = mix(0.25, 0.5, random(vertTexCoord.xy));
  float minSize = 0.0;
  float width = mix(minSize, 1.0, speed);
  float height = mix(minSize, 0.25, speed);
  float rectSDF = rectangleSDF(uv, vec2(width, height));
  float filled = fill(rectSDF, 0.75, 0.5);

  vec4 color = vec4(vec3(filled), filled * vertColor.a * 0.25);// * (1.0 - uv.x) );
  color.rgb = dslrRGB;
  color.a = vertColor.a * filled * life;
  fragColor = color;
}