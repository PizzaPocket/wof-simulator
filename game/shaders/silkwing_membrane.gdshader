shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/dragon_iridescence.gdshaderinc"
uniform float iridescence_strength = 0.65;
void fragment() {
	vec3 base = COLOR.rgb;
	vec3 color = dragon_sheen(base, NORMAL, VIEW, iridescence_strength);
	ALBEDO = OUTPUT_IS_SRGB ? mix(color*12.92,1.055*pow(max(color,vec3(0)),vec3(1.0/2.4))-.055,step(vec3(.0031308),color)) : color;
	ROUGHNESS = 0.37;
	METALLIC = 0.16;
	SPECULAR = 0.52;
	CLEARCOAT = 0.22;
}
