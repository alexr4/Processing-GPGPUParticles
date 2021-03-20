#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif
uniform sampler2D ramp;

in vec4 vertColor;
in vec4 vertTexCoord;
in vec2 texCoord;
in float angle;
in float speed;

out vec4 fragColor;


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

  vec2 uv = texCoord * 2.0 - 1.0;
  uv = rotate2d(angle) * uv;
  uv = uv * 0.5 + 0.5;

  float rectSDF = rectangleSDF(uv, vec2(1.0, 0.2));
  float filled = fill(rectSDF, 0.75, 0.5);

  vec4 color = vec4(vec3(filled), filled * vertColor.a * 0.25);// * (1.0 - uv.x) );
  color.rgb *= rgb;
  fragColor = color;
}