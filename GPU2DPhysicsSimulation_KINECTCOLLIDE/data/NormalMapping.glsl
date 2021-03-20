//Sobel-Filter normal mapping from : http://www.gamedev.net/topic/594457-calculate-normals-from-a-displacement-map/

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D texture;

in vec2 texOffset;
in vec4 vertColor;
in vec4 vertTexCoord;

//Scharr operator constants combined with luminance weights
uniform float sobel1Scale = 1.0;
uniform float sobel2Scale = 1.0;
//const vec3 Sobel1 = vec3(0.2990, 0.5870, 0.1140) * vec3(sobel1Scale);
//const vec3 Sobel2 = vec3(0.2990, 0.5870, 0.1140) * vec3(sobel2Scale);

//Luminance weights, scaled by the average of 3x3 normalised kernel weights (including zeros)
uniform float luminanceScale = 0.355556;
const vec3 Lum = vec3(0.2990, 0.5870, 0.1140) * vec3(luminanceScale);

//Blur level (mip map LOD bias)
uniform float Blur  = 0.0; 

out vec4 fragColor;


vec4 Desaturate(vec3 color, float Desaturation)
{
	vec3 grayXfer = vec3(0.3, 0.59, 0.11);
	vec3 gray = vec3(dot(grayXfer, color));
	return vec4(mix(color, gray, Desaturation), 1.0);
}

void main()
{
	vec4 texColor = texture2D(texture, vertTexCoord.st).rgba;

	vec2 d = vec2(dFdx(vertTexCoord.s), dFdy(vertTexCoord.t)); //offset of the vertexTexCoord using derivative
	vec2 Coord[3]; //Array fo index of near vertTexCoord
    vec4 Texel[6]; //Array of Texels
    vec3 Normal; //NormalMap
    vec3 Sobel1 = vec3(0.2990, 0.5870, 0.1140) * sobel1Scale;
    vec3 Sobel2 = vec3(0.2990, 0.5870, 0.1140) * sobel2Scale;

   //3x3 kernel offset
   Coord[0] = vertTexCoord.st - d; 
   Coord[1] = vertTexCoord.st;
   Coord[2] = vertTexCoord.st + d;


	//Sobel operator, U direction
   Texel[0] = Desaturate(texture2D(texture, vec2(Coord[2].s, Coord[0].t), Blur).rgb, 1.0) - Desaturate(texture2D(texture, vec2(Coord[0].s, Coord[0].t), Blur).rgb, 1.0);
   Texel[1] = Desaturate(texture2D(texture, vec2(Coord[2].s, Coord[1].t), Blur).rgb, 1.0) - Desaturate(texture2D(texture, vec2(Coord[0].s, Coord[1].t), Blur).rgb, 1.0);
   Texel[2] = Desaturate(texture2D(texture, vec2(Coord[2].s, Coord[2].t), Blur).rgb, 1.0) - Desaturate(texture2D(texture, vec2(Coord[0].s, Coord[2].t), Blur).rgb, 1.0);

   //Sobel operator, V direction
   Texel[3] = Desaturate(texture2D(texture, vec2(Coord[0].s, Coord[0].t), Blur).rgb, 1.0) - Desaturate(texture2D(texture, vec2(Coord[0].s, Coord[2].t), Blur).rgb, 1.0);
   Texel[4] = Desaturate(texture2D(texture, vec2(Coord[1].s, Coord[0].t), Blur).rgb, 1.0) - Desaturate(texture2D(texture, vec2(Coord[1].s, Coord[2].t), Blur).rgb, 1.0);
   Texel[5] = Desaturate(texture2D(texture, vec2(Coord[2].s, Coord[0].t), Blur).rgb, 1.0) - Desaturate(texture2D(texture, vec2(Coord[2].s, Coord[2].t), Blur).rgb, 1.0);

   //Compute luminance from each texel, apply kernel weights, and sum them all
   Normal.s  = dot(Texel[0].rgb, Sobel1);
   Normal.s += dot(Texel[1].rgb, Sobel2);
   Normal.s += dot(Texel[2].rgb, Sobel1);

   Normal.t  = dot(Texel[3].rgb, Sobel1);
   Normal.t += dot(Texel[4].rgb, Sobel2);
   Normal.t += dot(Texel[5].rgb, Sobel1);

   Normal.p = dot(texture2D(texture, Coord[1], Blur).rgb, Lum);
   
   vec4 normalMap = vec4(vec3(0.5, 0.5, 1.) + normalize(vec3(Normal.xy, 0.5)) * 0.5, 1.0);
   
	fragColor = normalMap;
}
