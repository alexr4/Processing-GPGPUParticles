#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform vec2 amount;
uniform sampler2D previousFrame;
uniform sampler2D texture;

in vec4 vertTexCoord;
in vec4 vertColor;
out vec4 fragColor;

vec2 get2DOffset(sampler2D tex, vec2 texCood){
	vec4 inputPix = texture(tex, texCood);
	if(inputPix.w > 0.95){
		inputPix.z = inputPix.z * -1;
	}
	return vec2(-1 * (inputPix.y - inputPix.x), inputPix.z);
}

void main(){
	vec2 texCoord = get2DOffset(previousFrame,  vec2(vertTexCoord.s, 1.0 - vertTexCoord.t)) * amount + vertTexCoord.st;//vec2(vertTexCoord.s, 1.0 - vertTexCoord.t);
	vec4 repos = texture(texture, texCoord.st);

	fragColor = vec4(texCoord.st, 0.0, 1.0);
}