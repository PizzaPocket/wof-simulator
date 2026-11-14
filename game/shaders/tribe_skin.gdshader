shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/dragon_iridescence.gdshaderinc"
uniform float iridescence_strength = 0.0;
uniform bool clay_mode = false;
uniform float surface_specular = .34;
varying vec3 point;
void vertex() { point = VERTEX; }
vec3 hash3(vec3 p) {
	p = vec3(dot(p,vec3(127.1,311.7,74.7)),dot(p,vec3(269.5,183.3,246.1)),dot(p,vec3(113.5,271.9,124.6)));
	return fract(sin(p)*43758.5453);
}
void fragment() {
	vec3 cell = floor(point*29.0);
	vec3 f = fract(point*29.0);
	float nearest = 8.0;
	float second = 8.0;
	for(int x=-1;x<=1;x++) for(int y=-1;y<=1;y++) for(int z=-1;z<=1;z++) {
		vec3 q=vec3(float(x),float(y),float(z));
		vec3 v=q+hash3(cell+q)*0.72-f;
		float d=dot(v,v);
		if(d<nearest){second=nearest;nearest=d;}else if(d<second){second=d;}
	}
	float edge=1.0-smoothstep(.012,.055,sqrt(second)-sqrt(nearest));
	vec3 color = COLOR.rgb * (1.0-edge*.22);
	// The pale ventral pigment stays coherent across jaw and neck angles.
	float sheen_mask = clamp((COLOR.b-COLOR.r)*6.0,0.0,1.0);
	color = dragon_sheen(color, NORMAL, VIEW, iridescence_strength*sheen_mask);
	if(clay_mode) color=vec3(.50,.46,.40);
	ALBEDO = OUTPUT_IS_SRGB ? mix(color*12.92,1.055*pow(max(color,vec3(0)),vec3(1.0/2.4))-.055,step(vec3(.0031308),color)) : color;
	ROUGHNESS = mix(.58,.41,iridescence_strength);
	METALLIC = iridescence_strength*.12;
	SPECULAR = mix(surface_specular,.48,iridescence_strength);
}
